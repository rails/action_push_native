class ActionNativePush::InstallGenerator < Rails::Generators::Base
  source_root File.expand_path('templates', __dir__)

  def copy_files
    template "config/action_native_push.yml"
  end

  def copy_migrations
    rails_command "action_native_push:install:migrations"
  end
end
