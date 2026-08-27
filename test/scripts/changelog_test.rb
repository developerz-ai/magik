# frozen_string_literal: true

require_relative "helper"

# Keep a Changelog, enforced. The rule is pure, so every negative case is a
# string here rather than a mutilation of the real CHANGELOG.md.
class MagikScriptsChangelogTest < Minitest::Test
  Changelog = MagikScripts::Checks::Changelog

  GOOD = <<~MD
    # Changelog

    The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

    ## [Unreleased]

    Nothing yet.

    ## [0.0.2] - 2026-08-27

    ### Added

    - a thing

    ## [0.0.1] - 2026-08-26

    ### Notes

    - nothing measured

    [Unreleased]: https://example.test/compare
    [0.0.2]: https://example.test/v0.0.2
    [0.0.1]: https://example.test/v0.0.1
  MD

  def test_a_correct_changelog_is_silent
    assert_empty Changelog.audit(GOOD, "0.0.2")
  end

  def test_a_missing_unreleased_section_is_reported
    assert_includes codes(GOOD.sub("## [Unreleased]\n\nNothing yet.\n\n", ""), "0.0.2"),
                    "MAGIK_CHANGELOG_NO_UNRELEASED"
  end

  def test_a_version_with_no_section_is_reported
    finding = find(GOOD, "9.9.9", "MAGIK_CHANGELOG_VERSION_MISSING")

    assert_includes finding.cause, "stamped 9.9.9"
    assert_includes finding.fix, "## [9.9.9]"
  end

  def test_an_undated_release_heading_is_reported
    assert_includes codes(GOOD.sub("## [0.0.2] - 2026-08-27", "## [0.0.2]"), "0.0.2"),
                    "MAGIK_CHANGELOG_HEADING"
  end

  def test_releases_out_of_order_are_reported
    reversed = GOOD.sub("## [0.0.2] - 2026-08-27", "## [0.0.0] - 2026-08-25")
    finding = find(reversed, "0.0.1", "MAGIK_CHANGELOG_ORDER")

    assert_includes finding.cause, "newest-first"
  end

  def test_a_heading_with_no_link_definition_is_reported
    finding = find(GOOD.sub("[0.0.1]: https://example.test/v0.0.1\n", ""), "0.0.2",
                   "MAGIK_CHANGELOG_LINK_MISSING")

    assert_includes finding.cause, "[0.0.1]"
  end

  def test_a_subsection_that_is_not_a_change_type_is_reported
    finding = find(GOOD.sub("### Added", "### Improvements"), "0.0.2",
                   "MAGIK_CHANGELOG_UNKNOWN_SECTION")

    assert_includes finding.fix, "Added, Changed"
  end

  def test_a_page_that_does_not_declare_its_format_is_reported
    assert_includes codes(GOOD.sub(/\[Keep a Changelog\]\([^)]*\)/, "Keep a Changelog"), "0.0.2"),
                    "MAGIK_CHANGELOG_FORMAT_UNDECLARED"
  end

  def test_notes_is_accepted_alongside_the_six_keep_a_changelog_types
    assert_equal %w[Added Changed Deprecated Removed Fixed Security Notes], Changelog::SECTIONS
    assert_empty Changelog.sections(GOOD)
  end

  def test_the_real_changelog_passes
    status, out, = run_script("scripts/checks/changelog.rb")

    assert_equal 0, status, out
  end

  private

  # @param markdown [String]
  # @param version [String]
  # @return [Array<String>] the codes the audit produces
  def codes(markdown, version)
    Changelog.audit(markdown, version).map(&:code)
  end

  # @param markdown [String]
  # @param version [String]
  # @param code [String]
  # @return [MagikScripts::Finding]
  def find(markdown, version, code)
    finding = Changelog.audit(markdown, version).find { |f| f.code == code }

    refute_nil finding, "expected #{code}, got #{codes(markdown, version)}"
    finding
  end
end
