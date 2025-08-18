# frozen_string_literal: true

require "zeitwerk"
require "action_native_push/engine"
require "action_native_push/errors"
require "net/http"
require "apnotic"
require "googleauth"

loader= Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
loader.ignore("#{__dir__}/generators")
loader.ignore("#{__dir__}/action_native_push/errors.rb")
loader.setup

module ActionNativePush
  def self.service_for(platform, notification)
    platform_config = config_for(platform, notification)

    case platform.to_sym
    when :apple
      Service::Apns.new(platform_config)
    when :google
      Service::Fcm.new(platform_config)
    else
      raise "ActionNativePush: '#{platform}' platform is unsupported"
    end
  end

  def self.config_for(platform, notification)
    platform_config = Rails.application.config_for(:push)[platform.to_sym]
    raise "ActionNativePush: '#{platform}' platform is not configured" unless platform_config.present?

    if notification.application.present?
      notification_config = platform_config.fetch(notification.application.to_sym, {})
      platform_config.fetch(:application, {}).merge(notification_config)
    else
      platform_config
    end
  end
end
