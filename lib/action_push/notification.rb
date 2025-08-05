# frozen_string_literal: true

module ActionPush
  # = Action Push Notification
  #
  # A notification that can be delivered to devices.
  class Notification
    extend ActiveModel::Callbacks
    include NotificationBuilder

    attr_accessor :title, :body, :badge, :thread_id, :sound, :high_priority, :apns_payload, :fcm_payload
    attr_accessor :context
    attr_accessor :token
    # Legacy fields which will be removed in the next release.
    attr_accessor :service_payload, :custom_payload

    class_attribute :queue_name, default: ActiveJob::Base.default_queue_name

    def self.queue_as(name)
      self.queue_name = name
    end

    class_attribute :enabled, default: !Rails.env.test?

    define_model_callbacks :delivery

    # === Attributes
    #
    #   title - The title
    #   body - The message body
    #   badge - The badge number to display on the app icon
    #   thread_id - The thread ID for grouping notifications
    #   sound - The sound to play when the notification is received
    #   high_priority - Whether to send the notification with high priority (default: true).
    #                   For silent notifications is recommended to set this to false.
    #   service_payload, custom_payload, context - Legacy fields to handle in-flight jobs deserialization.
    #
    #   Any extra attributes is set inside the `context` hash.
    def initialize(title: nil, body: nil, badge: nil, thread_id: nil, sound: nil, high_priority: true, service_payload: {}, custom_payload: {}, context: {}, **new_context)
      @title = title
      @body = body
      @badge = badge
      @thread_id = thread_id
      @sound = sound
      @high_priority = high_priority
      # Legacy fields to handle in-flight jobs deserialization.
      @service_payload = service_payload
      @custom_payload = custom_payload
      @context = context.presence || new_context
    end

    # Backward compatibilty methods.
    def apns_payload_with_fallback
      @apns_payload || service_payload[:apns]
    end

    def fcm_payload_with_fallback
       @fcm_payload || service_payload[:fcm]
    end

    def deliver_to(device)
      return unless enabled

      self.token = device.token
      begin
        run_callbacks :delivery do
          ActionPush.service_for(device, self.class).push(self)
        end
      rescue Errors::TokenError => e
        Rails.logger.info("Device##{device.id} token is invalid: #{e.message}")
        device.on_token_error
      end
    end

    def deliver_later_to(devices)
      Array(devices).each do |device|
        ApplicationPushNotificationJob.set(queue: queue_name).perform_later(self.class.name, self.as_json, device)
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
        context: context,
        apns_payload: apns_payload,
        fcm_payload: fcm_payload
      }.compact
    end
  end
end
