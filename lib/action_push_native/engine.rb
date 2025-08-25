# frozen_string_literal: true

module ActionPushNative
  class Engine < ::Rails::Engine
    isolate_namespace ActionPushNative

    initializer "action_push_native.config" do |app|
      app.paths.add "config/push", with: "config/push.yml"
    end
  end
end
