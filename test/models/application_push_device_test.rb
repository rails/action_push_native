require "test_helper"

class ApplicationPushDeviceTest < ActiveSupport::TestCase
  test "TokenErrors are ignored" do
    notification = ActionPush::Notification.new(title: "Hi!")
    iphone = application_push_devices(:iphone_6)
    ActionPush::Service::Apns.any_instance.expects(:push).raises(ActionPush::TokenError)

    assert_no_difference -> { ApplicationPushDevice.count } do
      iphone.push(notification)
    end
    assert_not iphone.destroyed?
  end
end
