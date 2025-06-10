require "test_helper"

module ActionNativePush
  module Service
    class ApnsTest < ActiveSupport::TestCase
      setup do
        @config = ActionNativePush.configuration.platforms[:ios]
        @apns = Apns.new(@config)
      end
      teardown { Apns.connection_pools = {} }

      test "push" do
        connection_pool = FakeConnectionPool.new(FakeResponse.new(status: "200"))
        Apns.connection_pools = { @config => connection_pool }

        notification = build_notification
        @apns.push(notification)

        assert_equal 1, connection_pool.deliveries.size

        options = connection_pool.deliveries.first[:options]
        assert_equal 30, options[:timeout]

        notification =  connection_pool.deliveries.first[:notification]
        assert_equal "123", notification.token
        assert_equal "Hi!", notification.alert[:title]
        assert_equal "This is a push notification", notification.alert[:body]
        assert_equal 1, notification.badge
        assert_equal "12345", notification.thread_id
        assert_equal "default", notification.sound
        assert_equal "readable", notification.category
        assert_equal "Jacopo", notification.custom_payload[:person]
      end

      test "push response error" do
        connection_pool = FakeConnectionPool.new(FakeResponse.new(status: "400"))
        Apns.connection_pools = { @config => connection_pool }

        assert_raises ActionNativePush::Errors::BadRequestError do
          @apns.push(build_notification)
        end

        connection_pool = FakeConnectionPool.new(FakeResponse.new(status: "400", body: { reason: "BadDeviceToken" }))
        Apns.connection_pools = { @config => connection_pool }

        assert_raises ActionNativePush::Errors::DeviceTokenError do
          @apns.push(build_notification)
        end
      end

      private
        class FakeConnectionPool
          attr_reader :deliveries

          def initialize(response)
            @response = response
            @deliveries = []
          end

          def with
            yield self
          end

          def push(notification, options = {})
            deliveries.push(notification:, options:)
            response
          end

          private
            attr_reader :response
        end

        class FakeResponse
          attr_reader :status, :body

          def initialize(status:, body: {})
            @status = status
            @body = body.stringify_keys
          end

          def ok?
            status.start_with?("20")
          end
        end

        def build_notification
          ActionNativePush::Notification.new \
            token: "123",
            title: "Hi!",
            body: "This is a push notification",
            badge: 1,
            thread_id: "12345",
            sound: "default",
            high_priority: false,
            platform_payload: { apns: { category: "readable" } },
            custom_payload: { person: "Jacopo" }
        end
    end
  end
end
