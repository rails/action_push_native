require "test_helper"

module ActionNativePush
  module Service
    class FcmTest < ActiveSupport::TestCase
      setup do
        @fcm = Fcm.new(ActionNativePush.applications[:android])
        @notification = build_notification
        stub_authorizer
      end

      test "push" do
        payload = \
          {
            message: {
              token: "123",
              data: { person: "Jacopo", badge: "1" },
              android: {
                notification: {
                  title: "Hi!",
                  body: "This is a push notification",
                  notification_count: 1,
                  sound: "default"
                },
                collapse_key: "321",
                priority: "normal"
              }
            }
          }
        stub_request(:post, "https://fcm.googleapis.com/v1/projects/your_project_id/messages:send").
          with(body: payload.to_json, headers: { "Authorization"=>"Bearer fake_access_token" }).
          to_return(status: 200)

        assert_nothing_raised do
          @fcm.push(@notification)
        end
      end

      test "push response error" do
        stub_request(:post, "https://fcm.googleapis.com/v1/projects/your_project_id/messages:send").
          to_return(status: 503, body: { error: { message: "Bad Request" } }.to_json)
        assert_raises ActionNativePush::Errors::ServiceUnavailableError do
          @fcm.push(@notification)
        end

        stub_request(:post, "https://fcm.googleapis.com/v1/projects/your_project_id/messages:send").
          to_return(status: 400, body: { error: { message: "message is too big" } }.to_json)
        assert_raises ActionNativePush::Errors::PayloadTooLargeError do
          @fcm.push(@notification)
        end

        Net::HTTP.stubs(:start).raises(OpenSSL::SSL::SSLError.new("SSL_connect returned=1 errno=0 state=error"))
        assert_raises ActionNativePush::Errors::ConnectionError do
          @fcm.push(@notification)
        end
      end

      test "push fcm payload can be overridden" do
        @notification.service_payload[:fcm] = { android: { collapse_key: "changed", notification: nil } }
        payload = { message: { token: "123", data: { person: "Jacopo", badge: "1" }, android: { collapse_key: "changed", priority: "normal" } } }
        stub_request(:post, "https://fcm.googleapis.com/v1/projects/your_project_id/messages:send").
          with(body: payload.to_json, headers: { "Authorization"=>"Bearer fake_access_token" }).
          to_return(status: 200)

        assert_nothing_raised do
          @fcm.push(@notification)
        end
      end

      private
        def build_notification
          ActionNativePush::Notification.new(
            title: "Hi!",
            body: "This is a push notification",
            badge: 1,
            thread_id: "12345",
            sound: "default",
            high_priority: false,
            service_payload: {
              apns: { category: "readable" },
              fcm:  { android: { collapse_key: "321" }.compact } },
            custom_payload: { person: "Jacopo", badge: 1 }
          ).tap do |notification|
            notification.token = "123"
          end
        end

        def stub_authorizer
          authorizer = stub("authorizer")
          authorizer.stubs(:fetch_access_token!).returns({ "access_token" => "fake_access_token" })
          Google::Auth::ServiceAccountCredentials.stubs(:make_creds).returns(authorizer)
        end
    end
  end
end
