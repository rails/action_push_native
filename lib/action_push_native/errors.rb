# frozen_string_literal: true

require "time"

module ActionPushNative
  # Base class for Action Push Native errors. Errors raised from a provider
  # response carry structured context: the service that answered, the
  # provider's status and reason tokens, any Retry-After it mandated, and
  # any quota violations it reported (FCM).
  class Error < StandardError
    attr_reader :service, :status, :reason, :retry_after, :quota_violations

    def initialize(message = nil, service: nil, status: nil, reason: nil, retry_after: nil, quota_violations: nil)
      @service = service
      @status = status
      @reason = reason
      @retry_after = retry_after_in_seconds(retry_after)
      @quota_violations = normalized_quota_violations(quota_violations)
      super(message || reason)
    end

    private
      # Retry-After arrives as delta-seconds or an HTTP-date (RFC 9110 §10.2.3).
      def retry_after_in_seconds(value)
        case value
        when nil, Numeric
          value
        when /\A\d+\z/
          Integer(value)
        else
          [ Time.httpdate(value.to_s) - Time.now, 0 ].max
        end
      rescue ArgumentError
        nil
      end

      # Quota violations arrive as raw google.rpc.QuotaFailure violation hashes
      # and pass through losslessly.
      def normalized_quota_violations(violations)
        Array(violations).grep(Hash).map(&:freeze).freeze
      end
  end

  class TimeoutError < Error; end
  class ConnectionError < Error; end
  class ConnectionPoolTimeoutError < Error; end

  class BadRequestError < Error; end
  class ForbiddenError < Error; end
  class PayloadTooLargeError < Error; end
  class TooManyRequestsError < Error; end
  class ServiceUnavailableError < Error; end
  class InternalServerError < Error; end
  class BadDeviceTopicError < Error; end
  class NotFoundError < Error; end

  class TokenError < Error; end
end
