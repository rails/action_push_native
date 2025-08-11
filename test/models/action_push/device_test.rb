require "test_helper"

module ActionPush
  class DeviceTest < ActiveSupport::TestCase
    setup { @notification = ActionPush::Notification.new(title: "Hi!") }

    test "push to apple" do
      iphone = action_push_devices(:iphone)

      apns = stub(:apns)
      apns.expects(:push).with(@notification)
      ActionPush::Service::Apns.expects(:new).with(ActionPush.config_for(:apple, @notification)).returns(apns)

      assert_changes -> { @notification.token }, from: nil, to: iphone.token do
        iphone.push(@notification)
      end
    end

    test "push to google" do
      pixel = action_push_devices(:pixel9)

      fcm = stub(:fcm)
      fcm.expects(:push).with(@notification)
      ActionPush::Service::Fcm.expects(:new).with(ActionPush.config_for(:google, @notification)).returns(fcm)

      assert_changes -> { @notification.token }, from: nil, to: pixel.token do
        pixel.push(@notification)
      end
    end

    test "device is destroyed on TokenError" do
      iphone = action_push_devices(:iphone)
      ActionPush::Service::Apns.any_instance.expects(:push).raises(TokenError)

      assert_difference -> { ActionPush::Device.count }, -1 do
        iphone.push(@notification)
      end
      assert iphone.destroyed?
    end
  end
end
