# frozen_string_literal: true

module ActionPush
  class TimeoutError < StandardError; end
  class BadRequestError < StandardError; end
  class BadDeviceTopicError < StandardError; end
  class ConnectionError < StandardError; end
  class TokenError < StandardError; end
  class DeviceTokenError < TokenError; end
  class ForbiddenError < StandardError; end
  class NotFoundError < StandardError; end
  class ExpiredTokenError < TokenError; end
  class PayloadTooLargeError < StandardError; end
  class TooManyRequestsError < StandardError; end
  class InternalServerError < StandardError; end
  class ServiceUnavailableError < StandardError; end
end
