require "../spec_helper"

describe Beanstalk::Tube do
  #-----------------------------------------------------------------------------
  # bury()
  #-----------------------------------------------------------------------------
  describe "#bury()" do
    it "throws an exception for an unknown job id" do
      expect_raises(Beanstalk::Exception) do
        get_test_tube.bury(123123123)
      end
    end

    it "returns true when successful" do
      jobs = create_populated_queue
      tube = get_test_tube
      tube.bury(tube.reserve(Time::Span.new(seconds: 1))).should eq true
      tube.kick(100)
      tube.empty!
    end
  end

  #-----------------------------------------------------------------------------
  # delete()
  #-----------------------------------------------------------------------------
  describe "#delete()" do
    it "raises an exception when given a job with no id" do
      job    = Beanstalk::Job.new("Some content for the job.")
      job.id = 1000000.to_i64
      expect_raises(Beanstalk::Exception) do
        get_test_tube.delete(job)
      end
    end

    it "returns true when it successfully deletes a Job" do
      tube = get_test_tube
      tube.put(Beanstalk::Job.new("Test delete job data."))
      job = tube.reserve(Time::Span.new(seconds: 1))
      job.should_not be_nil
      tube.delete(job).should be_true
    end
  end

  #-----------------------------------------------------------------------------
  # delete?()
  #-----------------------------------------------------------------------------
  describe "#delete?()" do
    it "returns false for Jobs that have no id" do
      get_test_tube.delete?(get_test_job).should be_false
    end
  end

  #-----------------------------------------------------------------------------
  # empty!()
  #-----------------------------------------------------------------------------
  describe "empty!()" do
    it "returns 0 when called on an empty queue" do
      get_test_tube.empty!.should eq 0
    end

    it "returns the number of jobs deleted when called on a non-empty queue" do
      jobs = create_populated_queue(5)
      get_test_tube.empty!.should eq jobs.size
    end
  end

  #-----------------------------------------------------------------------------
  # ignore()
  #-----------------------------------------------------------------------------
  describe "#ignore()" do
    it "raises an exception when the queue name if the Tubes only watched queue" do
      expect_raises(Beanstalk::Exception) do
        get_test_tube.ignore(Beanstalk::Tube::DEFAULT_QUEUE_NAME)
      end
    end

    it "removes the specified queue from the Tube's watching list when successful" do
      tube = get_test_tube
      tube.watch("alternative_queue")
      tube.ignore(Beanstalk::Tube::DEFAULT_QUEUE_NAME)
      tube.watching.size.should eq 1
      tube.watching.should contain("alternative_queue")
    end
  end

  #-----------------------------------------------------------------------------
  # kick()
  #-----------------------------------------------------------------------------
  describe "#kick()" do
    it "returns 0 when there are no jobs to kick" do
      tube = get_test_tube
      tube.empty!
      get_test_tube.kick(10).should eq 0
    end

    it "returns the number of jobs kicked when there are jobs to kick" do
      tube = get_test_tube
      tube.empty!
      jobs = create_populated_queue(5)
      jobs.each {|job| tube.bury(tube.reserve())}
      tube.kick(5).should eq jobs.size
      tube.empty!
    end

    it "returns a lesser number if told to kick no more than that number and there are more jobs available" do
      tube = get_test_tube
      tube.use "test_tube"
      tube.watch "test_tube"
      tube.empty!
      jobs = create_populated_queue(5, 0, "test_tube")
      jobs.each do |job|
        tube.bury(tube.reserve())
      end
      tube.kick(3).should eq 3
      tube.kick(100)
      tube.empty!
    end
  end

  #-----------------------------------------------------------------------------
  # kick_job()
  #-----------------------------------------------------------------------------
  describe "#kick_job()" do
    it "returns false for an unknown job id" do
      get_test_tube.kick_job(123123123).should be_false
    end

    it "returns true when successful" do
      jobs = create_populated_queue
      tube = get_test_tube
      tube.bury(tube.reserve(Time::Span.new(seconds: 1)))
      tube.kick_job(jobs.first).should eq true
    end
  end

  #-----------------------------------------------------------------------------
  # peek()
  #-----------------------------------------------------------------------------
  describe "#peek()" do
    context "for buried jobs" do
      it "returns nil if there are no jobs available" do
        tube = get_test_tube
        tube.kick(100)
        tube.empty!
        tube.peek(Beanstalk::Tube::JobState::Buried).should be_nil
      end

      it "returns a Job instance when one is available" do
        jobs = create_populated_queue(1)
        tube = get_test_tube
        job = tube.reserve(Time::Span.new(seconds: 1))
        job.should_not be_nil
        tube.bury(job) if job.is_a?(Beanstalk::Job)
        job  = tube.peek(Beanstalk::Tube::JobState::Buried)
        job.should_not be_nil
        job.id.should eq jobs.first.id if job.is_a?(Beanstalk::Job)
        tube.kick(100)
        tube.empty!
      end
    end

    context "for delayed jobs" do
      it "returns nil if there are no jobs available" do
        tube = get_test_tube
        tube.empty!
        tube.peek(Beanstalk::Tube::JobState::Delayed).should be_nil
      end

      it "returns a Job instance when one is available" do
        jobs = create_populated_queue(1, 2)
        tube = get_test_tube
        job  = tube.peek(Beanstalk::Tube::JobState::Delayed)
        job.should_not be_nil
        job.id.should eq jobs.first.id if job.is_a?(Beanstalk::Job)
        sleep(Time::Span.new(seconds: 2))
        tube.empty!
      end
    end

    context "for ready jobs" do
      it "returns nil if there are no jobs available" do
        tube = get_test_tube
        tube.empty!
        tube.peek(Beanstalk::Tube::JobState::Ready).should be_nil
      end

      it "returns a Job instance when one is available" do
        jobs = create_populated_queue
        tube = get_test_tube
        job  = tube.peek(Beanstalk::Tube::JobState::Ready)
        job.should_not be_nil
        job.id.should eq jobs.first.id if job.is_a?(Beanstalk::Job)
        tube.empty!
      end
    end
  end

  #-----------------------------------------------------------------------------
  # put()
  #-----------------------------------------------------------------------------
  describe "#put()" do
    it "adds the specified job to the using queue" do
      job  = Beanstalk::Job.new("Some content for the job.")
      get_test_tube.put(job)
      job.id.should_not be_nil
      get_test_tube.empty!
    end
  end

  #-----------------------------------------------------------------------------
  # release()
  #-----------------------------------------------------------------------------
  describe "#release()" do
    it "raises an exception if given an invalid job id" do
      job    = Beanstalk::Job.new("Some content for the job.")
      job.id = 1000000.to_i64
      expect_raises(Beanstalk::Exception) do
        get_test_tube.release(job)
      end
    end

    it "returns true if successful" do
      job  = Beanstalk::Job.new("Some content for the job.")
      tube = get_test_tube
      tube.put(job)

      job = tube.reserve(Time::Span.new(seconds: 1))
      tube.release(job).should be_true if !job.nil?
    end
  end

  #-----------------------------------------------------------------------------
  # reserve()
  #-----------------------------------------------------------------------------
  describe "#reserve()" do
    it "returns a Job instance when one is available" do
      jobs = create_populated_queue
      tube = get_test_tube
      job = tube.reserve()
      job.should_not be_nil
      tube.release(job) if job.is_a?(Beanstalk::Job)
      tube.empty!
    end
  end

  #-----------------------------------------------------------------------------
  # reserve(job_id)
  #-----------------------------------------------------------------------------
  describe "#reserve(job_id)" do
    it "returns nil for a job that does not exist" do
      tube = get_test_tube
      tube.empty!
      expect_raises(Beanstalk::Exception) do
        tube.reserve(123123123)
      end
    end

    # it "returns a Job instance when a valid id is provided (fails for versions of Beanstalk before v1.12)" do
    #   jobs = create_populated_queue
    #   tube = get_test_tube
    #   job  = tube.reserve(jobs[0].id)
    #   job.should_not be_nil
    #   job.id.should eq jobs[0].id
    # end
  end

  #-----------------------------------------------------------------------------
  # reserve(Time::Span)
  #-----------------------------------------------------------------------------
  describe "#reserve(Time::Span)" do
    it "returns nil when no Job is available" do
      tube = get_test_tube
      tube.empty!
      job  = tube.reserve(Time::Span.new(seconds: 1))
      job.should be_nil
    end

    it "returns a Job instance when one is available" do
      jobs = create_populated_queue
      tube = get_test_tube
      job = tube.reserve(Time::Span.new(seconds: 1))
      job.should_not be_nil
      tube.release(job) if job.is_a?(Beanstalk::Job)
      tube.empty!
    end

    it "returns nil when no jobs are available and the time out expires" do
      tube = get_test_tube
      tube.empty!
      job = tube.reserve(Time::Span.new(seconds: 1))
      job.should be_nil
      tube.release(job) if job.is_a?(Beanstalk::Job)
      tube.empty!
    end
  end

  #-----------------------------------------------------------------------------
  # stats()
  #-----------------------------------------------------------------------------
  describe "#stats()" do
    it "returns an Any instance when invoked" do
      get_test_tube.stats.should be_a(YAML::Any)
    end
  end

  #-----------------------------------------------------------------------------
  # stats(job_id)
  #-----------------------------------------------------------------------------
  describe "#stats(job_id)" do
    it "raises an exception whenever an invalid job id is specified" do
      expect_raises(Beanstalk::Exception) do
        get_test_tube.stats(12345123)
      end
    end

    it "returns an Any instance when invoked for a valid job id" do
      job = create_populated_queue.first
      get_test_tube.stats(job).should be_a(YAML::Any)
      get_test_tube.empty!
    end
  end

  #-----------------------------------------------------------------------------
  # touch()
  #-----------------------------------------------------------------------------
  describe "#touch()" do
    it "raises an exception for a job id that does not exist" do
      expect_raises(Beanstalk::Exception) do
        get_test_tube.touch(12332123)
      end
    end

    it "returns true for a valid, reserved job" do
      jobs = create_populated_queue
      tube = get_test_tube
      job = tube.reserve(Time::Span.new(seconds: 1))
      tube.touch(job).should be_true
      tube.release(job) if job.is_a?(Beanstalk::Job)
      tube.empty!
    end
  end

  #-----------------------------------------------------------------------------
  # use()
  #-----------------------------------------------------------------------------
  describe "#use()" do
    it "switches the tube to using the given queue" do
      tube = get_test_tube
      tube.use("testq")
      tube.using.should eq "testq"
    end
  end

  #-----------------------------------------------------------------------------
  # watch()
  #-----------------------------------------------------------------------------
  describe "#watch()" do
    it "adds the queue to the Tube's watch list" do
      tube = get_test_tube
      tube.watch("other_queue")
      tube.watching.size.should eq 2
      tube.watching.should contain(Beanstalk::Tube::DEFAULT_QUEUE_NAME)
      tube.watching.should contain("other_queue")
    end
  end

  #-----------------------------------------------------------------------------
  # Tube.valid_tube_name?()
  #-----------------------------------------------------------------------------
  describe "#valid_tube_name?()" do
    it "returns false for invalid tube names" do
      Beanstalk::Tube.valid_tube_name?("-Wrong").should be_false
      Beanstalk::Tube.valid_tube_name?("Invalid!").should be_false
      Beanstalk::Tube.valid_tube_name?(("1234567890" * 20) + "0").should be_false
    end

    it "returns true for valid tube names" do
      Beanstalk::Tube.valid_tube_name?("TubeOne").should be_true
      Beanstalk::Tube.valid_tube_name?("Tube-Two").should be_true
      Beanstalk::Tube.valid_tube_name?("Tube-Three-123-+/;.$_()").should be_true
    end
  end
end