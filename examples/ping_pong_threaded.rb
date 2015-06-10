#!/bin/env ruby

require 'bundler/setup'
require 'ffi/libevent'
require 'socket'

FFI::Libevent.use_threads!

base = FFI::Libevent::Base.new :avoid_method => :kqueue
trapper = base.add_event("INT", FFI::Libevent::EV_SIGNAL) { base.loopbreak! }

t = Thread.new{ base.loop! }

pinger, ponger = UNIXSocket.pair

## PINGER
wait_for_pong = nil

wait_to_ping = base.new_event(pinger, FFI::Libevent::EV_WRITE) do
  pinger << "PING"
  Thread.new{ wait_for_pong.add! }
end

wait_for_pong = base.new_event(pinger, FFI::Libevent::EV_READ) do
  puts pinger.recv(4)
  Thread.new{ wait_to_ping.add! }
end

## PONGER
wait_for_ping = nil
wait_to_pong = base.new_event(ponger, FFI::Libevent::EV_WRITE) do
  ponger << "PONG"
  Thread.new{ wait_for_ping.add! }
end

wait_for_ping = base.new_event(ponger, FFI::Libevent::EV_READ) do
  puts ponger.recv(4)
  Thread.new{ wait_to_pong.add! }
end

wait_to_ping.add!
wait_for_ping.add!

t.join
