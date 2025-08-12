require "test_helper"

module ActionPush
  module Service
    class ApnsTest < ActiveSupport::TestCase
      setup do
        @notification = build_notification
        @config = ActionPush.config_for(:apple, @notification)
        @apns = Apns.new(@config)
      end
      teardown { Apns.connection_pools = {} }

      test "push" do
        connection_pool = FakeConnectionPool.new(FakeResponse.new(status: "200"))
        Apns.connection_pools = { @config => connection_pool }

        @apns.push(@notification)

        assert_equal 1, connection_pool.deliveries.size

        options = connection_pool.deliveries.first[:options]
        assert_equal 60, options[:timeout]

        delivery =  connection_pool.deliveries.first[:notification]
        assert_equal "your.bundle.identifier", delivery.topic
        assert_equal "123", delivery.token
        assert_equal "Hi!", delivery.alert[:title]
        assert_equal "This is a push notification", delivery.alert[:body]
        assert_equal 1, delivery.badge
        assert_equal "12345", delivery.thread_id
        assert_equal "default", delivery.sound
        assert_equal "readable", delivery.category
        assert_equal 5, delivery.priority
        assert_equal "Jacopo", delivery.custom_payload[:person]
      end

      test "push response error" do
        connection_pool = FakeConnectionPool.new(FakeResponse.new(status: "400"))
        Apns.connection_pools = { @config => connection_pool }

        assert_raises ActionPush::BadRequestError do
          @apns.push(@notification)
        end

        connection_pool = FakeConnectionPool.new(FakeResponse.new(status: "400", body: { reason: "BadDeviceToken" }))
        Apns.connection_pools = { @config => connection_pool }

        assert_raises ActionPush::TokenError do
          @apns.push(@notification)
        end
      end

      test "push apns payload can be overridden" do
        connection_pool = FakeConnectionPool.new(FakeResponse.new(status: "200"))
        high_priority = 10
        Apns.connection_pools = { @config => connection_pool }
        @notification.apple_data = { priority: high_priority, "thread-id": "changed", custom_payload: nil }

        @apns.push(@notification)

        delivery =  connection_pool.deliveries.first[:notification]
        assert_equal high_priority, delivery.priority
        assert_equal "changed", delivery.thread_id
        assert_nil delivery.custom_payload
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
          ActionPush::Notification
            .with_apple(category: "readable")
            .with_data(person: "Jacopo")
            .new(
              title: "Hi!",
              body: "This is a push notification",
              badge: 1,
              thread_id: "12345",
              sound: "default",
              high_priority: false
            ).tap do |notification|
              notification.token = "123"
            end
        end
    end
  end
end
