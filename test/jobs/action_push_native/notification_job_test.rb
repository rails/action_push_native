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
      stub_request(:post, "https://fcm.googleapis.com/v1/projects/your_project_id/messages:send").
        to_raise(SocketError.new)
      authorizer = stub("authorizer")
      authorizer.stubs(:fetch_access_token!).returns({ "access_token" => "fake_access_token", "expires_in" => 3599 })
      Google::Auth::ServiceAccountCredentials.stubs(:make_creds).returns(authorizer)

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
