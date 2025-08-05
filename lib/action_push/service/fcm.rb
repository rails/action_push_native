# frozen_string_literal: true

module ActionPush
  module Service
    class Fcm
      # FCM suggests at least a 10s timeout for requests, we set 15 to add some buffer.
      # https://firebase.google.com/docs/cloud-messaging/scale-fcm#timeouts
      DEFAULT_TIMEOUT = 15.seconds

      def initialize(config)
        @config = config
      end

      def push(notification)
        response = post_request payload_from(notification)
        handle_error(response) unless response.code == "200"
      end

      private
        attr_reader :config

        def payload_from(notification)
          deep_compact({
            message: {
              token: notification.token,
              # FCM requires data values to be strings.
              data: notification.custom_payload.compact.transform_values(&:to_s),
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
            }.deep_merge(stringify_data(notification.fcm_payload) || {})
          })
        end

        def deep_compact(payload)
          payload.dig(:message, :android, :notification).try(&:compact!)
          payload.dig(:message, :android).try(&:compact!)
          payload[:message].compact!
          payload
        end

        # FCM requires data values to be strings.
        def stringify_data(fcm_payload)
          fcm_payload&.tap do |payload|
            if payload[:data]
              payload[:data] = payload[:data].compact.transform_values(&:to_s)
            end
          end
        end

        def post_request(payload)
          uri = URI("https://fcm.googleapis.com/v1/projects/#{config.fetch(:project_id)}/messages:send")
          request = Net::HTTP::Post.new(uri)
          request["Authorization"] = "Bearer #{access_token}"
          request["Content-Type"]  = "application/json"
          request.body             = payload.to_json

          rescue_and_reraise_network_errors do
            Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: config[:request_timeout] || DEFAULT_TIMEOUT) do |http|
              http.request(request)
            end
          end
        end

        def rescue_and_reraise_network_errors
          yield
        rescue Net::ReadTimeout, Net::OpenTimeout => e
          raise ActionPush::Errors::TimeoutError, e.message
        rescue SocketError => e
          raise ActionPush::Errors::ConnectionError, e.message
        rescue OpenSSL::SSL::SSLError => e
          if e.message.include?("SSL_connect")
            raise ActionPush::Errors::ConnectionError, e.message
          else
            raise
          end
        end

        def access_token
          authorizer = Google::Auth::ServiceAccountCredentials.make_creds \
            json_key_io: StringIO.new(config.fetch(:encryption_key)),
            scope: "https://www.googleapis.com/auth/firebase.messaging"
          authorizer.fetch_access_token!["access_token"]
        end

        def handle_error(response)
          code = response.code
          reason = \
            begin
              JSON.parse(response.body).dig("error", "message")
            rescue JSON::ParserError
              response.body
            end

          Rails.logger.error("FCM response error #{code}: #{reason}")

          case
          when reason =~ /message is too big/i
            raise ActionPush::Errors::PayloadTooLargeError, reason
          when code == "400"
            raise ActionPush::Errors::BadRequestError, reason
          when code == "404"
            raise ActionPush::Errors::TokenError, reason
          when code.in?([ "401", "403" ])
            raise ActionPush::Errors::ForbiddenError, reason
          when code == "429"
            raise ActionPush::Errors::TooManyRequestsError, reason
          when code == "503"
            raise ActionPush::Errors::ServiceUnavailableError, reason
          else
            raise ActionPush::Errors::InternalServerError, reason
          end
        end
    end
  end
end
