require "test_helper"

module ActionPush
  class NotificationDeliveryJobTest < ActiveSupport::TestCase
    test "429 errors are retried with an exponential backoff delay" do
      device = action_push_devices(:iphone)
      Notification.any_instance.stubs(:deliver_to).raises(Errors::TooManyRequestsError)

      assert_enqueued_jobs 1, only: ActionPush::NotificationDeliveryJob do
        ActionPush::NotificationDeliveryJob.perform_later({}, device)
      end

      [ 1, 2, 4, 8, 16 ].each do |minutes|
        perform_enqueued_jobs only: ActionPush::NotificationDeliveryJob
        assert_wait minutes.minutes
      end

      Notification.any_instance.stubs(:deliver_to)
      ActionPush::NotificationDeliveryJob.perform_now({}, device)
      perform_enqueued_jobs only: ActionPush::NotificationDeliveryJob
      assert_enqueued_jobs 0, only: ActionPush::NotificationDeliveryJob
    end

    test "BadDeviceTopic errors are discarded" do
      device = action_push_devices(:iphone)
      Notification.any_instance.stubs(:deliver_to).raises(Errors::BadDeviceTopicError)

      assert_enqueued_jobs 1, only: ActionPush::NotificationDeliveryJob do
        ActionPush::NotificationDeliveryJob.perform_later({}, device)
      end
      perform_enqueued_jobs only: ActionPush::NotificationDeliveryJob
      assert_enqueued_jobs 0, only: ActionPush::NotificationDeliveryJob
    end

    test "Socket errors are retried" do
      device = action_push_devices(:pixel9)
      Net::HTTP.any_instance.stubs(:request).raises(Socket::ResolutionError)
      ActionPush::Service::Fcm.any_instance.stubs(:access_token).returns("fake_access_token")

      assert_enqueued_jobs 1, only: ActionPush::NotificationDeliveryJob do
        ActionPush::NotificationDeliveryJob.perform_later({}, device)
      end
      perform_enqueued_jobs only: ActionPush::NotificationDeliveryJob
      assert_enqueued_jobs 1, only: ActionPush::NotificationDeliveryJob
    end

    private
      def assert_wait(seconds)
        job = enqueued_jobs_with(only: ActionPush::NotificationDeliveryJob).last
        delay = job["scheduled_at"].to_time - job["enqueued_at"].to_time
        assert_in_delta seconds, delay, 0.15 * delay, "Expected job to wait approximately #{seconds} seconds, but waited #{delay} seconds instead."
      end
  end
end
