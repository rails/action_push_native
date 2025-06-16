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
  mattr_accessor :job_queue_name, default: ActiveJob::Base.default_queue_name
  mattr_accessor :log_job_arguments, default: false
  mattr_accessor :report_job_retries, default: false
  mattr_accessor :enabled, default: !Rails.env.test?
  mattr_accessor :applications, default: {}

  def self.supported_applications
    applications.keys.map(&:to_s)
  end
end
