# frozen_string_literal: true

require "test_helper"

# The version string is a published API: the gemspec, the CLI and the changelog
# all read it.
class MagikVersionTest < Minitest::Test
  def test_version_is_a_semver_string
    assert_match(/\A\d+\.\d+\.\d+\z/, Magik::VERSION)
  end

  def test_version_is_the_name_reservation_release
    assert_equal "0.0.1", Magik::VERSION
  end

  def test_gemspec_reports_the_same_version
    spec = Gem::Specification.load(Magik.root.join("magik.gemspec").to_s)

    refute_nil spec, "magik.gemspec did not load"
    assert_equal Magik::VERSION, spec.version.to_s
    assert_equal "magik", spec.name
    assert_equal ["magik"], spec.executables
    assert_equal "exe", spec.bindir
    assert_equal "true", spec.metadata["rubygems_mfa_required"]
    assert_empty spec.runtime_dependencies
  end
end
