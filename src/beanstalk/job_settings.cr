module Beanstalk
  # This structure is used to encapsulate the concepts of priority, delay and
  # time to run which are associated with a job when it is put or released to
  # Beanstalk.
  struct JobSettings
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
      @delay       = JobSettings.default_delay
      @priority    = JobSettings.default_priority
      @time_to_run = JobSettings.default_time_to_run
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
end