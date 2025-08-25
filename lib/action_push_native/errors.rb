# frozen_string_literal: true

module ActionPushNative
  class TimeoutError < StandardError; end
  class ConnectionError < StandardError; end

  class BadRequestError < StandardError; end
  class ForbiddenError < StandardError; end
  class PayloadTooLargeError < StandardError; end
  class TooManyRequestsError < StandardError; end
  class ServiceUnavailableError < StandardError; end
  class InternalServerError < StandardError; end
  class BadDeviceTopicError < StandardError; end
  class NotFoundError < StandardError; end

  class TokenError < StandardError; end
end
