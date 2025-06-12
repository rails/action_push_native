require "test_helper"

module ActionNativePush
  class NotificationTest < ActiveSupport::TestCase
    setup { @notification = build_notification }

    test "as_json" do
      assert_equal({ title: "Hi!",
                     body: "This is a push notification",
                     badge: 1,
                     thread_id: "12345",
                     sound: "default",
                     high_priority: false,
                     service_payload: { apns: { category: "readable" } },
                     custom_payload: { person: "Jacopo" } }, @notification.as_json)
    end

    test "deliver_later_to" do
      @notification.deliver_later_to([ action_native_push_devices(:iphone), action_native_push_devices(:pixel9) ])
      assert_enqueued_with job: ActionNativePush::NotificationDeliveryJob, args: [ @notification.as_json, action_native_push_devices(:pixel9) ]
      assert_enqueued_with job: ActionNativePush::NotificationDeliveryJob, args: [ @notification.as_json, action_native_push_devices(:iphone) ]
    end

    test "deliver_to APNs" do
      device = action_native_push_devices(:iphone)

      apns = stub(:apns)
      apns.expects(:push).with(@notification)
      ActionNativePush::Service::Apns.expects(:new).with(ActionNativePush.configuration.applications[:ios]).returns(apns)

      assert_changes -> { @notification.token }, from: nil, to: device.token do
        @notification.deliver_to(device)
      end
    end

    test "deliver_to FCM" do
      device = action_native_push_devices(:pixel9)

      fcm = stub(:fcm)
      fcm.expects(:push).with(@notification)
      ActionNativePush::Service::Fcm.expects(:new).with(ActionNativePush.configuration.applications[:android]).returns(fcm)

      assert_changes -> { @notification.token }, from: nil, to: device.token do
        @notification.deliver_to(device)
      end
    end

    test "deliver_to calls device callback token error" do
      device = action_native_push_devices(:iphone)

      device.expects(:on_token_error).once
      ActionNativePush::Service::Apns.any_instance.expects(:push).raises(ActionNativePush::Errors::TokenError)

      @notification.deliver_to(device)
    end

    test "deliver_to is a noop when disabled" do
      previously_enabled, ActionNativePush.configuration.enabled = ActionNativePush.configuration.enabled, false

      device = action_native_push_devices(:iphone)
      ActionNativePush::Service::Apns.any_instance.expects(:push).never
      @notification.deliver_to(device)

      ActionNativePush.configuration.enabled = previously_enabled
    end

    test "deliver_to runs before_delivery callback" do
      device = action_native_push_devices(:iphone)
      callback_called = false
      ActionNativePush::Service::Apns.any_instance.stubs(:push)
      @notification.before_delivery do |notification|
        assert_equal @notification, notification
        callback_called = true
      end

      @notification.deliver_to(device)

      assert callback_called, "before_deliver callback was not called"
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
          service_payload: {
            apns: { category: "readable" },
            fcm:  nil
          },
          custom_payload: { person: "Jacopo", extras: nil }
      end
  end
end
