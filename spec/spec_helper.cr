require "spec"
require "yaml"
require "../src/beanstalk-cr"

def create_populated_queue(entries : UInt32 = 1, delay : UInt32 = 0, name : String = Beanstalk::Tube::DEFAULT_QUEUE_NAME)
  jobs = Array(Beanstalk::Job).new
  tube = Beanstalk::Connection.open()[name]
  (0...entries).each do|i| 
    jobs << Beanstalk::Job.new("Some test data.")
    if delay > 0
      tube.put(jobs.last, Beanstalk::Job::Settings.new(Beanstalk::Job::Settings::DEFAULT_PRIORITY, delay))
    else
      tube.put(jobs.last)
    end
  end
  jobs
end

def get_test_connection()
  Beanstalk::Connection.open()
end

def get_test_job()
  Beanstalk::Job.new()
end

def get_test_server()
  Beanstalk::Server.new("localhost")
end

def get_test_tube()
  get_test_connection.default_tube
end
