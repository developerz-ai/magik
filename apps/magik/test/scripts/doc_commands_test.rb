# frozen_string_literal: true

require_relative "helper"

# Documented commands versus real ones. The silence cases matter as much as the
# detections: this check reads every fence in the wiki, and one false positive
# on a page that is correct is what gets a check switched off rather than fixed.
class MagikScriptsDocCommandsTest < Minitest::Test
  DocCommands = MagikScripts::Checks::DocCommands

  def test_a_documented_script_that_does_not_exist_is_reported
    finding = only("bin/nope --fast")

    assert_equal "MAGIK_DEV_DOC_COMMAND_MISSING", finding.code
    assert_equal "page.md:2", finding.at
    assert_includes finding.fix, "chmod +x bin/nope"
  end

  def test_an_unknown_program_is_reported
    finding = only("yarn install")

    assert_equal "MAGIK_DEV_DOC_COMMAND_UNKNOWN", finding.code
    assert_includes finding.cause, "\"yarn\""
  end

  def test_a_magik_subcommand_the_cli_does_not_define_is_reported
    finding = only("magik teleport --now")

    assert_equal "MAGIK_DEV_DOC_SUBCOMMAND_UNKNOWN", finding.code
    assert_includes finding.cause, "lib/magik/cli.rb does not define it"
  end

  def test_a_rake_task_the_rakefile_does_not_define_is_reported
    finding = only("rake deploy")

    assert_equal "MAGIK_DEV_DOC_SUBCOMMAND_UNKNOWN", finding.code
    assert_includes finding.cause, "Rakefile does not define it"
  end

  def test_a_slash_command_with_no_file_behind_it_is_reported
    finding = only("/teleport")

    assert_equal "MAGIK_DEV_DOC_SLASH_COMMAND_UNKNOWN", finding.code
    assert_includes finding.fix, ".claude/commands/teleport.md"
  end

  def test_everything_this_repo_actually_provides_is_silent
    script = <<~SH
      bin/check
      ./bin/setup
      rake test
      magik version --json
      /check
      git status && cd ..
      bundle exec rake rubocop
    SH

    assert_empty DocCommands.audit(sightings(script), surface)
  end

  def test_a_flag_immediately_after_the_program_is_not_a_subcommand
    assert_empty DocCommands.audit(sightings("magik --json\nrake -T\n"), surface)
  end

  def test_only_shell_fences_are_read
    page = "```ruby\nnot_a_command_at_all\n```\n\n```text\nMAGIK_X: boom\n```\n"

    assert_empty DocCommands.sightings(page, "page.md")
  end

  def test_a_sighting_points_at_the_line_inside_the_fence
    sighting = DocCommands.sightings("intro\n\n```bash\nbin/check\nbin/setup\n```\n", "page.md").last

    assert_equal "page.md:5", sighting.at
  end

  def test_the_check_runs_against_the_real_tree_and_returns_a_verdict
    result = DocCommands.new.run

    assert_includes [MagikScripts::Result::PASS, MagikScripts::Result::FAIL,
                     MagikScripts::Result::MISSING], result.status
    result.findings.each { |finding| refute_nil finding.at, "#{finding.code} has no file:line" }
  end

  private

  # @param line [String] one documented command
  # @return [MagikScripts::Finding]
  def only(line)
    findings = DocCommands.audit(sightings(line), surface)

    assert_equal 1, findings.size, "expected one finding, got #{findings.map(&:code)}"
    findings.first
  end

  # @param script [String] the body of a shell fence
  # @return [Array<MagikScripts::Checks::DocCommands::Sighting>]
  def sightings(script)
    DocCommands.sightings("```bash\n#{script.chomp}\n```\n", "page.md")
  end

  # @return [MagikScripts::Checks::DocCommands::Surface] a fixed, tiny surface
  def surface
    DocCommands::Surface.new(executables: %w[bin/check bin/setup exe/magik],
                             rake_tasks: %w[test rubocop yard],
                             magik_commands: %w[version help check],
                             slash_commands: %w[check release])
  end
end
