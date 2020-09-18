require "../spec_helper"

describe Beanstalk::Connection do
  describe "#self.open()" do
    it "creates a connection with default settings" do
      connection = Beanstalk::Connection.open()
      connection.server.host.should eq Beanstalk::Connection::DEFAULT_HOST
      connection.server.port.should eq Beanstalk::Server::DEFAULT_PORT
    end
  end

  describe "#self.open(host, port)" do
    context "when only a host is specified" do
      it "creates a connection with the specified host and default port" do
        connection = Beanstalk::Connection.open("127.0.0.1")
        connection.server.host.should eq "127.0.0.1"
        connection.server.port.should eq Beanstalk::Server::DEFAULT_PORT
      end
    end

    context "when a host and a port are specified" do
      it "creates a connection with the specified host and port" do
        connection = Beanstalk::Connection.open("127.0.0.1", 11300)
        connection.server.host.should eq "127.0.0.1"
        connection.server.port.should eq 11300
      end
    end
  end

  describe "#self.open(server)" do
    it "creates a connection with the specified server details" do
      server = Beanstalk::Server.new("127.0.0.1", 11300)
      connection = Beanstalk::Connection.open(server)
      connection.server.host.should eq "127.0.0.1"
      connection.server.port.should eq 11300
    end

    it "raises an exception when it cannot connect to the server" do
      server = Beanstalk::Server.new("ningy.wahwah.flk")
      expect_raises(Beanstalk::Exception) do
        Beanstalk::Connection.open(server)
      end
    end
  end

  describe "#self.buffer_size()" do
    context "when the environment variable is not set" do
      it "will return the default setting" do
        Beanstalk::Connection.buffer_size.should eq Beanstalk::Connection::DEFAULT_BUFFER_SIZE.to_i
      end
    end

    context "when the environment variable is set" do
      it "will return a setting based on the environment variable" do
        ENV["BEANSTALK_READ_BUFFER_SIZE"] = "12345"
        Beanstalk::Connection.buffer_size.should eq 12345
        ENV["BEANSTALK_READ_BUFFER_SIZE"] = nil
      end
    end  
  end

  describe "#open?(), #close() & #closed?()" do
    it "returns true for an open connection" do
      connection = Beanstalk::Connection.open
      connection.open?.should be_true
      connection.closed?.should eq !connection.open?
    end

    it "return false for a closed connection" do
      connection = Beanstalk::Connection.open
      connection.close
      connection.open?.should be_false
      connection.closed?.should eq !connection.open?
    end
  end

  describe "#default_tube()" do
    it "returns a Tube set to use and watch the default queue" do
      tube = Beanstalk::Connection.open.default_tube
      tube.using.should eq Beanstalk::Tube::DEFAULT_QUEUE_NAME
      tube.watching.should eq [Beanstalk::Tube::DEFAULT_QUEUE_NAME]
    end
  end

  describe "#[]()" do
    it "returns a Tube set to use and watch the specified queue" do
      tube = Beanstalk::Connection.open["tester_tube"]
      tube.using.should eq "tester_tube"
      tube.watching.should eq [Beanstalk::Tube::DEFAULT_QUEUE_NAME, "tester_tube"]
    end
  end
end