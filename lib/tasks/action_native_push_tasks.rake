# frozen_string_literal: true

desc "Copy over the migration, and the configuration template"
namespace :action_native_push do
  task :install do
    Rails::Command.invoke :generate, [ "action_native_push:install" ]
  end
end
