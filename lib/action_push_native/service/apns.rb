# frozen_string_literal: true

module ActionPushNative
  module Service
    class Apns
      def initialize(config)
        @config = config
      end

      # Per-application HTTPX session
      cattr_accessor :httpx_sessions

      def push(notification)
        notification.apple_data = ApnoticLegacyConverter.convert(notification.apple_data) if notification.apple_data.present?

        headers, payload = headers_from(notification), payload_from(notification)
        Rails.logger.info("Pushing APNs notification: #{headers[:"apns-id"]}")
        response = httpx_session.post("https://api.push.apple.com/3/device/#{notification.token}", json: payload, headers: headers)
        handle_error(response) if response.error
      end

      private
        attr_reader :config

        PRIORITIES = { high: 10, normal: 5 }.freeze
        HEADERS = %i[ apns-id apns-push-type apns-priority apns-topic apns-expiration apns-collapse-id ].freeze

        def headers_from(notification)
          push_type = notification.apple_data&.dig(:aps, :"content-available") == 1 ? "background" : "alert"
          custom_apple_headers = notification.apple_data&.slice(*HEADERS) || {}

          {
            "apns-push-type": push_type,
            "apns-id": SecureRandom.uuid,
            "apns-priority": notification.high_priority ? PRIORITIES[:high] : PRIORITIES[:normal],
            "apns-topic": config.fetch(:topic)
          }.merge(custom_apple_headers).compact
        end

        def payload_from(notification)
          payload = \
            {
              aps: {
                alert: { title: notification.title, body: notification.body },
                badge: notification.badge,
                "thread-id": notification.thread_id,
                sound: notification.sound
              }
            }

          payload = payload.merge notification.data if notification.data.present?
          custom_apple_payload = notification.apple_data&.except(*HEADERS) || {}
          payload = payload.deep_merge custom_apple_payload

          payload.dig(:aps, :alert)&.compact!
          payload[:aps]&.compact_blank!
          payload.compact
        end

        def httpx_session
          self.class.httpx_sessions ||= {}
          self.class.httpx_sessions[config] ||= HttpxSession.new(config)
        end

        def handle_error(response)
          if response.is_a?(HTTPX::ErrorResponse)
            handle_network_error(response.error)
          else
            handle_apns_error(response)
          end
        end

        def handle_network_error(error)
          case error
          when Errno::ETIMEDOUT, HTTPX::TimeoutError
            raise ActionPushNative::TimeoutError, error.message
          when Errno::ECONNRESET, Errno::ECONNABORTED, Errno::ECONNREFUSED, Errno::EHOSTUNREACH,
               SocketError, IOError, EOFError, Errno::EPIPE, Errno::EINVAL, HTTPX::ConnectionError,
               HTTPX::TLSError, HTTPX::Connection::HTTP2::Error
            raise ActionPushNative::ConnectionError, error.message
          when OpenSSL::SSL::SSLError
            if error.message.include?("SSL_connect")
              raise ActionPushNative::ConnectionError, error.message
            else
              raise
            end
          end
        end

        def handle_apns_error(response)
          status = response.status
          reason = JSON.parse(response.body.to_s)["reason"] unless response.body.empty?

          Rails.logger.error("APNs response error #{status}: #{reason}") if reason

          case [ status, reason ]
          in [ 400, "BadDeviceToken" ]
            raise ActionPushNative::TokenError, reason
          in [ 400, "DeviceTokenNotForTopic" ]
            raise ActionPushNative::BadDeviceTopicError, reason
          in [ 400, _ ]
            raise ActionPushNative::BadRequestError, reason
          in [ 403, _ ]
            raise ActionPushNative::ForbiddenError, reason
          in [ 404, _ ]
            raise ActionPushNative::NotFoundError, reason
          in [ 410, _ ]
            raise ActionPushNative::TokenError, reason
          in [ 413, _ ]
            raise ActionPushNative::PayloadTooLargeError, reason
          in [ 429, _ ]
            raise ActionPushNative::TooManyRequestsError, reason
          in [ 503, _ ]
            raise ActionPushNative::ServiceUnavailableError, reason
          else
            raise ActionPushNative::InternalServerError, reason
          end
        end
    end
  end
end
