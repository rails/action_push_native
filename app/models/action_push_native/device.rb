# frozen_string_literal: true

module ActionPushNative
  class Device < ApplicationRecord
    include ActiveSupport::Rescuable

    rescue_from(TokenError) { destroy! }

    validates :platform, presence: true
    validates :token, presence: true

    belongs_to :owner, polymorphic: true, optional: true

    enum :platform, { apple: "apple", google: "google" }

    def push(notification)
       notification.token = token
       ActionPushNative.service_for(platform, notification).push(notification)
    rescue => error
      rescue_with_handler(error) || raise
    end
  end
end
