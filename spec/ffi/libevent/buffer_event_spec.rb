describe FFI::Libevent::BufferEvent do
  let(:base) { FFI::Libevent::Base.new }
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

  describe '#dns_error' do
    let(:bufferevent) { described_class.socket base }

    before do
      bufferevent.connect_hostname :inet, 'nonexist.example.com', 80
      base.loop :nonblock
    end
    
    it "returns a Error::GAI object" do
      expect(bufferevent.dns_error).to be_a FFI::Libevent::Error::GAI
      expect(bufferevent.dns_error.to_s).to eq "nodename nor servname provided, or not known"
    end
  end

  describe '#setcb' do
    let(:bufferevent) { described_class.socket base, pair[0] }

    it "connects the readcb" do
      called = false
      equal = false

      cb = proc do |bev|
        called = true
        equal = bev == bufferevent
      end

      bufferevent.setcb readcb: cb
      bufferevent.enable :read

      pair[1] << 'testing 1 2 3 4'
      base.loop :nonblock

      expect(called).to be true
      expect(equal).to be true
    end

    it "connects the writecb" do
      called = false
      equal = false
      cb = proc do |bev|
        called = true
        equal = bev == bufferevent
      end
      bufferevent.setcb writecb: cb
      expect(bufferevent.write "test").to eq 0
      base.loop :nonblock

      expect(called).to be true
      expect(equal).to be true
    end
  end

  describe '#enable and #disable' do
    let(:bufferevent) { described_class.socket base, pair[0] }

    context "reading" do
      it "is not enabled by default" do
        called = false
        cb = proc{ called = true }

        expect(bufferevent.enabled? :read).to be false
        expect(bufferevent.enabled? FFI::Libevent::EV_READ).to be false
        bufferevent.setcb readcb: cb
        pair[1] << 'testing 1 2 3 4'
        base.loop :nonblock

        expect(called).to be false
      end

      it "enables reading when :read is passed" do
        called = false
        cb = proc{ called = true }

        bufferevent.setcb readcb: cb
        bufferevent.enable :read
        pair[1] << 'testing 1 2 3 4'
        base.loop :nonblock

        expect(called).to be true
      end

      it "enables reading when the EV_READ constant is passed" do
        called = false
        cb = proc{ called = true }

        bufferevent.setcb readcb: cb
        bufferevent.enable FFI::Libevent::EV_READ
        pair[1] << 'testing 1 2 3 4'
        base.loop :nonblock

        expect(called).to be true
      end

      it "can be disabled again" do
        called = false
        cb = proc{ called = true }

        bufferevent.setcb readcb: cb
        bufferevent.enable FFI::Libevent::EV_READ
        bufferevent.disable :read
        pair[1] << 'testing 1 2 3 4'
        base.loop :nonblock

        expect(called).to be false
      end
    end

    context "writing" do
      it "is enabled by default" do
        called = false
        cb = proc{ called = true }
 
        expect(bufferevent.enabled? :write).to be true
        expect(bufferevent.enabled?(FFI::Libevent::EV_READ | FFI::Libevent::EV_WRITE)).to be false
        bufferevent.setcb writecb: cb
        expect(bufferevent.write "test").to eq 0
        base.loop :nonblock

        expect(called).to be true
      end

      it "can be disabled" do
        called = false
        cb = proc{ called = true }

        bufferevent.setcb writecb: cb
        bufferevent.disable :write
        expect(bufferevent.write "test").to eq 0
        base.loop :nonblock

        expect(called).to be false
      end

      it "can be re-enabled, writing anything that is pending" do
        called = false
        cb = proc{ called = true }

        bufferevent.setcb writecb: cb
        bufferevent.disable :write
        expect(bufferevent.enabled? :write).to be false
        expect(bufferevent.write "test").to eq 0
        base.loop :nonblock

        bufferevent.enable :write
        base.loop :nonblock

        expect(called).to be true
      end
    end
  end

  describe "#set_watermark" do
    pending "writing"

    pending "reading"
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
          base.loop :nonblock
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
        evbuffer.add! str
        evbuffer
      end

      it "writes the contents of the EvBuffer" do
        bufferevent.write evbuffer
        base.loop :nonblock
        result = pair[1].recv(str.length)
        expect(result).not_to be_empty
        expect(result).to eq str
      end
    end
  end

  describe '#read' do
    let(:bufferevent) { described_class.socket base, pair[0] }

    pending
  end

  pending "#set_timeouts"
  pending '#flush'
  pending '#fd='
  pending '#fd'
  pending '#lock'
  pending '#unlock'
  pending '#locked'

end