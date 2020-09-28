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

  describe "#self.for()" do
    it "returns a Server instance" do
      Beanstalk::Server.for("host.com:12345").should be_a Beanstalk::Server
    end

    it "sets the host and port correctly" do
      server = Beanstalk::Server.for("host.com:12345")
      server.host.should eq "host.com"
      server.port.should eq 12345
    end

    it "can default the port setting" do
      server = Beanstalk::Server.for("host.com")
      server.host.should eq "host.com"
      server.port.should eq Beanstalk::Server::DEFAULT_PORT
    end
  end
end