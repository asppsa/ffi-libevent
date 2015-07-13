module FFI::Libevent
  class ConditionCallbacks < FFI::Struct
    layout :condition_api_version, :int,
           :alloc_condition, callback([:uint], :pointer),
           :free_condition, callback([:pointer], :void),
           :signal_condition, callback([:pointer, :int], :int),
           :wait_condition, callback([:pointer, :pointer, :pointer], :int)
  end
end
