module Beanstalk
  # This class represents a single server instance running the Beanstalk queue.
  class Server
    # Constant for the default Beanstalk port number.
    DEFAULT_PORT = 11300

    # Instance data.
    @host : String

    # Accessors & mutators.
    getter :host
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
  end
end