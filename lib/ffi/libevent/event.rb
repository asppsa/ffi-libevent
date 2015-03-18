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
  EV_TIMEOUT = 0x01
  EV_READ = 0x02
  EV_WRITE = 0x04
  EV_SIGNAL = 0x08
  EV_PERSIST = 0x10
  EV_ET = 0x20

  callback :callback_fn, [:int, :short, :pointer], :void
  attach_function :event_new, [:pointer, :int, :short, :callback_fn, :pointer], :pointer
  attach_function :event_free, [:pointer], :void
  attach_function :event_add, [:pointer, :pointer], :int
  attach_function :event_del, [:pointer], :int
  #attach_function :event_remove_timer, [:pointer], :int
  attach_function :event_active, [:pointer, :int, :short], :void
end

class FFI::Libevent::Event < FFI::AutoPointer
  def initialize base, what, flags, &block
    # Prevent these from being GC'ed
    @what = what
    @block = block

    # Deal with ruby IO objects and signals
    if what.is_a? IO
      fp = what.fileno
    elsif what.is_a? String
      fp = Signal.list[what]
    else
      fp = what
    end

    ptr = FFI::Libevent.event_new base, fp, flags, block, nil
    raise "Could not create event" if ptr.null?

    super ptr, self.class.method(:release)
  end

  def add! tv=nil
    FFI::Libevent.event_add self, tv
  end

  def del!
    FFI::Libevent.event_del self
  end

  # def remove_timer!
  #   FFI::Libevent.event_remove_timer self
  # end

  def active! flag, ncalls
    FFI::Libevent.event_active self, flag, ncalls
  end

  def self.release ptr
    FFI::Libevent.event_free ptr
  end
end
