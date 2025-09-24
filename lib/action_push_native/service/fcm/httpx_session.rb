# frozen_string_literal: true

class ActionPushNative::Service::Fcm::HttpxSession
  # FCM suggests at least a 10s timeout for requests, we set 15 to add some buffer.
  # https://firebase.google.com/docs/cloud-messaging/scale-fcm#timeouts
  DEFAULT_REQUEST_TIMEOUT = 15.seconds
  DEFAULT_POOL_SIZE       = 5

  def initialize(config)
    @session = \
      HTTPX.
        plugin(:persistent, close_on_fork: true).
        with(timeout: { request_timeout: config[:request_timeout] || DEFAULT_REQUEST_TIMEOUT }).
        with(pool_options: { max_connections: config[:connection_pool_size] || DEFAULT_POOL_SIZE }).
        with(origin: "https://fcm.googleapis.com")
    @token_provider = ActionPushNative::Service::Fcm::TokenProvider.new(config)
  end

  def post(*uri, **options)
    options[:headers] ||= {}
    options[:headers][:authorization] = "Bearer #{token_provider.fresh_access_token}"
    session.post(*uri, **options)
  end

  private
    attr_reader :token_provider, :session
end
