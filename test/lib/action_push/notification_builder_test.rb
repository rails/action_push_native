require "test_helper"

module ActionPush
  class NotificationBuilderTest < ActiveSupport::TestCase
    setup { @notification = ActionPush::Notification.new(title: "Hi!") }

    test "silent notification" do
      notification = @notification.silent
      assert_equal false, notification.high_priority
      assert_equal({ content_available: 1 }, notification.apns_payload)
      assert_nil @notification.apns_payload
    end

    test "with_apple" do
      notification = @notification.with_apple(category: "readable").with_apple(thread_id: "67890")
      assert_equal({ category: "readable", thread_id: "67890" }, notification.apns_payload)
      assert_nil @notification.apns_payload
    end

    test "with_google" do
      notification = @notification.with_google(data: { badge: "1" }).with_google(android: { notification_count: 1 })
      assert_equal({ data: { badge: "1" }, android: { notification_count: 1 } }, notification.fcm_payload)
      assert_nil @notification.fcm_payload
    end
  end
end
