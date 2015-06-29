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
      core, pthreads = if ENV['LIBEVENT']
                         ['/libevent_core*.so.*', '/libevent_pthreads*.so.*'].map do |splat|
                           Dir[ENV['LIBEVENT'] + splat].first
                         end
                       else
                         %w{event_core event_pthreads}
                       end
      puts core
      puts pthreads
      ffi_lib_flags :now, :global
      ffi_lib 'c', core, pthreads
      attach_function :_use_pthreads, :evthread_use_pthreads, [], :int
    end

    attach_function :_supported_methods, :event_get_supported_methods, [], :pointer

    callback :event_log_cb, [:int, :string], :void
    attach_function :_set_log_callback, :event_set_log_callback, [:event_log_cb], :void

    attach_function :enable_lock_debugging, :evthread_enable_lock_debuging, [], :void

    attach_function :_set_lock_callbacks, :evthread_set_lock_callbacks, [:pointer], :int
    callback :id_fn, [], :int
    attach_function :_set_id_callback, :evthread_set_id_callback, [:id_fn], :void

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
      return if @use_threads

      if RUBY_PLATFORM =~ /windows/
        raise "not implemented"
      else
        raise "not linked to pthreads" unless self.respond_to? :_use_pthreads
        raise "pthreads not available" unless _use_pthreads == 0
      end

      @use_threads = true
    end

    def self.use_ruby_locking!
      return if @use_threads

      # This object contains methods for creating and deleting lock
      # objects
      @lock_manager = LockManager.new

      # This object is passed to libevent
      @lock_callbacks = LockCallbacks.new
      @lock_callbacks[:lock_api_version] = 1
      @lock_callbacks[:supported_locktypes] = LOCKTYPE_RECURSIVE
      @lock_callbacks[:alloc] = @lock_manager.method(:alloc)
      @lock_callbacks[:free] = @lock_manager.method(:free)
      @lock_callbacks[:lock] = @lock_manager.method(:lock)
      @lock_callbacks[:unlock] = @lock_manager.method(:unlock)

      _set_lock_callbacks(@lock_callbacks)
      _set_id_callback(proc{ Thread.current.object_id })

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

require_relative 'libevent/error'
require_relative 'libevent/timeval'
require_relative 'libevent/config'
require_relative 'libevent/base'
require_relative 'libevent/event'
require_relative 'libevent/ev_buffer'
require_relative 'libevent/buffer_event'
require_relative 'libevent/lock_callbacks'
require_relative 'libevent/lock_manager'
