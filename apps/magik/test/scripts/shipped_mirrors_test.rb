# frozen_string_literal: true

require_relative "helper"

require_relative "../../scripts/checks/shipped_mirrors"

# The generated mirrors of the checkout's docs/ trees. The pure rules —
# {MagikScripts::Checks::ShippedMirrors.render} and `.compare` — are exercised
# with fixtures, including a mutated committed mirror, so a compare that stopped
# comparing fails here and not only at the gate; the collector (`#run`) runs
# against the real tree, so a stale committed mirror fails here and not only at
# the gate.
class MagikScriptsShippedMirrorsTest < Minitest::Test
  Mirrors = MagikScripts::Checks::ShippedMirrors

  def test_a_link_to_a_packaged_page_stays_inside_the_gem
    mirror = Mirrors.render(
      "See [`04-swap-points.md`](04-swap-points.md).\n",
      version: "1.2.3",
      source: "../../docs/idea/00-build-spec.md",
      link_target_globs: ["docs/**/*.md"]
    )

    assert_includes mirror, "](04-swap-points.md)"
    refute_includes mirror, "githubusercontent.com",
                    "the packaged copy exists, so the mirror must not send the reader to the repository"
  end

  def test_a_link_to_a_packaged_page_in_another_tree_climbs_to_it
    mirror = Mirrors.render("Manual: [`CLI-Reference.md`](../../apps/magik/wiki/CLI-Reference.md).\n",
                            version: "1.2.3", source: "../../docs/architecture/09-shipped-docs.md",
                            link_target_globs: ["wiki/**/*.md", "docs/**/*.md"])

    assert_includes mirror, "](../../wiki/CLI-Reference.md)"
  end

  def test_a_fragment_rides_along_on_a_packaged_target
    mirror = Mirrors.render("Drafted Ruby: [`02-dsl-surface.md`](02-dsl-surface.md#policy).\n",
                            version: "1.2.3", source: "../../docs/idea/00-build-spec.md",
                            link_target_globs: ["docs/**/*.md"])

    assert_includes mirror, "](02-dsl-surface.md#policy)"
  end

  def test_a_filesystem_absolute_target_is_treated_as_repository_root_relative
    mirror = Mirrors.render("Spec: [`00-build-spec.md`](/docs/idea/00-build-spec.md).\n",
                            version: "1.2.3", source: "../../docs/README.md", link_target_globs: ["docs/**/*.md"])

    assert_includes mirror, "](idea/00-build-spec.md)",
                    "a `/`-leading target resolves from the checkout root in this repo's docs, and an " \
                    "installed gem has no filesystem root for it to resolve against"
  end

  def test_a_link_to_a_file_the_gem_does_not_package_becomes_a_repository_url
    mirror = Mirrors.render("Order: [`ROADMAP.md`](../../apps/magik/ROADMAP.md).\n",
                            version: "1.2.3", source: "../../docs/idea/06-phases.md",
                            link_target_globs: ["docs/**/*.md", "wiki/**/*.md"])

    assert_includes mirror, "(https://raw.githubusercontent.com/developerz-ai/magik/main/apps/magik/ROADMAP.md)"
  end

  def test_a_link_with_a_fragment_to_an_unpackaged_file_becomes_a_blob_url
    mirror = Mirrors.render("Tokens: [`03-error-codes.md`](../architecture/03-error-codes.md#tokens).\n",
                            version: "1.2.3", source: "../../docs/idea/00-build-spec.md",
                            link_target_globs: ["docs/idea/**/*.md"])

    assert_includes mirror,
                    "(https://github.com/developerz-ai/magik/blob/main/docs/architecture/03-error-codes.md#tokens)"
  end

  def test_a_directory_link_becomes_a_tree_url
    mirror = Mirrors.render("Why: [`idea/`](idea/).\n", version: "1.2.3",
                                                        source: "../../docs/README.md",
                                                        link_target_globs: ["docs/**/*.md"])

    assert_includes mirror, "(https://github.com/developerz-ai/magik/tree/main/docs/idea)"
  end

  def test_absolute_fragment_and_fenced_links_are_left_alone
    source = <<~MD
      [site](https://example.com) and [section](#rules) and [autolink](<https://example.com/a>)
      ```ruby
      markdown = "[looks like a link](not-a-page.md)"
      ```
    MD

    mirror = Mirrors.render(source, version: "1.2.3", source: "../../docs/idea/00-build-spec.md",
                                    link_target_globs: ["docs/**/*.md"])

    assert_includes mirror, "[looks like a link](not-a-page.md)", "fenced links are illustration, not promises"
    assert_includes mirror, "(https://example.com)"
    assert_includes mirror, "(#rules)"
    assert_includes mirror, "(<https://example.com/a>)"
  end

  def test_the_banner_names_the_version_the_source_and_the_regenerating_command
    mirror = Mirrors.render("# The spec\n", version: "1.2.3", source: "../../docs/idea/00-build-spec.md")

    assert_includes mirror, "at Magik 1.2.3"
    assert_includes mirror, "`docs/idea/00-build-spec.md`"
    assert_includes mirror, "ruby apps/magik/scripts/checks/shipped_mirrors.rb --write"
    assert_match(/do not edit/i, mirror)
  end

  def test_render_is_deterministic
    source = "See [`05-limits.md`](05-limits.md).\n\n```bash\nbin/check\n```\n"
    args = { version: "1.2.3", source: "../../docs/idea/05-limits.md", link_target_globs: ["docs/**/*.md"] }

    assert_equal Mirrors.render(source, **args), Mirrors.render(source, **args)
  end

  # The discriminator: a committed mirror that differs from its render is the
  # finding this check exists to raise. If `.compare` stopped comparing, every
  # render test above stays green and only this one goes red.
  def test_a_committed_mirror_that_differs_from_its_render_is_stale
    findings = Mirrors.compare({ "docs/idea/00-build-spec.md" => "rendered\n" },
                               mirrors: { "docs/idea/00-build-spec.md" => "edited by hand\n" })

    assert_equal ["MAGIK_DEV_SHIPPED_MIRRORS_STALE"], findings.map(&:code)
    assert_equal "docs/idea/00-build-spec.md", findings.first.at
    assert_includes findings.first.fix, "shipped_mirrors.rb --write"
  end

  def test_a_source_with_no_mirror_is_missing
    findings = Mirrors.compare({ "docs/idea/00-build-spec.md" => "rendered\n" }, mirrors: {})

    assert_equal ["MAGIK_DEV_SHIPPED_MIRRORS_MISSING"], findings.map(&:code)
  end

  def test_current_mirrors_are_silent
    assert_empty Mirrors.compare({ "docs/idea/x.md" => "same\n" }, mirrors: { "docs/idea/x.md" => "same\n" })
  end

  def test_the_committed_mirrors_are_current
    result = Mirrors.new.run

    assert_equal MagikScripts::Result::PASS, result.status
  end

  def test_every_source_has_a_mirror_and_the_errors_named_path_is_among_them
    assert_includes Mirrors.sources, "../../docs/idea/00-build-spec.md",
                    "the path Magik::Error::DEFAULT_FIX and every stub names must have a mirror"
    Mirrors.sources.each do |source|
      assert_path_exists MagikScripts::Repo.path(Mirrors.mirror_for(source)).to_s
    end
  end
end
