require "test_helper"

module ActionPushNative
  module Service
    class FcmTest < ActiveSupport::TestCase
      setup do
        @notification = build_notification
        @fcm = ActionPushNative.service_for(:google, @notification)
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
        assert_raises ActionPushNative::ServiceUnavailableError do
          @fcm.push(@notification)
        end

        stub_request(:post, "https://fcm.googleapis.com/v1/projects/your_project_id/messages:send").
          to_return(status: 400, body: { error: { message: "message is too big" } }.to_json)
        assert_raises ActionPushNative::PayloadTooLargeError do
          @fcm.push(@notification)
        end

        stub_request(:post, "https://fcm.googleapis.com/v1/projects/your_project_id/messages:send").
          to_return(status: 500, body: "Not a JSON")
        assert_raises ActionPushNative::InternalServerError do
          @fcm.push(@notification)
        end

        stub_request(:post, "https://fcm.googleapis.com/v1/projects/your_project_id/messages:send").
          to_raise(OpenSSL::SSL::SSLError.new("SSL_connect returned=1 errno=0 state=error"))
        assert_raises ActionPushNative::ConnectionError do
          @fcm.push(@notification)
        end
      end

      test "response errors carry structured provider context" do
        body = \
          {
            error: {
              code: 429,
              message: "Sending limit exceeded",
              status: "RESOURCE_EXHAUSTED",
              details: [
                { "@type": "type.googleapis.com/google.rpc.RetryInfo", retryDelay: "42s" },
                { "@type": "type.googleapis.com/google.rpc.ErrorInfo", reason: "QUOTA_EXCEEDED", domain: "fcm.googleapis.com" },
                { "@type": "type.googleapis.com/google.rpc.QuotaFailure", violations: [
                  { subject: "project:123456", description: "Message rate limit exceeded for device" }
                ] }
              ]
            }
          }

        stub_request(:post, "https://fcm.googleapis.com/v1/projects/your_project_id/messages:send").
          to_return(status: 429, headers: { "Retry-After" => "42" }, body: body.to_json)

        error = assert_raises ActionPushNative::TooManyRequestsError do
          @fcm.push(@notification)
        end
        assert_equal "Sending limit exceeded", error.message
        assert_equal :fcm, error.service
        assert_equal "RESOURCE_EXHAUSTED", error.status
        assert_equal "QUOTA_EXCEEDED", error.reason
        assert_equal 42, error.retry_after
        assert_equal [ { "subject" => "project:123456", "description" => "Message rate limit exceeded for device" } ],
          error.quota_violations
      end

      test "quota violations concatenate across QuotaFailure details" do
        body = \
          {
            error: {
              code: 429,
              message: "Sending limit exceeded",
              status: "RESOURCE_EXHAUSTED",
              details: [
                { "@type": "type.googleapis.com/google.rpc.QuotaFailure", violations: [ { subject: "device:1" } ] },
                { "@type": "type.googleapis.com/google.rpc.QuotaFailure", violations: [ { subject: "device:2" } ] }
              ]
            }
          }

        stub_request(:post, "https://fcm.googleapis.com/v1/projects/your_project_id/messages:send").
          to_return(status: 429, body: body.to_json)

        error = assert_raises ActionPushNative::TooManyRequestsError do
          @fcm.push(@notification)
        end
        assert_equal [ { "subject" => "device:1" }, { "subject" => "device:2" } ], error.quota_violations
      end

      test "malformed error details read as no quota violations" do
        body = \
          {
            error: {
              code: 429,
              message: "Sending limit exceeded",
              status: "RESOURCE_EXHAUSTED",
              details: [
                "not a hash",
                { "@type": "type.googleapis.com/google.rpc.QuotaFailure", violations: "not an array" }
              ]
            }
          }

        stub_request(:post, "https://fcm.googleapis.com/v1/projects/your_project_id/messages:send").
          to_return(status: 429, body: body.to_json)

        error = assert_raises ActionPushNative::TooManyRequestsError do
          @fcm.push(@notification)
        end
        assert_equal [], error.quota_violations

        stub_request(:post, "https://fcm.googleapis.com/v1/projects/your_project_id/messages:send").
          to_return(status: 429, body: { error: { message: "Sending limit exceeded", status: "RESOURCE_EXHAUSTED" } }.to_json)

        error = assert_raises ActionPushNative::TooManyRequestsError do
          @fcm.push(@notification)
        end
        assert_equal [], error.quota_violations
      end

      test "push instruments provider errors with their structured context" do
        stub_request(:post, "https://fcm.googleapis.com/v1/projects/your_project_id/messages:send").
          to_return(status: 503, headers: { "Retry-After" => "15" },
            body: { error: { message: "Service unavailable", status: "UNAVAILABLE" } }.to_json)

        event = nil
        capture = ->(e) { event = e }
        ActiveSupport::Notifications.subscribed(capture, "push.action_push_native") do
          assert_raises(ActionPushNative::ServiceUnavailableError) { @fcm.push(@notification) }
        end

        assert_equal :fcm, event.payload[:service]
        assert_equal "123", event.payload[:device_token]
        assert_equal "UNAVAILABLE", event.payload[:status]
        assert_equal 15, event.payload[:retry_after]
        assert_instance_of ActionPushNative::ServiceUnavailableError, event.payload[:exception_object]
      end

      test "push fcm payload can be overridden" do
        @notification.google_data = { android: { collapse_key: "changed", notification: nil }, data: nil }
        payload = { message: { token: "123", android: { collapse_key: "changed", priority: "normal" } } }
        stub_request(:post, "https://fcm.googleapis.com/v1/projects/your_project_id/messages:send").
          with(body: payload.to_json, headers: { "Authorization"=>"Bearer fake_access_token" }).
          to_return(status: 200)

        assert_nothing_raised do
          @fcm.push(@notification)
        end
      end

      test "access tokens are refreshed" do
        ActiveSupport::IsolatedExecutionState.clear

        stub_request(:post, "https://fcm.googleapis.com/v1/projects/your_project_id/messages:send")

        authorizer = stub("authorizer")
        authorizer.stubs(:fetch_access_token!).once.returns({ "access_token" => "fake_access_token", "expires_in" => 3599 })
        Google::Auth::ServiceAccountCredentials.stubs(:make_creds).returns(authorizer)
        @fcm.push(@notification)
        @fcm.push(@notification)

        authorizer.stubs(:fetch_access_token!).once.returns({ "access_token" => "fake_access_token", "expires_in" => 3599 })
        travel 3600 do
          @fcm.push(@notification)
        end
      end

      private
        def build_notification
          ActionPushNative::Notification.
            with_google(android: { collapse_key: "321" })
            .with_data(person: "Jacopo", badge: 1)
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

        def stub_authorizer
          authorizer = stub("authorizer")
          authorizer.stubs(:fetch_access_token!).returns({ "access_token" => "fake_access_token", "expires_in" => 3599 })
          Google::Auth::ServiceAccountCredentials.stubs(:make_creds).returns(authorizer)
        end
    end
  end
end
