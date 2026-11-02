# frozen_string_literal: true

require "fileutils"
require "tmpdir"

require_relative "helper"

# The contract every check answers to, asserted against every check in the tree
# rather than one representative. A check that quietly stops speaking `--json`
# is a check `bin/check` can no longer read the result of.
class MagikScriptsRunnerTest < Minitest::Test
  Runner = MagikScripts::Runner

  # A check with a fixed verdict, so the runner is tested without a repository.
  class FakeCheck < MagikScripts::Check
    # @return [Hash{String => Symbol}]
    def self.flags
      { "--boom" => :boom }
    end

    # @return [MagikScripts::Result]
    def run
      return failure(reason: "boom", expected: "quiet", fix: "run it", got: "noise") if options[:boom]

      ok(expected: "quiet", got: "8 files scanned")
    end
  end

  HEADER = <<~RUBY
    # @check   fake
    # @summary A check that does what it is told.
    # @order   999
    #
    # Prose the --help output prints.
  RUBY

  def test_a_satisfied_check_exits_zero_and_says_what_it_inspected
    status, out, = run_fake

    assert_equal 0, status
    assert_includes out, "fake: pass"
    assert_includes out, "8 files scanned"
  end

  def test_a_failing_check_exits_one_and_prints_a_fix_line_last
    status, out, = run_fake("--boom")

    assert_equal 1, status
    assert_includes out, "fake: FAIL"
    assert_match(/fix: run it\s*\z/, out)
  end

  def test_an_unknown_flag_is_bad_usage_not_a_failure
    status, out, err = run_fake("--nope")

    assert_equal 64, status
    assert_empty out
    assert_includes err, "--help"
  end

  def test_help_prints_the_header_and_exits_zero
    status, out, = run_fake("--help")

    assert_equal 0, status
    assert_includes out, "A check that does what it is told."
    assert_includes out, "Prose the --help output prints."
    assert_includes out, "Cost order in bin/check: 999"
  end

  def test_json_is_the_only_thing_on_stdout
    _, out, = run_fake("--boom", "--json")
    parsed = JSON.parse(out)

    assert_equal "fake", parsed["check"]
    assert_equal "fail", parsed["status"]
    assert_equal 1, parsed["exit_code"]
    refute parsed["ok"]
    assert_kind_of Integer, parsed["duration_ms"]
  end

  def test_every_check_in_the_tree_speaks_json_and_exits_a_known_code
    MagikScripts::Registry.discover.each do |entry|
      status, out, = run_script(entry.path, "--json")
      parsed = JSON.parse(out)

      assert_includes [0, 1, 69], status, "#{entry.name} exited #{status}"
      assert_equal entry.name, parsed["check"]
      assert_equal status, parsed["exit_code"]
      assert_equal status.zero?, parsed["ok"]
    end
  end

  def test_every_failing_check_in_the_tree_carries_a_runnable_fix
    MagikScripts::Registry.discover.each do |entry|
      _, out, = run_script(entry.path, "--json")
      parsed = JSON.parse(out)
      next if parsed["ok"]

      refute_nil parsed["fix"], "#{entry.name} failed without a fix: line"
      refute_empty parsed["findings"], "#{entry.name} failed without naming a finding"
      parsed["findings"].each do |finding|
        assert_match(/\AMAGIK_[A-Z0-9_]+\z/, finding["code"])
        refute_empty finding["fix"].to_s, "#{finding["code"]} has no fix:"
      end
    end
  end

  def test_every_check_in_the_tree_answers_help
    MagikScripts::Registry.discover.each do |entry|
      status, out, = run_script(entry.path, "--help")

      assert_equal 0, status
      assert_includes out, entry.summary
    end
  end

  private

  # Run {FakeCheck} through the runner with a header on disk.
  #
  # @param argv [Array<String>]
  # @return [Array(Integer, String, String)]
  def run_fake(*argv)
    dir = Dir.mktmpdir("magik-runner")
    path = File.join(dir, "fake.rb")
    File.write(path, HEADER)
    out = StringIO.new
    err = StringIO.new
    [Runner.main(path, FakeCheck, argv.flatten, out: out, err: err), out.string, err.string]
  ensure
    FileUtils.remove_entry(dir)
  end
end
