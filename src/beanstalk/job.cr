require "./tube"

module Beanstalk
  # This class represents a job within Beanstalk.
  class Job
    # This structure is used to encapsulate the concepts of priority, delay and
    # time to run which are associated with a job when it is put or released to
    # Beanstalk.
    struct Settings
      # Constant for the default delay setting.
      DEFAULT_DELAY = 0_u32

      # Constant for the default priority setting.
      DEFAULT_PRIORITY = 1000_u32

      # Constant for the default time to run setting (in seconds).
      DEFAULT_TIME_TO_RUN = 3600_u32

      # Accessor for the delay setting.
      property delay

      # Accessor for the priority setting.
      property priority

      # Accessor for the time_to_run setting.
      property time_to_run

      # Default constructor that creates an instance with default values for the
      # settings.
      def initialize()
        @delay       = Settings.default_delay
        @priority    = Settings.default_priority
        @time_to_run = Settings.default_time_to_run
      end

      # Explicit constructor.
      def initialize(@priority : UInt32, @delay : UInt32 = DEFAULT_DELAY, @time_to_run : UInt32 = DEFAULT_TIME_TO_RUN)
      end

      # Generates a delay setting based on either an environment variable or
      # a constant.
      def self.default_delay()
        ENV.fetch("BEANSTALK_DEFAULT_JOB_DELAY", "#{DEFAULT_DELAY}").to_u32
      end

      # Generates a priority setting based on either an environment variable or
      # a constant.
      def self.default_priority()
        ENV.fetch("BEANSTALK_DEFAULT_JOB_PRIORITY", "#{DEFAULT_PRIORITY}").to_u32
      end

      # Generates a time to run setting based on either an environment variable or
      # a constant.
      def self.default_time_to_run()
        ENV.fetch("BEANSTALK_DEFAULT_JOB_TTR", "#{DEFAULT_TIME_TO_RUN}").to_u32
      end
    end

    # --------------------------------------------------------------------------

    # Instance data.
    @id : Int64? = nil

    # Property for the job identifier. This will only be non-nil for jobs that
    # have actually been inserted into Beanstalk.
    property :id

    # Constructor.
    def initialize()
      @data = Array(UInt8).new
    end

    # Constructor that takes a collection of data elements and appends them to
    # the job. Note that entries must be of type Array(UInt8) or String.
    def initialize(*entries)
      @data = Array(UInt8).new
      entries.each {|entry| append(entry)}
    end

    # This method writes data into the job.
    def append(data : Array(UInt8))
      @data.concat(data)
    end

    # This method writes data into the job.
    def append(data : Slice(UInt8))
      append(data.to_a)
    end

    # Appends the content of a String to the Job data.
    def append(text : String)
      append(text.bytes)
    end

    # Fetches a slice of the data bytes within the Job.
    def bytes()
      Slice.new(@data.to_unsafe, @data.size, read_only: true)
    end

    # Fetches the size, in bytes, of the data currently held within the Job.    
    def size()
      @data.size
    end

    # Interprets the current data contents of a job as a string which is
    # returned from the  method call.
    def to_s
      @data.size > 0 ? String.new(bytes) : ""
    end
  end
end