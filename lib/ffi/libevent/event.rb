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

  enum FFI::Type::SHORT,
       :what, [:timeout, EV_TIMEOUT,
               :read, EV_READ,
               :write, EV_WRITE,
               :signal, EV_SIGNAL,
               :persist, EV_PERSIST,
               :et, EV_ET]

  attach_function :event_new, [:pointer, :int, :what, :event_callback, :pointer], :pointer
  attach_function :event_free, [:pointer], :void
  attach_function :event_add, [:pointer, :pointer], :int
  attach_function :event_del, [:pointer], :int
  #attach_function :event_remove_timer, [:pointer], :int
  attach_function :event_active, [:pointer, :what, :short], :void

  class Event < FFI::AutoPointer
    include FFI::Libevent

    def initialize base, what, flags, &block
      # Prevent these from being GC'ed
      @what = what
      @block = block

      ptr = event_new base, Event.fp_from_what(what), flags, block, nil
      raise "Could not create event" if ptr.null?

      super ptr, FFI::Libevent.method(:event_free)
    end

    def add! tv=nil
      event_add self, tv
    end

    def del!
      event_del self
    end

    # def remove_timer!
    #   FFI::Libevent.event_remove_timer self
    # end

    def active! flag, ncalls
      event_active self, flag, ncalls
    end

    ##
    # Deal with ruby IO objects and signals
    def self.fp_from_what what
      if what.is_a? IO
        what.fileno
      elsif what.is_a? String
        Signal.list[what]
      elsif what.nil?
        -1
      else
        what
      end
    end
  end
end
