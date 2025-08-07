module ActionPush
  module NotificationBuilder
    extend ActiveSupport::Concern

    prepended do
      class_attribute :default_apns_payload
      class_attribute :default_fcm_payload
      class_attribute :default_data
      class_attribute :default_high_priority
    end

    def initialize(...)
      @apns_payload = self.default_apns_payload
      @fcm_payload = self.default_fcm_payload
      @data = self.default_data
      @high_priority = self.default_high_priority
      super
    end

    class_methods do
      def with_data(data)
        Class.new(self) do
          self.default_data ||= {}
          self.default_data.merge! data
        end
      end

      def with_apple(apple_data)
        Class.new(self) do
          self.default_apns_payload ||= {}
          self.default_apns_payload.merge! apple_data
        end
      end

      def with_google(google_data)
        Class.new(self) do
          self.default_fcm_payload ||= {}
          self.default_fcm_payload.merge! google_data
        end
      end

      def silent
        Class.new(self) do
          self.default_high_priority = false
        end.with_apple(content_available: 1)
      end
    end
  end
end
