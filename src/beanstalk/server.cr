module Beanstalk
  # This class represents a single server instance running the Beanstalk queue.
  class Server
    # Constant for the default Beanstalk port number.
    DEFAULT_PORT = 11300

    # Instance data.
    @host : String

    # Fetches the host name/IP address for the server.
    getter :host

    # Fetches the port number for the server.
    getter :port

    # Constructor.
    def initialize(host, port = DEFAULT_PORT)
      @host = host
      @port = port
    end

    # Generates a string for a Server.
    def to_s
      "#{host}:#{port}"
    end

    # Class method that converts a String in the form "host:port" into a Server
    # instance. The port part of the string is optional.
    def self.for(details : String)
      parts = details.split(":").map {|e| e.strip}
      host  = parts[0]
      port  = (parts.size > 1 ? parts[1].to_i : DEFAULT_PORT)
      Server.new(host, port)
    end
  end
end