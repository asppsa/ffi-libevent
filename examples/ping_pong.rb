#!/bin/env ruby

require 'bundler/setup'
require 'ffi/libevent'
require 'socket'

base = FFI::Libevent::Base.new
trapper = FFI::Libevent::Event.new(base, "INT", FFI::Libevent::EV_SIGNAL) { base.loopbreak! }
trapper.add!

module Stats
  @pinged = 0
  @ponged = 0
  @last_report = nil
  @last_report_ponged = 0

  def self.inc_pinged
    @pinged += 1
  end

  def self.inc_ponged
    @ponged += 1

    now = Time.now
    if @last_report.nil? || now - @last_report >= 1
      diff = @ponged - @last_report_ponged
      puts "#{diff} pongs/sec"
      @last_report = now
      @last_report_ponged = @ponged
    end
  end
end

class PingPong
  PING = 'PING'
  PONG = 'PONG'

  def initialize base, fd
    @base = base
    @fd  = fd
    @received = ''
  end

  def wait_to_write
    @writer ||= self.method(:writer)
    @wait_to_write ||= FFI::Libevent::Event.new(@base, @fd, FFI::Libevent::EV_WRITE, &@writer)
  end

  def wait_for_response
    @reader ||= self.method(:reader)
    @wait_for_response ||= FFI::Libevent::Event.new(@base, @fd, FFI::Libevent::EV_READ, &@reader)
  end
end

class Pinger < PingPong
  def reader *_
    begin
      while input = @fd.read_nonblock(4)
        @received << input
      end
    rescue IO::EAGAINWaitReadable
    end

    if @received == PONG
      @received = ''
      wait_to_write.add!
      Stats.inc_ponged
    end
  end

  def writer *_
    @fd << PING
    wait_for_response.add!
  end
end

class Ponger < PingPong
  def reader *_
    begin
      while input = @fd.read_nonblock(4)
        @received << input
      end
    rescue IO::EAGAINWaitReadable
    end

    if @received == PING
      @received = ''
      wait_to_write.add!
      Stats.inc_ponged
    end
  end

  def writer *_
    @fd << PONG
    wait_for_response.add!
  end
end

pinger_fd, ponger_fd = UNIXSocket.pair
pinger = Pinger.new base, pinger_fd
ponger = Ponger.new base, ponger_fd

pinger.wait_to_write.add!
ponger.wait_for_response.add!
base.loop!
