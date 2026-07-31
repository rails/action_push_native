require "test_helper"

module ActionPushNative
  class ErrorsTest < ActiveSupport::TestCase
    test "retry_after accepts delta-seconds, numerics, and nil" do
      assert_equal 30, TooManyRequestsError.new(retry_after: "30").retry_after
      assert_equal 2.5, TooManyRequestsError.new(retry_after: 2.5).retry_after
      assert_nil TooManyRequestsError.new.retry_after
    end

    test "retry_after accepts an HTTP-date, clamping past dates to zero" do
      freeze_time do
        error = ServiceUnavailableError.new(retry_after: 42.seconds.from_now.httpdate)
        assert_in_delta 42.0, error.retry_after, 1.0

        assert_equal 0.0, ServiceUnavailableError.new(retry_after: 1.hour.ago.httpdate).retry_after
      end
    end

    test "an unparseable Retry-After reads as nil" do
      assert_nil TooManyRequestsError.new(retry_after: "soon").retry_after
    end

    test "the message stays the first positional argument, falling back to the reason" do
      assert_equal "boom", TooManyRequestsError.new("boom", reason: "QUOTA_EXCEEDED").message
      assert_equal "QUOTA_EXCEEDED", TooManyRequestsError.new(reason: "QUOTA_EXCEEDED").message
    end

    test "quota_violations defaults to an empty array" do
      assert_equal [], TooManyRequestsError.new.quota_violations
    end

    test "quota_violations keeps hash entries and drops the rest, frozen" do
      violation = { "subject" => "device:1", "description" => "rate limited" }
      error = TooManyRequestsError.new(quota_violations: [ violation, "junk", nil ])

      assert_equal [ violation ], error.quota_violations
      assert error.quota_violations.frozen?
      assert error.quota_violations.first.frozen?
    end
  end
end
