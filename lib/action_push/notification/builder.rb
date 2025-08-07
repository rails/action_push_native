module ActionPush::Notification::Builder
  extend ActiveSupport::Concern

  prepended do
    class_attribute :default_apns_payload, default: {}
    class_attribute :default_fcm_payload, default: {}
    class_attribute :default_data, default: {}
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
      new_class_preserving_name(self) do
        self.default_data = self.default_data.merge data
      end
    end

    def with_apple(apple_data)
      new_class_preserving_name(self) do
        self.default_apns_payload = self.default_apns_payload.merge apple_data
      end
    end

    def with_google(google_data)
      new_class_preserving_name(self) do
        self.default_fcm_payload = self.default_fcm_payload.merge google_data
      end
    end

    def silent
      new_class_preserving_name(self) do
        self.default_high_priority = false
      end.with_apple(content_available: 1)
    end

    private
      def new_class_preserving_name(klass, &block)
        Class.new(klass, &block).tap do |notification_class|
          notification_class.define_singleton_method(:name) do
            klass.name
          end
        end
      end
  end
end
