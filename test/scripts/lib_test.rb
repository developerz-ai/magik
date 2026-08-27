# frozen_string_literal: true

require_relative "helper"

# The helper library. Small, so its tests are small — but the file walker's
# exclusions and the result's exit codes are load-bearing for every check, and
# both are the kind of thing that silently stops working.
class MagikScriptsLibTest < Minitest::Test
  Repo = MagikScripts::Repo
  Result = MagikScripts::Result
  Tiers = MagikScripts::Tiers

  def test_root_is_the_directory_holding_the_gemspec
    assert_path_exists Repo.path("magik.gemspec").to_s
    assert_predicate Repo.root, :absolute?
  end

  def test_glob_returns_root_relative_paths
    assert_includes Repo.glob("lib/**/*.rb"), "lib/magik/version.rb"
    assert(Repo.glob("lib/**/*.rb").none? { |path| path.start_with?("/") })
  end

  def test_glob_excludes_generated_and_vendored_trees
    Repo::EXCLUDED.each do |directory|
      assert_empty Repo.glob("#{directory}/**/*"), "#{directory}/ leaked into a check's corpus"
    end
  end

  def test_dummy_is_opt_in_never_default
    assert_empty Repo.glob("dummy/**/*.rb")
    refute_empty Repo.glob("dummy/**/*.rb", dummy: true)
  end

  def test_result_exit_codes_match_bin_check
    assert_equal 0, Result.ok(got: "x", expected: "y").exit_code
    assert_equal 1, Result.failure(reason: "r", expected: "y", fix: "f").exit_code
    assert_equal 69, Result.missing_tool(tool: "yard", install: "bin/setup", expected: "y").exit_code
  end

  def test_result_sorts_its_findings_so_two_runs_agree
    findings = %w[b.rb a.rb c.rb].map do |at|
      MagikScripts::Finding.new(code: "MAGIK_X", cause: "c", fix: "f", at: at)
    end
    result = Result.failure(reason: "r", expected: "e", fix: "f", findings: findings.shuffle)

    assert_equal %w[a.rb b.rb c.rb], result.findings.map(&:at)
  end

  def test_a_finding_renders_code_cause_and_fix
    rendered = MagikScripts::Finding.new(code: "MAGIK_X", cause: "why", fix: "run it", at: "a.rb:2").render

    assert_includes rendered, "MAGIK_X (a.rb:2)"
    assert_includes rendered, "cause: why"
    assert_includes rendered, "fix:   run it"
  end

  def test_the_base_check_refuses_to_pretend_it_ran
    assert_raises(NotImplementedError) { MagikScripts::Check.new.run }
  end

  def test_the_tier_table_covers_exactly_the_twenty_subsystems
    assert_equal MagikScripts::Library.subsystems.keys.map(&:to_s).sort, Tiers::TABLE.keys.sort
  end

  def test_tiers_allow_downward_only
    assert Tiers.allows?("cli", "core")
    refute Tiers.allows?("core", "cli")
    refute Tiers.allows?("render", "realtime"), "sideways within a tier must be refused"
    refute Tiers.allows?("core", "core")
  end

  def test_parse_doc_reads_a_tier_block_and_survives_one_that_is_not_there
    assert_equal({ "core" => 0, "schema" => 1, "router" => 1 },
                 Tiers.parse_doc("tier 0   core\ntier 1   schema, router\n"))
    assert_empty Tiers.parse_doc("no table here")
  end

  def test_the_rendered_table_round_trips_through_the_parser
    assert_equal Tiers::TABLE, Tiers.parse_doc(Tiers.render)
  end
end
