module FFI::Libevent
  class LockManager
    def initialize
      @mutex = Mutex.new
      @locks = {}
    end

    def alloc locktype
      lock = case locktype
             when 0
               RecursiveLock.new
             when FFI::Libevent::LOCKTYPE_RECURSIVE
               RecursiveLock.new
             else
               raise "unsupported locktype: #{locktype}"
             end

      id = lock.object_id
      @mutex.synchronize{ @locks[id] = lock }
      id
    end

    def free ptr, locktype
      id = ptr.address
      puts "free #{id}"
      lock = @mutex.synchronize{ @locks.delete(id) }
      raise "no such lock" unless lock
    end

    def lock mode, ptr
      id = ptr.address
      lock = @mutex.synchronize{ @locks[id] }
      raise "no such lock" unless lock

      if lock.acquire! mode
        0
      else
        1
      end
    end

    def unlock mode, ptr
      id = ptr.address
      lock = @mutex.synchronize{ @locks[id] }
      raise "no such lock" unless lock

      if lock.release! mode
        0
      else
        1
      end
    end

    class RecursiveLock
      def initialize
        @mutex = Mutex.new
        @thread = nil
        @level = 0
      end

      def acquire! mode
        @mutex.synchronize do
          return false if @thread && @thread != Thread.current
          @thread ||= Thread.current
          @level += 1
          true
        end
      end

      def release! mode
        @mutex.synchronize do
          return false if @thread.nil? || @thread != Thread.current
          @level -= 1
          @thread = nil if @level.zero?
          true
        end
      end
    end
  end
end
