# frozen_string_literal: true

require "zeitwerk"
require "action_push/engine"
require "action_push/errors"
require "net/http"
require "apnotic"
require "googleauth"

loader= Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
loader.ignore("#{__dir__}/generators")
loader.ignore("#{__dir__}/action_push/errors.rb")
loader.setup

module ActionPush
  def self.service_for(platform, notification)
    platform_config = config_for(platform, notification.class)

    case platform.to_sym
    when :apple
      Service::Apns.new(platform_config)
    when :google
      Service::Fcm.new(platform_config)
    else
      raise "ActionPush: '#{platform}' Platform is unsupported"
    end
  end

  def self.config_for(platform, notification_class)
    platform_config = config[platform.to_sym]
    raise "ActionPush: '#{platform}' Platform is not configured" unless platform_config.present?

    if application_config = platform_config.delete(:application)
      notification_class_config = platform_config.fetch(to_underscore(notification_class).to_sym, {})
      application_config.merge(notification_class_config)
    else
      platform_config
    end
  end

  private
    def self.config
      Rails.application.config_for(:push)
    end

    def self.to_underscore(klass)
      klass.name.tr(":", "").underscore
    end
end
