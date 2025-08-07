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
      @notification.apns_payload = { category: "readable" }
      @notification.fcm_payload = { notification: { collapse_key: "1" } }
      @notification.data = { badge: "1" }
      assert_equal({ title: "Hi!",
                     body: "This is a push notification",
                     badge: 1,
                     thread_id: "12345",
                     sound: "default",
                     high_priority: false,
                     apns_payload: { category: "readable" },
                     fcm_payload: { notification: { collapse_key: "1" } },
                     data: { badge: "1" },
                     calendar_id: 1 }, @notification.as_json)
    end

    test "legacy fields deserialization" do
      attributes = {
        service_payload: {
          apns: { category: "readable" },
          fcm:  { data: { badge: "1" } }
        },
        context: { notification_id: 123 },
        custom_payload: { person: "Jacopo", extras: nil }
      }
      notification = ActionPush::Notification.new(**attributes)

      assert_equal({ category: "readable" }, notification.apns_payload_with_fallback)
      assert_equal({ data: { badge: "1" } }, notification.fcm_payload_with_fallback)
      assert_equal({ notification_id: 123 }, notification.context)
      assert_equal({ person: "Jacopo", extras: nil }, notification.data_with_fallback)
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
