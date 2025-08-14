require "test_helper"

module ActionNativePush
  class Notification::ConfiguredNotificationTest < ActiveSupport::TestCase
    test "silent notification" do
      notification = ActionNativePush::Notification.silent.new(title: "Hi!")
      assert_equal false, notification.high_priority
      assert_equal({ content_available: 1 }, notification.apple_data)
      assert_equal("Hi!", notification.title)
    end

    test "with_apple" do
      notification = ActionNativePush::Notification.with_apple(category: "readable").with_apple(thread_id: "67890").new
      assert_equal({ category: "readable", thread_id: "67890" }, notification.apple_data)
    end

    test "with_google" do
      notification = ActionNativePush::Notification.with_google(notification: { collapse_key: "123" }).with_google(android: { notification_count: 1 }).new
      assert_equal({ notification: { collapse_key: "123" }, android: { notification_count: 1 } }, notification.google_data)
    end

    test "with_data" do
      notification = ActionNativePush::Notification.with_data({ badge: "1" }).new
      assert_equal({ badge: "1" }, notification.data)
    end
  end
end
