describe FFI::Libevent::BufferEvent do
  let(:base) { FFI::Libevent::Base.new num_priorities: 10 }
  let(:pair) { UNIXSocket.pair }

  describe '.socket' do
    it "is freed by calling bufferevent_free" do
      obj = described_class.socket(base, pair[0])
      obj.free
    end

    shared_examples :returns do
      it "returns an object of the correct class" do
        expect(obj).to be_a described_class
      end
    end

    shared_examples :does_not_close_socket do
      it "leaves the socket intact" do
        pair[0] << "Test"
        obj.free
        pair[0] << "Test"
      end
    end

    context "without flags" do
      let(:obj) { described_class.socket base, pair[0] }
      include_examples :returns
      include_examples :does_not_close_socket
    end

    shared_examples :closes_socket do
      it "closes the socket when the object is freed" do
        pair[0] << "Test"
        obj.free
        expect{ pair[0] << "Test" }.to raise_error Errno::EBADF
      end
    end

    context "with close_on_free symbol flag" do
      let(:obj) { described_class.socket base, pair[0], :close_on_free }
      include_examples :returns
      include_examples :closes_socket
    end

    context "with close_on_free integer flag" do
      let(:obj) { described_class.socket base, pair[0], FFI::Libevent::BEV_OPT_CLOSE_ON_FREE }
      include_examples :returns
      include_examples :closes_socket
    end

    context "with a null socket" do
      let(:obj) { described_class.socket base, nil }
      include_examples :returns
    end

  end

  describe '#connect' do
    let(:bufferevent) { described_class.socket base }

    shared_examples :connects do
      it "connects to the address" do
        expect{ bufferevent.connect addr }.not_to raise_error
      end
    end

    context "with a sockaddr array" do
      let(:addr) { Socket.sockaddr_in(80, '127.0.0.1') }
      include_examples :connects
    end

    context "with a sockaddr string" do
      let(:addr) { Addrinfo.new(Socket.sockaddr_in(80, '127.0.0.1')).to_sockaddr }
      include_examples :connects
    end

    context "with an Addrinfo object" do
      let(:addr) { Addrinfo.new(Socket.sockaddr_in(80, '127.0.0.1')) }
      before{ pair[0].close }

      include_examples :connects
    end
  end

  describe "#connect_hostname" do
    let(:bufferevent) { described_class.socket base }

    shared_examples :connects do
      it "connects to the address" do
        expect{ bufferevent.connect_hostname family, hostname, port }.not_to raise_error
      end
    end

    context 'inet' do
      let(:family) { :inet }
      let(:hostname) { 'localhost' }
      let(:port) { 80 }
      include_examples :connects
    end

    context 'inet6' do
      let(:family) { :inet6 }
      let(:hostname) { 'localhost' }
      let(:port) { 80 }
      include_examples :connects
    end

  end

  describe '#dns_error?' do
    let(:bufferevent) { described_class.socket base }

    before do
      bufferevent.connect_hostname :inet, 'nonexist.example.com', 80
      base.loop! :nonblock
    end

    it "returns a Error::GAI object" do
      expect(bufferevent.dns_error?).to be_a FFI::Libevent::Error::GAI
      expect(bufferevent.dns_error?.to_s).to eq "nodename nor servname provided, or not known"
    end
  end

  describe '#set_callbacks' do
    let(:bufferevent) { described_class.socket base, pair[0] }

    it "connects the read callback" do
      called = false
      equal = false

      cb = proc do |bev|
        called = true
        equal = bev == bufferevent
      end

      bufferevent.set_callbacks read: cb
      bufferevent.enable! :read

      pair[1] << 'testing 1 2 3 4'
      base.loop! :nonblock

      expect(called).to be true
      expect(equal).to be true
    end

    it "connects the write callback" do
      called = false
      equal = false
      cb = proc do |bev|
        called = true
        equal = bev == bufferevent
      end
      bufferevent.set_callbacks write: cb
      expect(bufferevent.write "test").to eq 0
      base.loop! :nonblock

      expect(called).to be true
      expect(equal).to be true
    end
  end

  describe '#enable! and #disable!' do
    let(:bufferevent) { described_class.socket base, pair[0] }

    context "reading" do
      it "is not enabled by default" do
        called = false
        cb = proc{ called = true }

        expect(bufferevent.enabled? :read).to be false
        expect(bufferevent.enabled? FFI::Libevent::EV_READ).to be false
        bufferevent.set_callbacks read: cb
        pair[1] << 'testing 1 2 3 4'
        base.loop! :nonblock

        expect(called).to be false
      end

      it "enables reading when :read is passed" do
        called = false
        cb = proc{ called = true }

        bufferevent.set_callbacks read: cb
        bufferevent.enable! :read
        pair[1] << 'testing 1 2 3 4'
        base.loop! :nonblock

        expect(called).to be true
      end

      it "enables reading when the EV_READ constant is passed" do
        called = false
        cb = proc{ called = true }

        bufferevent.set_callbacks read: cb
        bufferevent.enable! FFI::Libevent::EV_READ
        pair[1] << 'testing 1 2 3 4'
        base.loop! :nonblock

        expect(called).to be true
      end

      it "can be disabled again" do
        called = false
        cb = proc{ called = true }

        bufferevent.set_callbacks read: cb
        bufferevent.enable! FFI::Libevent::EV_READ
        bufferevent.disable! :read
        pair[1] << 'testing 1 2 3 4'
        base.loop! :nonblock

        expect(called).to be false
      end
    end

    context "writing" do
      it "is enabled by default" do
        called = false
        cb = proc{ called = true }

        expect(bufferevent.enabled? :write).to be true
        expect(bufferevent.enabled?(FFI::Libevent::EV_READ | FFI::Libevent::EV_WRITE)).to be false
        bufferevent.set_callbacks write: cb
        expect(bufferevent.write "test").to eq 0
        base.loop! :nonblock

        expect(called).to be true
      end

      it "can be disabled" do
        called = false
        cb = proc{ called = true }

        bufferevent.set_callbacks write: cb
        bufferevent.disable! :write
        expect(bufferevent.write "test").to eq 0
        base.loop! :nonblock

        expect(called).to be false
      end

      it "can be re-enabled, writing anything that is pending" do
        called = false
        cb = proc{ called = true }

        bufferevent.set_callbacks write: cb
        bufferevent.disable! :write
        expect(bufferevent.enabled? :write).to be false
        expect(bufferevent.write "test").to eq 0
        base.loop! :nonblock

        bufferevent.enable! :write
        base.loop! :nonblock

        expect(called).to be true
      end
    end
  end

  describe "#set_watermark" do
    let(:bufferevent) { described_class.socket base, pair[0] }

    describe "writing" do
      context "zero low-water mark" do
        it "means the writecb will be called when the buffer is empty" do
          called = false

          bufferevent.set_watermark :write, 0
          bufferevent.set_callbacks write: proc{ called = true }

          # This will easily drain
          expect(bufferevent.write("t" * 1)).to eq 0
          base.loop! :nonblock
          expect(called).to be true

          # This probably won't drain
          called = false
          expect(bufferevent.write("t" * 1024**2)).to eq 0
          base.loop! :nonblock
          expect(called).to be false
        end
      end

      context "non-zero low-water mark" do
        it "stops writecb being called if number of bytes is too small" do
          called = false
          cb = proc{ called = true }

          # Don't call until there are fewer than 1024 bytes left
          bufferevent.set_watermark :write, 1024
          bufferevent.set_callbacks write: cb

          # Write a MiB.  This (probably) won't be written in a single
          # go
          expect(bufferevent.write("t" * 1024**2)).to eq 0
          base.loop! :nonblock

          expect(called).to be false
        end
      end
    end

    describe "reading" do
      context "zero low-water mark" do
        it "means that the callback is called if the buffer isn't empty" do
          called = false
          cb = proc{ called = true }

          bufferevent.enable! :read
          bufferevent.set_watermark :read, 0
          bufferevent.set_callbacks read: cb
          pair[1] << 't'
          base.loop! :nonblock

          expect(called).to be true
        end
      end

      context "non-zero low-water mark" do
        it "means that the callback isn't called until the buffer is sufficiently full" do
          called = false
          cb = proc{ called = true }

          bufferevent.enable! :read
          bufferevent.set_callbacks read: cb

          # Don't invoke callback till there are 10 bytes
          bufferevent.set_watermark :read, 10

          # Write 9 bytes
          pair[1] << ('t' * 9)
          base.loop! :nonblock
          expect(called).to be false

          # Write 1 byte
          pair[1] << 't'
          base.loop! :nonblock
          expect(called).to be true
        end
      end
    end
  end

  describe '#input' do
    let(:bufferevent) { described_class.socket base, pair[0] }

    it "returns an EvBuffer object" do
      expect(bufferevent.input).to be_a FFI::Libevent::EvBuffer
    end
  end

  describe '#output' do
    let(:bufferevent) { described_class.socket base, pair[0] }

    it "returns an EvBuffer object" do
      expect(bufferevent.output).to be_a FFI::Libevent::EvBuffer
    end
  end

  describe '#write' do
    let(:bufferevent) { described_class.socket base, pair[0] }

    context 'with a string' do
      let(:what) { 'this is a test' }

      shared_examples :writes_something do
        before do
          bufferevent.write what, len
          base.loop! :nonblock
        end

        it "writes all or part of the string, according to len" do
          l = [what.length, len].compact.min
          result = pair[1].recv(l)
          expect(result).not_to be_empty
          expect(result.length).to eq l
          expect(what).to start_with result
        end
      end

      context 'without a length' do
        let(:len) { nil }
        include_examples :writes_something
      end

      context 'with a length less than the string length' do
        let(:len) { 4 }
        include_examples :writes_something
      end

      context 'with a length greater than the string length' do
        let(:len) { what.length * 2 }
        include_examples :writes_something
      end
    end

    context "with a EvBuffer" do
      let(:str){ "this is a test" }
      let(:evbuffer) do
        evbuffer = FFI::Libevent::EvBuffer.new
        evbuffer.add str
        evbuffer
      end

      it "writes the contents of the EvBuffer" do
        bufferevent.write evbuffer
        base.loop! :nonblock
        result = pair[1].recv(str.length)
        expect(result).not_to be_empty
        expect(result).to eq str
      end
    end
  end

  describe '#read' do
    let(:bufferevent){ described_class.socket base, pair[0] }

    context "with an EvBuffer" do
      let(:str){ "this is a test" }
      let(:evbuffer){ FFI::Libevent::EvBuffer.new }

      it "reads into the buffer" do
        expect(evbuffer.length).to eq 0

        pair[1] << str

        bufferevent.enable! :read
        base.loop! :nonblock
        bufferevent.read evbuffer
        expect(evbuffer.length).to eq str.length
      end
    end

    context "with an integer" do
      let(:str){ "this is a test" }

      it "returns a string" do
        expect(bufferevent.read 1).to be_a String
      end

      context "when there is nothing to read" do
        it "returns an empty string" do
          expect(bufferevent.read 1000).to be_empty
        end
      end

      context "when there is more than the given length to read" do
        before{ pair[1] << str }

        it "returns a string of length equal to the parameter" do
          bufferevent.enable! :read
          base.loop! :nonblock
          expect(bufferevent.read 2).to eq str[0..1]
        end
      end

      context "when there is less than the given length to read" do
        before{ pair[1] << str }

        it "returns the whole string" do
          bufferevent.enable! :read
          base.loop! :nonblock
          expect(bufferevent.read 1024).to eq str
        end
      end
    end

    context "with a pointer and a length" do
      let(:str){ "Some random text" }
      let(:len){ 1024 }
      let(:mem){ FFI::MemoryPointer.new(len) }

      before do
        pair[1] << str
        bufferevent.enable! :read
        base.loop! :nonblock
      end

      it "returns the number of bytes read" do
        expect(bufferevent.read mem, len).to eq str.length
      end

      it "reads into the pointer" do
        l = bufferevent.read(mem,len)
        expect(mem.read_string(l)).to eq str
      end
    end
  end

  describe "#set_timeouts" do
    let(:bufferevent){ described_class.socket base, pair[0] }
    let(:timeout){ 0.5 }

    before do
      timer = FFI::Libevent::Event.new(base, "INT", :signal) { base.loopbreak! }
      timer.add! FFI::Libevent::Timeval.seconds(timeout)
    end

    shared_examples :does_nothing do
      it "never calls the eventcb" do
        called = false
        cb = proc{ called = true }

        bufferevent.set_callbacks event: cb

        base.loop!
        expect(base.got_break?).to be true
        expect(called).to be false
      end
    end

    context "when not set" do
      include_examples :does_nothing
    end

    context "when set to nil" do
      before do
        bufferevent.set_timeouts nil, nil
      end

      include_examples :does_nothing
    end

    context "when read timeout is not nil" do
      let(:read_timeout){ timeout/2 }

      context "when reading is not enabled" do
        before do
          bufferevent.set_timeouts(read_timeout)
          bufferevent.disable! :read
        end

        include_examples :does_nothing
      end

      context "when reading is enabled" do
        before do
          bufferevent.enable! :read
        end

        shared_examples :read_timeout do
          it "calls the eventcb after the given number of seconds" do
            start = Time.now
            time_called = nil
            cb = proc{ time_called = Time.now }
            bufferevent.set_callbacks event: cb

            base.loop!
            expect(base.got_break?).to be true
            expect(time_called).not_to be_nil
            expect(time_called - start).to be_within(0.005).of(read_timeout)
          end

          it "passes the READING flag to the eventcb" do
            equal = false
            read = false
            cb = proc do |bev,events|
              equal = bev == bufferevent
              read = events & FFI::Libevent::BEV_EVENT_READING != 0
            end

            bufferevent.set_callbacks event: cb

            base.loop!
            expect(base.got_break?).to be true
            expect(equal).to be true
            expect(read).to be true
          end

          it "passes the TIMEOUT flag to the eventcb" do
            timeout = false
            cb = proc do |bev,events|
              timeout = events & FFI::Libevent::BEV_EVENT_TIMEOUT != 0
            end

            bufferevent.set_callbacks event: cb

            base.loop!
            expect(base.got_break?).to be true
            expect(timeout).to be true
          end
        end

        context "when set to a number" do
          before do
            bufferevent.set_timeouts(read_timeout)
          end

          include_examples :read_timeout
        end

        context "when set to a Timeval" do
          let(:tv){ FFI::Libevent::Timeval.us(read_timeout*1_000_000) }
          before do
            bufferevent.set_timeouts(tv)
          end

          include_examples :read_timeout
        end
      end
    end

    context "when write timeout is not nil" do
      let(:write_timeout){ timeout/2 }

      ##
      # Simulating a write timeout seems to be too hard
      context "when writing is not enabled" do
        before do
          bufferevent.set_timeouts(nil, write_timeout)
          bufferevent.disable! :write
        end

        include_examples :does_nothing
      end
    end
  end

  describe '#priority=' do
    let(:bufferevent){ described_class.socket base, pair[0] }

    it "works for any positive integer" do
      expect{ bufferevent.priority = -1 }.to raise_error
      expect{ bufferevent.priority = 0 }.not_to raise_error
      expect{ bufferevent.priority = 9 }.not_to raise_error
    end
  end

  describe '#fd' do
    let(:bufferevent){ described_class.socket base, pair[0] }

    it "returns the file number of the bufferevent" do
      expect(bufferevent.fd).to eq pair[0].fileno
    end
  end

  describe '#fd=' do
    let(:bufferevent){ described_class.socket base, pair[0] }

    context "with a Socket object" do
      it "replaces the file descriptor" do
        bufferevent.fd = pair[1]
        expect(bufferevent.fd).to eq pair[1].fileno
      end
    end

    context "with nil" do
      it "sets the fileno to -1" do
        bufferevent.fd = nil
        expect{ bufferevent.fd }.to raise_error
      end
    end
  end

  describe '#locked' do
    context "when not threadsafe" do
      let(:bufferevent){ described_class.socket base, pair[0] }

      it "works (but has no effect)" do
        called = false
        bufferevent.locked do
          called = true
        end
        expect(called).to be true
      end
    end

    context "when threadsafe" do
      let(:bufferevent){ described_class.socket base, pair[0], :threadsafe }

      it "works" do
        called = false
        bufferevent.locked do
          called = true
        end
        expect(called).to be true
      end

      it "can be called from other threads" do
        called = false
        t1 = Thread.new do
          bufferevent.locked do
            called = true
          end
        end

        t1.join

        expect(called).to be true
      end

      it "serializes operations" do
        time1 = nil
        time2 = nil

        t1 = Thread.new do
          bufferevent.locked do
            time1 = Time.now
            sleep 0.5
          end
        end

        t2 = Thread.new do
          sleep 0.25
          bufferevent.locked do
            time2 = Time.now
          end
        end

        t1.join
        t2.join

        expect(time2 - time1).to be_within(0.001).of(0.5)
      end
    end
  end

  describe '.pair' do
    it "returns a pair of BufferEvent objects" do
      pair = described_class.pair(base)
      expect(pair.length).to eq 2
      expect(pair).to all(be_a(described_class))
    end

    let(:pair){ described_class.pair(base) }

    describe "the pair" do

      it "contains objects that can talk to each other" do
        pair[0].write "test"
        pair[1].enable! :read
        base.loop! :nonblock

        expect(pair[1].read 4).to eq "test"
      end
      
    end
  end
end
