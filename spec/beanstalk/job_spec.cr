require "../spec_helper"

describe Beanstalk::Job do
  describe "#initialize()" do
    context "tube only constructor" do
      it "creates an empty Job object" do
        job = Beanstalk::Job.new()
        job.size.should eq 0
      end
    end

    context "tube and data constructor" do
      it "creates a Job populated with the data passed in" do
        arrays = [[1_u8, 2_u8, 3_u8], [4_u8, 5_u8]]
        job = Beanstalk::Job.new(arrays[0], arrays[1])
        job.size.should eq 5
        job.bytes[0].should eq 1
        job.bytes[1].should eq 2
        job.bytes[2].should eq 3
        job.bytes[3].should eq 4
        job.bytes[4].should eq 5
      end
    end
  end

  describe "#append()" do
    context "for arrays of UInt8" do
      it "merges the array data into the Job data" do
        job = Beanstalk::Job.new()
        data = Array(UInt8).new
        data.push(1)
        data.push(2)

        job.append(data)
        job.size.should eq 2
        job.bytes[0].should eq 1
        job.bytes[1].should eq 2

        job.append(data)
        job.size.should eq 4
        job.bytes[0].should eq 1
        job.bytes[1].should eq 2
        job.bytes[2].should eq 1
        job.bytes[3].should eq 2
      end
    end

    context "for Strings" do
      it "merges the String data into the Job data" do
        job = Beanstalk::Job.new()

        job.append("12")
        job.size.should eq 2
        String.new(job.bytes).should eq "12"

        job.append("34")
        job.size.should eq 4
        String.new(job.bytes).should eq "1234"
      end
    end
  end

  describe "#bytes()" do
    it "returns an empty slice for a Job with no data" do
      job = Beanstalk::Job.new()
      job.bytes.size.should eq 0
    end

    it "returns a slice containing the complete Job data for a non-empty Job" do
      job = Beanstalk::Job.new("123", "456")
      job.bytes.size.should eq 6
      String.new(job.bytes).should eq "123456"
    end
  end

  describe "#size()" do
    it "returns 0 for an empty Job" do
      Beanstalk::Job.new().size.should eq 0
    end

    it "returns the Job's data size in bytes for a non-empty Job" do
      Beanstalk::Job.new("12", "34", "56").size.should eq 6
    end
  end

  describe "#to_s()" do
    it "returns an empty String for a Job with no data" do
      Beanstalk::Job.new().to_s.should eq ""
    end

    it "returns a String built from the Job data for a non-empty Job" do
      Beanstalk::Job.new("12", "34", "56").to_s.should eq "123456"
    end
  end
end