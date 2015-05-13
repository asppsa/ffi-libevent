module FFI::Libevent

  attach_function :evutil_gai_strerror, [:int], :string
  
  class Error < ::StandardError
  end

  class Error::GAI < Error
    include FFI::Libevent

    def initialize code
      super evutil_gai_strerror(code)
    end
  end
end
