# frozen_string_literal: true

require_relative "helper"

# `magik.manifest.json`. Regenerating without comparing would prove only that
# the generator runs — a check that cannot fail, which is worse than no check —
# so the drift half is what is tested hardest here.
class MagikScriptsManifestTest < Minitest::Test
  Manifest = MagikScripts::Manifest

  def test_the_manifest_is_derived_from_the_tree_not_typed_in
    fresh = Manifest.build

    assert_equal MagikScripts::Library.subsystems.size, fresh["subsystems"].size
    assert_equal MagikScripts::Library.error_classes.size, fresh["error_codes"].size
    assert_equal MagikScripts::Registry.discover.size, fresh["checks"].size
    assert_equal MagikScripts::Tiers::TABLE.values.uniq.size, fresh["tiers"].size
  end

  def test_every_subsystem_row_carries_its_tier_phase_and_status
    MagikScripts::Manifest.build["subsystems"].each do |row|
      refute_nil row["tier"], "#{row["name"]} has no tier"
      assert_equal MagikScripts::Tiers.tier_of(row["name"]), row["tier"]
      assert_path_exists MagikScripts::Repo.path(row["file"]).to_s
    end
  end

  def test_the_build_is_deterministic
    assert_equal Manifest.serialise(Manifest.build), Manifest.serialise(Manifest.build)
  end

  def test_the_build_id_is_a_full_sha256_of_the_body
    fresh = Manifest.build

    assert_match(/\A[0-9a-f]{64}\z/, fresh["build_id"])
    assert_equal fresh["build_id"], Manifest.build_id(fresh)
  end

  def test_key_order_is_fixed_so_two_runs_diff_cleanly
    assert_equal Manifest::KEY_ORDER, Manifest.build.keys
  end

  def test_a_missing_file_is_drift
    assert_equal ["#{Manifest::PATH} is missing, unreadable, or not a JSON object"],
                 Manifest.drift(nil, Manifest.build)
  end

  def test_a_changed_section_is_named_in_the_drift_report
    fresh = Manifest.build
    stale = fresh.merge("subsystems" => fresh["subsystems"].first(1))

    assert_equal ["subsystems differs"], Manifest.drift(stale, fresh)
  end

  def test_a_hand_edited_digest_over_a_matching_body_is_still_drift
    fresh = Manifest.build
    tampered = fresh.merge("build_id" => "0" * 64)

    assert_equal 1, Manifest.drift(tampered, fresh).size
    assert_includes Manifest.drift(tampered, fresh).first, "hand-edited"
  end

  def test_a_current_file_is_not_drift
    assert_empty Manifest.drift(Manifest.build, Manifest.build)
  end

  def test_the_finding_names_the_command_that_repairs_it
    finding = MagikScripts::Checks::ManifestCheck.drift_finding(["checks differs"])

    assert_equal "MAGIK_MANIFEST_DRIFT", finding.code
    assert_includes finding.fix, "ruby scripts/checks/manifest.rb --write"
  end

  def test_a_broken_generator_is_a_different_finding_from_a_stale_file
    finding = MagikScripts::Checks::ManifestCheck.broken_finding(RuntimeError.new("boom"))

    assert_equal "MAGIK_MANIFEST_UNBUILDABLE", finding.code
    refute_equal "MAGIK_MANIFEST_DRIFT", finding.code
  end
end
