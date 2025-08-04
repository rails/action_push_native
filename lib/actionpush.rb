# frozen_string_literal: true

require "zeitwerk"
require "action_push/version"
require "action_push/engine"
require "net/http"
require "apnotic"
require "googleauth"

loader= Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
loader.ignore("#{__dir__}/generators")
loader.setup

module ActionPush
  mattr_accessor :applications, default: {}

  def self.supported_applications
    applications.keys.map(&:to_s)
  end
end
