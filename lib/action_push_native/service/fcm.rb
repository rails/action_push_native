# frozen_string_literal: true

module ActionPushNative
  module Service
    class Fcm
      include NetworkErrorHandling

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
          reason = \
            begin
              JSON.parse(response.body.to_s).dig("error", "message")
            rescue JSON::ParserError
              response.body.to_s
            end

          Rails.logger.error("FCM response error #{status}: #{reason}")

          case
          when reason =~ /message is too big/i
            raise ActionPushNative::PayloadTooLargeError, reason
          when status == 400
            raise ActionPushNative::BadRequestError, reason
          when status == 404
            raise ActionPushNative::TokenError, reason
          when status.in?([ 401, 403 ])
            raise ActionPushNative::ForbiddenError, reason
          when status == 429
            raise ActionPushNative::TooManyRequestsError, reason
          when status == 503
            raise ActionPushNative::ServiceUnavailableError, reason
          else
            raise ActionPushNative::InternalServerError, reason
          end
        end
    end
  end
end
