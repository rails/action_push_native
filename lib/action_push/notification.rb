# frozen_string_literal: true

module ActionPush
  # = Action Push Notification
  #
  # A notification that can be delivered to devices.
  class Notification
    extend ActiveModel::Callbacks
    include Serializable

    attr_accessor :title, :body, :badge, :thread_id, :sound, :high_priority, :apns_payload, :fcm_payload, :data
    attr_accessor :context
    attr_accessor :token

    define_model_callbacks :delivery

    class_attribute :queue_name, default: ActiveJob::Base.default_queue_name
    class_attribute :enabled, default: !Rails.env.test?
    class_attribute :application

    class << self
      def queue_as(name)
        self.queue_name = name
      end

      def with_data(data)
        ConfiguredNotification.new(self, data: data)
      end

      def with_apple(apns_payload)
        ConfiguredNotification.new(self, apns_payload: apns_payload)
      end

      def with_google(fcm_payload)
        ConfiguredNotification.new(self, fcm_payload: fcm_payload)
      end

      def silent
        ConfiguredNotification.new(self, high_priority: false).with_apple(content_available: 1)
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
    #                   For silent notifications is recommended to set this to false
    #   apns_payload - Apple Push Notification Service (APNS) specific data
    #   fcm_payload - Firebase Cloud Messaging (FCM) specific data
    #   data - Custom data to be sent with the notification
    #
    #   Any extra attributes are set inside the `context` hash.
    def initialize(title: nil, body: nil, badge: nil, thread_id: nil, sound: nil, high_priority: true, apns_payload: {}, fcm_payload: {}, data: {}, **context)
      @title = title
      @body = body
      @badge = badge
      @thread_id = thread_id
      @sound = sound
      @high_priority = high_priority
      @apns_payload = apns_payload
      @fcm_payload = fcm_payload
      @data = data
      @context = context
    end

    def deliver_to(device)
      if enabled
        run_callbacks(:delivery) { device.push(self) }
      end
    end

    def deliver_later_to(devices)
      Array(devices).each do |device|
        ApplicationPushNotificationJob.set(queue: queue_name).perform_later(self.class.name, self.serialize, device)
      end
    end
  end
end
