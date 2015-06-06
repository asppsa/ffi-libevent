# Copyright 2015 Alastair Pharo

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module FFI::Libevent

  # Event callback signature
  callback :event_callback, [:int, :short, :pointer], :void

  # Base functions
  attach_function :base_new, :event_base_new, [], :pointer
  attach_function :base_new_with_config, :event_base_new_with_config, [:pointer], :pointer
  attach_function :base_free, :event_base_free, [:pointer], :void
  attach_function :base_get_method, :event_base_get_method, [:pointer], :string

  EVLOOP_ONCE = 0x01
  EVLOOP_NONBLOCK = 0x02
  EVLOOP_NO_EXIT_ON_EMPTY = 0x04
  enum FFI::Type::INT,
       :loop_flag, [:once, EVLOOP_ONCE,
                    :nonblock, EVLOOP_NONBLOCK,
                    :no_exit_on_empty, EVLOOP_NO_EXIT_ON_EMPTY]

  attach_function :base_loop, :event_base_loop, [:pointer, :loop_flag], :int, :blocking => true
  attach_function :base_dispatch, :event_base_dispatch, [:pointer], :int, :blocking => true

  attach_function :base_loopexit, :event_base_loopexit, [:pointer, :pointer], :int, :blocking => true
  attach_function :base_loopbreak, :event_base_loopbreak, [:pointer], :int

  attach_function :base_got_exit, :event_base_got_exit, [:pointer], :int
  attach_function :base_got_break, :event_base_got_break, [:pointer], :int

  attach_function :base_reinit, :event_reinit, [:pointer], :int

  #attach_function :base_loopcontinue, :event_base_loopcontinue, [:pointer], :int 

  # Only in 2.1
  #callback :base_foreach_event_cb, [:pointer, :pointer, :pointer], :int
  #attach_function :base_foreach_event, :event_base_foreach_event, [:pointer, :base_foreach_event_cb, :pointer], :int

  # Won't work due to garbage collection of the callback
  #attach_function :base_once, :event_base_once, [:pointer, :int, :short, :event_callback, :pointer, :pointer], :int

  attach_function :base_priority_init, :event_base_priority_init, [:pointer, :int], :int

  class Base < FFI::AutoPointer
    include FFI::Libevent

    def initialize opts=nil
      ptr = if opts.nil? || opts.empty?
              base_new
            else
              config = Config.new(opts)
              base_new_with_config config
            end

      raise "Could not satisfy requirements" if ptr.null?

      if opts && opts[:num_priorities]
        res = base_priority_init ptr, opts[:num_priorities]
        raise "Could not set priorities" unless res == 0
      end

      super ptr, FFI::Libevent.method(:base_free)
    end

    def base_method
      base_get_method(self).to_sym
    end

    def loop! flags=0
      base_loop(self, flags)
    end

    def dispatch!
      base_dispatch(self)
    end

    def loopexit! tv=nil
      base_loopexit(self, tv)
    end

    def loopbreak!
      base_loopbreak(self)
    end

    # def loopcontinue
    #   base_loopcontinue(self)
    # end

    def got_exit?
      base_got_exit(self) == 1
    end

    def got_break?
      base_got_break(self) == 1
    end

    # def events
    #   Enumerator.new do |y|
    #     p = lambda do |bptr, eptr, arg|
    #       y << eptr
    #       0
    #     end
    #     FFI::Libevent.base_foreach_event self, p, null
    #   end
    # end

    def reinit!
      base_reinit(self)
    end

    def new_event *params, &block
      Event.new(self, *params, &block)
    end

    def add_event *params, &block
      ev = new_event(*params, &block)
      ev.add!
      ev
    end

    # def once what, flags, tv=nil, &block
    #   if base_once(self, Event.fp_from_what(what), flags, block, nil, tv) != 0
    #     raise "Could not add event once"
    #   end
    # end
  end
end
