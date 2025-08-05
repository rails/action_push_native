# frozen_string_literal: true

module ActionPush
  class Device < ApplicationRecord
    include DeviceModel

    belongs_to :owner, polymorphic: true, optional: true

    enum :platform, { apple: "apple", google: "google" }
  end
end
