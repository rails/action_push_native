require "test_helper"

module ActionPush
  class Notification::SerializableTest < ActiveSupport::TestCase
    test "serialize" do
      notification = ActionPush::Notification
        .with_apple(category: "readable")
        .with_google(notification: { collapse_key: "1" })
        .with_data(badge: "1")
        .new \
          title: "Hi!",
          body: "This is a push notification",
          badge: 1,
          thread_id: "12345",
          sound: "default",
          high_priority: false,
          calendar_id: 1

      expected = \
        {
          title: "Hi!",
          body: "This is a push notification",
          badge: 1,
          thread_id: "12345",
          sound: "default",
          high_priority: false,
          apple_data: { category: "readable" },
          google_data: { notification: { collapse_key: "1" } },
          data: { badge: "1" },
          calendar_id: 1
        }
      assert_equal(expected, notification.serialize)
    end

    test "deserialize" do
      attributes = \
        {
          title: "Hi!",
          body: "This is a push notification",
          badge: 1,
          thread_id: "12345",
          sound: "default",
          high_priority: false,
          apple_data: { category: "readable" },
          google_data: { notification: { collapse_key: "1" } },
          data: { badge: "1" },
          calendar_id: 1
        }
      notification = ActionPush::Notification.deserialize(**attributes)

      assert_equal "Hi!", notification.title
      assert_equal "This is a push notification", notification.body
      assert_equal 1, notification.badge
      assert_equal "12345", notification.thread_id
      assert_equal "default", notification.sound
      assert_equal false, notification.high_priority
      assert_equal({ category: "readable" }, notification.apple_data)
      assert_equal({ notification: { collapse_key: "1" } }, notification.google_data)
      assert_equal({ badge: "1" }, notification.data)
      assert_equal 1, notification.context[:calendar_id]
    end

    test "deserialize legacy fields" do
      attributes = \
        {
          title: "Hi!",
          body: "This is a push notification",
          badge: 1,
          thread_id: "12345",
          sound: "default",
          high_priority: false,
          service_payload: {
            apns: { category: "readable" },
            fcm:  { data: { badge: "1" } }
          },
          custom_payload: { person: "Jacopo", extras: nil },
          context: { notification_id: 123 }
        }
      notification = ActionPush::Notification.deserialize(**attributes)

      assert_equal "Hi!", notification.title
      assert_equal "This is a push notification", notification.body
      assert_equal 1, notification.badge
      assert_equal "12345", notification.thread_id
      assert_equal "default", notification.sound
      assert_equal false, notification.high_priority
      assert_equal({ category: "readable" }, notification.apple_data)
      assert_equal({ data: { badge: "1" } }, notification.google_data)
      assert_equal({ person: "Jacopo", extras: nil }, notification.data)
      assert_equal({ notification_id: 123 }, notification.context)
    end
  end
end
