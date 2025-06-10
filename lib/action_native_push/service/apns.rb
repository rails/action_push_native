# frozen_string_literal: true

module ActionNativePush
  module Service
    class Apns
      DEFAULT_TIMEOUT   = 30.seconds
      DEFAULT_POOL_SIZE = 5

      def initialize(config)
        @config = config
      end

      # Per-platform connection pools
      cattr_accessor :connection_pools

      def push(notification)
        reset_connection_error

        connection_pool.with do |connection|
          response = connection.push \
            apnotic_notification_from(notification),
            timeout: config[:request_timeout] || DEFAULT_TIMEOUT
          handle_connection_error(connection_error) if connection_error
          handle_response_error(response) unless response&.ok?
        end
      end

      private
        attr_reader :config, :connection_error

        def reset_connection_error
          @connection_error = nil
        end

        def connection_pool
          self.class.connection_pools ||= {}
          self.class.connection_pools[config] ||= build_connection_pool
        end

        def build_connection_pool
          build_method = config[:connect_to_development_server] ? "development" : "new"
          Apnotic::ConnectionPool.public_send(build_method, {
            auth_method: :token,
            cert_path: StringIO.new(config.fetch(:encryption_key)),
            key_id: config.fetch(:key_id),
            team_id: config.fetch(:team_id)
          }, size: config[:connection_pool_size] || DEFAULT_POOL_SIZE) do |connection|
            # Prevent the main thread from crashing collecting errors and handling them afterwards.
            connection.on(:error) { |error| @connection_error = error }
          end
        end

        def apnotic_notification_from(notification)
          Apnotic::Notification.new(notification.token).tap do |n|
            n.topic = config.fetch(:topic)
            n.alert = { title: notification.title, body: notification.body }.compact
            n.badge = notification.badge
            n.thread_id = notification.thread_id
            n.sound = notification.sound
            notification.platform_payload[:apns].each do |key, value|
              n.public_send("#{key.to_s.underscore}=", value)
            end
            n.custom_payload = notification.custom_payload
          end
        end

        def handle_connection_error(error)
          Rails.logger.error("APNs connection error: #{error.message}")
          # Bubble up connection errors, let job handle retries.
          raise error
        end

        def handle_response_error(response)
          code = response&.status
          reason = response.body["reason"] if response

          Rails.logger.error("APNs response error #{code}: #{reason}")

          case [ code, reason ]
          in [nil, _]
            raise ActionNativePush::Errors::TimeoutError
          in ["400", "BadDeviceToken"]
            raise ActionNativePush::Errors::DeviceTokenError, reason
          in ["400", _]
            raise ActionNativePush::Errors::BadRequestError, reason
          in ["403", _]
            raise ActionNativePush::Errors::ForbiddenError, reason
          in ["404", _]
            raise ActionNativePush::Errors::NotFoundError, reason
          in ["410", _]
            raise ActionNativePush::Errors::ExpiredTokenError, reason
          in ["413", _]
            raise ActionNativePush::Errors::PayloadTooLargeError, reason
          in ["429", _]
            raise ActionNativePush::Errors::TooManyRequestsError, reason
          in ["503", _]
            raise ActionNativePush::Errors::ServiceUnavailableError, reason
          else
            raise ActionNativePush::Errors::InternalServerError, reason
          end
        end
    end
  end
end
