module FFI::Libevent
  attach_function :util_make_socket_nonblocking, :evutil_make_socket_nonblocking, [:int], :int
  
  module Util
    extend FFI::Libevent

    def self.make_socket_nonblocking socket
      raise "Failed" unless util_make_socket_nonblocking(socket.fileno) == 0
    end
  end
end
