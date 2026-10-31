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

  # A filesystem-absolute target resolves against the reader's filesystem
  # root — never the gem root — so it dangles in an installed gem even though
  # it resolves from the checkout, where bin/check's docs step resolves it
  # against the repository root. That asymmetry is exactly why this check
  # exists, and why `/…` is judged rather than skipped.
  def test_a_filesystem_absolute_target_is_reported_as_escaping
    finding = only("[spec](/docs/idea/00-build-spec.md)", page: "wiki/Home.md",
                                                          packaged: ["wiki/Home.md", "docs/idea/00-build-spec.md"])

    assert_equal "MAGIK_DEV_SHIPPED_LINK_ESCAPES", finding.code
    assert_equal "wiki/Home.md:1", finding.at
    assert_includes finding.cause, "filesystem root"
    assert_includes finding.fix, "/docs/idea/00-build-spec.md", "names the target it replaces"
    assert_includes finding.fix, "../docs/idea/00-build-spec.md", "names the packaged replacement"
  end

  # A repository URL to a page the gem packages is the version-blindness
  # failure: an installed gem's reader would leave their version for whatever
  # main carries. The fix names the packaged copy's page-relative spelling.
  def test_a_main_url_to_a_packaged_page_is_reported
    finding = only(
      "[swap points](https://raw.githubusercontent.com/developerz-ai/magik/main/docs/idea/04-swap-points.md)",
      page: "wiki/Screens-And-Components.md",
      packaged: ["wiki/Screens-And-Components.md", "docs/idea/04-swap-points.md"]
    )

    assert_equal "MAGIK_DEV_SHIPPED_LINK_MUTABLE_MAIN", finding.code
    assert_equal "wiki/Screens-And-Components.md:1", finding.at
    assert_includes finding.fix, "../docs/idea/04-swap-points.md"
  end

  def test_a_blob_url_with_a_fragment_keeps_the_anchor_in_its_fix
    finding = only(
      "[codes](https://github.com/developerz-ai/magik/blob/main/docs/architecture/03-error-codes.md#tokens)",
      page: "wiki/Error-Codes.md", packaged: ["wiki/Error-Codes.md", "docs/architecture/03-error-codes.md"]
    )

    assert_equal "MAGIK_DEV_SHIPPED_LINK_MUTABLE_MAIN", finding.code
    assert_includes finding.fix, "../docs/architecture/03-error-codes.md#tokens"
  end

  # For content the gem does not carry, the repository URL is the only link
  # there is — unpackaged files, directories, and other repositories are
  # silent, as are https URLs to nobody's main.
  def test_main_urls_to_unpacked_files_directories_and_other_repositories_are_silent
    source = <<~MD
      [roadmap](https://raw.githubusercontent.com/developerz-ai/magik/main/apps/magik/ROADMAP.md)
      [idea tree](https://github.com/developerz-ai/magik/tree/main/docs/idea)
      [ultimate](https://raw.githubusercontent.com/developerz-ai/ultimate/main/README.md)
    MD

    assert_empty ShippedLinks.audit(links(source), page: "wiki/Home.md", packaged: ["wiki/Home.md"])
  end

  def test_a_link_to_an_unpackaged_file_inside_the_gem_is_reported
    finding = only("[roadmap](../ROADMAP.md)", page: "wiki/Home.md", packaged: ["wiki/Home.md"])

    assert_equal "MAGIK_DEV_SHIPPED_LINK_UNPACKAGED", finding.code
    assert_includes finding.cause, "ROADMAP.md"
    assert_includes finding.cause, "does not package"
    assert_includes finding.fix, "wiki/Home.md:1", "the fix names the file and line to edit"
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
