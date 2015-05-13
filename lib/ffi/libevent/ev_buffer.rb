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

  attach_function :evbuffer_new, [], :pointer
  attach_function :evbuffer_free, [:pointer], :void

  attach_function :evbuffer_enable_locking, [:pointer, :pointer], :int
  attach_function :evbuffer_lock, [:pointer], :void
  attach_function :evbuffer_unlock, [:pointer], :void

  attach_function :evbuffer_get_length, [:pointer], :size_t
  attach_function :evbuffer_get_contiguous_space, [:pointer], :size_t

  attach_function :evbuffer_add, [:pointer, :pointer, :size_t], :int
  attach_function :evbuffer_expand, [:pointer, :size_t], :int
  attach_function :evbuffer_add_buffer, [:pointer, :pointer], :int
  
  attach_function :evbuffer_remove, [:pointer, :pointer, :size_t], :int
  attach_function :evbuffer_remove_buffer, [:pointer, :pointer, :size_t], :int

  attach_function :evbuffer_prepend, [:pointer, :pointer, :size_t], :int
  attach_function :evbuffer_prepend_buffer, [:pointer, :pointer], :int

  attach_function :evbuffer_pullup, [:pointer, :size_t], :pointer
  attach_function :evbuffer_drain, [:pointer, :size_t], :pointer

  attach_function :evbuffer_copyout, [:pointer, :pointer, :size_t], :size_t
  #attach_function :evbuffer_copyout_from, [:pointer, :pointer, :pointer, :size_t], :size_t

  enum FFI::Type::INT,
       :evbuffer_eol_style, [:any,
                             :crlf,
                             :crlf_strict,
                             :lf]

  attach_function :evbuffer_readln, [:pointer, :pointer, :evbuffer_eol_style], :pointer

  class EvBuffer < FFI::AutoPointer
    include FFI::Libevent
    
    def initialize ptr=nil
      if ptr
        release = proc{} # noop
      else
        ptr = FFI::Libevent.evbuffer_new
        raise "Could not create evbuffer" unless ptr
        release = FFI::Libevent.method(:evbuffer_free)
      end

      super ptr, release
    end

    def enable_locking lock=nil
      res = evbuffer_enable_locking self, lock
      raise "Could not enable locking" unless res == 0
    end

    def lock
      evbuffer_lock(self)
    end

    def unlock
      evbuffer_unlock(self)
    end

    def locked &block
      lock
      block.call
    ensure
      unlock
    end

    def length
      evbuffer_get_length self
    end

    def contiguous_space
      evbuffer_get_contiguous_space self
    end

    def add! bytes, len=nil
      if bytes.is_a? EvBuffer
        res = evbuffer_add_buffer self, bytes
      else
        len ||= bytes.bytesize
        res = evbuffer_add self, bytes, len
      end

      raise "Could not add" if res == -1
      res
    end

    def remove! dst, len
      if dst.is_a? EvBuffer
        res = evbuffer_remove_buffer self, dst, len
      else
        res = evbuffer_remove self, dst, len
      end

      raise "Could not remove" if res == -1
      res
    end

    def expand! len
      res = evbuffer_expand self, bytes
      raise "Could not expand" unless res == 0
    end

    def prepend! src, len=nil
      if bytes.is_a? EvBuffer
        res = evbuffer_prepend_buffer self, src
      else
        len ||= bytes.bytesize
        res = evbuffer_prepend self, src, len
      end

      raise "Could not prepend" if res == -1
      res
    end

    def pullup! size=-1
      evbuffer_pullup(self, size)
    end

    def drain! size
      res = evbuffer_drain(self, size)
      raise "Could not drain" if res == -1
    end

    def copyout data, len=nil
      len ||= data.bytesize
      size = evbuffer_copyout self, data, len
      raise "Could not copy out" if size == -1
      size
    end

    # def copyout_from pos, data, len=nil
    #   len ||= data.bytesize
    #   size = evbuffer_copyout_from self, pos, data, len
    #   raise "Could not copy out" if size == -1
    #   size
    # end

    def readln eol_style=:lf
      if ptr = evbuffer_readln(self, nil, eol_style)
        ptr.read_string
      end
    ensure
      ptr.free if ptr
    end

    def each_line eol_style=:lf, &block
      enum = Enumerator.new do |y|
        while str = readln
          y << str
        end
      end

      if block
        enum.each(&block)
      else
        enum
      end
    end
    
  end

  # class EvBuffer::Ptr < FFI::Pointer

  #   def initialize ev_buffer, ptr
  #     @ev_buffer = ev_buffer
  #     super FFI::Type::CHAR.size, ptr
  #   end

  # end

end
