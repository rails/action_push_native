require "test_helper"

class ApplicationPushDeviceTest < ActiveSupport::TestCase
  test "TokenErrors are ignored" do
    notification = ActionPushNative::Notification.new(title: "Hi!")
    iphone = application_push_devices(:iphone_6)
    ActionPushNative::Service::Apns.any_instance.expects(:push).raises(ActionPushNative::TokenError)

    assert_no_difference -> { ApplicationPushDevice.count } do
      iphone.push(notification)
    end
    assert_not iphone.destroyed?
  end
end
