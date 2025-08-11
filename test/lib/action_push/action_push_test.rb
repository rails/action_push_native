require "test_helper"

class CalendarPushNotification < ApplicationPushNotification; end
class CalendarCustomPushNotification < ApplicationPushNotification; end

class ActionPushTest < ActiveSupport::TestCase
  test "service_for" do
    notification = CalendarPushNotification.new(title: "Hi")
    stub_config("push_apple_calendar.yml")

    service = ActionPush.service_for(action_push_devices(:iphone).platform, notification)

    assert_kind_of ActionPush::Service::Apns, service
    expected_config = {
      key_id: "calendar_key_id",
      encryption_key: "your_apple_encryption_key",
      team_id: "your_apple_team_id",
      topic: "your.bundle.identifier",
      timeout: 30
    }
    assert_equal expected_config, service.send(:config)
  end

  test "config_for" do
    [ CalendarPushNotification, ApplicationPushNotification ].each do |notification_class|
      stub_config("push_apple.yml")
      config = ActionPush.config_for :apple, notification_class
      expected_config = {
        key_id: "your_key_id",
        encryption_key: "your_apple_encryption_key",
        team_id: "your_apple_team_id",
        topic: "your.bundle.identifier"
      }
      assert_equal expected_config, config
    end
  end

  test "config_for using custom notifications" do
    stub_config("push_apple_calendar.yml")
    config = ActionPush.config_for :apple, ApplicationPushNotification
    expected_config = {
      key_id: "your_key_id",
      encryption_key: "your_apple_encryption_key",
      team_id: "your_apple_team_id",
      topic: "your.bundle.identifier"
    }
    assert_equal expected_config, config

    stub_config("push_apple_calendar.yml")
    config = ActionPush.config_for :apple, CalendarPushNotification
    expected_config = {
      key_id: "calendar_key_id",
      encryption_key: "your_apple_encryption_key",
      team_id: "your_apple_team_id",
      topic: "your.bundle.identifier",
      timeout: 30
    }
    assert_equal expected_config, config

    stub_config("push_apple_calendar.yml")
    config = ActionPush.config_for :apple, CalendarCustomPushNotification
    expected_config = {
      key_id: "your_key_id",
      encryption_key: "your_apple_encryption_key",
      team_id: "your_apple_team_id",
      topic: "your.bundle.identifier",
      timeout: 60
    }
    assert_equal expected_config, config
  end

  private
    def stub_config(name)
      ActionPush.stubs(:config).returns(YAML.load_file(file_fixture("config/#{name}"), symbolize_names: true))
    end
end
