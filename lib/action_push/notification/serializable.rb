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
      apns_payload: apns_payload,
      fcm_payload: fcm_payload,
      data: data,
      **context
    }.compact
  end

  class_methods do
    def deserialize(title:, body:, badge:, thread_id:, sound:, high_priority:, apns_payload: nil, fcm_payload: nil, data: nil, service_payload: nil, custom_payload: nil, context: nil, **new_context)
      self.new(title:, body:, badge:, thread_id:, sound:, high_priority:).tap do |notification|
        # Legacy fields backward compatibility to handle in-flight jobs.
        notification.apns_payload = service_payload&.dig(:apns) || apns_payload
        notification.fcm_payload  = service_payload&.dig(:fcm)  || fcm_payload
        notification.data         = custom_payload   || data
        notification.context      = context.presence || new_context
      end
    end
  end
end
