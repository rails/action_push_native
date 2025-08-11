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
      application_config.merge(notification_config_for(platform_config, notification_class))
    else
      platform_config
    end
  end

  private
    def self.config
      Rails.application.config_for(:push)
    end

    def self.notification_config_for(platform_config, notification_class)
      notification_config = platform_config.find do |name, options|
        expected_class_name = options[:class_name] || "#{name.to_s.camelize}PushNotification"
        expected_class_name == notification_class.name
      end&.last

      notification_config&.delete(:class_name)
      notification_config || {}
    end
end
