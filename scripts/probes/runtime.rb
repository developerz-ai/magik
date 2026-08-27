#!/usr/bin/env ruby
# frozen_string_literal: true

# Runtime capability probe. Answers, for whichever engine runs it, the three
# questions spec items 1 and 2 depend on:
#
#   1. Does Ractor exist and work?          (spec item 1 names Ractors)
#   2. Is the Fiber scheduler present?      (Falcon/async need it — spec item 2)
#   3. Are threads ACTUALLY parallel?       (the fallback the spec now relies on)
#
# Question 3 is the one that is easy to get wrong. It uses SHA256 over a
# rolling buffer rather than arithmetic, because a JIT will fold a numeric
# loop away and leave you measuring thread-creation overhead; and it warms
# the JIT before timing, because a cold native image loses to its own
# interpreter. Run it on every engine in the CI matrix.
#
#   ruby scripts/probes/runtime.rb [--json]
#
# See docs/architecture/12-runtime-verification.md for the recorded results.

require "json"
require "digest"

ROUNDS = Integer(ENV.fetch("MAGIK_PROBE_ROUNDS", 200_000))
THREADS = Integer(ENV.fetch("MAGIK_PROBE_THREADS", 4))

# Real CPU work a JIT cannot eliminate: each round depends on the last.
def burn(seed, rounds)
  digest = seed.to_s
  rounds.times { digest = Digest::SHA256.hexdigest(digest) }
  digest
end

def timed
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  yield
  Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
end

def ractor_support
  return { defined: false, works: false, error: "Ractor is not defined" } unless defined?(Ractor)

  { defined: true, works: Ractor.new { 1 + 1 }.take == 2, error: nil }
rescue Exception => e # rubocop:disable Lint/RescueException
  { defined: true, works: false, error: "#{e.class}: #{e.message}" }
end

def fiber_scheduler_support
  return { available: false, error: "Fiber does not respond to set_scheduler" } unless Fiber.respond_to?(:set_scheduler)

  { available: true, error: nil }
end

def thread_parallelism
  sink = []
  THREADS.times { |i| sink << burn(i, ROUNDS / 10) } # warm the JIT
  serial = timed { THREADS.times { |i| sink << burn(i, ROUNDS) } }
  workers = -> { Array.new(THREADS) { |i| Thread.new { burn(i, ROUNDS) } }.map(&:value) }
  parallel = timed { sink.concat(workers.call) }
  { threads: THREADS, serial_s: serial.round(3), parallel_s: parallel.round(3),
    speedup: (serial / parallel).round(2), parallel?: (serial / parallel) > 1.5 }
end

report = {
  engine: RUBY_ENGINE, version: RUBY_VERSION, description: RUBY_DESCRIPTION,
  ractor: ractor_support, fiber_scheduler: fiber_scheduler_support, threads: thread_parallelism
}

if ARGV.include?("--json")
  puts JSON.pretty_generate(report)
else
  ractor = report[:ractor][:works] ? "works" : "unavailable — #{report[:ractor][:error]}"
  scheduler = report[:fiber_scheduler][:available] ? "present" : "ABSENT — async/Falcon cannot run"
  threads = report[:threads]
  verdict = threads[:parallel?] ? "genuinely parallel" : "NOT parallel"

  puts report[:description]
  puts "  Ractor          : #{ractor}"
  puts "  Fiber scheduler : #{scheduler}"
  puts "  Threads         : #{threads[:speedup]}x on #{threads[:threads]} threads — #{verdict}"
end
