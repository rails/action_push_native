# frozen_string_literal: true

module ActionNativePush
  class Device < ApplicationRecord
    validates :token, presence: true
    validates :platform, inclusion: { in: ActionNativePush.configuration.supported_platforms }

    def on_token_error
      destroy!
    end
  end
end
