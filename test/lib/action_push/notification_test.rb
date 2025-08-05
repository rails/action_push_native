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

    test "as_json" do
      as_json = @notification.with_apple(category: "readable").with_google(data: { badge: "1" }).as_json
      assert_equal({ title: "Hi!",
                     body: "This is a push notification",
                     badge: 1,
                     thread_id: "12345",
                     sound: "default",
                     high_priority: false,
                     apns_payload: { category: "readable" },
                     fcm_payload: { data: { badge: "1" } },
                     context: { calendar_id: 1 } }, as_json)
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
      assert_equal({ person: "Jacopo", extras: nil }, notification.custom_payload)
    end

    test "silent notification" do
      notification = ActionPush::Notification.silent
      assert_equal false, notification.high_priority
      assert_equal({ content_available: 1 }, notification.apns_payload)
    end

    test "with_apple and with_google are non destructive" do
      notification = @notification.with_apple(category: "readable").with_apple(thread_id: "67890")
      assert_equal({ category: "readable", thread_id: "67890" }, notification.apns_payload)
      assert_nil @notification.apns_payload

      notification = @notification.with_google(data: { badge: "1" }).with_google(android: { notification_count: 1 })
      assert_equal({ data: { badge: "1" }, android: { notification_count: 1 } }, notification.fcm_payload)
      assert_nil @notification.fcm_payload
    end

    test "deliver_later_to" do
      @notification.deliver_later_to([ action_push_devices(:iphone), action_push_devices(:pixel9) ])
      assert_enqueued_with job: ApplicationPushNotificationJob, args: [ "ActionPush::Notification", @notification.as_json, action_push_devices(:pixel9) ]
      assert_enqueued_with job: ApplicationPushNotificationJob, args: [ "ActionPush::Notification", @notification.as_json, action_push_devices(:iphone) ]
    end

    test "deliver_to APNs" do
      device = action_push_devices(:iphone)

      apns = stub(:apns)
      apns.expects(:push).with(@notification)
      ActionPush::Service::Apns.expects(:new).with(ActionPush.config_for(:apple, @notification)).returns(apns)

      assert_changes -> { @notification.token }, from: nil, to: device.token do
        @notification.deliver_to(device)
      end
    end

    test "deliver_to FCM" do
      device = action_push_devices(:pixel9)

      fcm = stub(:fcm)
      fcm.expects(:push).with(@notification)
      ActionPush::Service::Fcm.expects(:new).with(ActionPush.config_for(:google, @notification)).returns(fcm)

      assert_changes -> { @notification.token }, from: nil, to: device.token do
        @notification.deliver_to(device)
      end
    end

    test "deliver_to calls device.on_token_error callback on token error" do
      device = action_push_devices(:iphone)

      device.expects(:on_token_error).once
      ActionPush::Service::Apns.any_instance.expects(:push).raises(ActionPush::TokenError)

      @notification.deliver_to(device)
    end

    test "deliver_to is a noop when disabled" do
      ActionPush::Notification.enabled = false
      device = action_push_devices(:iphone)
      ActionPush::Service::Apns.any_instance.expects(:push).never

      @notification.deliver_to(device)
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
