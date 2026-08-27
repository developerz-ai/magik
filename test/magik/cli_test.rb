# frozen_string_literal: true

require "json"
require "test_helper"

# The CLI is the one subsystem with real behaviour today, so it gets real tests.
class MagikCLITest < Minitest::Test
  def test_version_prints_the_version
    status, out, err = run_cli("version")

    assert_equal Magik::CLI::EXIT_SUCCESS, status
    assert_includes out, Magik::VERSION
    assert_includes out, "spec only"
    assert_empty err
  end

  def test_version_json_is_parseable
    status, out, = run_cli("version", "--json")
    payload = JSON.parse(out)

    assert_equal Magik::CLI::EXIT_SUCCESS, status
    assert_equal "magik", payload["name"]
    assert_equal Magik::VERSION, payload["version"]
    assert_equal "spec only", payload["status"]
  end

  def test_version_flag_matches_the_version_command
    _, flag_out, = run_cli("--version")
    _, command_out, = run_cli("version")

    assert_equal command_out, flag_out
  end

  def test_help_lists_every_planned_command
    status, out, = run_cli("help")

    assert_equal Magik::CLI::EXIT_SUCCESS, status
    %w[new generate console server worker test check docs version help].each do |command|
      assert_includes out, command
    end

    assert_includes out, "planned"
  end

  def test_help_json_marks_command_status
    _, out, = run_cli("help", "--json")
    commands = JSON.parse(out).fetch("commands")
    by_name = commands.to_h { |c| [c["name"], c["status"]] }

    assert_equal(%w[new generate console server worker test check docs version help], commands.map { |c| c["name"] })
    assert_equal "planned", by_name.fetch("server")
    assert_equal "ready", by_name.fetch("version")
    assert_equal "ready", by_name.fetch("docs")
  end

  # `ready` vs `planned` is the one thing `magik help --json` exists to say
  # honestly, so the ready set is pinned: exactly the commands that run today.
  def test_the_ready_set_is_exactly_the_commands_that_run
    _, out, = run_cli("help", "--json")
    ready = JSON.parse(out).fetch("commands").select { |c| c["status"] == "ready" }.map { |c| c["name"] }

    assert_equal %w[docs version help], ready
    assert_equal Magik::CLI::EXIT_SUCCESS, run_cli("docs", "path").first
    assert_equal Magik::CLI::EXIT_SUCCESS, run_cli("version").first
    assert_equal Magik::CLI::EXIT_SUCCESS, run_cli("help").first
    assert_equal Magik::CLI::EXIT_ERROR, run_cli("server").first
  end

  def test_no_arguments_prints_help
    _, bare_out, = run_cli
    _, help_out, = run_cli("help")

    assert_equal help_out, bare_out
  end

  def test_planned_command_exits_non_zero_with_a_magik_code
    status, out, err = run_cli("server")

    assert_equal Magik::CLI::EXIT_ERROR, status
    assert_empty out
    assert_includes err, "MAGIK_COMMAND_NOT_IMPLEMENTED"
    assert_includes err, "fix:"
  end

  def test_unknown_command_exits_non_zero_with_a_magik_code
    status, _, err = run_cli("frobnicate")

    assert_equal Magik::CLI::EXIT_ERROR, status
    assert_includes err, "MAGIK_UNKNOWN_COMMAND"
  end

  def test_errors_are_json_when_json_is_requested
    status, out, err = run_cli("frobnicate", "--json")
    payload = JSON.parse(out).fetch("error")

    assert_equal Magik::CLI::EXIT_ERROR, status
    assert_empty err
    assert_equal "MAGIK_UNKNOWN_COMMAND", payload["code"]
    assert_match(/\S/, payload["cause"])
    assert_match(/\S/, payload["fix"])
  end

  def test_invalid_option_exits_non_zero
    status, _, err = run_cli("version", "--nope")

    assert_equal Magik::CLI::EXIT_ERROR, status
    assert_includes err, "MAGIK_INVALID_OPTION"
  end

  # --- magik docs ------------------------------------------------------------
  #
  # The command an agent runs instead of a web search: the gem's own docs, read
  # off the local filesystem, matching the installed version by construction.

  def test_docs_is_a_ready_command_not_a_planned_one
    status, out, err = run_cli("docs", "path")

    assert_equal Magik::CLI::EXIT_SUCCESS, status
    assert_empty err
    refute_includes out, "MAGIK_COMMAND_NOT_IMPLEMENTED"
  end

  def test_docs_lists_the_catalogue_grouped_by_audience
    status, out, = run_cli("docs", "list")

    assert_equal Magik::CLI::EXIT_SUCCESS, status
    assert_includes out, Magik::Docs.root.to_s
    Magik::Docs::AUDIENCE_LABELS.each_value { |label| assert_includes out, label }
    assert_includes out, "wiki/models"
    assert_includes out, "magik docs search <term>"
  end

  def test_docs_with_no_subcommand_lists
    _, bare_out, = run_cli("docs")
    _, list_out, = run_cli("docs", "list")

    assert_equal list_out, bare_out
  end

  def test_docs_list_json_has_a_stable_schema
    status, out, = run_cli("docs", "list", "--json")
    payload = JSON.parse(out)

    assert_equal Magik::CLI::EXIT_SUCCESS, status
    assert_equal "docs.list", payload["command"]
    assert_equal Magik::VERSION, payload["version"]
    assert_equal Magik::Docs.root.to_s, payload["root"]
    assert_equal Magik::Docs.pages.size, payload["count"]
    assert_equal %w[slug title path summary audience], payload["pages"].first.keys
  end

  def test_docs_path_prints_only_the_directory_so_it_can_be_shelled_out
    _, out, = run_cli("docs", "path")

    assert_equal "#{Magik::Docs.root}\n", out
    assert_path_exists out.strip
  end

  def test_docs_path_json_reports_the_root_and_page_count
    _, out, = run_cli("docs", "path", "--json")
    payload = JSON.parse(out)

    assert_equal "docs.path", payload["command"]
    assert_equal Magik::Docs.root.to_s, payload["root"]
    assert_equal Magik::Docs.pages.size, payload["pages"]
  end

  def test_docs_prints_a_page_as_raw_markdown
    status, out, err = run_cli("docs", "wiki/models")

    assert_equal Magik::CLI::EXIT_SUCCESS, status
    assert_empty err
    assert_equal Magik::Docs.read("wiki/models"), out
  end

  def test_docs_accepts_a_shorthand_slug
    _, short_out, = run_cli("docs", "dsl-surface")
    _, full_out, = run_cli("docs", "docs/idea/02-dsl-surface")

    assert_equal full_out, short_out
  end

  def test_docs_page_json_carries_the_entry_and_the_content
    _, out, = run_cli("docs", "models", "--json")
    payload = JSON.parse(out)

    assert_equal "docs.page", payload["command"]
    assert_equal "wiki/Models.md", payload.dig("page", "path")
    assert_equal "app", payload.dig("page", "audience")
    assert_equal Magik::Docs.read("models"), payload["content"]
  end

  def test_docs_search_reports_matching_lines_with_line_numbers
    status, out, = run_cli("docs", "search", "UUIDv7")

    assert_equal Magik::CLI::EXIT_SUCCESS, status
    assert_includes out, "wiki/Models.md"
    assert_match(/^\s+\d+\s+\S/, out)
  end

  def test_docs_search_json_has_a_stable_schema
    _, out, = run_cli("docs", "search", "UUIDv7", "--json")
    payload = JSON.parse(out)
    result = payload.fetch("results").first

    assert_equal "docs.search", payload["command"]
    assert_equal "UUIDv7", payload["term"]
    assert_equal payload["results"].size, payload["count"]
    assert_equal %w[slug title path summary audience matches], result.keys
    assert_operator result.fetch("matches").first.fetch("line"), :>, 0
  end

  def test_docs_search_miss_is_not_an_error
    status, out, err = run_cli("docs", "search", "zzz-no-such-term-zzz")

    assert_equal Magik::CLI::EXIT_SUCCESS, status
    assert_empty err
    assert_includes out, "No shipped page contains"
  end

  def test_docs_search_without_a_term_exits_non_zero_with_a_magik_code
    status, _, err = run_cli("docs", "search")

    assert_equal Magik::CLI::EXIT_ERROR, status
    assert_includes err, "MAGIK_DOCS_MISSING_TERM"
    assert_includes err, "fix:"
  end

  def test_docs_unknown_page_exits_non_zero_with_a_magik_code
    status, out, err = run_cli("docs", "no-such-page")

    assert_equal Magik::CLI::EXIT_ERROR, status
    assert_empty out
    assert_includes err, "MAGIK_DOCS_PAGE_NOT_FOUND"
  end

  def test_docs_errors_are_json_when_json_is_requested
    status, out, err = run_cli("docs", "no-such-page", "--json")
    payload = JSON.parse(out).fetch("error")

    assert_equal Magik::CLI::EXIT_ERROR, status
    assert_empty err
    assert_equal "MAGIK_DOCS_PAGE_NOT_FOUND", payload["code"]
    assert_includes payload["fix"], "magik docs list"
  end

  def test_executable_shim_exists_and_is_executable
    exe = Magik.root.join("exe", "magik")

    assert_path_exists exe.to_s
    assert File.executable?(exe), "exe/magik must be executable"
    assert_includes exe.read, "Magik::CLI.start(ARGV)"
  end
end
