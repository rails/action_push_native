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
          raise ActionNativePush::TimeoutError, e.message
        rescue Errno::ECONNRESET, SocketError => e
          raise ActionNativePush::ConnectionError, e.message
        rescue OpenSSL::SSL::SSLError => e
          if e.message.include?("SSL_connect")
            raise ActionNativePush::ConnectionError, e.message
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
            raise ActionNativePush::PayloadTooLargeError, reason
          when code == "400"
            raise ActionNativePush::BadRequestError, reason
          when code == "404"
            raise ActionNativePush::TokenError, reason
          when code.in?([ "401", "403" ])
            raise ActionNativePush::ForbiddenError, reason
          when code == "429"
            raise ActionNativePush::TooManyRequestsError, reason
          when code == "503"
            raise ActionNativePush::ServiceUnavailableError, reason
          else
            raise ActionNativePush::InternalServerError, reason
          end
        end
    end
  end
end
