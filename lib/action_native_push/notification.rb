# frozen_string_literal: true

module ActionNativePush
  class Notification
    include ActiveSupport::Callbacks

    attr_accessor :title, :body, :badge, :thread_id, :sound, :high_priority, :service_payload, :custom_payload
    attr_accessor :token

    define_callbacks :delivery
    set_callback     :delivery, :before, :before_delivery

    # Attributes
    #
    #   title - The title
    #   body - The message body
    #   badge - The badge number to display on the app icon
    #   thread_id - The thread ID for grouping notifications
    #   sound - The sound to play when the notification is received
    #   high_priority - Whether to send the notification with high priority (default: true)
    #   service_payload - A hash of platform-specific payload data keyed by platform (e.g., :apns, :fcm)
    #   platform_payload - temporary field used for backward compatibility, will be removed in future versions
    #   custom_payload - A hash of custom data to include in the notification
    def initialize(title: nil, body: nil, badge: nil, thread_id: nil, sound: nil, high_priority: true, service_payload: {}, platform_payload: {}, custom_payload: {})
      @title = title
      @body = body
      @badge = badge
      @thread_id = thread_id
      @sound = sound
      @high_priority = high_priority
      @service_payload = service_payload.present? ? service_payload : platform_payload
      @custom_payload = custom_payload
    end

    def deliver_to(device)
      return unless ActionNativePush.configuration.enabled

      self.token = device.token
      begin
        run_callbacks :delivery do |args|
          service_for(device).push(self)
        end
      rescue Errors::TokenError
        Rails.logger.info("Device##{device.id} token is invalid")
        device.on_token_error
      end
    end

    def deliver_later_to(devices)
      Array(devices).each do |device|
        NotificationDeliveryJob.perform_later(self.as_json, device)
      end
    end

    def as_json
      { title: title, body: body, badge: badge, thread_id: thread_id, sound: sound, high_priority: high_priority, service_payload: service_payload.compact, custom_payload: custom_payload.compact }.compact
    end

    def before_delivery(&block)
      block ? @before_delivery = block : @before_delivery&.call(self)
    end

    private
      def service_for(device)
        service_config = ActionNativePush.configuration.applications[device.application.to_sym]
        raise "ActionNativePush:: Application #{device.application} is not configured" unless service_config
        service_class = "ActionNativePush::Service::#{service_config[:service].capitalize}".constantize
        service_class.new(service_config)
      end
  end
end
