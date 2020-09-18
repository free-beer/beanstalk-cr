require "../spec_helper"

describe Beanstalk::Server do
  describe "#initialize()" do
    context "specifying only host" do
      it "creates a valid server object" do
        subject = Beanstalk::Server.new("192.168.0.14")
        subject.host.should eq "192.168.0.14"
        subject.port.should eq Beanstalk::Server::DEFAULT_PORT
      end
    end

    context "specifying host and port" do
      it "creates a valid server object" do
        subject = Beanstalk::Server.new("test.beanstalk.net", 12345)
        subject.host.should eq "test.beanstalk.net"
        subject.port.should eq 12345
      end
    end
  end
end