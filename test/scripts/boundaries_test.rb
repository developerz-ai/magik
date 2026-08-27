# frozen_string_literal: true

require_relative "helper"

# The tier rule. The pure half takes fixtures, so the negative cases are strings
# here rather than a require typed into `lib/` to watch it fail — and the last
# test holds this repository to the rule for real.
class MagikScriptsBoundariesTest < Minitest::Test
  Boundaries = MagikScripts::Checks::Boundaries

  def test_an_upward_require_is_refused
    finding = only(source("lib/magik/model.rb", "model", %(require "magik/action"\n)))

    assert_equal "MAGIK_BOUNDARY_TIER", finding.code
    assert_equal "lib/magik/model.rb:1", finding.at
    assert_includes finding.cause, "model (tier 2) requires action (tier 3)"
    assert_includes finding.fix, "may use: core, i18n, policy, router, schema"
  end

  def test_a_sideways_require_within_one_tier_is_refused
    finding = only(source("lib/magik/render.rb", "render", %(require "magik/realtime"\n)))

    assert_equal "MAGIK_BOUNDARY_TIER", finding.code
    assert_includes finding.cause, "render (tier 2) requires realtime (tier 2)"
  end

  def test_reaching_past_a_front_door_is_refused_even_when_the_tier_allows_it
    finding = only(source("lib/magik/api/resource.rb", "api", %(require "magik/model/dataset"\n)))

    assert_equal "MAGIK_BOUNDARY_INTERNAL_REQUIRE", finding.code
    assert_includes finding.fix, %(require "magik/model")
  end

  def test_a_constant_reference_counts_as_a_dependency
    finding = only(source("lib/magik/core/boot.rb", "core", %(Magik::Check.run\n)))

    assert_equal "MAGIK_BOUNDARY_TIER", finding.code
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

    assert_equal "MAGIK_BOUNDARY_TABLE_DRIFT", finding.code
    assert_includes finding.cause, "states no `tier N"
  end

  def test_a_document_that_states_the_wrong_tier_is_drift
    text = MagikScripts::Tiers.render.sub("tier 2   model", "tier 2   ")
    finding = Boundaries.drift("fake.md" => text).first

    assert_equal "MAGIK_BOUNDARY_TABLE_DRIFT", finding.code
    assert_includes finding.fix, "tier 2   model, render, realtime, jobs"
  end

  def test_a_document_that_agrees_is_silent
    assert_empty Boundaries.drift("fake.md" => MagikScripts::Tiers.render)
  end

  def test_this_repository_obeys_its_own_tier_table
    status, out, = run_script("scripts/checks/boundaries.rb")

    assert_equal 0, status, out
  end

  private

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
