# Action Push Native

Action Push Native is a Rails push notification gem for mobile and web platforms, supporting APNs (Apple) and FCM (Google Android/Web).

## Installation

```bash
1. bundle add action_push_native
2. bin/rails g action_push_native:install
3. bin/rails action_push_native:install:migrations
4. bin/rails db:migrate
```

This will install the gem and run the necessary migrations to set up the database.

## Configuration

The installation will create:

- `app/models/application_push_notification.rb`
- `app/jobs/application_push_notification_job.rb`
- `app/models/application_push_device.rb`
- `config/push.yml`

`app/models/application_push_notification.rb`:

```ruby
class ApplicationPushNotification < ActionPushNative::Notification
  # Set a custom job queue_name
  queue_as :realtime

  # Controls whether push notifications are enabled (default: !Rails.env.test?)
  self.enabled = Rails.env.production?

  # Define a custom callback to modify or abort the notification before it is sent
  before_delivery do |notification|
    throw :abort if Notification.find(notification.context[:notification_id]).expired?
  end
end
```

Used to create and send push notifications. You can customize it by subclassing or
you can change the application defaults by editing it directly.

`app/jobs/application_push_notification_job.rb`:

```ruby
class ApplicationPushNotificationJob < ActionPushNative::NotificationJob
  # Enable logging job arguments (default: false)
  self.log_arguments = true

  # Report job retries via the `Rails.error` reporter (default: false)
  self.report_job_retries = true
end
```

Job class that processes the push notifications. You can customize it by editing it
directly in your application.

`app/models/application_push_device.rb`:

```ruby
class ApplicationPushDevice < ActionPushNative::Device
  # Customize TokenError handling (default: destroy!)
  # rescue_from (ActionPushNative::TokenError) { Rails.logger.error("Device #{id} token is invalid") }
end
```

This represents a push notification device. You can customize it by editing it directly in your application.

`config/push.yml`:

```yaml
shared:
  apple:
    # Token auth params
    # See https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns
    key_id: <%= Rails.application.credentials.dig(:action_push_native, :apns, :key_id) %>
    encryption_key: <%= Rails.application.credentials.dig(:action_push_native, :apns, :encryption_key)&.dump %>

    team_id: your_apple_team_id
    # Your identifier found on https://developer.apple.com/account/resources/identifiers/list
    topic: your.bundle.identifier

  google:
    # Your Firebase project service account credentials
    # See https://firebase.google.com/docs/cloud-messaging/auth-server
    encryption_key: <%= Rails.application.credentials.dig(:action_push_native, :fcm, :encryption_key)&.dump %>

    # Firebase project_id
    project_id: your_project_id

  web:
    # Uses the same Firebase project service account credentials as Android.
    # See https://firebase.google.com/docs/cloud-messaging/auth-server
    encryption_key: <%= Rails.application.credentials.dig(:action_push_native, :fcm, :encryption_key)&.dump %>

    # Firebase project_id
    project_id: your_project_id
```

This file contains the configuration for the push notification services you want to use.
The push notification services supported are `apple` (APNs), `google` (FCM Android), and `web` (FCM Web Push).
If you're configuring more than one app, see the section [Configuring multiple apps](#configuring-multiple-apps) below.

### Configuring multiple apps

You can send push notifications to multiple apps using different notification classes.
Each notification class need to inherit from `ApplicationPushNotification` and set `self.application`, to a key set in `push.yml`
for each supported platform. You can also (optionally) set a shared `application` option in `push.yml`.
This acts as the base configuration for that platform, and its values will be merged (and overridden) with the matching app-specific configuration.

In the example below we are configuring two apps: `calendar` and `email` using respectively the
`CalendarPushNotification` and `EmailPushNotification` notification classes.

```ruby
class CalendarPushNotification < ApplicationPushNotification
  self.application = "calendar"

  # Custom notification logic for calendar app
end

class EmailPushNotification < ApplicationPushNotification
  self.application = "email"

  # Custom notification logic for email app
end
```

```yaml
shared:
  apple:
    # Base configuration for Apple platform
    # This will be merged with the app-specific configuration
    application:
      team_id: your_apple_team_id

    calendar:
      # Token auth params
      # See https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns
      key_id: <%= Rails.application.credentials.dig(:action_push_native, :apns, :calendar, :key_id) %>
      encryption_key: <%= Rails.application.credentials.dig(:action_push_native, :apns, :calendar, :encryption_key)&.dump %>
      # Your identifier found on https://developer.apple.com/account/resources/identifiers/list
      topic: calendar.bundle.identifier

    email:
      # Token auth params
      # See https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns
      key_id: <%= Rails.application.credentials.dig(:action_push_native, :apns, :email, :key_id) %>
      encryption_key: <%= Rails.application.credentials.dig(:action_push_native, :apns, :email, :encryption_key)&.dump %>
      # Your identifier found on https://developer.apple.com/account/resources/identifiers/list
      topic: email.bundle.identifier

  google:
    calendar:
      # Your Firebase project service account credentials
      # See https://firebase.google.com/docs/cloud-messaging/auth-server
      encryption_key: <%= Rails.application.credentials.dig(:action_push_native, :fcm, :calendar, :encryption_key)&.dump %>

      # Firebase project_id
      project_id: calendar_project_id

    email:
      # Your Firebase project service account credentials
      # See https://firebase.google.com/docs/cloud-messaging/auth-server
      encryption_key: <%= Rails.application.credentials.dig(:action_push_native, :fcm, :email, :encryption_key)&.dump %>

      # Firebase project_id
      project_id: email_project_id
```

## Usage

### Create and send a notification asynchronously to a device

```ruby
device = ApplicationPushDevice.create! \
  name: "iPhone 16",
  token: "6c267f26b173cd9595ae2f6702b1ab560371a60e7c8a9e27419bd0fa4a42e58f",
  platform: "apple"

notification = ApplicationPushNotification.new \
  title: "Hello world!",
  body:  "Welcome to Action Push Native"

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
  .new(title: "Welcome to Action Push Native")
```

### Custom platform Payload

You can configure custom platform payload to be sent with the notification. This is useful when you
need to send additional data that is specific to the platform you are using.

You can use `with_apple` for Apple, `with_google` for Android, and `with_web` for Web:

```ruby
notification = ApplicationPushNotification
  .with_apple(aps: { category: "observable", "thread-id": "greeting"}, "apns-priority": "1")
  .with_google(data: { badge: 1 })
  .with_web(webpush: { headers: { TTL: "300" }, data: { url: "https://example.com" } })
  .new(title: "Hello world!")
```

The platform payload takes precedence over the other fields, and you can use it to override the
default behaviour:

```ruby
notification = ApplicationPushNotification
  .with_google(android: { notification: { notification_count: nil } })
  .with_web(webpush: { notification: { tag: "custom" } })
  .new(title: "Hello world!", body: "Welcome to Action Push Native", badge: 1)
```

This will unset the default `notification_count` (`badge`) field in the Google payload, while keeping `title`
and `body`.

### Silent Notifications

You can create a silent notification via the `silent` method:

```ruby
notification = ApplicationPushNotification.silent.with_data(id: 1).new
```

This will create a silent notification for both Apple and Google platforms and sets an application
data field of `{ id: 1 }` for both platforms. Silent push notification must not contain any attribute which would trigger
a visual notification on the device, such as `title`, `body`, `badge`, etc.

### Linking a Device to a Record

A Device can be associated with any record in your application via the `owner` polymorphic association:

```ruby
  user = User.find_by_email_address("jacopo@37signals.com")

  ApplicationPushDevice.create! \
    name: "iPhone 16",
    token: "6c267f26b173cd9595ae2f6702b1ab560371a60e7c8a9e27419bd0fa4a42e58f",
    platform: "apple",
    owner: user
```
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
    .with_apple(data)
    .with_google(data: data)
    .new(calendar_id: 123)

  notification.deliver_later_to(device)
```

### Registering Web Push Devices via API

For web clients (including TWA-backed PWAs), obtain an FCM registration token in the browser and POST it to your backend as a `web` device.

```js
import { initializeApp } from "firebase/app";
import { getMessaging, getToken, isSupported } from "firebase/messaging";

const firebaseApp = initializeApp({
  apiKey: "...",
  projectId: "...",
  messagingSenderId: "...",
  appId: "...",
});

async function registerPushDevice() {
  if (!(await isSupported())) return;

  const registration = await navigator.serviceWorker.register("/firebase-messaging-sw.js");
  const messaging = getMessaging(firebaseApp);
  const token = await getToken(messaging, {
    serviceWorkerRegistration: registration,
    vapidKey: "YOUR_WEB_PUSH_CERTIFICATE_KEY_PAIR_VAPID_KEY",
  });

  if (!token) return;

  await fetch("/push_devices", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      device: {
        platform: "web",
        token,
        name: navigator.userAgent,
      },
    }),
    credentials: "include",
  });
}
```

```ruby
# app/controllers/push_devices_controller.rb
class PushDevicesController < ApplicationController
  protect_from_forgery with: :null_session

  def create
    device = ApplicationPushDevice.find_or_initialize_by(token: device_params[:token])
    device.assign_attributes(device_params.merge(owner: current_user))
    device.save!
    head :created
  end

  private
    def device_params
      params.require(:device).permit(:platform, :token, :name)
    end
end
```

### Using a custom Device model

If using the default `ApplicationPushDevice` model does not fit your needs, you can create a custom
device model, as long as:

1. It can be serialized and deserialized by `ActiveJob`.
2. It responds to the `token` and `platform` methods.
3. It implements a `push` method like this:

```ruby
class CustomDevice
  # Your custom device attributes and methods...

  def push(notification)
    notification.token = token
    ActionPushNative.service_for(platform, notification).push(notification)
  rescue ActionPushNative::TokenError => error
    # Custom token error handling
  end
end
```

## `ActionPushNative::Notification` attributes

| Name           | Description
|------------------|------------
| :title           | The title of the notification.
| :body            | The body of the notification.
| :badge           | The badge number to display on the app icon.
| :thread_id       | The thread identifier for grouping notifications.
| :sound           | The sound to play when the notification is received.
| :high_priority   | Whether the notification should be sent with high priority (default: true).
| :google_data     | The Google-specific payload for the notification.
| :web_data        | The Web-specific payload for the notification (FCM Web).
| :apple_data      | The Apple-specific payload for the notification. It can also be used to override APNs request headers, such as `apns-push-type`, `apns-priority`, etc.
| :data            | The data payload for the notification, sent to all platforms.
| **               | Any additional attributes passed to the constructor will be merged in the `context` hash.

### Factory methods

| Name           | Description
|------------------|------------
| :with_apple           | Set the Apple-specific payload for the notification.
| :with_google          | Set the Google-specific payload for the notification. It can also be used to override APNs request headers, such as `apns-push-type`, `apns-priority`, etc.
| :with_web             | Set the Web-specific payload for the notification.
| :with_data            | Set the data payload for the notification, sent to all platforms.
| :silent               | Create a silent notification that does not trigger a visual alert on the device.

## License

Action Push Native is licensed under MIT.
