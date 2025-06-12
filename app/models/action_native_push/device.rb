# frozen_string_literal: true

module ActionNativePush
  class Device < ApplicationRecord
    belongs_to :record, polymorphic: true, optional: true

    # E.g. { "ios" => "ios", "android" => "android" }
    enum :application, ActionNativePush.configuration.supported_applications.index_with(&:itself), validate: true

    validates_presence_of :token

    def on_token_error
      destroy!
    end
  end
end
