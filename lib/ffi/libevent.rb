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

require 'ffi'
require "ffi/libevent/version"

module FFI
  module Libevent
    extend FFI::Library

    # This links to the correct set of libs for this platform

    # This function is available on non-windows platforms
    if RUBY_PLATFORM =~ /windows/
      ffi_lib 'event_core'
    else
      ffi_lib_flags :now, :global
      ffi_lib 'c', 'event_core', 'event_pthreads'
      attach_function :_use_pthreads, :evthread_use_pthreads, [], :int
    end

    attach_function :_supported_methods, :event_get_supported_methods, [], :pointer

    callback :event_log_cb, [:int, :string], :void
    attach_function :_set_log_callback, :event_set_log_callback, [:event_log_cb], :void

    attach_function :enable_lock_debugging, :evthread_enable_lock_debuging, [], :void

    def self.supported_methods
      ptr = _supported_methods
      methods = []
      loop do
        method_ptr = ptr.read_pointer
        break if method_ptr.null?
        methods << method_ptr.read_string.to_sym
        ptr += FFI::Pointer.size
      end
      methods
    end

    @use_threads = false
    def self.use_threads!
      if RUBY_PLATFORM =~ /windows/
        raise "not implemented"
      else
        raise "not linked to pthreads" unless self.respond_to? :_use_pthreads
        raise "pthreads not available" unless _use_pthreads == 0
      end

      @use_threads = true
    end

    ##
    # Either pass nil to reset the logger to the default; a proc,
    # which implements the logger#add interface; or pass an object
    # that has an '#add' method (e.g. a stdlib logger)
    def self.logger= logger
      l = if logger.nil? || logger.is_a?(Proc)
            logger
          elsif logger.respond_to? :add
            logger.method(:add)
          end

      _set_log_callback l

      # Record both to prevent the proc being GCed
      @logger_proc = l
      @logger = logger
    end

    ##
    # If a block is given, this method is used to assign a new logger
    # proc.  Otherwise, it returns the current logger (proc or object)
    def self.logger &block
      if block
        self.logger= block
      else
        @logger
      end
    end
  end
end

require_relative 'libevent/util'
require_relative 'libevent/error'
require_relative 'libevent/timeval'
require_relative 'libevent/config'
require_relative 'libevent/base'
require_relative 'libevent/event'
require_relative 'libevent/ev_buffer'
require_relative 'libevent/buffer_event'
