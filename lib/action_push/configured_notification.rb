module ActionPush
  class ConfiguredNotification
    def initialize(notification_class, **options)
      @notification_class = notification_class
      @options = options
    end

    def new(**attributes)
      notification_class.new(**attributes.merge(options))
    end

    def with_data(data)
      @options[:data] ||= {}
      options[:data].merge!(data)
      self
    end

    def with_apple(apple_data)
      @options[:apple_data] ||= {}
      options[:apple_data].merge!(apple_data)
      self
    end

    def with_google(google_data)
      @options[:google_data] ||= {}
      options[:google_data].merge!(google_data)
      self
    end

    def silent
      options.merge!(high_priority: false)
      with_apple(content_available: 1)
    end

    private
      attr_reader :notification_class, :options
  end
end
