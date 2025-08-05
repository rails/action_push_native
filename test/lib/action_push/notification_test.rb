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
      assert_equal({ title: "Hi!",
                     body: "This is a push notification",
                     badge: 1,
                     thread_id: "12345",
                     sound: "default",
                     high_priority: false,
                     service_payload: { apns: { category: "readable" } },
                     custom_payload: { person: "Jacopo" },
                     context: {} }, @notification.as_json)
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
      ActionPush::Service::Apns.expects(:new).with(ActionPush.platforms[:apple]).returns(apns)

      assert_changes -> { @notification.token }, from: nil, to: device.token do
        @notification.deliver_to(device)
      end
    end

    test "deliver_to FCM" do
      device = action_push_devices(:pixel9)

      fcm = stub(:fcm)
      fcm.expects(:push).with(@notification)
      ActionPush::Service::Fcm.expects(:new).with(ActionPush.platforms[:google]).returns(fcm)

      assert_changes -> { @notification.token }, from: nil, to: device.token do
        @notification.deliver_to(device)
      end
    end

    test "deliver_to calls device.on_token_error callback on token error" do
      device = action_push_devices(:iphone)

      device.expects(:on_token_error).once
      ActionPush::Service::Apns.any_instance.expects(:push).raises(ActionPush::Errors::TokenError)

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
          service_payload: {
            apns: { category: "readable" },
            fcm:  nil
          },
          custom_payload: { person: "Jacopo", extras: nil }
      end
  end
end
