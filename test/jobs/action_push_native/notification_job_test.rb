require "test_helper"

module ActionPushNative
  class NotificationJobTest < ActiveSupport::TestCase
    setup { @notification_attributes = { title: "Hi!", body: "This is a push notification" } }

    test "429 errors are retried with an exponential backoff delay" do
      device = action_push_native_devices(:iphone)
      Notification.any_instance.stubs(:deliver_to).raises(TooManyRequestsError)

      assert_enqueued_jobs 1, only: ActionPushNative::NotificationJob do
        ActionPushNative::NotificationJob.perform_later("ApplicationPushNotification", @notification_attributes, device)
      end

      [ 1, 2, 4, 8, 16 ].each do |minutes|
        perform_enqueued_jobs only: ActionPushNative::NotificationJob
        assert_wait minutes.minutes
      end

      Notification.any_instance.stubs(:deliver_to)
      ActionPushNative::NotificationJob.perform_now("ApplicationPushNotification", @notification_attributes, device)
      perform_enqueued_jobs only: ActionPushNative::NotificationJob
      assert_enqueued_jobs 0, only: ActionPushNative::NotificationJob
    end

    test "BadDeviceTopic errors are discarded" do
      device = action_push_native_devices(:iphone)
      Notification.any_instance.stubs(:deliver_to).raises(BadDeviceTopicError)

      assert_enqueued_jobs 1, only: ActionPushNative::NotificationJob do
        ActionPushNative::NotificationJob.perform_later("ApplicationPushNotification", @notification_attributes, device)
      end
      perform_enqueued_jobs only: ActionPushNative::NotificationJob
      assert_enqueued_jobs 0, only: ActionPushNative::NotificationJob
    end

    test "Socket errors are retried" do
      device = action_push_native_devices(:pixel9)
      Net::HTTP.any_instance.stubs(:request).raises(SocketError)
      ActionPushNative::Service::Fcm.any_instance.stubs(:access_token).returns("fake_access_token")

      assert_enqueued_jobs 1, only: ActionPushNative::NotificationJob do
        ActionPushNative::NotificationJob.perform_later("ApplicationPushNotification", @notification_attributes, device)
      end
      perform_enqueued_jobs only: ActionPushNative::NotificationJob
      assert_enqueued_jobs 1, only: ActionPushNative::NotificationJob
    end

    private
      def assert_wait(seconds)
        job = enqueued_jobs_with(only: ActionPushNative::NotificationJob).last
        delay = job["scheduled_at"].to_time - job["enqueued_at"].to_time
        assert_in_delta seconds, delay, 0.15 * delay, "Expected job to wait approximately #{seconds} seconds, but waited #{delay} seconds instead."
      end
  end
end
