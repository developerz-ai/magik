# frozen_string_literal: true

require "fileutils"
require "tmpdir"

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

  # --- a refresh that cannot complete ----------------------------------------
  #
  # The recovery contract: the failure names the half that failed — reading a
  # checkout original, or writing a packaged mirror — and the exact path, and
  # the recovery inspects that path instead of restoring anything. A blanket
  # `git checkout -- docs` destroys uncommitted edits to the checkout originals
  # and addresses no write failure at all.

  def test_an_unreadable_source_is_wrapped_with_its_operation_and_path
    error = assert_raises(MagikScripts::Checks::RefreshError) do
      Mirrors.read_source("../../docs/idea/no-such-source.md")
    end

    assert_equal :read, error.operation
    assert_equal "../../docs/idea/no-such-source.md", error.path
    assert_instance_of Errno::ENOENT, error.original
    assert_includes error.message, "reading ../../docs/idea/no-such-source.md"
  end

  def test_a_failed_mirror_write_is_wrapped_with_its_operation_and_path
    error = assert_raises(MagikScripts::Checks::RefreshError) do
      Mirrors.write_mirror("Rakefile/inner/mirror.md", "body\n")
    end

    assert_equal :write, error.operation
    assert_equal "Rakefile/inner/mirror.md", error.path
    assert_includes error.message, "writing Rakefile/inner/mirror.md"
  end

  def test_a_read_failure_reports_the_source_and_a_recovery_that_restores_nothing
    result = Mirrors.new.send(:unrefreshable, refresh_error(:read, "../../docs/idea/00-build-spec.md"))

    assert_equal MagikScripts::Result::FAIL, result.status
    assert_equal "MAGIK_DEV_SHIPPED_MIRRORS_UNREFRESHABLE", result.findings.first.code
    assert_equal "../../docs/idea/00-build-spec.md", result.findings.first.at
    assert_includes result.findings.first.cause, "reading ../../docs/idea/00-build-spec.md"
    assert_includes result.fix, "git status --short -- docs/idea/00-build-spec.md"
    refute_includes result.fix, "git checkout",
                    "a blanket restore would destroy uncommitted source edits"
  end

  def test_a_write_failure_reports_the_mirror_and_a_recovery_that_restores_nothing
    result = Mirrors.new.send(:unrefreshable, refresh_error(:write, "docs/idea/00-build-spec.md"))

    assert_equal MagikScripts::Result::FAIL, result.status
    assert_equal "docs/idea/00-build-spec.md", result.findings.first.at
    assert_includes result.findings.first.cause, "writing docs/idea/00-build-spec.md"
    assert_includes result.fix, "ls -l apps/magik/docs/idea/00-build-spec.md"
    assert_includes result.fix, "ruby apps/magik/scripts/checks/shipped_mirrors.rb --write"
    refute_includes result.fix, "git checkout",
                    "a blanket restore would destroy uncommitted source edits"
  end

  def test_a_renderer_bug_is_reported_without_telling_anyone_to_touch_the_tree
    result = Mirrors.new.send(:unrefreshable, StandardError.new("boom"))

    assert_equal MagikScripts::Result::FAIL, result.status
    assert_equal Mirrors::SOURCE_GLOB, result.findings.first.at
    assert_includes result.fix, "ruby apps/magik/scripts/checks/shipped_mirrors.rb"
    refute_includes result.fix, "git checkout"
  end

  def test_run_routes_a_failed_write_to_the_mirror_specific_recovery
    error = refresh_error(:write, "docs/idea/00-build-spec.md")
    original = Mirrors.method(:render_all)
    Mirrors.define_singleton_method(:render_all) { |*_args, **_kwargs| raise error }
    begin
      result = Mirrors.new(write: true).run
    ensure
      Mirrors.define_singleton_method(:render_all, original)
    end

    assert_equal MagikScripts::Result::FAIL, result.status
    assert_equal "shipped_mirrors_unrefreshable", result.reason
    assert_includes result.fix, "ls -l apps/magik/docs/idea/00-build-spec.md"
    refute_includes result.fix, "git checkout"
  end

  # The routing test above stubs `render_all`, so it never reaches the write.
  # This one runs a real refresh against a temp checkout, so the `--write` path
  # is exercised to its last line: a write that is skipped, or dispatched to a
  # method that does not exist on the instance, fails here and not only at the
  # gate.
  def test_write_regenerates_the_mirrors_into_the_app_tree
    MagikScripts::Library.load! # resolve `lib/` through the real root before it is re-rooted
    source_body = "Regenerated: [`sibling.md`](sibling.md).\n"

    Dir.mktmpdir do |tmp|
      checkout = File.join(tmp, "repo")
      app_root = File.join(checkout, "apps/app")
      FileUtils.mkdir_p([app_root, File.join(checkout, "docs/idea")])
      File.write(File.join(checkout, "docs/idea/regenerated.md"), source_body)

      result = with_repo_root(app_root) { Mirrors.new(write: true).run }

      assert_equal MagikScripts::Result::PASS, result.status, result.got
      assert_includes result.got, "wrote 1 mirror"

      mirror = File.join(app_root, "docs/idea/regenerated.md")

      assert_path_exists mirror
      assert_equal Mirrors.render(source_body, version: Magik::VERSION,
                                               source: "../../docs/idea/regenerated.md"),
                   File.read(mirror)
    end
  end

  private

  # Run the block with {MagikScripts::Repo} rooted at `app_root`, restoring the
  # real root afterwards — the same singleton-method swap the routing test
  # applies to `render_all`. The temp layout mirrors the real one — a checkout
  # with the app two levels down, `tmp/repo/apps/app` beside `tmp/repo/docs` —
  # so `sources` globs the checkout two levels above the root, `read_source`
  # reads it there, and `write_mirror` writes the mirror into the app tree.
  def with_repo_root(app_root)
    original_root = MagikScripts::Repo.method(:root)
    MagikScripts::Repo.define_singleton_method(:root) { Pathname.new(app_root) }
    yield
  ensure
    MagikScripts::Repo.define_singleton_method(:root, original_root)
  end

  # A refresh failure as the check's rescue receives it.
  #
  # @param operation [Symbol] `:read` or `:write`
  # @param path [String] the app-root-relative path that failed
  # @return [MagikScripts::Checks::RefreshError]
  def refresh_error(operation, path)
    original = operation == :read ? Errno::ENOENT.new(path) : Errno::EACCES.new(path)
    MagikScripts::Checks::RefreshError.new(operation: operation, path: path, original: original)
  end
end
