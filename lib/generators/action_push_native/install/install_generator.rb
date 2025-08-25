# frozen_string_literal: true

class ActionPushNative::InstallGenerator < Rails::Generators::Base
  source_root File.expand_path("templates", __dir__)

  def copy_files
    template "config/push.yml"
    template "app/models/application_push_notification.rb"
    template "app/models/application_push_device.rb"
    template "app/jobs/application_push_notification_job.rb"
  end
end
