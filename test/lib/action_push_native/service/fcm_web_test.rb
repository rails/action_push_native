require "test_helper"

module ActionPushNative
  module Service
    class FcmWebTest < ActiveSupport::TestCase
      setup do
        @notification = build_notification
        @fcm_web = ActionPushNative.service_for(:web, @notification)
        stub_authorizer
      end

      test "push" do
        payload = {
          message: {
            token: "123",
            data: { person: "Jacopo" },
            webpush: {
              notification: {
                title: "Hi!",
                body: "This is a web push notification",
                tag: "thread-123"
              },
              headers: { Urgency: "high" },
              data: { badge: "1", url: "https://example.test" }
            }
          }
        }

        stub_request(:post, "https://fcm.googleapis.com/v1/projects/your_project_id/messages:send").
          with(body: payload.to_json, headers: { "Authorization" => "Bearer fake_access_token" }).
          to_return(status: 200)

        assert_nothing_raised do
          @fcm_web.push(@notification)
        end
      end

      test "push with low priority urgency" do
        @notification.high_priority = false
        payload = {
          message: {
            token: "123",
            data: { person: "Jacopo" },
            webpush: {
              notification: {
                title: "Hi!",
                body: "This is a web push notification",
                tag: "thread-123"
              },
              headers: { Urgency: "normal" },
              data: { badge: "1", url: "https://example.test" }
            }
          }
        }

        stub_request(:post, "https://fcm.googleapis.com/v1/projects/your_project_id/messages:send").
          with(body: payload.to_json, headers: { "Authorization" => "Bearer fake_access_token" }).
          to_return(status: 200)

        assert_nothing_raised do
          @fcm_web.push(@notification)
        end
      end

      private
        def build_notification
          ActionPushNative::Notification.
            with_web(webpush: { data: { badge: 1, url: "https://example.test" } }).
            with_data(person: "Jacopo").
            new(
              title: "Hi!",
              body: "This is a web push notification",
              thread_id: "thread-123"
            ).tap do |notification|
              notification.token = "123"
            end
        end

        def stub_authorizer
          authorizer = stub("authorizer")
          authorizer.stubs(:fetch_access_token!).returns({ "access_token" => "fake_access_token", "expires_in" => 3599 })
          Google::Auth::ServiceAccountCredentials.stubs(:make_creds).returns(authorizer)
        end
    end
  end
end
