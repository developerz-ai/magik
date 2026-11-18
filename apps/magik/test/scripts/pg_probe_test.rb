# frozen_string_literal: true

require "open3"
require "rbconfig"
require "tmpdir"

require_relative "helper"

# The optional `pg` probe, `apps/magik/scripts/probes/pg_concurrency.rb`.
#
# `pg` is deliberately NOT a dependency of this repository or its gem — the
# probe is run by hand, on a box where someone installed it — so the checkout
# that lacks it is the ordinary case, not the exotic one. That case must hand
# the reader a `MAGIK_DEV_PROBE_PG_MISSING` diagnostic with a runnable `fix:`,
# and it must do so on **stderr**: the probe has a `--json` mode whose stdout a
# parser consumes, so a diagnostic printed there corrupts the machine interface.
#
# Both cases are hermetic. "Missing" is not this box's accident: the child gets
# an empty `GEM_HOME`/`GEM_PATH`, so `require "pg"` raises `LoadError` even
# where pg is installed. "Present" is not this box's accident either: a stub
# `pg.rb` on `RUBYLIB` supplies `PG.connect`, so the probe runs its whole body
# with no database at all. Removing the `rescue LoadError` turns the first case
# red — the child then dies with a bare backtrace and prints no code.
class MagikScriptsPgProbeTest < Minitest::Test
  # The checkout root: this file lives four levels down, under
  # apps/magik/test/scripts/, and the probe is reached from there.
  REPO = File.expand_path("../../../..", __dir__).freeze

  # The subject.
  PROBE = File.join(REPO, "apps", "magik", "scripts", "probes", "pg_concurrency.rb").freeze

  # The same interpreter as the suite, so the child needs no PATH of its own.
  RUBY = File.join(RbConfig::CONFIG["bindir"], RbConfig::CONFIG["ruby_install_name"]).freeze

  # Reported back by the stub, so the "available" case proves the probe ran
  # past the require rather than merely failing differently.
  STUB_VERSION = "0.0.0-magik-test-stub"

  # A stand-in for the pg gem, loadable from RUBYLIB alone: `PG.connect`,
  # `PG::VERSION` and a connection whose `exec` does nothing are the whole of
  # the surface the probe touches. `exec` returns the connection because
  # `SELECT 1`'s result is discarded.
  PG_STUB = <<~RUBY.freeze
    module PG
      VERSION = "#{STUB_VERSION}"

      class Connection
        def exec(_sql)
          self
        end

        def close; end
      end

      def self.connect(_url)
        Connection.new
      end
    end
  RUBY

  def test_a_checkout_without_the_pg_gem_gets_a_diagnostic_not_a_bare_load_error
    Dir.mktmpdir("magik-pg-probe-missing") do |scratch|
      gems = File.join(scratch, "gems")
      Dir.mkdir(gems)

      out, err, status = run_probe("GEM_HOME" => gems, "GEM_PATH" => gems)

      refute_predicate status, :success?, "a checkout without pg must not report success"

      assert_equal 69, status.exitstatus,
                   "the probe exits 69 (EX_UNAVAILABLE) on a missing prerequisite — a tool that " \
                   "is not installed is not a broken repository, which is what 1 would mean; " \
                   "got #{status.exitstatus.inspect}"

      assert_includes err, "MAGIK_DEV_PROBE_PG_MISSING:",
                      "the diagnostic carries the code the scripts README names"

      assert_includes err, "cannot load such file -- pg",
                      "the code line names the real prerequisite, from the LoadError"

      fix = err.lines.find { |line| line.start_with?("  fix:") }

      refute_nil fix, "the diagnostic hands the reader a fix: line"

      assert_includes fix, "gem install pg", "the fix is a runnable command, not advice"

      refute_includes err, "LoadError",
                      "a bare LoadError must never be the primary output"

      refute_match(/\.rb:\d+:in /, err,
                   "no Ruby backtrace must be the primary output")

      assert_empty out,
                   "stdout is parser-consumed (the probe has --json); the diagnostic goes to stderr"
    end
  end

  def test_a_pg_gem_on_the_load_path_carries_the_probe_past_the_require
    Dir.mktmpdir("magik-pg-probe-present") do |scratch|
      File.write(File.join(scratch, "pg.rb"), PG_STUB)

      out, err, status = run_probe(
        "RUBYLIB" => scratch,
        "DATABASE_URL" => "postgres://localhost/magik_probe",
        "MAGIK_PROBE_THREADS" => "1",
        "MAGIK_PROBE_SLEEP" => "0.01"
      )

      assert_equal 0, status.exitstatus,
                   "with pg loadable the probe runs to the end; got #{status.exitstatus.inspect}\n#{err}"

      refute_includes err, "MAGIK_DEV_PROBE_PG_MISSING",
                      "the diagnostic belongs to the missing case only"

      assert_empty err, "the pg-present path writes nothing to stderr"

      assert_includes out, "pg #{STUB_VERSION}",
                      "the probe read the gem it loaded and reported it"
    end
  end

  private

  # Run the probe as its own process with a deterministic environment.
  #
  # The inherited environment is scrubbed first — the load-path and gem
  # variables, so "missing" is this test's doing and not the box's — and only
  # the caller's overrides are put back.
  #
  # `BUNDLER_SETUP` is the one that bites: `bundle exec rake test` exports it,
  # the child then boots bundler during rubygems' own start-up, and bundler
  # dies against the empty `GEM_HOME` below with a `Bundler::GemNotFound`
  # backtrace — before the probe's own `rescue LoadError` is ever reached. The
  # test would then be asserting this box's environment, not the probe.
  #
  # @param overrides [Hash{String => String}] environment for the child
  # @return [Array(String, String, Process::Status)] stdout, stderr, status
  def run_probe(overrides = {})
    scrubbed = %w[RUBYOPT RUBYLIB BUNDLE_GEMFILE BUNDLER_SETUP BUNDLE_BIN_PATH
                  BUNDLER_VERSION GEM_HOME GEM_PATH
                  DATABASE_URL MAGIK_PROBE_THREADS MAGIK_PROBE_SLEEP].to_h { |name| [name, nil] }

    Open3.capture3(scrubbed.merge(overrides), RUBY, PROBE)
  end
end
