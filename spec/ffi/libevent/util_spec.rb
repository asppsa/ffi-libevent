require 'fcntl'

describe FFI::Libevent::Util do
  describe '#make_socket_nonblocking' do
    let(:sockets){ UNIXSocket.pair }

    before do
      described_class.make_socket_nonblocking sockets[0]
    end

    it "makes the socket report that it is non-blocking" do
      expect(sockets[0].fcntl(Fcntl::F_GETFL) & Fcntl::O_NONBLOCK).to eq Fcntl::O_NONBLOCK
    end

    skip "makes the socket behave as non-blocking" do
      expect(sockets[0].sysread(1)).to raise Errno::EWOULDBLOCK
    end
  end
end
