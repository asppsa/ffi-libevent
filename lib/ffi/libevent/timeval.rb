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
    self[:tv_sec] + self[:tv_usec] / 1_000_000.0
  end
  alias :s :seconds

  def microseconds
    self[:tv_usec] + self[:tv_sec] * 1_000_000
  end
  alias :useconds :microseconds
  alias :us :microseconds

  def milliseconds
    microseconds * 1_000
  end

  def minutes
    seconds / 60.0
  end

  def hours
    minutes / 60.0
  end

  class << self
    def seconds s
      a,b = s.divmod(1)
      self.new.tap do |tv|
        tv[:tv_sec] = a
        tv[:tv_usec] = b*1_000_000
      end
    end
    alias :s :seconds

    def microseconds us
      self.new.tap do |tv|
        tv[:tv_sec] = 0
        tv[:tv_usec] = us
      end
    end
    alias :us :microseconds

    def milliseconds ms
      self.microseconds(ms*1000)
    end
    alias :ms :milliseconds

    def minutes m
      self.seconds(m*60)
    end
    alias :m :minutes

    def hours h
      self.minutes(h*60)
    end
    alias :h :hours
  end
end
