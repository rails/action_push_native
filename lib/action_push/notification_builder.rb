module ActionPush
  module NotificationBuilder
      extend ActiveSupport::Concern

      class_methods do
        def with_data(data)
          allocate.with_data(data)
        end

        def with_apple(apple_data)
          allocate.with_apple(apple_data)
        end

        def with_google(google_data)
          allocate.with_google(google_data)
        end

        def silent
          allocate.silent
        end
      end

      def new(...)
        self.tap { send(:initialize, ...) }
      end

      def with_data(data)
        dup.tap do |notification|
          notification.data ||= {}
          notification.data.merge!(data)
        end
      end

      def with_apple(apple_data)
        dup.tap do |notification|
          notification.apns_payload ||= {}
          notification.apns_payload.merge!(apple_data)
        end
      end

      def with_google(google_data)
        dup.tap do |notification|
          notification.fcm_payload ||= {}
          notification.fcm_payload.merge!(google_data)
        end
      end

      def silent
        dup.tap do |notification|
          notification.high_priority = false
        end.with_apple(content_available: 1)
      end
  end
end
