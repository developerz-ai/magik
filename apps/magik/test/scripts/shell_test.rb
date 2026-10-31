# frozen_string_literal: true

require_relative "helper"

# The quote-aware reader behind `doc-commands`. Each case here is a real line
# from this repository's documentation that the naive `line.split.first` gets
# wrong; getting one of them wrong turns a correct page into a finding, and a
# check that cries wolf is a check somebody turns off.
class MagikScriptsShellTest < Minitest::Test
  Shell = MagikScripts::Shell

  def test_a_trailing_comment_is_not_part_of_the_command
    assert_equal [%w[bin/check]], heads("bin/check        # THE GATE — what CI runs")
  end

  def test_a_hash_inside_quotes_is_not_a_comment
    assert_equal [["echo", "a # b"]], heads('echo "a # b"')
  end

  def test_a_semicolon_inside_quotes_does_not_split_the_command
    line = %q(ruby -Ilib -e 'require "magik"; puts Magik::VERSION')

    assert_equal 1, Shell.commands("#{line}\n").size
    assert_equal "ruby", Shell.commands("#{line}\n").first.tokens.first
  end

  def test_pipelines_and_chains_are_separate_commands
    assert_equal [%w[magik test --json], %w[jq .duration_ms]], heads("magik test --json | jq .duration_ms")
    assert_equal [%w[magik new shop], %w[cd shop]], heads("magik new shop && cd shop  # planned")
  end

  def test_env_prefixes_sudo_and_bundle_exec_are_not_the_command
    assert_equal [%w[bin/setup]], heads("FOO=1 sudo bin/setup")
    assert_equal [%w[rake test]], heads("bundle exec rake test")
  end

  def test_a_heredoc_body_is_data_not_commands
    script = "cat > x <<'EOF'\nrm -rf /\nEOF\nls\n"

    assert_equal(%w[cat ls], Shell.commands(script).map { |command| command.tokens.first })
  end

  def test_line_numbers_survive_continuations
    commands = Shell.commands("echo one \\\n  two\nls\n")

    assert_equal [1, 3], commands.map(&:line)
    assert_equal %w[echo one two], commands.first.tokens
  end

  def test_comments_and_blank_lines_produce_no_commands
    assert_empty Shell.commands("# just prose\n\n   \n")
  end

  def test_shell_keywords_are_control_flow_not_programs
    assert_empty(Shell.commands("for f in *; do\n")
                      .reject { |command| command.tokens.first == "*" }
                      .select { |command| Shell::KEYWORDS.include?(command.tokens.first) })
  end

  private

  # @param line [String] one documented line
  # @return [Array<Array<String>>] the tokens of each command it contains
  def heads(line)
    Shell.commands("#{line}\n").map(&:tokens)
  end
end
