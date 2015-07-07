require 'socket'

describe FFI::Libevent::Event do

  let(:base) { FFI::Libevent::Base.new }

  describe ".new" do
    it "returns an object of the correct class" do
      fps = UNIXSocket.pair
      expect(described_class.new(base, fps.first, :read) { |_,_,base| base.loopexit! }).
        to be_a described_class
    end
  end

  describe "reading a socket" do
    let(:sockets) { UNIXSocket.pair }
    subject{ described_class.new(base, sockets.first, :read) { |io,_,base| base.loopexit! if io.recv(4) == 'test' } }

    it "reads from the socket and exits" do
      sockets.last << "test"
      subject.add!
      expect(base.loop!).to eq 0
      expect(base.got_exit?).to be true
    end

    it "does nothing if the event is removed" do
      sockets.last << "test"
      subject.add!
      subject.del!
      expect(base.loop!).to eq 1
    end
  end

  describe "reading and writing a socket" do
    let(:sockets) { UNIXSocket.pair }
    let(:writer) { described_class.new(base, sockets.first, :write) { |io| io << "test" } }
    let(:reader) { described_class.new(base, sockets.last, :read) { |io,_,base| base.loopexit! if io.recv(4) == "test" } }

    it "can receive the data and close the loop" do
      reader.add!
      writer.add!
      expect(base.loop!).to eq 0
      expect(base.got_exit?).to be true
    end
  end

  describe "activating an event" do
    let(:sockets) { UNIXSocket.pair }
    let(:closer) { described_class.new(base, sockets.last, 0) { |_,_,base| base.loopexit! } }
    let(:writer) { described_class.new(base, sockets.first, :write) { |io| io << "test" } }
    let(:reader) { described_class.new(base, sockets.last, :read) { |io| closer.active!(:read, 0) if io.recv(4) == "test" } }

    it "can receive the data and close the loop" do
      reader.add!
      writer.add!
      expect(base.loop!).to eq 0
      expect(base.got_exit?).to be true
    end
  end

  describe "trapping an event" do
    it "receives the event" do
      pid = Process.fork do
        base.reinit!
        trapper = described_class.new(base, "USR1", :signal) { |_,_,base| base.loopbreak! }
        trapper.add!
        base.loop!
        expect(base.got_break?).to be true
      end

      sleep 1 # Give the proc time
      Process.kill "USR1", pid
      Process.wait pid
    end
  end

  describe "using a timer" do
    it "receives the event" do
      timer = described_class.new(base, "INT", FFI::Libevent::EV_SIGNAL | FFI::Libevent::EV_TIMEOUT) { |_,_,base| base.loopbreak! }
      timer.add! FFI::Libevent::Timeval.seconds(1)
      base.loop!
      expect(base.got_break?).to be true
    end
  end

  describe "multithreaded behaviour" do
    it "receives the event" do
      trapper = described_class.new(base, -1, 0) do |_,_,base|
        base.loopbreak!
      end
      trapper.add!

      # Start the loop in a thread
      t1 = Thread.new do
        base.loop!
      end

      # Tell the loop to stop from this thread
      trapper.active! :signal, 0
      t1.join
      
      expect(base.got_break?).to be true
    end
  end

  describe "deleting" do
    it "removes the event from the objectspace" do
      # Create event
      e = described_class.new(base, -1, 0){}
      id = e.object_id

      # Delete event and GC
      e = nil
      ObjectSpace.garbage_collect

      # Check that event has been deleted
      ObjectSpace.each_object(described_class) do |ev|
        expect(ev.object_id).not_to eq id
      end
    end
  end
end
