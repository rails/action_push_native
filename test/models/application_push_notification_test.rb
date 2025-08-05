require "test_helper"

class ApplicationPushNotificationTest < ActiveSupport::TestCase
  test "deliver_later_to with custom queue" do
    notification = ApplicationPushNotification.new title: "hi", body: "hello world!"

    notification.deliver_later_to([ action_push_devices(:iphone), action_push_devices(:pixel9) ])

    assert_enqueued_with job: ApplicationPushNotificationJob, args: [ "ApplicationPushNotification", notification.as_json, action_push_devices(:pixel9) ], queue: :realtime
    assert_enqueued_with job: ApplicationPushNotificationJob, args: [ "ApplicationPushNotification", notification.as_json, action_push_devices(:iphone) ], queue: :realtime
  end

  test "deliver_to before_delivery callback" do
    notification = AbortablePushNotification.new(context: { abort_delivery: true })
    ActionPush::Service::Apns.any_instance.expects(:push).never
    notification.deliver_to(action_push_devices(:iphone))

    notification = AbortablePushNotification.new(context: { abort_delivery: false })
    ActionPush::Service::Apns.any_instance.stubs(:push)
    notification.deliver_to(action_push_devices(:iphone))
  end

  private
    class AbortablePushNotification < ApplicationPushNotification
      before_delivery do |notification|
        throw :abort if notification.context[:abort_delivery]
      end
    end
end
