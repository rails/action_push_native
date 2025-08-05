module ActionPush
  module NotificationBuilder
      extend ActiveSupport::Concern

      class_methods do
        def with_apple(data)
          allocate.with_apple(data)
        end

        def with_google(data)
          allocate.with_google(data)
        end

        def silent
          allocate.silent
        end
      end

      def new(...)
        self.tap { send(:initialize, ...) }
      end

      def with_apple(data)
        dup.tap do |notification|
          notification.apns_payload ||= {}
          notification.apns_payload.merge!(data)
        end
      end

      def with_google(data)
        dup.tap do |notification|
          notification.fcm_payload ||= {}
          notification.fcm_payload.merge!(data)
        end
      end

      def silent
        dup.tap do |notification|
          notification.high_priority = false
        end.with_apple(content_available: 1)
      end
  end
end
