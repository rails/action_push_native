# frozen_string_literal: true

module ActionPushNative
  # = Action Push Native Notification
  #
  # A notification that can be delivered to devices.
  class Notification
    extend ActiveModel::Callbacks

    attr_accessor :title, :body, :badge, :thread_id, :sound, :high_priority, :apple_data, :google_data, :web_data, :data
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

      delegate :with_data, :silent, :with_apple, :with_google, :with_web, to: :configured_notification

      private
        def configured_notification
          ConfiguredNotification.new(self)
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
    #   apple_data - Apple Push Notification Service (APNS) specific data
    #   google_data - Firebase Cloud Messaging (FCM) specific data for Android
    #   web_data - Firebase Cloud Messaging (FCM) specific data for Web Push
    #   data - Custom data to be sent with the notification
    #
    #   Any extra attributes are set inside the `context` hash.
    def initialize(title: nil, body: nil, badge: nil, thread_id: nil, sound: nil, high_priority: true, apple_data: {}, google_data: {}, web_data: {}, data: {}, **context)
      @title = title
      @body = body
      @badge = badge
      @thread_id = thread_id
      @sound = sound
      @high_priority = high_priority
      @apple_data = apple_data
      @google_data = google_data
      @web_data = web_data
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
        apple_data: apple_data,
        google_data: google_data,
        web_data: web_data,
        data: data,
        **context
      }.compact
    end
  end
end
