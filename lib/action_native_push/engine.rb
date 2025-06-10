# frozen_string_literal: true

module ActionNativePush
  class Engine < ::Rails::Engine
    isolate_namespace ActionNativePush

    config.action_native_push = ActiveSupport::OrderedOptions.new

    CONFIG_PATH = "config/action_native_push.yml"

    initializer "action_native_push.config" do |app|
      app.paths.add CONFIG_PATH
      config_pathname = Pathname.new(app.config.paths[CONFIG_PATH].first)
      options = config_pathname.exist? ? app.config_for(config_pathname).to_h.deep_symbolize_keys : {}

      options[:job_queue_name] = config.action_native_push.job_queue_name if config.action_native_push.job_queue_name
      options[:log_job_arguments] = config.action_native_push.log_job_arguments if config.action_native_push.log_job_arguments
      options[:report_job_retries] = config.action_native_push.report_job_retries if config.action_native_push.report_job_retries
      options[:enabled] = config.action_native_push.enabled if config.action_native_push.enabled
      options[:platforms] = config.action_native_push.platforms if config.action_native_push.platforms

      ActionNativePush.configuration = ActionNativePush::Configuration.new(**options)
    end
  end
end
