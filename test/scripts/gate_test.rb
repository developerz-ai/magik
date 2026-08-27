# frozen_string_literal: true

require_relative "helper"
require_relative "../../scripts/lib/gate"

# The adapter `bin/check` wires in. It is two lines in `bin/check` and it has to
# stay two lines: the moment the gate has to know a check's name, adding a check
# means editing the gate, and the two can disagree again.
class MagikScriptsGateTest < Minitest::Test
  Gate = MagikScripts::Gate

  # The same shape `bin/check` declares.
  Step = Struct.new(:name, :title, :command, :body, keyword_init: true)

  def test_one_step_per_discovered_check_in_cost_order
    steps = Gate.steps(Step)
    entries = MagikScripts::Registry.discover

    assert_equal entries.map(&:name), steps.map(&:name)
    assert_equal entries.map(&:summary), steps.map(&:title)
  end

  def test_a_step_announces_the_command_a_person_would_run_by_hand
    step = Gate.steps(Step).first

    assert_equal "ruby scripts/checks/#{step.name.tr("-", "_")}.rb --json", step.command.call
  end

  def test_a_passing_check_becomes_a_pass_outcome_with_no_fix
    outcome = step_named("boundaries").body.call

    assert_equal "pass", outcome[:status]
    assert_equal 0, outcome[:exit_code]
    assert_nil outcome[:fix]
    refute_empty outcome[:got]
  end

  def test_a_failing_verdict_keeps_its_findings_expectation_and_fix
    data = { "ok" => false, "status" => "fail", "reason" => "boom", "expected" => "quiet",
             "got" => "1 finding", "fix" => "run it",
             "findings" => [{ "code" => "MAGIK_X", "cause" => "why", "fix" => "edit it",
                              "at" => "a.rb:1" }] }
    outcome = Gate.translate(entry, "cmd", data, fake_status(1))

    assert_equal "fail", outcome[:status]
    assert_equal "quiet", outcome[:expected]
    assert_equal "run it", outcome[:fix]
    assert_includes outcome[:got], "MAGIK_X (a.rb:1)"
    assert_includes outcome[:got], "fix:   edit it"
  end

  def test_a_missing_tool_stays_missing_rather_than_becoming_a_failure
    data = { "ok" => false, "status" => "missing", "reason" => "tool_not_installed:rake",
             "expected" => "e", "got" => "g", "fix" => "bin/setup", "findings" => [] }

    assert_equal "missing", Gate.translate(entry, "cmd", data, fake_status(69))[:status]
  end

  def test_output_that_is_not_json_is_a_bug_in_the_check_not_a_finding
    outcome = Gate.unreadable(entry, "cmd", "Traceback...\n", fake_status(1))

    assert_equal "check_json_unparseable:demo", outcome[:reason]
    assert_includes outcome[:fix], "a bug in the check itself"
  end

  def test_parse_refuses_anything_that_is_not_a_verdict
    assert_nil Gate.parse("not json")
    assert_nil Gate.parse("[]")
    assert_nil Gate.parse('{"no_ok_key": 1}')
    refute_nil Gate.parse('{"ok": true}')
  end

  def test_a_long_report_is_excerpted_so_the_fix_line_is_never_buried
    excerpted = Gate.excerpt((1..200).map { |n| "line #{n}\n" }.join)

    assert_includes excerpted, "line 1"
    assert_includes excerpted, "line 200"
    assert_includes excerpted, "lines elided"
    assert_operator excerpted.lines.size, :<, 60
  end

  private

  # @param name [String]
  # @return [Struct]
  def step_named(name)
    Gate.steps(Step).find { |step| step.name == name }
  end

  # @return [MagikScripts::Registry::Entry]
  def entry
    MagikScripts::Registry::Entry.new(name: "demo", summary: "s", order: 1, description: "",
                                      path: "scripts/checks/demo.rb")
  end

  # @param code [Integer]
  # @return [Object] something answering #exitstatus
  def fake_status(code)
    Struct.new(:exitstatus).new(code)
  end
end
