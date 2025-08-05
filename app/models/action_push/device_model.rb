# frozen_string_literal: true

module ActionPush
  module DeviceModel
    extend ActiveSupport::Concern
    include ActiveSupport::Rescuable

    included do
      rescue_from(TokenError) { destroy! }
    end

    def push(notification)
       notification.token = token
       ActionPush.service_for(self, notification).push(notification)
    rescue => error
      rescue_with_handler(error) || raise
    end
  end
end
