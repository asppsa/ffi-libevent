#!/bin/env ruby

require 'bundler/setup'
require 'ffi/libevent'
require 'socket'

base = FFI::Libevent::Base.new
trapper = FFI::Libevent::Event.new(base, "INT", FFI::Libevent::EV_SIGNAL) { base.loopbreak! }
trapper.add!

pinger, ponger = UNIXSocket.pair

## PINGER
wait_for_pong = nil

wait_to_ping = FFI::Libevent::Event.new(base, pinger, FFI::Libevent::EV_WRITE) do
  pinger << "PING"
  wait_for_pong.add!
end

wait_for_pong = FFI::Libevent::Event.new(base, pinger, FFI::Libevent::EV_READ) do
  puts pinger.recv(4)
  wait_to_ping.add!
end

## PONGER
wait_for_ping = nil
wait_to_pong = FFI::Libevent::Event.new(base, ponger, FFI::Libevent::EV_WRITE) do
  ponger << "PONG"
  wait_for_ping.add!
end

wait_for_ping = FFI::Libevent::Event.new(base, ponger, FFI::Libevent::EV_READ) do
  puts ponger.recv(4)
  wait_to_pong.add!
end

wait_to_ping.add!
wait_for_ping.add!
base.loop!
