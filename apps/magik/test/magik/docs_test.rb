# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "test_helper"

# The shipped-documentation resolver. Real behaviour, so real tests: root
# resolution under both layouts a gem can be loaded from, catalogue derivation,
# lookup, search, and the packaging checks that keep the checkout/gem docs
# split honest — repo-root docs/ served from a checkout, wiki/ + llms.txt +
# the generated build-spec mirror packaged in the gem.
class MagikDocsTest < Minitest::Test
  def teardown
    ENV.delete(Magik::Docs::ROOT_ENV)
    Magik::Docs.reset!
  end

  # --- root resolution -------------------------------------------------------

  def test_root_resolves_from_a_checkout
    assert_equal Magik.root, Magik::Docs.root
    assert_path_exists Magik::Docs.root.join("wiki").to_s
    assert_path_exists Magik::Docs.root.join("llms.txt").to_s
    # docs/ stays at the repository root, one `../../` step above the gem dir:
    assert_path_exists Magik::Docs.root.join("../../docs/idea").to_s
  end

  def test_root_resolves_from_an_installed_gem_layout
    with_installed_layout do |gem_root|
      assert_equal Pathname.new(gem_root), Magik::Docs.resolve_root([gem_root])
    end
  end

  def test_resolve_root_skips_a_candidate_with_no_documentation
    with_installed_layout do |gem_root|
      Dir.mktmpdir do |empty|
        assert_equal Pathname.new(gem_root), Magik::Docs.resolve_root([empty, gem_root])
      end
    end
  end

  def test_resolve_root_raises_a_magik_error_when_no_candidate_has_documentation
    Dir.mktmpdir do |empty|
      error = assert_raises(Magik::Docs::UnavailableError) { Magik::Docs.resolve_root([empty]) }

      assert_equal "MAGIK_DOCS_UNAVAILABLE", error.code
      assert_includes error.message, "fix:"
    end
  end

  def test_root_honours_the_environment_override_and_catalogues_that_tree
    with_installed_layout do |gem_root|
      ENV[Magik::Docs::ROOT_ENV] = gem_root
      Magik::Docs.reset!

      slugs = Magik::Docs.pages.map { |page| page[:slug] }

      assert_equal Pathname.new(gem_root), Magik::Docs.root
      assert_equal %w[docs/idea/02-dsl-surface llms wiki/models], slugs
      assert_equal "Models", Magik::Docs.find("models")[:title]
    end
  end

  def test_candidates_start_with_the_environment_override
    ENV[Magik::Docs::ROOT_ENV] = "/nowhere/in/particular"

    assert_equal Pathname.new("/nowhere/in/particular"), Magik::Docs.candidates.first
    assert_includes Magik::Docs.candidates, Magik.root
  end

  # --- the catalogue ---------------------------------------------------------

  def test_pages_are_derived_from_the_files_on_disk
    assert_equal Magik::Docs.relative_paths(Magik.root).sort, Magik::Docs.pages.map { |page| page[:path] }.sort
    refute_empty Magik::Docs.pages
    assert_predicate Magik::Docs.pages, :frozen?
  end

  def test_every_page_carries_a_slug_title_path_summary_and_audience
    Magik::Docs.pages.each do |page|
      assert_equal %i[slug title path summary audience], page.keys
      assert_match(/\S/, page[:slug])
      assert_match(/\S/, page[:title])
      assert_path_exists Magik::Docs.root.join(page[:path]).to_s
      assert_includes Magik::Docs::AUDIENCE_ORDER, page[:audience]
    end
  end

  def test_page_slugs_are_unique_and_lowercase
    slugs = Magik::Docs.pages.map { |page| page[:slug] }

    assert_equal slugs.uniq, slugs
    assert_equal slugs.map(&:downcase), slugs
  end

  def test_summaries_skip_the_status_banner_when_the_page_has_real_prose
    summary = Magik::Docs.find("wiki/models")[:summary]

    refute_includes summary, "Status:"
    assert_includes summary, "model"
  end

  def test_audience_is_derived_from_the_tree_a_page_lives_in
    assert_equal "app", Magik::Docs.audience_for("wiki/Models.md")
    assert_equal "app", Magik::Docs.audience_for("docs/ops/README.md")
    assert_equal "both", Magik::Docs.audience_for("docs/idea/02-dsl-surface.md")
    assert_equal "framework", Magik::Docs.audience_for("docs/architecture/03-error-codes.md")
    assert_equal Magik::Docs::DEFAULT_AUDIENCE, Magik::Docs.audience_for("llms.txt")
    # The repo-root trees, catalogued from a checkout under their ../../ spelling:
    assert_equal "app", Magik::Docs.audience_for("../../docs/ops/README.md")
    assert_equal "both", Magik::Docs.audience_for("../../docs/idea/02-dsl-surface.md")
    assert_equal "framework", Magik::Docs.audience_for("../../docs/architecture/03-error-codes.md")
  end

  def test_slug_strips_only_documentation_extensions
    assert_equal "wiki/models", Magik::Docs.slug_for("wiki/Models.md")
    assert_equal "llms", Magik::Docs.slug_for("llms.txt")
    assert_equal "docs/idea/02-dsl-surface", Magik::Docs.slug_for("docs/idea/02-dsl-surface.md")
    assert_equal "../../docs/idea/02-dsl-surface", Magik::Docs.slug_for("../../docs/idea/02-dsl-surface.md")
  end

  # --- find ------------------------------------------------------------------

  def test_find_accepts_a_slug_a_shipped_path_and_a_basename
    expected = "wiki/Models.md"

    assert_equal expected, Magik::Docs.find("wiki/models")[:path]
    assert_equal expected, Magik::Docs.find("wiki/Models.md")[:path]
    assert_equal expected, Magik::Docs.find("models")[:path]
    assert_equal expected, Magik::Docs.find(:models)[:path]
  end

  def test_find_accepts_a_numbered_page_without_its_number
    expected = "../../docs/idea/02-dsl-surface.md"

    assert_equal expected, Magik::Docs.find("dsl-surface")[:path]
    assert_equal expected, Magik::Docs.find("02-dsl-surface")[:path]
  end

  def test_find_raises_a_magik_error_with_a_runnable_fix_for_an_unknown_page
    error = assert_raises(Magik::Docs::PageNotFoundError) { Magik::Docs.find("no-such-page") }

    assert_equal "MAGIK_DOCS_PAGE_NOT_FOUND", error.code
    assert_includes error.fix, "magik docs list"
  end

  def test_find_refuses_an_ambiguous_shorthand_instead_of_guessing
    error = assert_raises(Magik::Docs::AmbiguousPageError) { Magik::Docs.find("readme") }

    assert_equal "MAGIK_DOCS_AMBIGUOUS_PAGE", error.code
    assert_includes error.cause_text, "docs/readme"
    assert_includes error.cause_text, "docs/ops/readme"
  end

  def test_read_returns_the_raw_markdown
    body = Magik::Docs.read("wiki/models")

    assert_equal Magik.root.join("wiki", "Models.md").read, body
    assert body.start_with?("# Models"), "expected the page verbatim, heading and all"
  end

  # --- search ----------------------------------------------------------------

  def test_search_finds_the_term_and_reports_line_numbers
    results = Magik::Docs.search("UUIDv7")

    refute_empty results
    results.each do |result|
      lines = Magik::Docs.read(result[:slug]).lines

      result[:matches].each do |match|
        assert_includes lines[match[:line] - 1].downcase, "uuidv7"
      end
    end
  end

  def test_search_is_case_insensitive_and_stable
    assert_equal Magik::Docs.search("uuidv7"), Magik::Docs.search("UUIDV7")
  end

  def test_search_sorts_heading_matches_first
    results = Magik::Docs.search("Guardrails")
    first = results.first

    assert first[:matches].any? { |match| match[:heading] }, "a page with a matching heading should sort first"
  end

  def test_search_returns_no_results_rather_than_failing_on_a_miss
    assert_empty Magik::Docs.search("zzz-not-in-any-shipped-page-zzz")
  end

  def test_search_without_a_term_raises_a_magik_error
    error = assert_raises(Magik::Docs::MissingTermError) { Magik::Docs.search("   ") }

    assert_equal "MAGIK_DOCS_MISSING_TERM", error.code
    assert_includes error.fix, "magik docs search"
  end

  # --- packaging -------------------------------------------------------------

  # The check that stops a catalogued page silently falling out of the gem:
  # every page the catalogue offers from inside the gem dir must be in
  # spec.files, or an installed gem would advertise a file it does not have.
  # Pages carrying the ../../ spelling are checkout-only — they live at the
  # repository root and are served by a checkout catalogue, never packaged.
  def test_every_catalogued_page_inside_the_gem_dir_is_packaged_by_the_gemspec
    packaged = gemspec_files

    Magik::Docs.pages.each do |page|
      next if page[:path].start_with?("../")

      assert_includes packaged, page[:path], "#{page[:path]} is in the catalogue but not in spec.files"
    end
  end

  # The gemspec is scoped to apps/magik: no packaged file may resolve outside
  # it, whatever glob a future editor aims at the repository root.
  def test_no_packaged_file_resolves_outside_the_gem_dir
    escapes = gemspec_files.select { |path| path.include?("../") }

    assert_empty escapes, "spec.files must stay inside the gem dir, got #{escapes.inspect}"
  end

  # The packaging split: the gem ships the app-author manual — wiki/ +
  # llms.txt — plus the generated build-spec mirror named by
  # `Magik::Error::DEFAULT_FIX` and every stub's error message, and nothing
  # from the rest of the repo-root docs/ trees or the repository's process
  # files (README, LICENSE, CHANGELOG stay at the checkout root).
  def test_packaged_documentation_is_wiki_llms_txt_and_the_build_spec
    packaged = gemspec_files
    catalogued_inside = Magik::Docs.pages.map { |page| page[:path] }.reject { |path| path.start_with?("../") }

    packaged_docs = packaged.select { |path| path.start_with?("docs/", "wiki/") || path == "llms.txt" }

    assert_equal catalogued_inside.sort, packaged_docs.sort
    assert_includes packaged, "llms.txt"
    assert_includes packaged, "wiki/Models.md"
    assert_includes packaged, "docs/idea/00-build-spec.md",
                    "the path Magik::Error::DEFAULT_FIX and every stub names must resolve in an installed gem"
    assert_includes catalogued_inside, "docs/idea/00-build-spec.md"
    refute_includes packaged, "README.md"
    refute_includes packaged, "LICENSE"
    refute_includes packaged, "CHANGELOG.md"
  end

  # The mirror is catalogued under the gem-relative spelling the error fix
  # lines name, so `magik docs docs/idea/00-build-spec` resolves in both
  # layouts. In a checkout the repository original is ALSO catalogued under
  # its ../../ spelling; the shorthand deliberately refuses to guess between
  # the two (Magik::Docs::AmbiguousPageError).
  def test_the_build_spec_mirror_is_catalogued_at_the_path_the_errors_name
    page = Magik::Docs.pages.find { |entry| entry[:path] == "docs/idea/00-build-spec.md" }

    refute_nil page, "docs/idea/00-build-spec.md must be in the catalogue at its gem-relative path"
    assert_equal "both", page[:audience]
    assert_path_exists Magik::Docs.root.join("docs/idea/00-build-spec.md").to_s
  end

  private

  # @return [Array<String>] spec.files, loaded from the real gemspec
  def gemspec_files
    @gemspec_files ||= Gem::Specification.load(Magik.root.join("magik.gemspec").to_s).files
  end

  # Build a throwaway tree shaped like an installed gem — `lib/` beside `docs/`,
  # `wiki/` and `llms.txt`, and nothing else — and yield its absolute path.
  #
  # @yieldparam root [String] the fake gem root
  # @return [void]
  def with_installed_layout
    Dir.mktmpdir("magik-docs") do |dir|
      write(dir, "lib/magik.rb", "# frozen_string_literal: true\n")
      write(dir, "llms.txt", "# Magik\n\nA link map.\n")
      write(dir, "wiki/Models.md", "# Models\n\n**Status:** planned.\n\nA model declares a table.\n")
      write(dir, "docs/idea/02-dsl-surface.md", "# DSL surface\n\nEvery construct in the grammar.\n")
      yield dir
    end
  end

  # @param dir [String] the tree root
  # @param path [String] a path relative to it
  # @param body [String] file contents
  # @return [void]
  def write(dir, path, body)
    full = File.join(dir, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, body)
  end
end
