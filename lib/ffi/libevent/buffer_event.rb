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

require 'socket'

module FFI::Libevent

  BEV_EVENT_READING   = 0x01
  BEV_EVENT_WRITING   = 0x02
  BEV_EVENT_EOF       = 0x10
  BEV_EVENT_ERROR     = 0x20
  BEV_EVENT_TIMEOUT   = 0x40
  BEV_EVENT_CONNECTED = 0x80

  BEV_OPT_CLOSE_ON_FREE    = (1 << 0)
  BEV_OPT_THREADSAFE       = (1 << 1)
  BEV_OPT_DEFER_CALLBACKS  = (1 << 2)
  BEV_OPT_UNLOCK_CALLBACKS = (1 << 3)
  enum FFI::Type::SHORT,
       :buffer_event_opt, [:close_on_free, BEV_OPT_CLOSE_ON_FREE,
                           :threadsafe, BEV_OPT_THREADSAFE,
                           :defer_callbacks, BEV_OPT_DEFER_CALLBACKS,
                           :unlock_callbacks, BEV_OPT_UNLOCK_CALLBACKS]

  BEV_NORMAL   = 0
  BEV_FLUSH    = 1
  BEV_FINISHED = 2
  enum FFI::Type::SHORT,
       :buffer_event_flush_mode, [:normal, 0,
                                  :flush, 1,
                                  :finished, 2]

  callback :bufferevent_data_cb, [:pointer, :pointer], :void
  callback :bufferevent_event_cb, [:pointer, :short, :pointer], :void

  attach_function :bufferevent_socket_new, [:pointer, :int, :buffer_event_opt], :pointer
  attach_function :bufferevent_free, [:pointer], :void

  attach_function :bufferevent_socket_connect, [:pointer, :pointer, :int], :int
  attach_function :bufferevent_socket_connect_hostname, [:pointer, :pointer, :int, :string, :int], :int
  attach_function :bufferevent_socket_get_dns_error, [:pointer], :int

  attach_function :bufferevent_setcb, [:pointer, :bufferevent_data_cb, :bufferevent_data_cb, :bufferevent_event_cb, :pointer], :void
  attach_function :bufferevent_enable, [:pointer, :what], :void
  attach_function :bufferevent_disable, [:pointer, :what], :void
  attach_function :bufferevent_get_enabled, [:pointer], :short
  attach_function :bufferevent_setwatermark, [:pointer, :short, :size_t, :size_t], :void

  attach_function :bufferevent_get_input, [:pointer], :pointer
  attach_function :bufferevent_get_output, [:pointer], :pointer
  
  attach_function :bufferevent_write, [:pointer, :pointer, :size_t], :int
  attach_function :bufferevent_write_buffer, [:pointer, :pointer], :int

  attach_function :bufferevent_read, [:pointer, :pointer, :size_t], :size_t
  attach_function :bufferevent_read_buffer, [:pointer, :pointer], :int

  attach_function :bufferevent_set_timeouts, [:pointer, :pointer, :pointer], :void
  attach_function :bufferevent_flush, [:pointer, :what, :buffer_event_flush_mode], :void

  attach_function :bufferevent_priority_set, [:pointer, :int], :int
  #attach_function :bufferevent_get_priority, [:pointer], :int

  attach_function :bufferevent_setfd, [:pointer, :int], :int
  attach_function :bufferevent_getfd, [:pointer], :int

  attach_function :bufferevent_lock, [:pointer], :void, :blocking => true
  attach_function :bufferevent_unlock, [:pointer], :void

  attach_function :bufferevent_pair_new, [:pointer, :int, :pointer], :int

  class BufferEvent < FFI::AutoPointer
    include FFI::Libevent

    attr_reader :base

    def initialize ptr, base, what=nil
      @callbacks = {}
      @rel = Releaser.new(base,what,@callbacks)
      super ptr, @rel
    end

    def connect what
      sockaddr = if what.respond_to? :to_sockaddr
                   what.to_sockaddr
                 elsif what.is_a? Array
                   Addrinfo.new(what).to_sockaddr
                 else
                   what.to_s
                 end

      res = bufferevent_socket_connect(self, sockaddr, sockaddr.bytesize)
      raise "Could not connect" unless res == 0
      @rel.what = what
      nil
    end

    def connect_hostname family, hostname, port, dns_base=nil
      af = case family
           when :INET, :inet
             Socket::Constants::AF_INET
           when :INET6, :inet6
             Socket::Constants::AF_INET6
           when Integer
             family
           end

      res = bufferevent_socket_connect_hostname(self, dns_base, af, hostname, port)
      unless res == 0
        error = dns_error? || "Could not connect"
        raise error
      end 
    end

    def dns_error?
      error_code = bufferevent_socket_get_dns_error(self)
      if error_code != 0
        Error::GAI.new error_code
      end
    end

    def set_callbacks(cbs)
      locked do
        # We need to keep track of the callbacks till the end of this
        # method call so that they don't get prematurely garbage
        # collected
        deleted = []

        cbs.each_pair do |k,cb|
          deleted.push @callbacks.delete(k)
          if cb.is_a? Proc
            @callbacks[k] = if k == :event
                              EventCallback.new(self, cb)
                            else
                              Callback.new(self, cb)
                            end
          elsif not cb.nil?
            raise "#{k} callback must be a proc or nil"
          end
        end

        bufferevent_setcb self, @callbacks[:read], @callbacks[:write], @callbacks[:event], nil
      end
    end

    def unset_callbacks *keys
      keys = [:read,:write,:event] if keys.empty?
      set_callbacks Hash[keys.map{ |k| [k,nil] }]
    end

    def read_callback
      locked{ @callbacks[:read] }
    end

    def read_callback= cb
      set_callbacks read: cb
    end

    def on_read(&block)
      set_callbacks read: block
    end

    def write_callback
      locked{ @callbacks[:write] }
    end

    def write_callback= cb
      set_callbacks write: cb
    end

    def on_write(&block)
      set_callbacks write: block
    end

    def event_callback
      locked{ @callbacks[:event] }
    end

    def event_callback= cb
      set_callbacks event: cb
    end

    def on_event(&block)
      set_callbacks event: block
    end

    def enable! events=(FFI::Libevent::EV_READ | FFI::Libevent::EV_WRITE)
      bufferevent_enable self, events
    end

    def disable! events=(FFI::Libevent::EV_READ | FFI::Libevent::EV_WRITE)
      bufferevent_disable self, events
    end

    def enabled
      bufferevent_get_enabled self
    end

    def enabled? what=(FFI::Libevent::EV_READ | FFI::Libevent::EV_WRITE)
      en = enabled
      case what
      when :read
        en & EV_READ != 0
      when :write
        en & EV_WRITE != 0
      when Integer
        en & what == what
      else
        false
      end
    end

    def set_watermark events, low=0, high=0
      bufferevent_setwatermark self, events, low, high
    end

    def input
      ptr = bufferevent_get_input(self)
      raise "Could not get input" unless ptr
      obj = EvBuffer.new ptr
      if block_given?
        yield obj
      else
        obj
      end
    end

    def output
      ptr = bufferevent_get_output(self)
      raise "Could not get output" unless ptr
      obj = EvBuffer.new ptr
      if block_given?
        yield obj
      else
        obj
      end
    end

    def write what, len=nil
      if what.is_a? String
        len ||= what.bytesize
        bufferevent_write self, what, len
      elsif what.is_a? EvBuffer
        res = bufferevent_write_buffer self, what
        raise "Could not write from evbuffer" unless res == 0
      else
        raise "Cannot write from #{what}"
      end
    end

    def read what, len=nil
      if what.is_a? Integer
        mem = FFI::MemoryPointer.new(what)
        res = bufferevent_read self, mem, what
        raise "Could not read" if res == -1
        mem.read_string(res)
      elsif what.is_a? EvBuffer
        res = bufferevent_read_buffer self, what
        raise "Could not read into evbuffer" unless res == 0
      elsif what.is_a?(FFI::Pointer) && len.is_a?(Integer)
        res = bufferevent_read self, what, len
        raise "Could not read into evbuffer" if res == -1
        res
      else
        raise "Cannot read into #{what}"
      end
    end

    def set_timeouts to_read=nil, to_write=nil
      tv_read, tv_write = [to_read, to_write].map do |timeout|
        case timeout
        when Timeval, nil
          timeout
        when Numeric
          Timeval.s timeout
        end
      end

      bufferevent_set_timeouts(self, tv_read, tv_write)
    end

    def flush! iotype=(EV_READ|EV_WRITE), mode=:normal
      res = bufferevent_flush(iotype, mode)
      raise "Could not flush" unless res == 0
    end

    def priority= pri
      res = bufferevent_priority_set(self, pri)
      raise "Could not set priority" unless res == 0
    end

    #def priority
    #end

    def fd= what
      res = bufferevent_setfd self, Event.fp_from_what(what)
      raise "Could not set fd" unless res == 0
      @rel.what = what
    end

    def fd
      res = bufferevent_getfd(self)
      raise "Could not get fd" if res == -1
      res
    end

    def lock!
      bufferevent_lock(self)
    end

    def unlock!
      bufferevent_unlock(self)
    end

    def locked
      raise "requires a block" unless block_given?
      lock!
      yield
    ensure
      unlock!
    end

    class << self
      def socket base, what=nil, flags=0
        fp = Event.fp_from_what(what)
        ptr = FFI::Libevent.bufferevent_socket_new base, fp, flags
        raise "Could not create bufferevent" if ptr.null?
        self.new ptr, base, what
      end

      def pair base, flags=0
        ptr_pair = FFI::MemoryPointer.new(FFI::Type::POINTER, 2)
        res = FFI::Libevent.bufferevent_pair_new base, flags, ptr_pair
        raise "Could not create pair" unless res == 0

        ptr_pair.read_array_of_pointer(2).map do |ptr|
          self.new ptr, base, nil
        end
      end
    end

    class Releaser
      attr_accessor :base, :what, :callbacks

      def initialize base, what, callbacks
        @base = base
        @what = what
        @callbacks = callbacks
      end

      def call ptr
        FFI::Libevent.bufferevent_free ptr
        @base = @what = @callbacks = nil
      end
    end

    class EventCallback
      def initialize base, cb
        @base = base
        @cb = cb
      end

      def call _,events,_
        @cb.call(@base,events)
      end
    end

    class Callback
      def initialize base, cb
        @base = base
        @cb = cb
      end

      def call _,_
        @cb.call(@base)
      end
    end
  end
end
