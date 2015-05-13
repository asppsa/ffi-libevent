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

  # Config objects
  attach_function :config_new, :event_config_new, [], :pointer
  attach_function :config_free, :event_config_free, [:pointer], :void

  attach_function :config_avoid_method, :event_config_avoid_method, [:pointer, :string], :int

  FEATURE_ET = 1
  FEATURE_O1 = 2
  FEATURE_FDS = 4
  enum FFI::Type::INT,
       :config_feature, [:et, FEATURE_ET,
                         :o1, FEATURE_O1,
                         :fds, FEATURE_FDS]
  
  attach_function :config_require_features, :event_config_require_features, [:pointer, :config_feature], :int

  FLAG_NOLOCK = 0x01
  FLAG_IGNORE_ENV = 0x02
  FLAG_STARTUP_IOCP = 0x04
  FLAG_NO_CACHE_TIME = 0x08
  FLAG_EPOLL_USE_CHANGELIST = 0x10
  FLAG_PRECISE_TIMER = 0x20
  enum FFI::Type::INT,
       :config_flag, [:nolock, FLAG_NOLOCK,
                      :ignore_env, FLAG_IGNORE_ENV,
                      :startup_iocp, FLAG_STARTUP_IOCP,
                      :no_cache_time, FLAG_NO_CACHE_TIME,
                      :epoll_use_changelist, FLAG_EPOLL_USE_CHANGELIST,
                      :precise_timer, FLAG_PRECISE_TIMER]

  attach_function :config_set_flag, :event_config_set_flag, [:pointer, :config_flag], :int

  # Only in 2.1
  #attach_function :config_set_max_dispatch_interval, :event_config_set_max_dispatch_interval, [:pointer, :pointer, :int, :int], :int
end
  
class FFI::Libevent::Config < FFI::AutoPointer
  def initialize opts
    ptr = FFI::Libevent.config_new
    super ptr, self.class.method(:release)

    if opts[:avoid_method]
      avoid_method(opts[:avoid_method])
    end

    if opts[:avoid_methods]
      opts[:avoid_methods].each do |method|
        avoid_method(method)
      end
    end

    if opts[:require_features]
      FFI::Libevent.config_require_features self, opts[:require_features]
    end

    if opts[:flags]
      FFI::Libevent.config_set_flag self, opts[:flags]
    end

    # if opts[:max_dispatch_interval]
    #   timeval = FFI::Libevent::Timeval.new
    #   timeval[:tv_sec] = opts[:max_dispatch_interval][:s]
    #   timeval[:tv_usec] = opts[:max_dispatch_interval][:us]
      
    #   FFI::Libevent.config_set_max_dispatch_interval self, timeval, opts[:max_dispatch_interval][:max_callbacks], opts[:max_dispatch_interval][:min_priority]
    # end
  end

  private

  def avoid_method method
    FFI::Libevent.config_avoid_method self, method.to_s
  end
  
  def self.release ptr
    FFI::Libevent.config_free ptr
  end
end

