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
      ffi_lib 'event'
    else
      ffi_lib_flags :now, :global
      ffi_lib 'event', 'event_pthreads'
      attach_function :_use_pthreads, :evthread_use_pthreads, [], :int
    end

    attach_function :_supported_methods, :event_get_supported_methods, [], :pointer

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

    def self.use_pthreads
      raise "not linked to pthreads" unless self.respond_to? :_use_pthreads
      raise "pthreads not available" unless _use_pthreads == 0
    end
    
    def self.use_windows_threads
      raise "not implemented"
    end
  end
end

require_relative 'libevent/timeval'
require_relative 'libevent/config'
require_relative 'libevent/base'
require_relative 'libevent/event'
