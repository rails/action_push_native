require "test_helper"

class CalendarPushNotification < ApplicationPushNotification
  self.application = "calendar"
end

# Test cases for ActionPushNative module
# These tests ensure that the ActionPushNative module correctly configures and provides services for different platforms.
# It also checks that the configuration is correctly applied based on the notification type.

class ActionPushNativeTest < ActiveSupport::TestCase
  test "service_for" do
    notification = CalendarPushNotification.new(title: "Hi")
    stub_config("push_calendar.yml")

    service = ActionPushNative.service_for(action_push_native_devices(:iphone).platform, notification)

    assert_kind_of ActionPushNative::Service::Apns, service
    expected_config = {
      key_id: "calendar_key_id",
      encryption_key: "your_apple_encryption_key",
      team_id: "your_apple_team_id",
      topic: "your.bundle.identifier",
      timeout: 60
    }
    assert_equal expected_config, service.send(:config)
  end

  test "config_for application" do
    stub_config("push_apple.yml")
    config = ActionPushNative.config_for :apple, ApplicationPushNotification.new
    expected_config = {
      key_id: "your_key_id",
      encryption_key: "your_apple_encryption_key",
      team_id: "your_apple_team_id",
      topic: "your.bundle.identifier"
    }
    assert_equal expected_config, config
  end

  test "config_for custom notification" do
    stub_config("push_calendar.yml")
    config = ActionPushNative.config_for :apple, CalendarPushNotification.new
    expected_config = {
      key_id: "calendar_key_id",
      encryption_key: "your_apple_encryption_key",
      team_id: "your_apple_team_id",
      topic: "your.bundle.identifier",
      timeout: 60
    }
    assert_equal expected_config, config
  end

  test "config_for custom notification not set for a platform" do
    stub_config("push_calendar.yml")
    config = ActionPushNative.config_for :google, CalendarPushNotification.new
    expected_config = {
      encryption_key: "your_service_account_json_file",
      project_id: "your_project_id"
    }
    assert_equal expected_config, config
  end

  test "config_for web" do
    stub_config("push_calendar.yml")
    config = ActionPushNative.config_for :web, CalendarPushNotification.new
    expected_config = {
      encryption_key: "your_service_account_json_file",
      project_id: "your_project_id"
    }
    assert_equal expected_config, config
  end

  test "service_for web" do
    notification = CalendarPushNotification.new(title: "Hello Web")
    stub_config("push_calendar.yml")

    service = ActionPushNative.service_for(:web, notification)

    assert_kind_of ActionPushNative::Service::FcmWeb, service
    expected_config = {
      encryption_key: "your_service_account_json_file",
      project_id: "your_project_id"
    }
    assert_equal expected_config, service.send(:config)
  end

  private
    def stub_config(name)
      Rails.application.stubs(:config_for).returns(YAML.load_file(file_fixture("config/#{name}"), symbolize_names: true))
    end
end
