# Action Push

Action Push is a Rails push notification gem for mobile platforms, supporting FCM (Android) and APNs (iOS).

## Installation

```ruby
1. bundle add actionpush
2. bin/rails actionpush:install
3. bin/rails db:migrate
```

This will install the gem and run the necessary migrations to set up the database.

## Configuration

The installation will create:

- `config/push.yml` file with a default configuration for Apple
and Android.
- `app/models/action_push_notification.rb` model to send push notifications.

Example `config/push.yml`:

```yaml
shared:
  report_job_retries: true
  log_job_arguments: true
  applications:
    ios:
      service: apns
      # Token auth params
      # See https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns
      key_id: your_key_id
      encryption_key: your_apple_encryption_key
      team_id: your_apple_team_id
      # Your identifier found on https://developer.apple.com/account/resources/identifiers/list
      topic: your.bundle.identifier

      # Set this to the number of threads used to process notifications (Default: 5).
      # When the pool size is too small a ConnectionPool::TimeoutError error will be raised.
      connection_pool_size: 10
      request_timeout: 60

      # Decide when to connect to APNs development server.
      # Please note that anything built directly from Xcode and loaded on your phone will have
      # the app generate DEVELOPMENT tokens, while everything else (TestFlight, Apple Store, ...)
      # will be considered as PRODUCTION environment.
      connect_to_development_server: <%= Rails.env.development? %>
    android:
      service: fcm
      # Your Firebase project service account credentials
      # See https://firebase.google.com/docs/cloud-messaging/auth-server
      encryption_key: your_service_account_json_file
      # Firebase project_id
      project_id: your_project_id

      request_timeout: 30
```

To send push notifications, you need to set up credentials for each configured application.
You can add as many applications as you like, as long as each one is configured
with a supported notification service (FCM or APNs).

The following options are supported:

- `log_job_arguments`: Whether to log job arguments when sending notifications. Defaults to `false`.
- `report_job_retries`: Whether to report job retries in the logs. Defaults to `false`.
- `applications`: A hash of applications to configure. See the example format in `config/push.yml`.

Example `app/models/action_push_notification.rb`:

```ruby
class ApplicationPushNotification < ActionPush::Notification
  # Set a custom job queue_name
  queue_as :realtime

  # Controls whether push notifications are enabled
  # self.enabled = true

  # Define a custom callback to modify or abort the notification before it is sent
  # before_delivery do |notification|
  #   throw :abort if Notification.find(notification.context[:notification_id]).expired?
  # end
end
```

## Usage

### Create and send a notification asynchronously to a device

```ruby
device = Device.create! \
  name: "iPhone 16",
  token: "6c267f26b173cd9595ae2f6702b1ab560371a60e7c8a9e27419bd0fa4a42e58f",
  application: "ios"

notification = ApplicationPushNotification.new \
  title: "Hello world!",
  body:  "Welcome to Action Push",

notification.deliver_later_to(device)
```

`deliver_later_to` supports also an array of devices:

```ruby
notification.deliver_later_to([ device1, device2 ])
```

A notification can also be delivered synchronously using `deliver_to`:

```ruby
notification.deliver_to(device)
```

It is recommended to send notifications asynchronously using `deliver_later_to`.
This ensures error handling and retry logic are in place, and avoids blocking your application's execution.

### Custom service Payload

You can configure a custom service payload to be sent with the notification. This is useful when you
need to send additional data that is specific to the service you are using (e.g., FCM or APNs).

```ruby
ActionPush::Notification.new \
  service_payload: {
    apns: { category: "observable", content_available: 1 }
  },
  custom_payload: {
    calendar_id: @calendar.id,
    identity_id: @identity.id
  }
```

This will configure APNs to send a silent notification with the `observable` category.
The valid keys are `apns` for Apple Push Notification Service and `fcm` for Firebase Cloud
Messaging.

### `before_delivery` callback

You can specify custom `delivery` callbacks to modify or cancel the notification before it is sent
by subclassing `ApplicationPushNotification` and defining a `before_delivery` block:

```ruby
  class CalendarPushNotification < ApplicationPushNotification
    before_delivery do |notification|
      throw :abort if Calendar.find(notification.context[:calendar_id]).expired?
    end
  end

  notification = CalendarPushNotification.new \
   custom_payload: {
     calendar_id: @calendar.id,
     identity_id: @identity.id
   },
   context: {
     calendar_id: @calendar.id
   }

  notification.deliver_later_to(device)
```

### Linking a Device to a Record

A Device can be associated with any record in your application via the `owner` polymorphic association:

```ruby
  user = User.find_by_email_address("jacopo@37signals.com")

  Device.create! \
    name: "iPhone 16",
    token: "6c267f26b173cd9595ae2f6702b1ab560371a60e7c8a9e27419bd0fa4a42e58f",
    application: "ios"
    owner: user
```

### Using a custom Device model

You can use a custom device model, as long as:

1. It can be serialized and deserialized by `ActiveJob`.
2. It responds to the `token` and `application` methods.
3. It implements an `on_token_error` callback to handle token errors. By default, device models handle this [by destroying the record](https://github.com/basecamp/actionpush/blob/main/app/models/action_push/device.rb#L10-L12).

### `ActionPush::Notification` attributes

| Name           | Description
|------------------|------------
| :title           | The title of the notification.
| :body            | The body of the notification.
| :badge           | The badge number to display on the app icon
| :thread_id       | The thread identifier for grouping notifications.
| :sound           | The sound to play when the notification is received.
| :high_priority   | Whether the notification should be sent with high priority (default: true). For silent notifications is recommended to set this to `false` to avoid [deprioritization or notification delegation](https://firebase.google.com/docs/cloud-messaging/android/message-priority#deprioritize).
| :service_payload | The service-specific payload for the notification. Valid subkeys are `apns` for Apple Push Notification Service and `fcm` for Firebase Cloud Messaging.
| :custom_payload  | Custom payload data to be sent with the notification.
| :context  | Hash of additional context data that won't be sent to the device, but can be used in callbacks |

## License

Action Push is licensed under MIT.
