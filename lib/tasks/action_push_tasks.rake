# frozen_string_literal: true

desc "Copy over the migration, and the configuration template"
namespace :action_push do
  task :install do
    Rails::Command.invoke :generate, [ "action_push:install" ]
  end
end
