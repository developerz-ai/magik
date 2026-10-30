# frozen_string_literal: true

require_relative "helper"

require_relative "../../scripts/checks/shipped_links"

# Links inside packaged pages, read the way an installed gem's reader reads
# them: relative targets resolve against the gem root, and there is no
# repository above it. The pure rule is exercised with fixtures; the collector
# runs against the real tree, so a shipped page that starts dangling again
# fails here and not only at the gate.
class MagikScriptsShippedLinksTest < Minitest::Test
  ShippedLinks = MagikScripts::Checks::ShippedLinks

  def test_a_link_that_climbs_out_of_the_gem_root_is_reported
    finding = only("[spec](../../../docs/idea/00-build-spec.md)", page: "wiki/Home.md", packaged: ["wiki/Home.md"])

    assert_equal "MAGIK_DEV_SHIPPED_LINK_ESCAPES", finding.code
    assert_equal "wiki/Home.md:1", finding.at
    assert_includes finding.cause, "dangles"
  end

  def test_a_link_to_an_unpackaged_file_inside_the_gem_is_reported
    finding = only("[roadmap](../ROADMAP.md)", page: "wiki/Home.md", packaged: ["wiki/Home.md"])

    assert_equal "MAGIK_DEV_SHIPPED_LINK_UNPACKAGED", finding.code
    assert_includes finding.cause, "ROADMAP.md"
    assert_includes finding.cause, "does not package"
  end

  def test_packaged_siblings_absolute_links_and_fragments_are_silent
    source = <<~MD
      [Models](Models.md)
      [llms](../llms.txt)
      [spec](../docs/idea/00-build-spec.md)
      [site](https://example.com)
      [section](#rules)
      [autolink](<https://example.com/x>)
    MD
    packaged = ["wiki/Models.md", "llms.txt", "docs/idea/00-build-spec.md"]

    assert_empty ShippedLinks.audit(links(source), page: "wiki/Home.md", packaged: packaged)
  end

  def test_template_links_are_left_alone
    assert_empty ShippedLinks.audit(links("[x]({{path}})\n"), page: "wiki/X.md", packaged: [])
  end

  def test_findings_carry_the_line_of_the_link_not_the_page
    finding = only("intro\n\nout: [spec](../../elsewhere.md)\n", page: "wiki/X.md", packaged: ["wiki/X.md"])

    assert_equal "wiki/X.md:3", finding.at
  end

  def test_every_packaged_page_in_this_repository_resolves_inside_the_gem
    result = ShippedLinks.new.run

    assert_equal MagikScripts::Result::PASS, result.status
  end

  private

  # @param markdown [String] a page body
  # @return [Array<MagikScripts::Markdown::Link>]
  def links(markdown)
    MagikScripts::Markdown.new(markdown).links
  end

  # @param markdown [String] a page body with exactly one violating link
  # @param page [String] the page's app-root-relative path
  # @param packaged [Array<String>] the packaged paths the rule is held against
  # @return [MagikScripts::Finding]
  def only(markdown, page:, packaged:)
    findings = ShippedLinks.audit(links(markdown), page: page, packaged: packaged)

    assert_equal 1, findings.size, "expected one finding, got #{findings.map(&:code).inspect}"
    findings.first
  end
end
