# frozen_string_literal: true

class ActionNativePush::InstallGenerator < Rails::Generators::Base
  source_root File.expand_path("templates", __dir__)

  def copy_files
    template "config/push.yml"
  end

  def copy_migrations
    rails_command "action_native_push:install:migrations"
  end
end
