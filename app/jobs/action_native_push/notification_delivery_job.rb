# frozen_string_literal: true

module ActionNativePush
  class NotificationDeliveryJob < ActiveJob::Base
    queue_as ActionNativePush.configuration.job_queue_name

    self.log_arguments = ActionNativePush.configuration.log_job_arguments

    discard_on ActiveJob::DeserializationError

    def self.retry_options
      Rails.version >= "8.1" ? { report: ActionNativePush.configuration.report_job_retries } : {}
    end

    with_options retry_options do
      with_options wait: 1.minute do
        retry_on ActionNativePush::Errors::TimeoutError, Net::ReadTimeout, Net::OpenTimeout
      end

      with_options attempts: 20 do
        retry_on SocketError, Errno::ECONNREFUSED
        retry_on ConnectionPool::TimeoutError
      end

      # Altough unexpected, these are short-lived errors that can be retried.
      retry_on ActionNativePush::Errors::ForbiddenError, ActionNativePush::Errors::BadRequestError

      with_options wait: ->(executions) { exponential_backoff_delay(executions) }, attempts: 6 do
        retry_on ActionNativePush::Errors::TooManyRequestsError
        retry_on ActionNativePush::Errors::ServiceUnavailableError
        retry_on ActionNativePush::Errors::InternalServerError
        retry_on Signet::RemoteServerError
      end
    end

    # Exponential backoff starting from a minimum of 1 minute, capped at 60m as suggested by FCM:
    # https://firebase.google.com/docs/cloud-messaging/scale-fcm#errors
    #
    # | Executions | Delay (rounded minutes) |
    # |------------|-------------------------|
    # | 1          | 1                       |
    # | 2          | 2                       |
    # | 3          | 4                       |
    # | 4          | 8                       |
    # | 5          | 16                      |
    # | 6          | 32                      |
    # | 7          | 60 (cap)                |
    def self.exponential_backoff_delay(executions)
      base_wait = 1.minute
      delay = base_wait * (2**(executions - 1))
      jitter = 0.15
      jitter_delay = rand * delay * jitter

      [ delay + jitter_delay, 60.minutes ].min
    end

    def perform(notification_attributes, device)
      if ActionNativePush.configuration.enabled
        ActionNativePush::Notification.new(**notification_attributes).deliver_to(device)
      end
    end
  end
end
