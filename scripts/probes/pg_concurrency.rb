#!/usr/bin/env ruby
# frozen_string_literal: true

# Does the `pg` C extension release the runtime lock while a query is in
# flight? This is the load-bearing question for Magik's whole concurrency
# model. Threads being parallel for Ruby code (scripts/probes/runtime.rb)
# is necessary but not sufficient: a web request spends most of its life
# inside libpq, so if `pg` serialises, every request serialises and the
# thread-per-request server is a thread-per-request queue.
#
# Method: N threads each run `SELECT pg_sleep(S)` on its own connection.
# The database does the waiting, so the wall clock answers directly —
# ~S seconds means the queries overlapped, ~N*S means they did not.
#
#   DATABASE_URL=postgres://... ruby scripts/probes/pg_concurrency.rb [--json]
#
# See docs/architecture/12-runtime-verification.md for recorded results.

require "json"
require "pg"

THREADS = Integer(ENV.fetch("MAGIK_PROBE_THREADS", 8))
SLEEP_S = Float(ENV.fetch("MAGIK_PROBE_SLEEP", 1.0))
URL = ENV.fetch("DATABASE_URL")

def timed
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  yield
  Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
end

# One connection per thread: sharing one would serialise for a reason that
# has nothing to do with the runtime lock, and would fake the bad result.
connections = Array.new(THREADS) { PG.connect(URL) }
connections.each { |c| c.exec("SELECT 1") } # connect + warm before timing

elapsed = timed do
  connections.map { |c| Thread.new { c.exec("SELECT pg_sleep(#{SLEEP_S})") } }.each(&:join)
end

serial_estimate = THREADS * SLEEP_S
overlapped = elapsed < (serial_estimate / 2)

report = {
  engine: RUBY_ENGINE, description: RUBY_DESCRIPTION, pg_gem: PG::VERSION,
  threads: THREADS, sleep_s: SLEEP_S, elapsed_s: elapsed.round(2),
  serial_would_be_s: serial_estimate.round(2),
  concurrency: (serial_estimate / elapsed).round(2), overlapped: overlapped
}
connections.each(&:close)

if ARGV.include?("--json")
  puts JSON.pretty_generate(report)
else
  verdict = overlapped ? "queries OVERLAP — the lock is released" : "queries SERIALISE — the lock is held"
  puts report[:description]
  puts "  pg #{report[:pg_gem]}, #{THREADS} threads x pg_sleep(#{SLEEP_S})"
  puts "  elapsed #{report[:elapsed_s]}s (serial would be #{report[:serial_would_be_s]}s) " \
       "— #{report[:concurrency]}x — #{verdict}"
end
