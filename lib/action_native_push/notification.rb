# frozen_string_literal: true

module ActionNativePush
  # = Action Native Push Notification
  #
  # A notification that can be delivered to devices.
  class Notification
    include ActiveSupport::Callbacks

    attr_accessor :title, :body, :badge, :thread_id, :sound, :high_priority, :service_payload, :custom_payload
    attr_accessor :context
    attr_accessor :token

    define_callbacks :delivery
    set_callback     :delivery, :before, -> { self.class.before_delivery(self) }

    class << self
      def before_delivery(notification)
        @before_delivery&.call(notification)
      end

      def before_delivery=(block)
        @before_delivery = block
      end
    end

    # === Attributes
    #
    #   title - The title
    #   body - The message body
    #   badge - The badge number to display on the app icon
    #   thread_id - The thread ID for grouping notifications
    #   sound - The sound to play when the notification is received
    #   high_priority - Whether to send the notification with high priority (default: true).
    #                   For silent notifications is recommended to set this to false.
    #   service_payload - A hash of platform-specific payload data keyed by platform (e.g., :apns, :fcm)
    #   platform_payload - temporary field used for in-flight jobs backward compatibility, will be removed in future versions
    #   custom_payload - A hash of custom data to include in the notification
    #   context - A hash of additional context data that won't be sent to the device, but can be used in callbacks
    def initialize(title: nil, body: nil, badge: nil, thread_id: nil, sound: nil, high_priority: true, service_payload: {}, platform_payload: {}, custom_payload: {}, context: {})
      @title = title
      @body = body
      @badge = badge
      @thread_id = thread_id
      @sound = sound
      @high_priority = high_priority
      @service_payload = service_payload.present? ? service_payload : platform_payload
      @custom_payload = custom_payload
      @context = context
    end

    def deliver_to(device)
      return unless ActionNativePush.enabled

      self.token = device.token
      begin
        run_callbacks :delivery do
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
      {
        title: title,
        body: body,
        badge: badge,
        thread_id: thread_id,
        sound: sound,
        high_priority: high_priority,
        service_payload: service_payload.compact,
        custom_payload: custom_payload.compact,
        context: context
      }.compact
    end

    private
      def service_for(device)
        service_config = ActionNativePush.applications[device.application.to_sym]
        raise "ActionNativePush: Application #{device.application} is not configured" unless service_config
        service_class = "ActionNativePush::Service::#{service_config[:service].capitalize}".constantize
        service_class.new(service_config)
      end
  end
end
