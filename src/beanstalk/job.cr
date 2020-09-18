require "./tube"

module Beanstalk
  # This class represents a job within Beanstalk.
  class Job
    # Instance data.
    @id : Int64? = nil

    # Accessors & mutators.
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