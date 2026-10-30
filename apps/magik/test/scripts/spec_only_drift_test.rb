# frozen_string_literal: true

require_relative "helper"

# `Magik::SPEC_ONLY_SUBSYSTEMS` is what every "not implemented" claim in this
# repository is downstream of. Both drift directions are tested, because the
# dangerous one is the quiet one: a list that still says "spec only" after a
# phase lands is a repo that under-claims, which nobody notices. A list that
# stops saying it before the phase lands is a repo that lies.
class MagikScriptsSpecOnlyDriftTest < Minitest::Test
  SpecOnlyDrift = MagikScripts::Checks::SpecOnlyDrift

  def test_a_listed_subsystem_that_no_longer_refuses_is_reported
    finding = only(observed(listed: true, raises: false))

    assert_equal "MAGIK_DEV_SPEC_ONLY_IMPLEMENTED", finding.code
    assert_includes finding.cause, "no longer raises NotImplementedError"
    assert_includes finding.fix, "remove :model from SPEC_ONLY_SUBSYSTEMS"
  end

  def test_a_listed_subsystem_with_no_define_at_all_is_reported
    finding = only(observed(listed: true, raises: false, defines: false))

    assert_equal "MAGIK_DEV_SPEC_ONLY_IMPLEMENTED", finding.code
    assert_includes finding.cause, "has no .define at all"
  end

  def test_an_unlisted_subsystem_that_still_refuses_is_reported
    finding = only(observed(listed: false, raises: true, status: "Working"))

    assert_equal "MAGIK_DEV_SPEC_ONLY_UNLISTED", finding.code
    assert_includes finding.cause, "promise behaviour that refuses to run"
  end

  def test_a_status_constant_that_disagrees_with_the_list_is_reported
    finding = only(observed(listed: true, raises: true, status: "Shipping"))

    assert_equal "MAGIK_DEV_SPEC_ONLY_STATUS_DRIFT", finding.code
    assert_includes finding.fix, SpecOnlyDrift::SPEC_ONLY_STATUS
  end

  def test_a_list_entry_that_is_not_a_subsystem_is_reported
    finding = only(observed(listed: true, known: false, name: :nonesuch))

    assert_equal "MAGIK_DEV_SPEC_ONLY_UNKNOWN", finding.code
    assert_equal "lib/magik.rb", finding.at
  end

  def test_a_listed_and_refusing_subsystem_is_silent
    assert_empty SpecOnlyDrift.audit(observed(listed: true, raises: true))
  end

  def test_an_unlisted_and_working_subsystem_is_silent
    assert_empty SpecOnlyDrift.audit(observed(listed: false, raises: false, status: "Working"))
  end

  def test_this_repository_agrees_with_its_own_list
    status, out, = run_script("scripts/checks/spec_only_drift.rb")

    assert_equal 0, status, out
  end

  def test_the_shipped_list_still_covers_every_subsystem_but_the_cli
    assert_equal MagikScripts::Library.subsystems.keys - [:cli], MagikScripts::Library.spec_only
  end

  private

  # @param overrides [Hash] fields to override on the default observation
  # @return [Array<MagikScripts::Checks::SpecOnlyDrift::Observed>]
  def observed(**overrides)
    defaults = { name: :model, constant: "Magik::Model", listed: true, defines: true, raises: true,
                 status: SpecOnlyDrift::SPEC_ONLY_STATUS, at: "lib/magik/model.rb", known: true }
    [SpecOnlyDrift::Observed.new(**defaults, **overrides)]
  end

  # @param rows [Array<MagikScripts::Checks::SpecOnlyDrift::Observed>]
  # @return [MagikScripts::Finding]
  def only(rows)
    findings = SpecOnlyDrift.audit(rows)

    assert_equal 1, findings.size, "expected one finding, got #{findings.map(&:code)}"
    findings.first
  end
end
