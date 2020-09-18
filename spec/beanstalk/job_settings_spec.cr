require "../spec_helper"

describe Beanstalk::Job::Settings do
  describe "#initialize()" do
    context "default constructor" do
      it "returns an instance with default settings" do
        settings = Beanstalk::Job::Settings.new
        settings.delay.should eq Beanstalk::Job::Settings::DEFAULT_DELAY
        settings.priority.should eq Beanstalk::Job::Settings::DEFAULT_PRIORITY
        settings.time_to_run.should eq Beanstalk::Job::Settings::DEFAULT_TIME_TO_RUN
      end

      it "should prefer environment variable settings where they are available" do
        ENV["BEANSTALK_DEFAULT_JOB_DELAY"]    = "100"
        ENV["BEANSTALK_DEFAULT_JOB_PRIORITY"] = "123"
        ENV["BEANSTALK_DEFAULT_JOB_TTR"]      = "456"
        settings = Beanstalk::Job::Settings.new
        settings.delay.should eq 100_u32
        settings.priority.should eq 123_u32
        settings.time_to_run.should eq 456_u32
      end
    end

    context "explicit constructor" do
      context "when given a single parameter" do
        it "returns an instance with all settings set appropriately" do
          settings = Beanstalk::Job::Settings.new(500_u32)
          settings.delay.should eq Beanstalk::Job::Settings::DEFAULT_DELAY
          settings.priority.should eq 500_u32
          settings.time_to_run.should eq Beanstalk::Job::Settings::DEFAULT_TIME_TO_RUN
        end
      end

      context "when given two parameters" do
        it "returns an instance with all settings set appropriately" do
          settings = Beanstalk::Job::Settings.new(500_u32, 123_u32)
          settings.delay.should eq 123_u32
          settings.priority.should eq 500_u32
          settings.time_to_run.should eq Beanstalk::Job::Settings::DEFAULT_TIME_TO_RUN
        end
      end

      context "when given three parameters" do
        it "returns an instance with all settings set appropriately" do
          settings = Beanstalk::Job::Settings.new(500_u32, 123_u32, 456_u32)
          settings.delay.should eq 123_u32
          settings.priority.should eq 500_u32
          settings.time_to_run.should eq 456_u32
        end
      end
    end
  end
end