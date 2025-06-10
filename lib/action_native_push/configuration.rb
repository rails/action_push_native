# frozen_string_literal: true

module ActionNativePush
  class Configuration
    attr_accessor :job_queue_name, :log_job_arguments, :report_job_retries, :enabled, :platforms

    def initialize(
      job_queue_name: ActiveJob::Base.default_queue_name,
      log_job_arguments: false,
      report_job_retries: false,
      enabled: !Rails.env.test?,
      platforms: {}
    )
      @job_queue_name = job_queue_name
      @log_job_arguments = log_job_arguments
      @report_job_retries = report_job_retries
      @enabled = enabled
      @platforms = platforms
    end

    def supported_platforms
      platforms.keys.map(&:to_s)
    end
  end
end
