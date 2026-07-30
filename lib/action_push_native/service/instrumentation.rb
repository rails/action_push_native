# frozen_string_literal: true

module ActionPushNative
  module Service
    # Instruments every provider round trip, token refresh included, as a
    # push.action_push_native event. Prepended so it wraps each service's
    # own push.
    module Instrumentation
      def push(notification)
        ActiveSupport::Notifications.instrument "push.action_push_native",
          service: service_name, device_token: notification.token do |payload|
          super
        rescue ActionPushNative::Error => error
          payload[:status] = error.status
          payload[:reason] = error.reason
          payload[:retry_after] = error.retry_after
          raise
        end
      end

      private
        def service_name
          self.class.name.demodulize.underscore.to_sym
        end
    end
  end
end
