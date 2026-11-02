# frozen_string_literal: true

require_relative "helper"
require "fileutils"
require "tmpdir"

# The tier rule. The pure half takes fixtures, so the negative cases are strings
# here rather than a require typed into `lib/` to watch it fail — and the last
# test holds this repository to the rule for real.
class MagikScriptsBoundariesTest < Minitest::Test
  Boundaries = MagikScripts::Checks::Boundaries

  def test_an_upward_require_is_refused
    finding = only(source("lib/magik/model.rb", "model", %(require "magik/action"\n)))

    assert_equal "MAGIK_DEV_BOUNDARY_TIER", finding.code
    assert_equal "lib/magik/model.rb:1", finding.at
    assert_includes finding.cause, "model (tier 2) requires action (tier 3)"
    assert_includes finding.fix, "may use: core, i18n, policy, router, schema"
  end

  def test_a_sideways_require_within_one_tier_is_refused
    finding = only(source("lib/magik/render.rb", "render", %(require "magik/realtime"\n)))

    assert_equal "MAGIK_DEV_BOUNDARY_TIER", finding.code
    assert_includes finding.cause, "render (tier 2) requires realtime (tier 2)"
  end

  def test_reaching_past_a_front_door_is_refused_even_when_the_tier_allows_it
    finding = only(source("lib/magik/api/resource.rb", "api", %(require "magik/model/dataset"\n)))

    assert_equal "MAGIK_DEV_BOUNDARY_INTERNAL_REQUIRE", finding.code
    assert_includes finding.fix, %(require "magik/model")
  end

  def test_a_constant_reference_counts_as_a_dependency
    finding = only(source("lib/magik/core/boot.rb", "core", %(Magik::Check.run\n)))

    assert_equal "MAGIK_DEV_BOUNDARY_TIER", finding.code
    assert_includes finding.cause, "names Magik::Check, owned by check (tier 5)"
  end

  def test_a_downward_require_and_an_own_file_are_silent
    sources = [
      source("lib/magik/action.rb", "action", %(require "magik/model"\n)),
      source("lib/magik/action/params.rb", "action", %(require_relative "definition"\n)),
      source("lib/magik/action.rb", "action", %(require "json"\n))
    ].flatten

    assert_empty Boundaries.violations(sources)
  end

  def test_the_exempt_entry_point_is_not_held_to_a_tier_it_does_not_have
    entry = [Boundaries::Source.new(path: "lib/magik.rb", subsystem: nil,
                                    body: %(x = Magik::Cli\n))]

    assert_empty Boundaries.violations(entry)
    assert_nil Boundaries.owner("lib/magik.rb")
    assert_nil Boundaries.owner("lib/magik/version.rb")
  end

  def test_a_document_that_stops_stating_the_table_is_drift
    finding = Boundaries.drift("fake.md" => "no table here").first

    assert_equal "MAGIK_DEV_BOUNDARY_TABLE_DRIFT", finding.code
    assert_includes finding.cause, "states no `tier N"
  end

  def test_a_document_that_states_the_wrong_tier_is_drift
    text = MagikScripts::Tiers.render.sub("tier 2   model", "tier 2   ")
    finding = Boundaries.drift("fake.md" => text).first

    assert_equal "MAGIK_DEV_BOUNDARY_TABLE_DRIFT", finding.code
    assert_includes finding.fix, "tier 2   model, render, realtime, jobs"
  end

  def test_a_document_that_agrees_is_silent
    assert_empty Boundaries.drift("fake.md" => MagikScripts::Tiers.render)
  end

  def test_this_repository_obeys_its_own_tier_table
    status, out, = run_script("scripts/checks/boundaries.rb")

    assert_equal 0, status, out
  end

  # The header comment IS the check's `--help` prose. A tier table that drifts
  # from `scripts/lib/tiers.rb` there is prose the reader trusts and the code
  # does not honour.
  def test_the_help_header_states_the_same_tier_table_as_the_code
    description = MagikScripts::Registry.parse("scripts/checks/boundaries.rb").description

    assert_equal MagikScripts::Tiers::TABLE, MagikScripts::Tiers.parse_doc(description)
  end

  def test_the_rendered_help_carries_every_tier_row
    status, out, = run_script("scripts/checks/boundaries.rb", "--help")

    assert_equal 0, status, out
    MagikScripts::Tiers.render.lines.each do |row|
      assert_includes out, row.strip
    end
  end

  def test_each_missing_document_fails_and_restoring_it_passes
    MagikScripts::Tiers::DOCUMENTS.each do |missing|
      with_checkout do
        MagikScripts::Repo.path(missing).delete

        assert_missing_documents([missing])

        MagikScripts::Repo.path(missing).write(MagikScripts::Tiers.render)
        [[], ["--json"]].each do |argv|
          status, out, = run_script("scripts/checks/boundaries.rb", *argv)

          assert_equal 0, status, out
        end
      end
    end
  end

  def test_both_missing_documents_are_reported
    with_checkout do
      MagikScripts::Tiers::DOCUMENTS.each { |path| MagikScripts::Repo.path(path).delete }

      assert_missing_documents(MagikScripts::Tiers::DOCUMENTS)
    end
  end

  def test_missing_document_does_not_hide_companion_drift_or_source_violations
    with_checkout do
      missing, companion = MagikScripts::Tiers::DOCUMENTS
      MagikScripts::Repo.path(missing).delete
      MagikScripts::Repo.path(companion).write("no table here")
      MagikScripts::Repo.path("lib/magik/model.rb").write(%(require "magik/action"\n))

      findings = assert_missing_documents([missing], total: 3)
      drift = findings.find { |finding| finding.fetch("code") == Boundaries::DRIFT_CODE }

      assert_equal companion, drift.fetch("at")
      assert_includes drift.fetch("cause"), "states no `tier N"
      tier = findings.find { |finding| finding.fetch("code") == Boundaries::TIER_CODE }

      assert_equal "lib/magik/model.rb:1", tier.fetch("at")
    end
  end

  private

  # A temporary checkout preserves apps/magik-relative ../../docs resolution.
  # @yield runs with only Repo.root stubbed; real checkout files are never changed
  # @return [void]
  def with_checkout(&block)
    script = MagikScripts::Repo.path("scripts/checks/boundaries.rb")
    Dir.mktmpdir("magik-boundaries") do |dir|
      root = Pathname.new(dir).join("apps/magik")
      FileUtils.mkdir_p(root.join("lib/magik"))
      FileUtils.mkdir_p(root.join("scripts/checks"))
      FileUtils.cp(script, root.join("scripts/checks/boundaries.rb"))
      root.join("lib/magik/model.rb").write("# valid source\n")
      MagikScripts::Tiers::DOCUMENTS.each do |path|
        document = root.join(path)
        FileUtils.mkdir_p(document.dirname)
        document.write(MagikScripts::Tiers.render)
      end
      with_repo_root(root, &block)
    end
  end

  # @param root [Pathname] temporary apps/magik directory
  # @yield runs with Repo.root replaced only for this block
  # @return [void]
  def with_repo_root(root)
    original = MagikScripts::Repo.method(:root)
    MagikScripts::Repo.define_singleton_method(:root) { root }
    yield
  ensure
    MagikScripts::Repo.define_singleton_method(:root, original)
  end

  # @param paths [Array<String>] missing configured documents
  # @param total [Integer] total findings, including any other violations
  # @return [Array<Hash>] JSON findings emitted by the real runner
  def assert_missing_documents(paths, total: paths.size)
    status, human, = run_script("scripts/checks/boundaries.rb")

    assert_equal 1, status, human
    status, json, = run_script("scripts/checks/boundaries.rb", "--json")

    assert_equal 1, status, json
    result = JSON.parse(json)

    assert_equal "fail", result.fetch("status")
    findings = result.fetch("findings")

    assert_equal total, findings.size
    paths.each do |path|
      finding = findings.find { |item| item.fetch("at") == path }

      refute_nil finding, json
      assert_equal "MAGIK_DEV_BOUNDARY_DOCUMENT_MISSING", finding.fetch("code")
      assert_equal "#{path} is missing; the configured tier document cannot be checked", finding.fetch("cause")
      assert_equal "git restore --source=HEAD -- #{path.delete_prefix("../../")}", finding.fetch("fix")
      assert_includes human, path
      assert_includes human, finding.fetch("cause")
      assert_includes human, finding.fetch("fix")
    end
    findings
  end

  # @param path [String]
  # @param subsystem [String]
  # @param body [String]
  # @return [Array<MagikScripts::Checks::Boundaries::Source>]
  def source(path, subsystem, body)
    [Boundaries::Source.new(path: path, subsystem: subsystem, body: body)]
  end

  # @param sources [Array<MagikScripts::Checks::Boundaries::Source>]
  # @return [MagikScripts::Finding]
  def only(sources)
    findings = Boundaries.violations(sources)

    assert_equal 1, findings.size, "expected exactly one finding, got #{findings.map(&:code)}"
    findings.first
  end
end
