# frozen_string_literal: true

module ActionNativePush
  class Device < ApplicationRecord
    belongs_to :record, polymorphic: true, optional: true

    validates_presence_of :token
    validates :application, inclusion: { in: ActionNativePush.configuration.supported_applications }

    def on_token_error
      destroy!
    end
  end
end
