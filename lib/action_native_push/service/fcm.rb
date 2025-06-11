# frozen_string_literal: true

module ActionNativePush
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

        class Payload
          def initialize(notification)
            @notification = notification
          end

          def as_json
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
                }.deep_merge(notification.platform_payload[:fcm])
              })
          end

          private
            attr_reader :notification

            def deep_compact(payload)
              payload.dig(:message, :android, :notification).try(&:compact!)
              payload.dig(:message, :android).try(&:compact!)
              payload[:message].compact!
              payload
            end
        end

        def payload_from(notification)
          Payload.new(notification).as_json
        end

        def post_request(payload)
          uri = URI("https://fcm.googleapis.com/v1/projects/#{config.fetch(:project_id)}/messages:send")
          request = Net::HTTP::Post.new(uri)
          request["Authorization"] = "Bearer #{access_token}"
          request["Content-Type"]  = "application/json"
          request.body             = payload.to_json

          Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: config[:request_timeout] || DEFAULT_TIMEOUT) do |http|
            http.request(request)
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
          reason = JSON.parse(response.body).dig("error", "message")

          Rails.logger.error("FCM response error #{code}: #{reason}")

          case
          when reason =~ /message is too big/i
            raise ActionNativePush::Errors::PayloadTooLargeError, reason
          when code == "400"
            raise ActionNativePush::Errors::BadRequestError, reason
          when code == "404"
            raise ActionNativePush::Errors::TokenError, reason
          when code.in?([ "401", "403" ])
            raise ActionNativePush::Errors::ForbiddenError, reason
          when code == "429"
            raise ActionNativePush::Errors::TooManyRequestsError, reason
          when code == "503"
            raise ActionNativePush::Errors::ServiceUnavailableError, reason
          else
            raise ActionNativePush::Errors::InternalServerError, reason
          end
        end
    end
  end
end
