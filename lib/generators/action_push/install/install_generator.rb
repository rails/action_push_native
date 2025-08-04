# frozen_string_literal: true

class ActionPush::InstallGenerator < Rails::Generators::Base
  source_root File.expand_path("templates", __dir__)

  def copy_files
    template "config/push.yml"
    template "app/models/application_push_notification.rb"
  end

  def copy_migrations
    rails_command "action_push:install:migrations"
  end
end
