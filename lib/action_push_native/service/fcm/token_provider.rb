# frozen_string_literal: true

class ActionPushNative::Service::Fcm::TokenProvider
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

    def regenerate_if_expired
      regenerate if Time.now.utc >= expires_at
    end

    REFRESH_BUFFER = 1.minutes

    def regenerate
      authorizer = Google::Auth::ServiceAccountCredentials.make_creds \
        json_key_io: StringIO.new(config.fetch(:encryption_key)),
        scope: "https://www.googleapis.com/auth/firebase.messaging"
      oauth2 = authorizer.fetch_access_token!
      @token = oauth2["access_token"]
      @expires_at = oauth2["expires_in"].seconds.from_now.utc - REFRESH_BUFFER
    end
end
