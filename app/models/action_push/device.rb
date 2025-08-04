# frozen_string_literal: true

module ActionPush
  class Device < ApplicationRecord
    belongs_to :owner, polymorphic: true, optional: true

    validates :application, inclusion: { in: ActionPush.supported_applications }

    def on_token_error
      destroy!
    end
  end
end
