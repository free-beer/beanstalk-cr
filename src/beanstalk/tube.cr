require "./connection"
require "./exceptions"

module Beanstalk
  # This class represents a Beanstalk tube.
  class Tube
    # Constant for the default tube name.
    DEFAULT_QUEUE_NAME = "default"

    # Constant for the maximum tube name length.
    MAX_NAME_LEN = 200

    # A constant for the valid name pattern.
    VALID_NAME_PATTERN = /^[A-Za-z0-9_\-\+;\$\/\.\(\)]{1,200}$/

    # An enumeration of the various job states.
    enum JobState
      Buried
      Delayed
      Ready
    end

    # Accessors & mutators.
    getter :connection
    getter :using
    getter :watching

    # Instance data.
    @watching : Array(String)
    @using : String

    # Constructor.
    def initialize(connection : Connection, name : String = DEFAULT_QUEUE_NAME)
      validate_tube_name!(name)
      @connection = connection
      @using      = DEFAULT_QUEUE_NAME
      @watching   = [DEFAULT_QUEUE_NAME]
      use(name) if name != DEFAULT_QUEUE_NAME
    end

    # Buries the specified job.
    def bury(job_id, priority : UInt32 = JobSettings::DEFAULT_PRIORITY)
      Log.debug {"Requesting that job id #{job_id} be buried with a priority of #{priority}."}
      connection.send(nil, "bury", job_id, priority)
      response = String.new(connection.receive())
      if !response.starts_with?("BURIED")
        Log.error {"Failed to bury job id #{job_id}. Response: #{response}"}
        raise Beanstalk::Exception.new("Failed to bury job id #{job_id}.")
      end
      true
    end

    # Buries the specified job.
    def bury(job : Job)
      raise Beanstalk::Exception.new("Job has no id and therefore cannot be buried.") if job.id.nil?
      bury(job.id)
    end

    # This method instructs the server to kick buried jobs to the ready queue.
    # No more than maximum jobs will be kicked by the server. If you specify
    # a maximum of zero then the method will automatical assume a maximum of
    # one. If successful the method returns the actual number of jobs that
    # were kicked.
    def kick(maximum : UInt32)
      maximum = 1 if maximum == 0
      Log.debug {"Instructing the server to kick at most #{maximum} buried jobs to the ready state for the #{using} queue."}
      connection.send(nil, "kick", maximum)
      response = String.new(connection.receive())
      if !response.starts_with?("KICKED")
        Log.error {"Failed to kick jobs for the #{using} queue. Response:\n#{response}"}
        raise Beanstalk::Exception.new("Failed to kick jobs for the #{using} queue.")
      end
      response.chomp.split(" ")[1].to_u32
    end

    # This method instructs the server to kick a specific job from the buried
    # state (if it is buried) to the ready state. The method returns a boolean
    # to indicate whether the kick request was successful.
    def kick_job(job_id)
      Log.debug {"Attempting to kick job id #{job_id}."}
      connection.send(nil, "kick-job", job_id)
      String.new(connection.receive()).starts_with?("KICKED")
    end

    # This method instructs the server to kick a specific job from the buried
    # state (if it is buried) to the ready state. The method returns a boolean
    # to indicate whether the kick request was successful.
    def kick_job(job : Job)
      raise Beanstalk::Exception.new("Job has no id and therefore cannot be kicked.") if job.id.nil?
      kick_job(job.id)
    end

    # Deletes a job from Beanstalk based on the job id. Returns true upon
    # successful completion. Raises an exception if the job id is invalid.
    def delete(job_id : Int64?)
      raise Beanstalk::Exception.new("Job has no id and therefore cannot be deleted.") if job_id.nil?
      Log.debug {"Requesting deletion of job id #{job_id}."}
      connection.send(nil, "delete", job_id)
      response = String.new(connection.receive())
      if !response.starts_with?("DELETED")
        Log.error {"Failed to delete Beanstalk job id #{job_id}. Response: #{response}"}
        raise Beanstalk::Exception.new("Job delete failed as server was unable to find it.")
      end
      true
    end

    # Deletes a Job from Beanstalk. Note the Job passed in *must* have an id
    # or an exception will be raised. Returns true upon completion.
    def delete(job : Job)
      delete(job.id)
    end

    # Attempts to delete the Job passed in. If the Job has no idea then the
    # method simply returns false, otherwise it makes a call to delete()
    # using the specified job.
    def delete?(job : Job)
      job.id.nil? ? false : delete(job.id)
    end

    # This method will reserve and delete every job that it can from a Tube and
    # will not return until it tries to reserve a job and receives nil back.
    # This method returns the number of jobs deleted from the queue.
    def empty!
      Log.warn {"WARNING: The '#{using}' queue is being emptied."}
      total = 0
      while job = reserve?
        Log.debug {"Deleting job id '#{job.id}' from the '#{using}' queue."}
        delete(job)
        total += 1
      end
      total
    end

    # This method instructs a Tube to stop watching a named queue for content.
    def ignore(name : String)
      if @watching.includes?(name)
        if @watching.size == 1
          Log.error {"Attempt made to remove tube's only remaining watched queue."}
          raise Beanstalk::Exception.new("Unable to ignore the '#{name}' queue as it is the only remaining one being watched.")
        end

        Log.debug {"Ignoring the '#{name}' queue."}
        connection.send(nil, "ignore #{name}")

        response = String.new(connection.receive())
        if !response.starts_with?("WATCHING")
          Log.error {"Failed to ignore the '#{name}' queue. Response:\n#{response}"}
          raise Beanstalk::Exception.new("Failed to ignore the '#{name}' queue.")
        end
        @watching.delete(name)
      end
      true
    end

    # Fetches details for a job, if one is available, without actually reserving
    # it. Note that you must stipulate the state of the job you would like to
    # peek at.
    def peek(state : JobState)
      Log.debug {"Peeking at the #{state} state jobs using a watch list of - #{watching.join(", ")}"}
      connection.send(nil, "peek-#{state.to_s.downcase}")
      handle_job_response(connection.receive_job())
    end

    # This method puts a Job into the queue currently being used by the
    # Tube.
    def put(job : Job, settings : JobSettings? = nil)
      settings = JobSettings.new if settings.nil?
      bytes    = job.bytes
      Log.debug {"Adding a job to a tube using the '#{using}' queue."}
      connection.send(bytes, "put", settings.priority, settings.delay, settings.time_to_run, bytes.size)

      response = String.new(connection.receive())
      parts    = response.chomp.split(" ")
      outcome  = parts[0]
      job_id   = parts[1].to_i64 if parts.size > 1
      if !outcome == "INSERTED"
        message = ""
        case outcome
          when "BURIED"
            message = "Server is out of memory to grow priority queue, buried response returned."
          when "JOB_TOO_BIG"
            message = "Job was larger than permitted maximum job size in bytes."
          when "DRAINING"
            message = "The Beanstalk server is in draining mode and not accepting new jobs."
          else
            message = "An unexpected error occurred sending a job to the Beanstalk server."
        end
        Log.error {"Error putting Beanstalk job. #{message}. Response:\n#{response}"}
        raise Beanstalk::Exception.new(message)
      end
      Log.debug {"Job added to the #{@using} Beanstalk queue with an id of #{job_id}."}
      job.id = job_id
    end

    # This method releases a Job that had previously been reserved. Note that,
    # if job settings are specified, only the priority and delay are set when
    # the job is released.
    def release(job : Job, settings : JobSettings? = nil)
      raise Beanstalk::Exception.new("Job has no id and cannot be released.") if job.id.nil?
      Log.debug {"Requesting release of job id #{job.id}."}
      settings = JobSettings.new if settings.nil?
      connection.send(nil, "release", job.id, settings.priority, settings.delay)

      response = String.new(connection.receive()).chomp
      if response != "RELEASED"
        message = ""
        case response
          when "BURIED"
            message = "Server is out of memory to grow priority queue, buried response returned."
          else
            message = "Unable to release job id #{job.id} as the job was not found."
        end
        Log.error {"Release job id #{job.id} filed. #{message}. Response:\n#{response}"}
        raise Beanstalk::Exception.new(message)
      end
      true
    end

    # Reserves a job from a Tube based on it's id. This method will raises
    # an exception if the Job could not be found.
    def reserve(job_id)
      job = reserve?(job_id)
      raise Beanstalk::Exception.new("Unable to locate a job with an id of #{job_id}.") if job.nil?
      job
    end

    # Reserves a job from a Tube based on it's id. This method will return
    # nil if the Job could not be found.
    def reserve?(job_id) : Job?
      Log.debug {"Reserving job id #{job_id} from a tube with a watch list of #{watching.join(", ")}"}
      connection.send(nil, "reserve-job", job_id)
      handle_job_response(connection.receive_job())
    end

    # Attempts to reserve a job from a Tube, blocking until one becomes
    # available.
    def reserve() : Job
      Log.debug {"Reserving job from a tube, with blocking and a watch list of #{watching.join(", ")}"}
      connection.send(nil, "reserve")
      job = handle_job_response(connection.receive_job())
      if job.is_a?(Nil)
        raise Beanstalk::Exception.new("Error reserving job from tube.")
      else
        job
      end
    end

    # Attempts to reserve a Job from a Tube. Takes an optional time_out parameter
    # the indicates the mimimum number of seconds to wait for a Job to become
    # available before giving up and returning nil. The time_out parameter
    # defaults to -1 to indicate that the reserve should wait indefinitely.
    def reserve(time_out : Time::Span) : Job|Nil
      Log.debug {"Reserving job from a tube with a time out of #{time_out.total_seconds.to_i} and a watch list of #{watching.join(", ")}."}
      connection.send(nil, "reserve-with-timeout #{time_out.total_seconds.to_i}")
      handle_job_response(connection.receive_job())
    end

    # This method is equivalent to calling the reserve method with a time out
    # of zero. It should return immediately with either a Job or nil.
    def reserve?
      reserve(Time::Span.new(seconds: 0))
    end

    # This method fetches stats for the queue being used by a tube.
    def stats
      Log.debug {"Attempting to fetch stats for a tube."}
      connection.send(nil, "stats-tube", using)
      connection.receive_stats()
    end

    # This method fetches information relating to a specific job.
    def stats(job_id : Int|String)
      Log.debug {"Attempting to fetch stats for job id #{job_id}."}
      connection.send(nil, "stats-job", job_id)
      connection.receive_stats()
    end

    # This method fetches information relating to a specific job.
    def stats(job : Job)
      job_id = job.id
      if job_id.is_a?(Nil)
        raise Beanstalk::Exception.new("Job has no id so stats cannot be fetched for it.")
      else
        stats(job_id)
      end
    end

    # Touches the specified job, extending it's current time to run.
    def touch(job_id)
      Log.debug {"Attempting to touch job id #{job_id}."}
      connection.send(nil, "touch", job_id)
      response = String.new(connection.receive())
      if !response.starts_with?("TOUCHED")
        Log.error {"Failed to touch job id #{job_id}. Response: #{response}"}
        raise Beanstalk::Exception.new("Failed to touch job id #{job_id}.")
      end
      true
    end

    # Touches the specified job, extending it's current time to run.
    def touch(job : Job)
      raise Beanstalk::Exception.new("Job has no id and therefore cannot be touched.") if job.id.nil?
      touch(job.id)
    end

    # Instructs a Tube to use a given queue name, supplanting the previously
    # used name. The queue name provided must be valid.
    def use(name : String)
      validate_tube_name!(name)
      Log.debug {"Setting the '#{name}' queue as the one to be used for jobs."}
      connection.send(nil, "use", name)

      response = String.new(connection.receive())
      if !response.chomp.starts_with?("USING")
        message = "Failed to switch tube to using '#{name}'."
        Log.error {"#{message} Server Response:\n'#{response}'"}
        raise Beanstalk::Exception.new(message)
      end
      @using = response.chomp.split(" ")[1]
    end

    # Instructs a tube to watch a named queue for content. If the named queue
    # does not exist it will be created.
    def watch(name : String)
      if !@watching.includes?(name)
        validate_tube_name!(name)
        Log.debug {"Adding the '#{name}' queue to the watching list."}
        connection.send(nil, "watch #{name}")

        response = String.new(connection.receive())
        if !response.starts_with?("WATCHING")
          Log.error {"Failed to watch the '#{name}' queue."}
          raise Beanstalk::Exception.new("Failed to watch the '#{name}' queue.")
        end
        @watching << name
      end
      true
    end

    # A method to check whether a given string is a valid tube name.
    def self.valid_tube_name?(name : String)
      VALID_NAME_PATTERN.matches?(name) && !name.starts_with?("-")
    end

    private def handle_job_response(response)
      job : Job? = nil
      if response.size > 0
        offset = 0
        prefix = ""
        if (prefix = String.new(response[0, 5])) == "FOUND"
          offset = 6
        elsif (prefix = String.new(response[0, 8])) == "RESERVED"
          offset = 9
        else
          offset = -1
        end

        if offset > 0
          prefix_span = prefix.size + 1
          while response[offset].unsafe_chr != '\r' && offset < response.size
            offset += 1
          end
          job_id, job_size = String.new(response[prefix_span, (offset - prefix_span)]).split(" ")

          offset += 2
          job = Job.new(response[offset, job_size.to_i])
          job.id = job_id.to_i64
        end
      end
      job
    end

    private def validate_tube_name!(name)
      raise Beanstalk::Exception.new("'#{name}' is not a valid tube name.") if !Beanstalk::Tube.valid_tube_name?(name)
    end
  end
end