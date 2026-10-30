# frozen_string_literal: true

require_relative "../test_helper"

require "json"
require "open3"
require "rbconfig"

# The gate's contract, pinned from OUTSIDE bin/check.
#
# bin/check is the script CI runs (one step per job) and the script a
# contributor runs (the whole list), so a step name ci.yml invokes and a step
# the gate lacks is a job that silently checks nothing — the exact drift
# ci.yml's header promises cannot happen (`.github/workflows/ci.yml` lines
# 17-20). These tests read the script the way both audiences invoke it, as a
# subprocess, and read the workflow the way only a test can: mechanically.
#
# The third test runs the `install` step for real — it builds the gem, installs
# it into an empty temp GEM_HOME and runs the installed binary — which is why
# it takes seconds where the rest of this suite takes milliseconds.
class BinCheckGateTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  CHECK = File.join(ROOT, "bin", "check")
  CI = File.join(ROOT, ".github", "workflows", "ci.yml")

  # The ordered steps the gate must print. Renaming one or moving one is a
  # change to this contract, not a free move: ci.yml names steps in its `run:`
  # lines, and the parity test below is what holds the two sides together.
  EXPECTED_STEPS = %w[rubocop test yard build install cli docs checks].freeze

  def test_list_prints_the_gate_steps_in_contract_order
    assert_path CHECK, "the gate script itself"

    out, err, status = run_check("--list")

    assert_predicate status, :success?, "bin/check --list exited #{status.exitstatus}\n#{err}"
    assert_equal EXPECTED_STEPS, out.lines.map(&:strip).reject(&:empty?)
  end

  def test_every_step_ci_invokes_is_a_step_the_gate_defines
    assert_path CI, "the workflow the parity guard reads"

    ci = File.read(CI)
    invoked = ci.lines.select { |line| line.include?("bin/check --only") }
                .flat_map { |line| line.scan(/--only\s+([\w-]+)/) }
                .map(&:first).uniq.sort

    refute_empty invoked,
                 "no `bin/check --only <step>` found in ci.yml — the parity regex went stale " \
                 "and this test can no longer see what CI runs"

    listed = run_check("--list").first.lines.map(&:strip).reject(&:empty?)
    unknown = invoked - listed

    assert_empty unknown,
                 "ci.yml invokes bin/check --only #{unknown.join(", ")}, which bin/check --list " \
                 "does not define (it prints: #{listed.join(" ")})"
  end

  def test_install_step_installs_the_built_gem_into_an_empty_gem_home_and_runs_it
    out, err, status = run_check("--only", "install", "--json")

    assert_predicate status, :success?,
                     "bin/check --only install exited #{status.exitstatus}\n#{err}#{out}"
    data = JSON.parse(out)

    assert data["ok"], "the install step did not pass: #{data["first_failure"].inspect}"
    assert_equal %w[install], data["selected"]
    assert_equal 1, data["steps"].size, "expected exactly one step to run"
    assert_equal "install", data["steps"].first["name"]
    assert_equal "pass", data["steps"].first["status"]
  end

  def test_install_step_fails_legibly_when_it_cannot_even_read_the_version
    # The test above pins that `install` PASSES; this one pins that it FAILS
    # the way the gate promises to fail. The step's refusal branches
    # (bin/check 267-378) are contracts like any other, and a branch that can
    # stop firing unnoticed is untested code. An empty PATH makes the FIRST
    # one fire deterministically: the version read (`ruby -Ilib -e ...`,
    # bin/check 278) cannot resolve `ruby` at all, `sh` rescues the
    # Errno::ENOENT (bin/check 78-80), and the step must report
    # version_unreadable — before any gem is built or installed, so this case
    # stays fast and writes nothing. Deleting that branch changes the reason
    # this asserts (the run would fall through to gem_build_failed), which is
    # exactly the drift this test exists to catch.
    #
    # The bundler variables are unset because this suite normally runs under
    # `bundle exec rake test`, and the child inherits that boot: RUBYOPT and
    # BUNDLER_SETUP make the child ruby re-evaluate magik.gemspec before
    # bin/check runs a single line (Gemfile `gemspec` -> magik.gemspec's
    # `git ls-files`), which with an empty PATH dies outside bin/check with
    # Bundler::GemspecError and an empty stdout — a boot failure, not the
    # legible verdict this test pins. Unsetting them (nil = unset, under
    # Process.spawn env semantics) boots the child on plain RubyGems — the
    # same scoping bin/check's install step applies to its own gem
    # subprocesses (bin/check 314-318).
    child_env = {
      "PATH" => "",
      "RUBYOPT" => nil, "BUNDLER_SETUP" => nil, "BUNDLE_GEMFILE" => nil,
      "BUNDLE_BIN_PATH" => nil, "BUNDLER_VERSION" => nil
    }
    out, err, status =
      Open3.capture3(child_env, RbConfig.ruby, CHECK, "--only", "install", "--json")

    refute_predicate status, :success?,
                     "an install step that cannot read the version must fail the gate " \
                     "(exit #{status.exitstatus})\n#{err}#{out}"
    assert_equal 1, status.exitstatus,
                 "a failing gate exits EXIT_FAILED (1), got #{status.exitstatus}"
    data = JSON.parse(out)

    refute data["ok"],
           "the install step failed, so the gate cannot report ok: #{data["first_failure"].inspect}"
    assert_equal %w[install], data["selected"]
    assert_equal 1, data["steps"].size, "expected exactly one step to run"
    step = data["steps"].first

    assert_equal "install", step["name"]
    assert_equal "fail", step["status"]
    assert_equal "version_unreadable", step["reason"],
                 "with `ruby` unresolvable, the version read is the failure the step must name"
    assert_includes step["got"], "Errno::ENOENT",
                    "the excerpt must carry the cause: the version read never ran"
    refute_nil step["fix"], "a failing step without a fix: line is an incomplete step (bin/check 21)"
  end

  private

  # A file this test reads must exist, so a moved path fails as itself instead
  # of as a mysteriously empty match or a stale contract.
  #
  # @param path [String] absolute path
  # @param what [String] what the path is, for the failure message
  # @return [void]
  def assert_path(path, what)
    assert_path_exists path, "#{what} is missing at #{path} — the test is reading the wrong checkout"
  end

  # Run bin/check as its own process, the way CI and a contributor do — never
  # by loading it, which would run the gate in this test process.
  #
  # @param argv [Array<String>]
  # @return [Array(String, String, Process::Status)] stdout, stderr, status
  def run_check(*argv)
    Open3.capture3(RbConfig.ruby, CHECK, *argv)
  end
end
