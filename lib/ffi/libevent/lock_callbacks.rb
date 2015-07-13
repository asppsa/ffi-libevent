module FFI::Libevent
  LOCKTYPE_RECURSIVE = 1
  LOCKTYPE_READWRITE = 2

  EVTHREAD_WRITE = 0x04
  EVTHREAD_READ = 0x08
  EVTHREAD_TRY = 0x10

  class LockCallbacks < FFI::Struct
    layout :lock_api_version, :int,
           :supported_locktypes, :int,
           :alloc, callback([:int], :size_t),
           :free, callback([:pointer, :int], :void),
           :lock, callback([:int, :pointer], :int),
           :unlock, callback([:int, :pointer], :int)

  end
end
