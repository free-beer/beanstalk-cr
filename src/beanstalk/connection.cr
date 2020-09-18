require "socket"
require "yaml"
require "./server"

module Beanstalk
  # Constant for the default socket connect time out setting. This value can be
  # overridden using the BEANSTALK_CR_CONNECT_TIMEOUT environment setting.
  DEFAULT_CONNECT_TIMEOUT = "10"

  # A constant for the default buffer size to be used when reading data from the
  # Beanstalk server (in bytes).
  DEFAULT_BUFFER_SIZE = "1024"

  # Constant for the default read wait time (in milliseconds).
  DEFAULT_READ_WAIT_TIME = "10000"

  # Constant for the line ending used by Beanstalk commands.
  LINE_ENDING = [13_u8, 10_u8]

  # Constant for the stats job buffer size.
  STATS_BUFFER_SIZE = 4096

  # Instance data.
  @socket : Socket? = nil

  # Accessors & mutators.
  getter :server

  # This class encapsulates a connection to a Beanstalk instance. Note that
  # this class is not thread safe and instances of it should not be shared.
  class Connection
    # Accessors & mutators.
    getter :server
    getter :socket

    # Constructor.
    private def initialize(server : Server)
      @server              = server
      @socket              = Socket.new(Socket::Family::INET, Socket::Type::STREAM)
      Log.debug {"Setting socket read time out to #{Connection.read_wait_time} seconds."}
      # @socket.read_timeout = Connection.read_wait_time
    end

    # This method attempts to establish a connection with the Beanstalk
    # server.
    protected def connect()
      Log.debug {"Attempting to connect to Beanstalk on port #{@server.port}."}
      @socket.connect(@server.host, @server.port, socket_timeout)
    end

    # Terminates the connection to the Beanstalk server.
    def close
      Log.debug {"Closing connection to the #{@server.to_s} Beanstalk server."}
      @socket.close if open?
    end

    # Used to check if the connection is closed.
    def closed?
      !open?
    end

    # Fetches the default tube for a Connection.
    def default_tube()
      Tube.new(self)
    end

    # Used to check if the connection is open.
    def open?
      !@socket.nil? && !@socket.closed?
    end

    # Attempts to retrieve data from the Beanstalk server.
    def receive()
      Log.debug {"Receiving non-job data from the server."}
      data  = Array(UInt8).new
      slice = Slice.new(Connection.buffer_size, 0_u8)
      done  = false
      total = 0
      while !done
        read_size = 0
        begin
          read_size = @socket.read(slice)
        end

        data.concat(slice.to_a[0, read_size])
        done = (read_size < slice.size)
      end

      Log.debug {"Generating result buffer of #{data.size} bytes."}
      Slice.new(data.to_unsafe, data.size, read_only: true)
    rescue error
      Log.error {"Exception caught receiving data from the server.\nCause: #{error}\n#{error.backtrace.join("\n")}"}
      raise Beanstalk::Exception.new("Error receiving data from the Beanstalk server. Cause: #{error}")
    end

    # Attempts to retrieve the data for a job from the Beanstalk server. This
    # is a specialized method as retrieving job data is really the only variable
    # fetch from the Beanstalk server.
    def receive_job()
      Log.debug {"Receiving job data from the server."}
      data      = Array(UInt8).new
      slice     = Slice.new(Connection.buffer_size, 0_u8)
      read_size = 0
      begin
        read_size = @socket.read(slice)
      rescue error : IO::TimeoutError
        Log.debug {"Socket read timed out, assuming no more to be read."}
        read_size = 0
      end

      # Check if we max'ed out the read buffer.
      if read_size == slice.size
        # Assume we received a successful reserve and locate the line break offset.
        offset = 0
        while slice[offset].unsafe_chr != '\r' && offset < slice.size
          offset += 1
        end

        # Parse the response intro to get the full job size in bytes.
        _, _, job_size = String.new(slice[0, offset]).split(" ")
        job_size  = job_size.to_i32
        available = slice.size - (offset + 2)
        if available < job_size + 2
          # More to be read, so go get it.
          remaining = (job_size - available) + 2
          extra     = Slice.new(remaining, 0_u8)
          begin
            read_size = @socket.read(extra)
          rescue error : IO::TimeoutError
            Log.debug {"Socket read timed out, assuming no more to be read."}
            read_size = 0
          end

          if read_size != remaining
            Log.error {"Error reading data from Beanstalk server."}
            raise Beanstalk::Exception.new("Error reading data from Beanstalk server.")
          end

          # Copy all the data into the output array.
          data.concat(slice.to_a[0, slice.size])
          data.concat(extra.to_a[0, extra.size])
        else
          # Full job content retrieved, copy data into output array.
          data.concat(slice.to_a[0, read_size])
        end
      else
        # Copy the data straight across into the output array.
        data.concat(slice.to_a[0, read_size])
      end

      Log.debug {"Generating result buffer of #{data.size} bytes."}
      Slice.new(data.to_unsafe, data.size, read_only: true)
    rescue error
      Log.error {"Exception caught receiving data from the server.\nCause: #{error}\n#{error.backtrace.join("\n")}"}
      raise Beanstalk::Exception.new("Error receiving data from the Beanstalk server. Cause: #{error}")
    end

    # A method intended to fetch the response for a stats-job request.
    def receive_stats()
      Log.debug {"Receiving job data from the server."}
      data      = Array(UInt8).new
      slice     = Slice.new(STATS_BUFFER_SIZE, 0_u8)
      read_size = 0
      begin
        read_size = @socket.read(slice)
      rescue error : IO::TimeoutError
        Log.debug {"Socket read timed out, assuming no more to be read."}
        read_size = 0
      end

      if read_size == 0
        raise Beanstalk::Exception.new("Fetch of stats data from the Beanstalk server was unsuccessful.")
      end

      response = String.new(slice[0, read_size])
      Log.debug {"Stats Response:\n#{response}"}
      if !response.starts_with?("OK")
        Log.error {"Error fetching stats data from the Beanstalk server. Response:\n#{response}"}
        raise Beanstalk::Exception.new("Error fetching stats data from the Beanstalk server.")
      end
      lines = response.lines
      YAML.parse(lines[1,lines.size - 1].join("\n"))
    end

    # Dispatches a message to the Beanstalk server via the socket connection in
    # the appropriate format.
    def send(data : Slice(UInt8)?, *parameters)
      raise Beanstalk::Exception.new("Write called on closed Beanstalk connection.") if !open?

      message = Array(UInt8).new
      parameters.each do |parameter|
        message << 32_u8 if message.size > 0
        message.concat(parameter.to_s.to_slice)
      end
      message.concat(LINE_ENDING)
      if !data.nil? && data.size > 0
        message.concat(data.to_a)
        message.concat(LINE_ENDING)
      end

      Log.debug {"Server message contains #{message.size} bytes of data. Contents...\n#{message.to_s}"}
      @socket.write(Slice.new(message.to_unsafe, message.size, read_only: true))
      @socket.flush
    end

    # Fetches stats for the server attached to a connection.
    def stats()
      Log.debug {"Requesting server stats for the #{@server.to_s} server."}
      send(nil, "stats")
      receive_stats()
    end

    # Internal method used to generate the socket connect timeout setting.
    def socket_timeout
      ENV.fetch("BEANSTALK_CONNECT_TIMEOUT", DEFAULT_CONNECT_TIMEOUT).to_i
    end

    # Retrieves a tube with a given name.
    def [](name : String)
      Tube.new(self, name)
    end

    # Returns the size of the read buffer to be used when fetching data from
    # the server.
    def self.buffer_size
      ENV.fetch("BEANSTALK_READ_BUFFER_SIZE", DEFAULT_BUFFER_SIZE).to_i
    end

    # This method creates a Connection object connecting to Beanstalk on
    # localhost and using the default port.
    def self.open()
      self.open(Server.new("localhost"))
    end

    # This method creates a Connection object and attempts to connect it to
    # a Beanstalk server instance.
    def self.open(server : Server)
      Log.debug {"Establishing a connection to Beanstalk at #{server.host}:#{server.port}."}
      instance = self.new(server)
      instance.connect()
      instance
    end

    # This method creates a Connection object and attempts to connect it to
    # a Beanstalk server instance.
    def self.open(host, port=Server::DEFAULT_PORT)
      self.open(Server.new(host, port))
    end

    def self.read_wait_time
      Time::Span.new(nanoseconds: ENV.fetch("BEANSTALK_READ_WAIT_TIME", DEFAULT_READ_WAIT_TIME).to_u64 * 1000000)
    end
  end
end