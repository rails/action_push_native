# frozen_string_literal: true

module ActionNativePush
  class NotificationDeliveryJob < ActiveJob::Base
    queue_as ActionNativePush.job_queue_name

    self.log_arguments = ActionNativePush.log_job_arguments

    discard_on ActiveJob::DeserializationError
    discard_on Errors::BadDeviceTopicError do |_job, error|
      Rails.error.report(error)
    end

    class << self
      def retry_options
        Rails.version >= "8.1" ? { report: ActionNativePush.report_job_retries } : {}
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
      def exponential_backoff_delay(executions)
        base_wait = 1.minute
        delay = base_wait * (2**(executions - 1))
        jitter = 0.15
        jitter_delay = rand * delay * jitter

        [ delay + jitter_delay, 60.minutes ].min
      end
    end

    with_options retry_options do
      retry_on Errors::TimeoutError, wait: 1.minute
      retry_on Errors::ConnectionError, ConnectionPool::TimeoutError, attempts: 20

      # Altough unexpected, these are short-lived errors that can be retried most of the times.
      retry_on Errors::ForbiddenError, Errors::BadRequestError

      with_options wait: ->(executions) { exponential_backoff_delay(executions) }, attempts: 6 do
        retry_on Errors::TooManyRequestsError, Errors::ServiceUnavailableError, Errors::InternalServerError
        retry_on Signet::RemoteServerError
      end
    end

    def perform(notification_attributes, device)
      Notification.new(**notification_attributes).deliver_to(device)
    end
  end
end
# backward compat for in-flight jobs
ActionNativePush::Jobs = Module.new
ActionNativePush::Jobs::NotificationDeliveryJob = ActionNativePush::NotificationDeliveryJob
