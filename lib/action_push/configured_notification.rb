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
      @options = options.merge(data: data)
      self
    end

    def with_apple(apple_data)
      @options = options.merge(apple_data: apple_data)
      self
    end

    def with_google(google_data)
      @options = options.merge(google_data: google_data)
      self
    end

    def silent
      @options = options.merge(high_priority: false)
      with_apple(content_available: 1)
      self
    end

    private
      attr_reader :notification_class, :options
  end
end
