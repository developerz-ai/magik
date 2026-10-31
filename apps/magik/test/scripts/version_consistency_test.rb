# frozen_string_literal: true

require_relative "helper"

# One version, many copies. The interesting half of this check is what it
# refuses to read: `v1.0.0` inside the Conventional Commits URL in
# CONTRIBUTING.md and `v0.1.0-rc1` in PUBLISHING.md are correct prose, and a
# check that reported them would be deleted within a week.
class MagikScriptsVersionConsistencyTest < Minitest::Test
  VersionConsistency = MagikScripts::Checks::VersionConsistency

  def test_a_stale_doc_stamp_is_reported
    finding = only("Install `magik 0.0.9` today.\n", "0.0.1")

    assert_equal "MAGIK_DEV_VERSION_STAMP_STALE", finding.code
    assert_equal "page.md:1", finding.at
    assert_includes finding.fix, "change 0.0.9 to 0.0.1"
  end

  def test_every_stamp_form_this_repo_uses_is_read
    text = <<~MD
      The CLI prints `magik 0.0.1`.
      A release is `magik-0.0.1.gem`.
      `Magik::VERSION # => "0.0.1"`
      `gem "magik", "~> 0.0.1"`
    MD

    assert_equal %w[0.0.1 0.0.1 0.0.1 0.0.1], VersionConsistency.stamps(text, "page.md").map(&:version)
  end

  def test_a_version_belonging_to_something_else_is_not_read
    text = "See https://www.conventionalcommits.org/en/v1.0.0/ and tag `v0.1.0-rc1`.\n"

    assert_empty VersionConsistency.stamps(text, "page.md")
  end

  def test_a_json_version_is_read_only_inside_a_fence_that_names_magik
    ours = "```json\n{\"name\": \"magik\", \"version\": \"0.0.9\"}\n```\n"
    theirs = "```json\n{\"name\": \"other\", \"version\": \"9.9.9\"}\n```\n"

    assert_equal %w[0.0.9], VersionConsistency.stamps(ours, "page.md").map(&:version)
    assert_empty VersionConsistency.stamps(theirs, "page.md")
  end

  def test_a_document_that_agrees_is_silent
    assert_empty VersionConsistency.audit(VersionConsistency.stamps("magik 0.0.1\n", "page.md"), "0.0.1")
  end

  def test_a_corpus_with_no_stamp_at_all_is_a_failure_not_a_pass
    finding = VersionConsistency.audit([], "0.0.1").first

    assert_equal "MAGIK_DEV_VERSION_UNSTAMPED", finding.code
    assert_includes finding.cause, "would pass whatever"
  end

  def test_the_real_tree_agrees_with_lib_magik_version_rb
    status, out, = run_script("scripts/checks/version_consistency.rb")

    assert_equal 0, status, out
  end

  private

  # @param text [String] a document
  # @param version [String] the real version
  # @return [MagikScripts::Finding]
  def only(text, version)
    findings = VersionConsistency.audit(VersionConsistency.stamps(text, "page.md"), version)

    assert_equal 1, findings.size, "expected one finding, got #{findings.map(&:code)}"
    findings.first
  end
end
