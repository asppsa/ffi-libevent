require 'monitor'
require 'forwardable'

module FFI::Libevent
  class LockManager
    def initialize
      @lock_mutex = Mutex.new
      @locks = {}

      @cond_mutex = Mutex.new
      @conds = {}
    end

    def lock_alloc locktype
      lock = case locktype
             when 0
               Mutex.new
             when FFI::Libevent::LOCKTYPE_RECURSIVE
               RecursiveLock.new
             else
               raise "unsupported locktype: #{locktype}"
             end

      lock.object_id.tap do |id|
        @lock_mutex.synchronize{ @locks[id] = lock }
        FFI::Libevent.logger.debug "Lock alloc #{id} #{lock.class}"
      end
    rescue Exception => e
      FFI::Libevent.logger.debug "#{e}\n#{e.backtrace}"
      nil
    end

    def lock_free ptr, _
      id = ptr.address
      FFI::Libevent.logger.debug "Lock free #{id}"
      lock = @lock_mutex.synchronize{ @locks.delete(id) }
      raise "no such lock: #{id}" unless lock
    rescue Exception => e
      FFI::Libevent.logger.debug "#{e}\n#{e.backtrace}"
    end

    def lock mode, ptr
      id = ptr.address
      l = @lock_mutex.synchronize{ @locks[id] }
      raise "no such lock: #{id}" unless l
      FFI::Libevent.logger.debug "Lock #{id} (#{l.class}) #{mode == EVTHREAD_TRY ? 'try' : 'now'}"

      case mode
      when EVTHREAD_TRY
        if l.try_lock
          0
        else
          1
        end
      else
        l.lock
        0
      end
    rescue ThreadError
      1
    rescue Exception => e
      FFI::Libevent.logger.debug "#{e}\n#{e.backtrace}"
      1
    end

    def unlock _, ptr
      id = ptr.address
      FFI::Libevent.logger.debug "Unlock #{id}"
      lock = @lock_mutex.synchronize{ @locks[id] }
      raise "no such lock: #{id}" unless lock

      lock.unlock
      0
    rescue ThreadError
      1
    rescue Exception => e
      FFI::Libevent.logger.debug "#{e}\n#{e.backtrace}"
      1
    end

    def cond_alloc _
      cond = ConditionVariable.new
      cond.object_id.tap do |id|
        @cond_mutex.synchronize{ @conds[id] = cond }
        FFI::Libevent.logger.debug "Cond alloc #{id}"
      end
    rescue Exception => e
      FFI::Libevent.logger.debug "#{e}\n#{e.backtrace}"
      nil
    end

    def cond_free ptr
      id = ptr.address
      FFI::Libevent.logger.debug "Cond free #{id}"
      cond = @cond_mutex.synchronize{ @conds.delete(id) }
      raise "no such cond: #{id}" unless cond
    rescue Exception => e
      FFI::Libevent.logger.debug "#{e}\n#{e.backtrace}"
    end

    def signal ptr, broadcast
      id = ptr.address
      FFI::Libevent.logger.debug "Signal #{id}"
      cond = @cond_mutex.synchronize{ @conds[id] }
      raise "no such cond: #{id}" unless cond
      if broadcast == 1
        cond.broadcast
      else
        cond.signal
      end
      0
    rescue ThreadError
      -1
    rescue Exception => e
      FFI::Libevent.logger.debug "#{e}\n#{e.backtrace}"
      -1
    end

    def wait cond_ptr, lock_ptr, tv_ptr
      FFI::Libevent.logger.debug "wait ..."
      cond_id = cond_ptr.address
      cond = @cond_mutex.synchronize{ @conds[cond_id] }
      raise "no such cond: #{cond_id}"
      lock_id = lock_ptr.address
      lock = @lock_mutex.synchronize{ @locks[lock_id] }
      raise "no such lock: #{lock_id}"
      FFI::Libevent.logger.debug "wait #{cond_id}, #{lock_id}"

      start,timeout = if tv_ptr.null?
                        [nil,nil]
                      else
                        [Time.now, FFI::Libevent::Timeval.new(tv_ptr).seconds]
                      end

      FFI::Libevent.logger.debug "wait #{cond_id}, #{lock_id}, #{timeout}"
      cond.wait lock, timeout

      # If there's a possibility that the signal timed out, check that
      # the number of seconds is less than the timeout
      if timeout && Time.now - start >= timeout
        1
      else
        0
      end
    rescue ThreadError
      -1
    rescue Exception => e
      FFI::Libevent.logger.debug "#{e}\n#{e.backtrace}"
      -1
    end

    ##
    # Creates a LockCallbacks struct referencing the methods in the
    # manager
    def lock_callbacks
      FFI::Libevent::LockCallbacks.new.tap do |lc|
        lc[:lock_api_version] = 1
        lc[:supported_locktypes] = LOCKTYPE_RECURSIVE
        lc[:alloc] = method(:lock_alloc)
        lc[:free] = method(:lock_free)
        lc[:lock] = method(:lock)
        lc[:unlock] = method(:unlock)
      end
    end

    def condition_callbacks
      FFI::Libevent::ConditionCallbacks.new.tap do |cc|
        cc[:condition_api_version] = 1
        cc[:alloc_condition] = method(:cond_alloc)
        cc[:free_condition] = method(:cond_free)
        cc[:signal_condition] = method(:signal)
        cc[:wait_condition] = method(:wait)
      end
    end

    ##
    # Gives a monitor a mutex's interface
    class RecursiveLock < Monitor
      alias :lock :mon_enter
      alias :unlock :mon_exit
      alias :try_lock :mon_try_enter
    end
  end
end
