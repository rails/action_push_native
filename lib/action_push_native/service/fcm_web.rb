# frozen_string_literal: true

module ActionPushNative
  module Service
    class FcmWeb < Fcm
      private
        def payload_from(notification)
          deep_compact({
            message: {
              token: notification.token,
              data: notification.data ? stringify(notification.data) : {},
              webpush: webpush_payload_from(notification)
            }.deep_merge(notification.web_data ? stringify_data(notification.web_data) : {})
          })
        end

        def webpush_payload_from(notification)
          notification_payload = {
            title: notification.title,
            body: notification.body,
            tag: notification.thread_id
          }.compact

          headers = urgency_header_for(notification)

          {
            notification: notification_payload.presence,
            headers: headers.presence
          }.compact
        end

        def urgency_header_for(notification)
          urgency = notification.high_priority == false ? "normal" : "high"
          { Urgency: urgency }.compact
        end

        def deep_compact(payload)
          payload.dig(:message, :webpush, :notification).try(&:compact!)
          payload.dig(:message, :webpush, :headers).try(&:compact!)
          payload.dig(:message, :webpush).try(&:compact!)
          payload[:message][:data] = payload[:message][:data].presence if payload[:message][:data].respond_to?(:presence)
          payload[:message].compact!
          payload
        end

        def stringify_data(web_data)
          super.tap do |payload|
            if payload[:webpush]&.key?(:data)
              payload[:webpush][:data] = stringify(payload[:webpush][:data])
            end
          end
        end
    end
  end
end
