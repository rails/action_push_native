require "test_helper"

module ActionNativePush
  class DeviceTest < ActiveSupport::TestCase
    test "on_token_error" do
      iphone = action_native_push_devices(:iphone)
      assert_difference -> { ActionNativePush::Device.count }, -1 do
        iphone.on_token_error
      end
      assert iphone.destroyed?
    end
  end
end
