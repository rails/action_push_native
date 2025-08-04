# frozen_string_literal: true

module ActionPush
  class Engine < ::Rails::Engine
    isolate_namespace ActionPush

    config.action_push = ActiveSupport::OrderedOptions.new

    initializer "action_push.config" do |app|
      app.paths.add "config/push", with: "config/push.yml"

      config_path = Pathname.new(app.config.paths["config/push"].first)
      options = config_path.exist? ? app.config_for(config_path).to_h : {}

      options[:applications] = config.action_push.applications if config.action_push.applications

      options.each do |name, value|
        ActionPush.public_send("#{name}=", value)
      end
    end
  end
end
