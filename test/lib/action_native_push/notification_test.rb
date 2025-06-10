require "test_helper"

module ActionNativePush
  class NotificationTest < ActiveSupport::TestCase
    test "as_json" do
      assert_equal({ title: "Hi!",
                     body: "This is a push notification",
                     badge: 1,
                     thread_id: "12345",
                     sound: "default",
                     high_priority: false,
                     platform_payload: { apns: { category: "readable" } },
                     custom_payload: { person: "Jacopo" } }, build_notification.as_json)
    end

    test "deliver_later_to" do
      notification = build_notification
      notification.deliver_later_to([ action_native_push_devices(:iphone), action_native_push_devices(:pixel9) ])
      assert_enqueued_with job: ActionNativePush::NotificationDeliveryJob, args: [ notification.as_json, action_native_push_devices(:pixel9) ]
      assert_enqueued_with job: ActionNativePush::NotificationDeliveryJob, args: [ notification.as_json, action_native_push_devices(:iphone) ]
    end

    test "deliver_to APNs" do
      notification = build_notification
      device = action_native_push_devices(:iphone)

      apns = stub(:apns)
      apns.expects(:push).with(notification)
      ActionNativePush::Service::Apns.expects(:new).with(ActionNativePush.configuration.platforms[:ios]).returns(apns)

      assert_changes -> { notification.token }, from: nil, to: device.token do
        notification.deliver_to(device)
      end
    end

    test "deliver_to FCM" do
      notification = build_notification
      device = action_native_push_devices(:pixel9)

      fcm = stub(:fcm)
      fcm.expects(:push).with(notification)
      ActionNativePush::Service::Fcm.expects(:new).with(ActionNativePush.configuration.platforms[:android]).returns(fcm)

      assert_changes -> { notification.token }, from: nil, to: device.token do
        notification.deliver_to(device)
      end
    end

    test "deliver_to calls device callback token error" do
      notification = build_notification
      device = action_native_push_devices(:iphone)

      device.expects(:on_token_error).once
      ActionNativePush::Service::Apns.any_instance.expects(:push).raises(ActionNativePush::Errors::TokenError)

      notification.deliver_to(device)
    end

    test "deliver_to is a noop when disabled" do
      previously_enabled, ActionNativePush.configuration.enabled = ActionNativePush.configuration.enabled, false

      notification = build_notification
      device = action_native_push_devices(:iphone)
      ActionNativePush::Service::Apns.any_instance.expects(:push).never

      ActionNativePush.configuration.enabled = previously_enabled
    end

    private
      def build_notification
        ActionNativePush::Notification.new \
          title: "Hi!",
          body: "This is a push notification",
          badge: 1,
          thread_id: "12345",
          sound: "default",
          high_priority: false,
          platform_payload: {
            apns: { category: "readable" },
            fcm:  nil
          },
          custom_payload: { person: "Jacopo", extras: nil }
      end
  end
end
