# frozen_string_literal: true

module ActionPushNative
  module Service
    class Fcm
      include NetworkErrorHandling
      prepend Instrumentation

      def initialize(config)
        @config = config
      end

      def push(notification)
        response = httpx_session.post("v1/projects/#{config.fetch(:project_id)}/messages:send", json: payload_from(notification))
        handle_error(response) if response.error
      end

      private
        attr_reader :config

        HTTPX_SESSIONS_KEY = :action_push_native_fcm_httpx_sessions

        def httpx_session
          ActiveSupport::IsolatedExecutionState[HTTPX_SESSIONS_KEY] ||= {}
          ActiveSupport::IsolatedExecutionState[HTTPX_SESSIONS_KEY][config] ||= HttpxSession.new(config)
        end

        def payload_from(notification)
          deep_compact({
            message: {
              token: notification.token,
              data: notification.data ? stringify(notification.data) : {},
              android: {
                notification: {
                  title: notification.title,
                  body: notification.body,
                  notification_count: notification.badge,
                  sound: notification.sound
                },
                collapse_key: notification.thread_id,
                priority: notification.high_priority == true ? "high" : "normal"
              }
            }.deep_merge(notification.google_data ? stringify_data(notification.google_data) : {})
          })
        end

        def deep_compact(payload)
          payload.dig(:message, :android, :notification).try(&:compact!)
          payload.dig(:message, :android).try(&:compact!)
          payload[:message].compact!
          payload
        end

        # FCM requires data values to be strings.
        def stringify_data(google_data)
          google_data.tap do |payload|
            payload[:data] = stringify(payload[:data]) if payload[:data]
          end
        end

        def stringify(hash)
          hash.compact.transform_values(&:to_s)
        end

        def handle_error(response)
          if response.is_a?(HTTPX::ErrorResponse)
            handle_network_error(response.error)
          else
            handle_fcm_error(response)
          end
        end

        def handle_fcm_error(response)
          status = response.status
          error = \
            begin
              JSON.parse(response.body.to_s)["error"]
            rescue JSON::ParserError
              nil
            end
          message = error ? error["message"] : response.body.to_s

          Rails.logger.error("FCM response error #{status}: #{message}")

          error_class = \
            case
            when message =~ /message is too big/i
              ActionPushNative::PayloadTooLargeError
            when status == 400
              ActionPushNative::BadRequestError
            when status == 404
              ActionPushNative::TokenError
            when status.in?([ 401, 403 ])
              ActionPushNative::ForbiddenError
            when status == 429
              ActionPushNative::TooManyRequestsError
            when status == 503
              ActionPushNative::ServiceUnavailableError
            else
              ActionPushNative::InternalServerError
            end

          raise error_class.new(message, service: :fcm, status: error&.fetch("status", nil) || status,
            reason: error_info_reason_from(error), retry_after: response.headers["retry-after"])
        end

        # The bounded, machine-readable token lives in the google.rpc.ErrorInfo
        # detail (QUOTA_EXCEEDED, UNREGISTERED, ...); the message is free-form.
        def error_info_reason_from(error)
          Array(error&.fetch("details", nil)).filter_map { |detail| detail["reason"] }.first
        end
    end
  end
end
