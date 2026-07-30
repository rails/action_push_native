module ActionPushNative::Service::NetworkErrorHandling
  private

  def handle_network_error(error)
    case error
    when HTTPX::PoolTimeoutError
      raise ActionPushNative::ConnectionPoolTimeoutError, error.message, cause: error
    when Errno::ETIMEDOUT, HTTPX::TimeoutError
      raise ActionPushNative::TimeoutError, error.message, cause: error
    when Errno::ECONNRESET, Errno::ECONNABORTED, Errno::ECONNREFUSED, Errno::EHOSTUNREACH,
      SocketError, IOError, EOFError, Errno::EPIPE, Errno::EINVAL, HTTPX::ConnectionError,
      HTTPX::TLSError, HTTPX::Connection::HTTP2::Error
      raise ActionPushNative::ConnectionError, error.message, cause: error
    when OpenSSL::SSL::SSLError
      if error.message.include?("SSL_connect")
        raise ActionPushNative::ConnectionError, error.message, cause: error
      else
        raise error
      end
    end
  end
end
