# frozen_string_literal: true

module ActionPush
  class Engine < ::Rails::Engine
    isolate_namespace ActionPush

    initializer "action_push.config" do |app|
      app.paths.add "config/push", with: "config/push.yml"
    end
  end
end
