# frozen_string_literal: true

module ActionPush
  class Device < ApplicationRecord
    belongs_to :owner, polymorphic: true, optional: true

    enum :platform, { apple: "apple", google: "google" }

    def on_token_error
      destroy!
    end
  end
end
