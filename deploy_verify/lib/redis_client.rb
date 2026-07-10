# frozen_string_literal: true

require "socket"

module DeployVerify
  # Minimal Redis RESP client (stdlib only) for cache probe on REDIS_CACHE_DB.
  class RedisClient
    class Error < StandardError; end

    def initialize(host:, port: 6379, password: nil, db: 0, timeout: 5)
      @host = host
      @port = port
      @password = password
      @db = db
      @timeout = timeout
    end

    def ping
      with_connection do |sock|
        auth!(sock)
        select_db!(sock)
        call(sock, "PING")
      end
    end

    def setex(key, seconds, value)
      with_connection do |sock|
        auth!(sock)
        select_db!(sock)
        call(sock, "SETEX", key, seconds.to_s, value)
      end
    end

    def get(key)
      with_connection do |sock|
        auth!(sock)
        select_db!(sock)
        call(sock, "GET", key)
      end
    end

    def dbsize
      with_connection do |sock|
        auth!(sock)
        select_db!(sock)
        call(sock, "DBSIZE")
      end
    end

    private

    def with_connection
      sock =
        if Socket.respond_to?(:tcp)
          begin
            Socket.tcp(@host, @port, connect_timeout: @timeout)
          rescue ArgumentError
            Socket.tcp(@host, @port)
          end
        else
          TCPSocket.new(@host, @port)
        end
      sock.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1) if sock.respond_to?(:setsockopt)
      sock.read_timeout = @timeout if sock.respond_to?(:read_timeout=)
      yield sock
    ensure
      sock&.close
    end

    def auth!(sock)
      return if @password.nil? || @password.empty?
      call(sock, "AUTH", @password)
    end

    def select_db!(sock)
      call(sock, "SELECT", @db.to_s)
    end

    def call(sock, *parts)
      payload = "*#{parts.size}\r\n"
      parts.each do |p|
        s = p.to_s
        payload << "$#{s.bytesize}\r\n#{s}\r\n"
      end
      sock.write(payload)
      read_reply(sock)
    end

    def read_reply(sock)
      line = sock.gets
      raise Error, "empty Redis reply" if line.nil?

      case line[0]
      when "+"
        line[1..].strip
      when "-"
        raise Error, line[1..].strip
      when ":"
        line[1..].to_i
      when "$"
        len = line[1..].to_i
        return nil if len < 0
        data = sock.read(len)
        sock.read(2) # CRLF
        data
      when "*"
        count = line[1..].to_i
        return [] if count < 0
        Array.new(count) { read_reply(sock) }
      else
        raise Error, "unknown Redis reply: #{line.inspect}"
      end
    end
  end
end
