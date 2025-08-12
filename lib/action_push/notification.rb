# frozen_string_literal: true

module ActionPush
  # = Action Push Notification
  #
  # A notification that can be delivered to devices.
  class Notification
    extend ActiveModel::Callbacks
    include Serializable
    prepend Builder

    attr_accessor :title, :body, :badge, :thread_id, :sound, :high_priority, :apns_payload, :fcm_payload, :data
    attr_accessor :context
    attr_accessor :token

    class_attribute :queue_name, default: ActiveJob::Base.default_queue_name

    def self.queue_as(name)
      self.queue_name = name
    end

    class_attribute :enabled, default: !Rails.env.test?
    class_attribute :application

    define_model_callbacks :delivery

    # === Attributes
    #
    #   title - The title
    #   body - The message body
    #   badge - The badge number to display on the app icon
    #   thread_id - The thread ID for grouping notifications
    #   sound - The sound to play when the notification is received
    #   high_priority - Whether to send the notification with high priority (default: true).
    #                   For silent notifications is recommended to set this to false
    #   Any extra attributes is set inside the `context` hash.
    def initialize(title: nil, body: nil, badge: nil, thread_id: nil, sound: nil, high_priority: true, **context)
      @title = title
      @body = body
      @badge = badge
      @thread_id = thread_id
      @sound = sound
      # Do not override @high_priority if it was already set earlier using .silent
      @high_priority = high_priority if @high_priority.nil?
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
