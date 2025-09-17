# frozen_string_literal: true

class ActionPushNative::Service::Apns::TokenProvider
  EXPIRED = -1

  def initialize(config)
    @config = config
    @expires_at = EXPIRED
  end

  def fresh_access_token
    regenerate_if_expired
    token
  end

  private
    attr_reader :config, :token, :expires_at

    # See https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns#Refresh-your-token-regularly
    def regenerate_if_expired
      if Time.now.utc >= expires_at
        @expires_at = 30.minutes.from_now.utc
        @token = generate
      end
    end

    def generate
      payload = { iss: config.fetch(:team_id), iat: Time.now.utc.to_i }
      header  = { kid: config.fetch(:key_id) }
      private_key = OpenSSL::PKey::EC.new(config.fetch(:encryption_key))
      JWT.encode(payload, private_key, "ES256", header)
    end
end
