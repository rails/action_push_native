# frozen_string_literal: true

require "zeitwerk"
require "action_native_push/version"
require "action_native_push/engine"
require "net/http"
require "apnotic"
require "googleauth"

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/generators")
loader.setup

module ActionNativePush
  mattr_accessor :configuration, default: Configuration.new
end
