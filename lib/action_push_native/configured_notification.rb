module ActionPushNative
  class ConfiguredNotification
    def initialize(notification_class)
      @notification_class = notification_class
      @options = {}
    end

    def new(**attributes)
      notification_class.new(**attributes.merge(options))
    end

    def with_data(data)
      @options[:data] = @options.fetch(:data, {}).merge(data)
      self
    end

    def silent
      @options = options.merge(high_priority: false)
      with_apple(aps: { "content-available": 1 })
    end

    def with_apple(apple_data)
      @options[:apple_data] = @options.fetch(:apple_data, {}).merge(apple_data)
      self
    end

    def with_google(google_data)
      @options[:google_data] = @options.fetch(:google_data, {}).merge(google_data)
      self
    end

    def with_web(web_data)
      @options[:web_data] = @options.fetch(:web_data, {}).merge(web_data)
      self
    end

    private
      attr_reader :notification_class, :options
  end
end
