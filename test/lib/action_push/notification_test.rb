require "test_helper"

module ActionPush
  class NotificationTest < ActiveSupport::TestCase
    setup do
      @notification = build_notification
      ActionPush::Notification.enabled = true
    end

    teardown do
      ActionPush::Notification.enabled = false
    end

    test "deliver_to" do
      device = action_push_devices(:iphone)
      device.expects(:push).with(@notification)

      @notification.deliver_to(device)
    end

    test "deliver_to is a noop when disabled" do
      ActionPush::Notification.enabled = false
      device = action_push_devices(:iphone)
      device.expects(:push).never

      @notification.deliver_to(device)
    end

    test "deliver_later_to" do
      @notification.deliver_later_to([ action_push_devices(:iphone), action_push_devices(:pixel9) ])
      assert_enqueued_with job: ApplicationPushNotificationJob, args: [ "ActionPush::Notification", @notification.as_json, action_push_devices(:pixel9) ]
      assert_enqueued_with job: ApplicationPushNotificationJob, args: [ "ActionPush::Notification", @notification.as_json, action_push_devices(:iphone) ]
    end

    test "as_json" do
      notification = ActionPush::Notification
        .with_apple(category: "readable")
        .with_google(notification: { collapse_key: "1" })
        .with_data(badge: "1")
        .new \
          title: "Hi!",
          body: "This is a push notification",
          badge: 1,
          thread_id: "12345",
          sound: "default",
          high_priority: false,
          calendar_id: 1

      expected = \
        {
          title: "Hi!",
          body: "This is a push notification",
          badge: 1,
          thread_id: "12345",
          sound: "default",
          high_priority: false,
          apple_data: { category: "readable" },
          google_data: { notification: { collapse_key: "1" } },
          data: { badge: "1" },
          calendar_id: 1
        }
      assert_equal(expected, notification.as_json)
    end

    private
      def build_notification
        ActionPush::Notification.new \
          title: "Hi!",
          body: "This is a push notification",
          badge: 1,
          thread_id: "12345",
          sound: "default",
          high_priority: false,
          calendar_id: 1
      end
  end
end
