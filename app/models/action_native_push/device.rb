# frozen_string_literal: true

module ActionNativePush
  class Device < ApplicationRecord
    enum :platform, ActionNativePush.configuration.supported_platforms.index_with(&:itself), validate: true

    validates_presence_of :token

    def on_token_error
      destroy!
    end
  end
end
