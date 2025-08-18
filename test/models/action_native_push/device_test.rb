require "test_helper"

module ActionNativePush
  class DeviceTest < ActiveSupport::TestCase
    setup { @notification = ActionNativePush::Notification.new(title: "Hi!") }

    test "push to apple" do
      iphone = action_native_push_devices(:iphone)

      apns = stub(:apns)
      apns.expects(:push).with(@notification)
      ActionNativePush::Service::Apns.expects(:new).with(ActionNativePush.config_for(:apple, @notification)).returns(apns)

      assert_changes -> { @notification.token }, from: nil, to: iphone.token do
        iphone.push(@notification)
      end
    end

    test "push to google" do
      pixel = action_native_push_devices(:pixel9)

      fcm = stub(:fcm)
      fcm.expects(:push).with(@notification)
      ActionNativePush::Service::Fcm.expects(:new).with(ActionNativePush.config_for(:google, @notification)).returns(fcm)

      assert_changes -> { @notification.token }, from: nil, to: pixel.token do
        pixel.push(@notification)
      end
    end

    test "device is destroyed on TokenError" do
      iphone = action_native_push_devices(:iphone)
      ActionNativePush::Service::Apns.any_instance.expects(:push).raises(TokenError)

      assert_difference -> { ActionNativePush::Device.count }, -1 do
        iphone.push(@notification)
      end
      assert iphone.destroyed?
    end
  end
end
