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

require 'logger'

module FFI
  module Libevent
    extend FFI::Library

    ##
    # This links to the correct set of libs for this platform.  On
    # Windows, we will only ever use the core set of functions at the
    # moment.
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

      ffi_lib_flags :now, :global
      ffi_lib 'c', core, pthreads
      attach_function :_use_pthreads, :evthread_use_pthreads, [], :int
    end

    attach_function :_supported_methods, :event_get_supported_methods, [], :pointer

    callback :event_log_cb, [:int, :string], :void
    attach_function :_set_log_callback, :event_set_log_callback, [:event_log_cb], :void

    attach_function :enable_lock_debugging, :evthread_enable_lock_debuging, [], :void

    attach_function :_set_lock_callbacks, :evthread_set_lock_callbacks, [:pointer], :int
    attach_function :_set_condition_callbacks, :evthread_set_condition_callbacks, [:pointer], :int
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

    ##
    # Use ruby thread methods in any of the following cases:
    #
    # - We are on Windows (no pthreads there)
    # - We are using Rubinius (segfaults otherwise)
    # - We have not linked to the event_pthreads lib
    # - Using pthreads fails for some reason
    def self.use_threads!
      return if @use_threads

      if RUBY_PLATFORM =~ /windows/ ||
         RUBY_ENGINE == 'rbx' ||
         !self.respond_to?(:_use_pthreads) ||
         _use_pthreads != 0
        return self.use_ruby_locking!
      end

      @use_threads = true
    end

    def self.use_ruby_locking!
      return if @use_threads

      # This object contains methods for creating and deleting lock
      # objects
      @lock_manager = LockManager.new

      # These objects are passed to libevent.  Recorded here to
      # prevent garbage collection
      @lock_callbacks = @lock_manager.lock_callbacks
      @condition_callbacks = @lock_manager.condition_callbacks
      @id_callback = proc{ Thread.current.object_id }

      # Tell libevent to use our locking callbacks
      _set_lock_callbacks(@lock_callbacks)
      _set_condition_callbacks(@condition_callbacks)
      _set_id_callback(@id_callback)

      @use_threads = true
    end

    ##
    # Either pass nil to reset the logger to the default; a proc,
    # which implements the logger#add interface; or pass an object
    # that has an '#add' method (e.g. a stdlib logger)
    def self.logger= logger
      raise "logger does not respond to :add" unless logger.respond_to? :add

      # Record both to prevent them being GCed
      @logger_proc = logger.method(:add)
      @logger = logger

      _set_log_callback @logger_proc
      @logger
    end

    ##
    # Returns the current logger object
    def self.logger
      @logger
    end

    ##
    # This is the default logger.  Logs errors or worse only.
    Logger.new(STDERR).tap do |logger|
      logger.level = Logger::ERROR
      self.logger = logger
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
require_relative 'libevent/condition_callbacks'
require_relative 'libevent/lock_callbacks'
require_relative 'libevent/lock_manager'
