# frozen_string_literal: true

module ActionNativePush
  class Engine < ::Rails::Engine
    isolate_namespace ActionNativePush

    initializer "action_native_push.config" do |app|
      app.paths.add "config/push", with: "config/push.yml"
    end
  end
end
