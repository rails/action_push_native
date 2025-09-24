# frozen_string_literal: true

module ActionPushNative
  module Service
    class Fcm
      include NetworkErrorHandling

      # Per-application HTTPX session
      cattr_accessor :httpx_sessions

      def initialize(config)
        @config = config
      end

      def push(notification)
        response = httpx_session.post("v1/projects/#{config.fetch(:project_id)}/messages:send", json: payload_from(notification), headers: { authorization: "Bearer #{access_token}" })
        handle_error(response) if response.error
      end

      private
        attr_reader :config

        def httpx_session
          self.class.httpx_sessions ||= {}
          self.class.httpx_sessions[config] ||= build_httpx_session
        end

        # FCM suggests at least a 10s timeout for requests, we set 15 to add some buffer.
        # https://firebase.google.com/docs/cloud-messaging/scale-fcm#timeouts
        DEFAULT_REQUEST_TIMEOUT = 15.seconds
        DEFAULT_POOL_SIZE       = 5

        def build_httpx_session
          HTTPX.
            plugin(:persistent, close_on_fork: true).
            with(timeout: { request_timeout: config[:request_timeout] || DEFAULT_REQUEST_TIMEOUT }).
            with(pool_options: { max_connections: config[:connection_pool_size] || DEFAULT_POOL_SIZE }).
            with(origin: "https://fcm.googleapis.com")
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

        def access_token
          authorizer = Google::Auth::ServiceAccountCredentials.make_creds \
            json_key_io: StringIO.new(config.fetch(:encryption_key)),
            scope: "https://www.googleapis.com/auth/firebase.messaging"
          authorizer.fetch_access_token!["access_token"]
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
