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

  # Base functions
  attach_function :base_new, :event_base_new, [], :pointer
  attach_function :base_new_with_config, :event_base_new_with_config, [:pointer], :pointer
  attach_function :base_free, :event_base_free, [:pointer], :void
  attach_function :base_get_method, :event_base_get_method, [:pointer], :string

  EVLOOP_ONCE = 0x01
  EVLOOP_NONBLOCK = 0x02
  EVLOOP_NO_EXIT_ON_EMPTY = 0x04

  attach_function :base_loop, :event_base_loop, [:pointer, :int], :int
  attach_function :base_dispatch, :event_base_dispatch, [:pointer], :int

  attach_function :base_loopexit, :event_base_loopexit, [:pointer, :pointer], :int
  attach_function :base_loopbreak, :event_base_loopbreak, [:pointer], :int 

  attach_function :base_got_exit, :event_base_got_exit, [:pointer], :int
  attach_function :base_got_break, :event_base_got_break, [:pointer], :int

  attach_function :reinit, :event_reinit, [:pointer], :int

  #attach_function :base_loopcontinue, :event_base_loopcontinue, [:pointer], :int 

  # Only in 2.1
  #callback :base_foreach_event_cb, [:pointer, :pointer, :pointer], :int
  #attach_function :base_foreach_event, :event_base_foreach_event, [:pointer, :base_foreach_event_cb, :pointer], :int

end

class FFI::Libevent::Base < FFI::AutoPointer
  def initialize opts=nil
    ptr = if opts.nil? || opts.empty?
            FFI::Libevent.base_new
          else
            config = FFI::Libevent::Config.new(opts)
            FFI::Libevent.base_new_with_config config
          end

    raise "Could not satisfy requirements" if ptr.null?
    super ptr, self.class.method(:release)
  end

  def base_method
    FFI::Libevent.base_get_method(self).to_sym
  end

  def loop flags=0
    FFI::Libevent.base_loop(self, flags)
  end

  def dispatch
    FFI::Libevent.base_dispatch(self)
  end

  def loopexit tv=nil
    FFI::Libevent.base_loopexit(self, tv)
  end

  def loopbreak
    FFI::Libevent.base_loopbreak(self)
  end

  # def loopcontinue
  #   FFI::Libevent.base_loopcontinue(self)
  # end

  def got_exit?
    FFI::Libevent.base_got_exit(self) == 1
  end

  def got_break?
    FFI::Libevent.base_got_break(self) == 1
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

  def reinit
    FFI::Libevent.reinit(self)
  end

  def self.release ptr
    FFI::Libevent.base_free ptr
  end
end

