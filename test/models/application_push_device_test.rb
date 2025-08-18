require "test_helper"

class ApplicationPushDeviceTest < ActiveSupport::TestCase
  test "TokenErrors are ignored" do
    notification = ActionNativePush::Notification.new(title: "Hi!")
    iphone = application_push_devices(:iphone_6)
    ActionNativePush::Service::Apns.any_instance.expects(:push).raises(ActionNativePush::TokenError)

    assert_no_difference -> { ApplicationPushDevice.count } do
      iphone.push(notification)
    end
    assert_not iphone.destroyed?
  end
end
