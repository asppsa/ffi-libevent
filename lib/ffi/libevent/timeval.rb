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

class FFI::Libevent::Timeval < FFI::Struct
  layout :tv_sec, :ulong,
         :tv_usec, :ulong

  def seconds
    self[:tv_sec]
  end
  alias :s :seconds

  def microseconds
    self[:tv_usec]
  end
  alias :useconds :microseconds
  alias :us :microseconds

  class << self
    def seconds s
      t = self.new
      t[:tv_sec] = s
      t[:tv_usec] = 0
      t
    end
    alias :s :seconds

    def microseconds us
      t = self.new
      t[:tv_sec] = 0
      t[:tv_usec] = us
      t
    end
    alias :useconds :microseconds
    alias :us :microseconds
  end
end
