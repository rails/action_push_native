# Action Push

Action Push is a Rails push notification gem for mobile platforms, supporting APNs (Apple) and FCM (Android).

## Installation

```ruby
1. bundle add actionpush
2. bin/rails action_push:install
3. bin/rails db:migrate
```

This will install the gem and run the necessary migrations to set up the database.

## Configuration

The installation will create:

- `app/models/application_push_notification.rb`
- `app/jobs/application_push_notification_job.rb`
- `config/push.yml`

`app/models/application_push_notification.rb`:

```ruby
class ApplicationPushNotification < ActionPush::Notification
  # Set a custom job queue_name
  queue_as :realtime

  # Controls whether push notifications are enabled
  self.enabled = Rails.env.production?

  # Define a custom callback to modify or abort the notification before it is sent
  before_delivery do |notification|
    throw :abort if Notification.find(notification.context[:notification_id]).expired?
  end
end
```

This class is used to create and send push notifications. You can customize it by subclassing or
change the application defaults by editing it directly.

`app/jobs/application_push_notification_job.rb`:

```ruby
class ApplicationPushNotificationJob < ActionPush::NotificationJob
  # Enable logging job arguments (false by default)
  self.log_arguments = true

  # Report job retries via the `Rails.error` reporter (false by default)
  self.report_job_retries = true
end
```

This is the job class that processes the push notifications. You can customize it by editing it
directly in your application.

`config/push.yml`:

```yaml
shared:
  apple:
    # When custom settings are needed for individual notification types,
    # start by defining a shared `application` configuration. Then, optionally add
    # specific settings for each notification class (e.g., `calendar`, `email`).
    # These settings will be merged with the base `application` configuration.
    # The `application` settings also apply to the `ApplicationPushNotification` class.
    application:
      # Token auth params
      # See https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns
      key_id: your_key_id
      encryption_key: your_apple_encryption_key

      team_id: your_apple_team_id
      # Your identifier found on https://developer.apple.com/account/resources/identifiers/list
      topic: your.bundle.identifier

      # Set this to the number of threads used to process notifications (Default: 5).
      # When the pool size is too small a ConnectionPool::TimeoutError error will be raised.
      # connection_pool_size: 5
      # request_timeout: 60

      # Decide when to connect to APNs development server.
      # Please note that anything built directly from Xcode and loaded on your phone will have
      # the app generate DEVELOPMENT tokens, while everything else (TestFlight, Apple Store, ...)
      # will be considered as PRODUCTION environment.
      # connect_to_development_server: <%# Rails.env.development? %>
    calendar:
      # Special configuration for CalendarPushNotification
      request_timeout: 30
    email:
      # If not inferred, the Class name can be specified directly
      # class_name: "CustomEmailPushNotification"
  google:
    # Your Firebase project service account credentials
    # See https://firebase.google.com/docs/cloud-messaging/auth-server
    encryption_key: your_service_account_json_file

    # Firebase project_id
    project_id: your_project_id

    # request_timeout: 15
```

This file contains the configuration for the push notification services you want to use.
The push notification services supported are `apple` (APNs) and `google` (FCM).
You can use a shared configuration for all the Notification classes, or define specific settings
for each class (e.g., `calendar`, `email`).

## Usage

### Create and send a notification asynchronously to a device

```ruby
device = Device.create! \
  name: "iPhone 16",
  token: "6c267f26b173cd9595ae2f6702b1ab560371a60e7c8a9e27419bd0fa4a42e58f",
  platform: "apple"

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

### Application data attributes

You can pass custom data to the application using the `with_data` method:

```ruby
notification = ApplicationPushNotification
  .with_data({ badge: "1" })
  .new(title: "Welcome to Action Push")
```

### Custom platform Payload

You can configure custom platform payload to be sent with the notification. This is useful when you
need to send additional data that is specific to the platform you are using.

You can use `with_apple` for Apple and `with_google` for Google:

```ruby
apple_notification = ApplicationPushNotification
  .with_apple(category: "observable")
  .new(title: "Hi Apple")

google_notification = ApplicationPushNotification
  .with_google({ data: { badge: 1 } })
  .new(title: "Hi Google")
```

The platform payload takes precedence over the other fields, and you can use it to override the
default behaviour:

```ruby
notification = ApplicationPushNotification
  .with_google({ android: { notification: { notification_count: nil } } })
  .new(title: "Hello world!", body: "Welcome to Action Push", badge: 1)
```

This will unset the `notification_count` (`badge`) field in the Google payload, while keeping `title`
and `body`.

### Silent Notifications

You can create a silent notification via the `silent` method:

```ruby
notification = Notification.silent.with_data({ id: 1 })
```

This will create a silent notification for both Apple and Google platforms and sets an application
data field of `{ id: 1 }` for both platforms. Silent push notification must not contain any attribute which would trigger
a visual notification on the device, such as `title`, `body`, `badge`, etc.

### `before_delivery` callback

You can specify Active Record like callbacks for the `delivery` method. For example, you can modify
or cancel the notification by specifying a custom `before_delivery` block. The callback has access
to the `notification` object. You can also pass additional context data to the notification
by adding extra arguments to the notification constructor:

```ruby
  class CalendarPushNotification < ApplicationPushNotification
    before_delivery do |notification|
      throw :abort if Calendar.find(notification.context[:calendar_id]).expired?
    end
  end

  data = { calendar_id: @calendar.id, identity_id: @identity.id }

  notification = CalendarPushNotification
    .with_apple({ custom_payload: data })
    .with_google({ data: data })
    .new({ calendar_id: 123 })

  notification.deliver_later_to(device)
```

### Linking a Device to a Record

A Device can be associated with any record in your application via the `owner` polymorphic association:

```ruby
  user = User.find_by_email_address("jacopo@37signals.com")

  Device.create! \
    name: "iPhone 16",
    token: "6c267f26b173cd9595ae2f6702b1ab560371a60e7c8a9e27419bd0fa4a42e58f",
    platform: "apple",
    owner: user
```

### Using a custom Device model

You can use a custom device model, as long as:

1. It can be serialized and deserialized by `ActiveJob`.
2. It responds to the `token` and `platform` methods.
3. It includes the `ActionPush::DeviceModel` module.

By default, when a token error occurs, the device is destroyed.
You can customize this behavior by adding custom rescue logic in your device model:

```ruby
class Device < ActionPush::Device
  rescue_from ActionPush::TokenError do |error|
    # Custom logic to handle token errors
  end
end

class CustomDevice < ActionPush::Device
  include ActionPush::DeviceModel

  rescue_from ActionPush::TokenError do |error|
    # Custom logic to handle token errors
  end
end
```

### `ActionPush::Notification` attributes

| Name           | Description
|------------------|------------
| :title           | The title of the notification.
| :body            | The body of the notification.
| :badge           | The badge number to display on the app icon
| :thread_id       | The thread identifier for grouping notifications.
| :sound           | The sound to play when the notification is received.
| :high_priority   | Whether the notification should be sent with high priority (default: true).

### Factory methods

| Name           | Description
|------------------|------------
| :with_apple           | Set the Apple-specific payload for the notification.
| :with_google          | Set the Google-specific payload for the notification.
| :with_data            | Set the data payload for the notification, sent to all platforms.
| :silent               | Create a silent notification that does not trigger a visual alert on the device.

## License

Action Push is licensed under MIT.
