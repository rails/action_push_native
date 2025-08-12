# frozen_string_literal: true

module ActionPush::Notification::Serializable
  extend ActiveSupport::Concern

  def serialize
    {
      title: title,
      body: body,
      badge: badge,
      thread_id: thread_id,
      sound: sound,
      high_priority: high_priority,
      apple_data: apple_data.compact,
      google_data: google_data.compact,
      data: data.compact,
      **context
    }.compact
  end

  class_methods do
    def deserialize(title: nil, body: nil, badge: nil, thread_id: nil, sound: nil, high_priority: nil, apple_data: nil, google_data: nil, data: nil, service_payload: nil, custom_payload: nil, context: nil, **new_context)
      self.new(title:, body:, badge:, thread_id:, sound:, high_priority:).tap do |notification|
        # Legacy fields backward compatibility to handle in-flight jobs.
        notification.apple_data   = service_payload&.fetch(:apns, nil) || apple_data
        notification.google_data  = service_payload&.fetch(:fcm,  nil) || google_data
        notification.data         = custom_payload   || data
        notification.context      = context.presence || new_context
      end
    end
  end
end
