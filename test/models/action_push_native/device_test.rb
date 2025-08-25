require "test_helper"

module ActionPushNative
  class DeviceTest < ActiveSupport::TestCase
    setup { @notification = ActionPushNative::Notification.new(title: "Hi!") }

    test "push to apple" do
      iphone = action_push_native_devices(:iphone)

      apns = stub(:apns)
      apns.expects(:push).with(@notification)
      ActionPushNative::Service::Apns.expects(:new).with(ActionPushNative.config_for(:apple, @notification)).returns(apns)

      assert_changes -> { @notification.token }, from: nil, to: iphone.token do
        iphone.push(@notification)
      end
    end

    test "push to google" do
      pixel = action_push_native_devices(:pixel9)

      fcm = stub(:fcm)
      fcm.expects(:push).with(@notification)
      ActionPushNative::Service::Fcm.expects(:new).with(ActionPushNative.config_for(:google, @notification)).returns(fcm)

      assert_changes -> { @notification.token }, from: nil, to: pixel.token do
        pixel.push(@notification)
      end
    end

    test "device is destroyed on TokenError" do
      iphone = action_push_native_devices(:iphone)
      ActionPushNative::Service::Apns.any_instance.expects(:push).raises(TokenError)

      assert_difference -> { ActionPushNative::Device.count }, -1 do
        iphone.push(@notification)
      end
      assert iphone.destroyed?
    end
  end
end
