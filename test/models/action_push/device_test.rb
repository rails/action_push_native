require "test_helper"

module ActionPush
  class DeviceTest < ActiveSupport::TestCase
    test "on_token_error" do
      iphone = action_push_devices(:iphone)
      assert_difference -> { ActionPush::Device.count }, -1 do
        iphone.on_token_error
      end
      assert iphone.destroyed?
    end
  end
end
