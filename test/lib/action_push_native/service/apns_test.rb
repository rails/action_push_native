require "test_helper"

module ActionPushNative
  module Service
    class ApnsTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::Deprecation

      setup do
        @notification = build_notification
        ActionPushNative::Service::Apns::TokenProvider.any_instance.stubs(:fresh_access_token).returns("fake_token")
        @config = ActionPushNative.config_for(:apple, @notification)
        @apns = Apns.new(@config)
      end

      test "push" do
        payload = \
          {
            aps: {
              alert: { title: "Hi!", body: "This is a push notification" },
              badge: 1,
              "thread-id": "12345",
              sound: "default",
              category: "readable"
            },
            person: "Jacopo"
          }

        headers = \
          {
            "Apns-Priority"=>"5",
            "Apns-Push-Type"=>"alert",
            "Apns-Topic"=>"your.bundle.identifier",
            "Authorization"=>"Bearer fake_token"
          }

        stub_request(:post, "https://api.push.apple.com/3/device/123").
          with(body: payload.to_json, headers: headers).
          to_return(status: 200)

        assert_nothing_raised { @apns.push(@notification) }
      end

      test "push silent notification" do
        notification = ActionPushNative::Notification.silent.with_data(id: "1").new
        notification.token = "123"

        payload = { aps: { "content-available": 1 }, id: "1" }

        headers = \
          {
            "Apns-Priority"=>"5",
            "Apns-Push-Type"=>"background",
            "Apns-Topic"=>"your.bundle.identifier",
            "Authorization"=>"Bearer fake_token"
          }

        stub_request(:post, "https://api.push.apple.com/3/device/123").
          with(body: payload.to_json, headers: headers).
          to_return(status: 200)

        assert_nothing_raised { @apns.push(notification) }
      end

      test "push response error" do
        stub_request(:post, "https://api.push.apple.com/3/device/123").
          to_return(status: 400)

        assert_raises ActionPushNative::BadRequestError do
          @apns.push(@notification)
        end

        stub_request(:post, "https://api.push.apple.com/3/device/123").
          to_return(status: 400, body: { reason: "BadDeviceToken" }.to_json)

        assert_raises ActionPushNative::TokenError do
          @apns.push(@notification)
        end

        stub_request(:post, "https://api.push.apple.com/3/device/123").
          to_raise(Errno::ECONNRESET.new("Connection reset by peer"))

        assert_raises ActionPushNative::ConnectionError do
          @apns.push(@notification)
        end
      end

      test "push apns payload can be overridden" do
        @notification.apple_data = { aps: { "thread-id": "changed" } }

        payload = \
          {
            aps: {
              alert: { title: "Hi!", body: "This is a push notification" },
              badge: 1,
              "thread-id": "changed",
              sound: "default"
            },
            person: "Jacopo"
          }

        stub_request(:post, "https://api.push.apple.com/3/device/123").
          with(body: payload.to_json).
          to_return(status: 200)

        assert_nothing_raised { @apns.push(@notification) }
      end

      test "push apns headers can be overridden" do
        @notification.apple_data = { "apns-priority": 10, "apns-expiration": 20 }

        payload = \
          {
            aps: {
              alert: { title: "Hi!", body: "This is a push notification" },
              badge: 1,
              "thread-id": "12345",
              sound: "default"
            },
            person: "Jacopo"
          }

        headers = { "apns-priority": 10, "apns-expiration": 20 }

        stub_request(:post, "https://api.push.apple.com/3/device/123").
          with(body: payload.to_json, headers: headers).
          to_return(status: 200)

        assert_nothing_raised do
          @apns.push(@notification)
        end
      end

      test "apnotic legacy format compatibility" do
        @notification.apple_data = { priority: 10, alert: { title: "Overridden!", body: nil }, custom_payload: { person: "Rosa" } }

        payload = \
          {
            aps: {
              alert: { title: "Overridden!" },
              badge: 1,
              "thread-id": "12345",
              sound: "default"
            },
            person: "Rosa"
          }

        headers = { "apns-priority": 10 }

        stub_request(:post, "https://api.push.apple.com/3/device/123").
          with(body: payload.to_json, headers: headers).
          to_return(status: 200)

        assert_nothing_raised do
          assert_deprecated(/field directly is deprecated/, ActionPushNative.deprecator) do
            @apns.push(@notification)
          end
        end
      end

      test "access tokens are refreshed every 30 minutes" do
        stub_request(:post, "https://api.push.apple.com/3/device/123")
        ActionPushNative::Service::Apns::TokenProvider.any_instance.unstub(:fresh_access_token)

        ActionPushNative::Service::Apns::TokenProvider.any_instance.stubs(:generate).once.returns("fake_token")
        @apns.push(@notification)
        @apns.push(@notification)

        ActionPushNative::Service::Apns::TokenProvider.any_instance.stubs(:generate).once.returns("new_fake_token")
        travel 31.minutes do
          @apns.push(@notification)
        end
      end

      private
        def build_notification
          ActionPushNative::Notification
            .with_apple(aps: { category: "readable" })
            .with_data(person: "Jacopo")
            .new(
              title: "Hi!",
              body: "This is a push notification",
              badge: 1,
              thread_id: "12345",
              sound: "default",
              high_priority: false
            ).tap do |notification|
              notification.token = "123"
            end
        end
    end
  end
end
