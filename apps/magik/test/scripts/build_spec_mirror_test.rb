# frozen_string_literal: true

require_relative "helper"

require_relative "../../scripts/checks/build_spec_mirror"

# The generated mirror of the build spec. The pure rule — {MagikScripts::Checks::BuildSpecMirror.render}
# — is exercised with fixtures; the collector (`#run`) is exercised against the
# real tree, so a stale committed mirror fails here and not only at the gate.
class MagikScriptsBuildSpecMirrorTest < Minitest::Test
  Mirror = MagikScripts::Checks::BuildSpecMirror

  SPEC = "docs/idea"

  def test_relative_links_become_absolute_repository_urls
    mirror = Mirror.render("See [`04-swap-points.md`](04-swap-points.md).\n", version: "1.2.3")

    assert_includes mirror,
                    "(https://raw.githubusercontent.com/developerz-ai/magik/main/docs/idea/04-swap-points.md)"
  end

  def test_a_link_with_a_fragment_becomes_a_blob_url_so_the_anchor_lands
    mirror = Mirror.render("Drafted Ruby: [`02-dsl-surface.md`](02-dsl-surface.md#policy).\n", version: "1.2.3")

    assert_includes mirror,
                    "(https://github.com/developerz-ai/magik/blob/main/docs/idea/02-dsl-surface.md#policy)"
  end

  def test_links_are_resolved_from_the_originals_location_not_the_mirrors
    mirror = Mirror.render("Provenance: [`../../apps/magik/ROADMAP.md`](../../apps/magik/ROADMAP.md).\n",
                           version: "1.2.3")

    assert_includes mirror, "(https://raw.githubusercontent.com/developerz-ai/magik/main/apps/magik/ROADMAP.md)"
  end

  def test_a_directory_link_becomes_a_tree_url
    mirror = Mirror.render("Why: [`../idea/`](../idea/).\n", version: "1.2.3")

    assert_includes mirror, "(https://github.com/developerz-ai/magik/tree/main/docs/idea)"
  end

  def test_absolute_fragment_and_fenced_links_are_left_alone
    source = <<~MD
      [site](https://example.com) and [section](#rules) and [autolink](<https://example.com/a>)
      ```ruby
      markdown = "[looks like a link](not-a-page.md)"
      ```
    MD

    mirror = Mirror.render(source, version: "1.2.3")

    assert_includes mirror, "[looks like a link](not-a-page.md)", "fenced links are illustration, not promises"
    assert_includes mirror, "(https://example.com)"
    assert_includes mirror, "(#rules)"
    assert_includes mirror, "(<https://example.com/a>)"
  end

  def test_the_banner_names_the_version_and_the_regenerating_command
    mirror = Mirror.render("# The spec\n", version: "1.2.3")

    assert_includes mirror, "at Magik 1.2.3"
    assert_includes mirror, "ruby apps/magik/scripts/checks/build_spec_mirror.rb --write"
    assert_match(/do not edit/i, mirror)
  end

  def test_render_is_deterministic
    source = "See [`05-limits.md`](05-limits.md).\n\n```bash\nbin/check\n```\n"

    assert_equal Mirror.render(source, version: "1.2.3"), Mirror.render(source, version: "1.2.3")
  end

  def test_the_committed_mirror_is_current
    result = Mirror.new.run

    assert_equal MagikScripts::Result::PASS, result.status
  end

  def test_the_mirror_exists_at_the_path_the_errors_name
    assert_path_exists MagikScripts::Repo.path(Mirror::MIRROR).to_s
    assert_equal "docs/idea/00-build-spec.md", Mirror::MIRROR
  end
end
