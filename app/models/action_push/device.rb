# frozen_string_literal: true

module ActionPush
  class Device < ApplicationRecord
    include ActiveSupport::Rescuable

    rescue_from(TokenError) { destroy! }

    belongs_to :owner, polymorphic: true, optional: true

    enum :platform, { apple: "apple", google: "google" }

    def push(notification)
       notification.token = token
       ActionPush.service_for(self, notification).push(notification)
    rescue => error
      rescue_with_handler(error) || raise
    end
  end
end
