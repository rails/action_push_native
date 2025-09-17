# frozen_string_literal: true

class ActionPushNative::Service::Apns::HttpxSession
  DEFAULT_POOL_SIZE       = 5
  DEFAULT_REQUEST_TIMEOUT = 30.seconds
  DEVELOPMENT_SERVER_URL  = "https://api.sandbox.push.apple.com:443"
  PRODUCTION_SERVER_URL   = "https://api.push.apple.com:443"

  def initialize(config)
    @session = \
      HTTPX.
        plugin(:persistent, close_on_fork: true).
        with(pool_options: { max_connections: config[:connection_pool_size] || DEFAULT_POOL_SIZE }).
        with(timeout: { request_timeout: config[:request_timeout] || DEFAULT_REQUEST_TIMEOUT }).
        with(origin: config[:connect_to_development_server] ? DEVELOPMENT_SERVER_URL : PRODUCTION_SERVER_URL)
    @token_provider = ActionPushNative::Service::Apns::TokenProvider.new(config)
  end

  def post(*uri, **options)
    options[:headers][:authorization] = "Bearer #{token_provider.fresh_access_token}"
    session.post(*uri, **options)
  end

  private
    attr_reader :token_provider, :session
end
