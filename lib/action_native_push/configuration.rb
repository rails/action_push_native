# frozen_string_literal: true

module ActionNativePush
  class Configuration
    attr_accessor :job_queue_name, :log_job_arguments, :report_job_retries, :enabled, :applications

    def initialize(
      job_queue_name: ActiveJob::Base.default_queue_name,
      log_job_arguments: false,
      report_job_retries: false,
      enabled: !Rails.env.test?,
      applications: {}
    )
      @job_queue_name = job_queue_name
      @log_job_arguments = log_job_arguments
      @report_job_retries = report_job_retries
      @enabled = enabled
      @applications = applications
    end

    def supported_applications
      applications.keys.map(&:to_s)
    end
  end
end
