# frozen_string_literal: true

module ActionPush
  class NotificationJob < ActiveJob::Base
    self.log_arguments = false

    class_attribute :report_job_retries, default: false

    discard_on ActiveJob::DeserializationError
    discard_on BadDeviceTopicError do |_job, error|
      Rails.error.report(error)
    end

    class << self
      def retry_options
        Rails.version >= "8.1" ? { report: report_job_retries } : {}
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
      retry_on TimeoutError, wait: 1.minute
      retry_on ConnectionError, ConnectionPool::TimeoutError, attempts: 20

      # Altough unexpected, these are short-lived errors that can be retried most of the times.
      retry_on ForbiddenError, BadRequestError
    end

    with_options wait: ->(executions) { exponential_backoff_delay(executions) }, attempts: 6, **retry_options do
      retry_on TooManyRequestsError, ServiceUnavailableError, InternalServerError
      retry_on Signet::RemoteServerError
    end

    def perform(notification_class, notification_attributes, device = nil)
      # Backward compatibility to handle in-flight jobs.
      if device.nil?
        device = notification_attributes
        notification_attributes = notification_class
        notification_class = Notification
      end

      notification_class.constantize.new(**notification_attributes).deliver_to(device)
    end
  end
end
# Backward compat for in-flight jobs.
ActionPush::NotificationDeliveryJob = ActionPush::NotificationJob
