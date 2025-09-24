module ActionPushNative::Service::NetworkErrorHandling
  private

  def handle_network_error(error)
    case error
    when Errno::ETIMEDOUT, HTTPX::TimeoutError
      raise ActionPushNative::TimeoutError, error.message
    when Errno::ECONNRESET, Errno::ECONNABORTED, Errno::ECONNREFUSED, Errno::EHOSTUNREACH,
      SocketError, IOError, EOFError, Errno::EPIPE, Errno::EINVAL, HTTPX::ConnectionError,
      HTTPX::TLSError, HTTPX::Connection::HTTP2::Error
      raise ActionPushNative::ConnectionError, error.message
    when OpenSSL::SSL::SSLError
      if error.message.include?("SSL_connect")
        raise ActionPushNative::ConnectionError, error.message
      else
        raise
      end
    end
  end
end
