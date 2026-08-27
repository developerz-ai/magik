# frozen_string_literal: true

require "pathname"

require_relative "../magik"

module Magik
  # The documentation Magik ships inside its own gem, and the resolver that
  # reads it.
  #
  # Magik invents a DSL — `model`, `screen`, `action`, `ledger`, `channel`,
  # `flow` — that no language model has in its training data. An agent writing
  # Magik code without the reference in front of it reconstructs a Rails-shaped
  # API from memory, every time. Fetching the reference over the network is
  # slow, rate-limited and **version-blind**: it returns whatever is on `main`,
  # not what the installed gem actually does.
  #
  # So the gem carries its own manual. `Magik::Docs` locates it, catalogues it
  # and searches it, using nothing but the standard library — the speed comes
  # from there being a few dozen small markdown files, not from an index.
  #
  # This is not a spec-only subsystem. Every method below does what it says.
  #
  # @example Point an agent's own grep at the shipped tree
  #   Magik::Docs.root # => #<Pathname:/…/gems/magik-0.0.1>
  # @example Read the DSL reference for screens
  #   Magik::Docs.read("wiki/screens-and-components")
  # @see Magik::CLI::DocsCommand the `magik docs` command
  # @see file:docs/architecture/09-shipped-docs.md the design note
  module Docs
    # The globs, relative to the repository or gem root, that define which
    # files are documentation.
    #
    # This constant is the single source of truth for the decision: `magik.gemspec`
    # reads it to build `spec.files`, and {pages} reads it to build the
    # catalogue. Keeping one list means `magik docs list` can never offer a page
    # that `gem build` left out.
    #
    # @return [Array<String>] `Dir.glob` patterns
    # @example
    #   Magik::Docs::PACKAGED_GLOBS # => ["llms.txt", "docs/**/*.md", "wiki/**/*.md"]
    PACKAGED_GLOBS = %w[
      llms.txt
      docs/**/*.md
      wiki/**/*.md
    ].freeze

    # Environment variable that overrides root resolution.
    #
    # Set it when the docs live somewhere the candidate search cannot guess —
    # a vendored copy, or a test fixture.
    #
    # @return [String]
    ROOT_ENV = "MAGIK_DOCS_ROOT"

    # Audience, derived from the tree a page lives in. The three trees already
    # have distinct jobs (see `docs/README.md`), so the audience is a property
    # of the directory and never a hand-maintained per-file list.
    #
    # @return [Hash{String => String}] path prefix => audience key
    AUDIENCE_BY_PREFIX = {
      "wiki/" => "app",
      "docs/ops/" => "app",
      "docs/architecture/" => "framework",
      "docs/idea/" => "both"
    }.freeze

    # Audience for a page that matches no prefix in {AUDIENCE_BY_PREFIX} —
    # the index files, `llms.txt` and `docs/README.md`, which route both readers.
    #
    # @return [String]
    DEFAULT_AUDIENCE = "both"

    # Human labels for each audience key, used by `magik docs list`.
    #
    # @return [Hash{String => String}]
    AUDIENCE_LABELS = {
      "app" => "Building an app with Magik",
      "both" => "Both audiences — the design and the reference",
      "framework" => "Contributing to Magik itself"
    }.freeze

    # The order audiences are printed and grouped in.
    #
    # @return [Array<String>]
    AUDIENCE_ORDER = %w[app both framework].freeze

    # Longest summary {pages} will derive from a page's opening paragraph,
    # in characters, before it is truncated on a word boundary.
    #
    # @return [Integer]
    SUMMARY_LIMIT = 180

    # File extensions {slug_for} strips when turning a shipped path into a slug.
    #
    # @return [Regexp]
    EXTENSION = /\.(?:md|markdown|txt)\z/i

    # A markdown horizontal rule, which is never a page summary.
    #
    # @return [Regexp]
    HORIZONTAL_RULE = /\A(?:-{3,}|\*{3,}|_{3,})\z/

    # Raised when no shipped documentation tree can be found at all.
    class UnavailableError < Magik::Error
      code "MAGIK_DOCS_UNAVAILABLE"
      fix "reinstall the gem with `gem install magik`, or set " \
          "`MAGIK_DOCS_ROOT` to a checkout of https://github.com/developerz-ai/magik"
    end

    # Raised when a slug or path names no shipped page.
    class PageNotFoundError < Magik::Error
      code "MAGIK_DOCS_PAGE_NOT_FOUND"
      fix "run `magik docs list` to see every page that ships with this gem"
    end

    # Raised when a shorthand slug matches more than one shipped page.
    class AmbiguousPageError < Magik::Error
      code "MAGIK_DOCS_AMBIGUOUS_PAGE"
      fix "run `magik docs list` and use the full slug, e.g. `magik docs wiki/models`"
    end

    # Raised when a search is asked for without a term to search for.
    class MissingTermError < Magik::Error
      code "MAGIK_DOCS_MISSING_TERM"
      fix "run `magik docs search <term>`, e.g. `magik docs search ledger`"
    end

    class << self
      # The root of the shipped documentation tree — the directory that has
      # `docs/`, `wiki/` and `llms.txt` inside it.
      #
      # Resolution order: the {ROOT_ENV} override, then {Magik.root} (which is
      # the checkout root when Magik is loaded from source and the gem root when
      # it is installed), then the directory RubyGems recorded for the loaded
      # `magik` gem. The first candidate that actually contains a packaged page
      # wins, so a layout with no docs is skipped rather than returned empty.
      #
      # @return [Pathname] an absolute directory
      # @raise [UnavailableError] if no candidate contains a packaged page
      # @example Hand the directory to a tool that greps
      #   system("grep", "-rn", "ledger", Magik::Docs.root.to_s)
      def root
        @root ||= resolve_root(candidates)
      end

      # Candidate roots, in resolution order, whether or not they contain docs.
      #
      # @return [Array<Pathname>] absolute directories, duplicates removed
      # @example
      #   Magik::Docs.candidates.first # => #<Pathname:/…/magik>
      def candidates
        [ENV.fetch(ROOT_ENV, nil), Magik.root, gem_path]
          .compact
          .map { |dir| Pathname.new(dir.to_s).expand_path }
          .uniq
      end

      # Pick the first candidate that contains at least one packaged page.
      #
      # Exposed so both layouts — a checkout and an installed gem — can be
      # exercised directly by a test without changing the process environment.
      #
      # @param dirs [Array<Pathname, String>] candidate roots, in priority order
      # @return [Pathname] the first candidate holding documentation
      # @raise [UnavailableError] if none of them does
      # @example
      #   Magik::Docs.resolve_root([Pathname.new("/nope"), Magik.root])
      def resolve_root(dirs)
        found = Array(dirs).map { |dir| Pathname.new(dir.to_s) }.find { |dir| packaged?(dir) }
        return found if found

        raise UnavailableError,
              "no shipped documentation found under #{Array(dirs).map(&:to_s).inspect}"
      end

      # Does this directory hold at least one file matched by {PACKAGED_GLOBS}?
      #
      # @param dir [Pathname, String] a candidate root
      # @return [Boolean]
      # @example
      #   Magik::Docs.packaged?(Magik.root) # => true
      def packaged?(dir)
        !relative_paths(dir).empty?
      end

      # Every packaged documentation file under `dir`, as sorted paths relative
      # to it.
      #
      # @param dir [Pathname, String] a root to look under
      # @return [Array<String>] e.g. `["docs/README.md", …, "llms.txt"]`
      # @example
      #   Magik::Docs.relative_paths(Magik.root).include?("wiki/Models.md") # => true
      def relative_paths(dir)
        base = Pathname.new(dir.to_s)
        return [] unless base.directory?

        Dir.glob(PACKAGED_GLOBS, base: base.to_s).select { |path| base.join(path).file? }.sort
      end

      # The catalogue: one entry per shipped page, derived from the files
      # themselves. Nothing here is hand-maintained — add a markdown file under
      # `docs/` or `wiki/` and it appears.
      #
      # @return [Array<Hash{Symbol => String}>] frozen entries with keys
      #   `:slug`, `:title`, `:path`, `:summary` and `:audience`
      # @example
      #   Magik::Docs.pages.first
      #   # => {slug: "docs/readme", title: "Magik — documentation map", …}
      def pages
        @pages ||= relative_paths(root).map { |path| build_page(path) }.sort_by { |page| page[:slug] }.freeze
      end

      # Look a page up by slug, by shipped path, or by an unambiguous shorthand.
      #
      # Accepted for `wiki/Models.md`: `"wiki/models"` (the slug),
      # `"wiki/Models.md"` (the path) and `"models"` (the basename). A numeric
      # prefix is optional, so `docs/idea/02-dsl-surface.md` also answers to
      # `"dsl-surface"`.
      #
      # @param slug_or_path [String, Symbol] any of the forms above
      # @return [Hash{Symbol => String}] the catalogue entry
      # @raise [PageNotFoundError] if nothing matches
      # @raise [AmbiguousPageError] if a shorthand matches several pages
      # @example
      #   Magik::Docs.find("ledgers")[:path] # => "wiki/Money-And-Ledgers.md"
      def find(slug_or_path)
        query = normalize(slug_or_path)
        exact = pages.find { |page| page[:slug] == query }
        return exact if exact

        matched = pages.select { |page| shorthands(page).include?(query) }
        return matched.first if matched.size == 1
        raise AmbiguousPageError, ambiguous_cause(slug_or_path, matched) if matched.size > 1

        raise PageNotFoundError, missing_cause(slug_or_path)
      end

      # The raw markdown of a page. Raw on purpose: the reader is an agent, not
      # a terminal, and rendering only removes information.
      #
      # @param slug_or_path [String, Symbol] anything {find} accepts
      # @return [String] the file's contents, verbatim
      # @raise [PageNotFoundError] if the page is not in the catalogue or the
      #   file behind it has gone missing
      # @example
      #   Magik::Docs.read("error-codes").lines.first # => "# Error codes\n"
      def read(slug_or_path)
        page_body(find(slug_or_path))
      end

      # Substring search across every shipped page, case-insensitively.
      #
      # There is no index and no dependency: a few dozen small files are read in
      # full, which is faster than any network round trip an agent would
      # otherwise make. Pages whose **headings** match sort first, then pages
      # with more hits, then alphabetically — so the answer is deterministic.
      #
      # @param term [String] the substring to look for
      # @return [Array<Hash{Symbol => Object}>] catalogue entries with an extra
      #   `:matches` key: an array of `{line: Integer, text: String,
      #   heading: Boolean}`
      # @raise [MissingTermError] if `term` is blank
      # @example
      #   Magik::Docs.search("UUIDv7").first[:matches].first[:line] # => 42
      def search(term)
        needle = term.to_s.strip
        raise MissingTermError, "`magik docs search` was given no term to search for" if needle.empty?

        needle = needle.downcase
        pages.filter_map { |page| matched_page(page, needle) }
             .sort_by { |result| sort_key(result) }
      end

      # Forget the memoised {root} and {pages}.
      #
      # Needed only when the tree moves underneath a live process — a test
      # pointing {ROOT_ENV} somewhere else, or a vendored copy being swapped.
      #
      # @return [void]
      # @example
      #   ENV["MAGIK_DOCS_ROOT"] = fixture_dir
      #   Magik::Docs.reset!
      def reset!
        @root = nil
        @pages = nil
      end

      # The audience a path serves, from {AUDIENCE_BY_PREFIX}.
      #
      # @param path [String] a path relative to {root}
      # @return [String] `"app"`, `"framework"` or `"both"`
      # @example
      #   Magik::Docs.audience_for("wiki/Models.md") # => "app"
      def audience_for(path)
        AUDIENCE_BY_PREFIX.find { |prefix, _| path.start_with?(prefix) }&.last || DEFAULT_AUDIENCE
      end

      # The stable slug for a shipped path: the path, lowercased, with its
      # documentation extension removed. Unique by construction, and typeable.
      #
      # @param path [String] a path relative to {root}
      # @return [String] e.g. `"wiki/models"`
      # @example
      #   Magik::Docs.slug_for("docs/idea/02-dsl-surface.md") # => "docs/idea/02-dsl-surface"
      def slug_for(path)
        path.sub(EXTENSION, "").downcase
      end

      private

      # @return [String, nil] the installed gem's directory, if RubyGems knows it
      def gem_path
        spec = Gem.loaded_specs["magik"] if defined?(Gem)
        spec&.full_gem_path
      rescue StandardError
        nil
      end

      # @param path [String] a path relative to {root}
      # @return [Hash{Symbol => String}] a frozen catalogue entry
      def build_page(path)
        title, summary = title_and_summary(root.join(path).read)
        {
          slug: slug_for(path),
          title: title || File.basename(path, ".*"),
          path: path,
          summary: summary,
          audience: audience_for(path)
        }.freeze
      end

      # @param page [Hash] a catalogue entry
      # @return [String] the file contents
      # @raise [PageNotFoundError] if the file is gone
      def page_body(page)
        file = root.join(page[:path])
        return file.read if file.file?

        raise PageNotFoundError, "#{page[:path]} is catalogued but missing from #{root}"
      end

      # @param page [Hash] a catalogue entry
      # @param needle [String] a lowercased search term
      # @return [Hash, nil] the entry plus `:matches`, or nil when nothing matched
      def matched_page(page, needle)
        matches = page_body(page).each_line.with_index(1).filter_map do |line, number|
          next unless line.downcase.include?(needle)

          text = line.chomp.strip
          { line: number, text: text, heading: text.start_with?("#") }
        end
        matches.empty? ? nil : page.merge(matches: matches).freeze
      end

      # @param result [Hash] a search result
      # @return [Array] headings first, then hit count, then slug
      def sort_key(result)
        [result[:matches].any? { |match| match[:heading] } ? 0 : 1, -result[:matches].size, result[:slug]]
      end

      # @param value [String, Symbol] user input
      # @return [String] lowercased, extension-free, leading `./` removed
      def normalize(value)
        slug_for(value.to_s.strip.delete_prefix("./"))
      end

      # @param page [Hash] a catalogue entry
      # @return [Array<String>] the shorthands that may stand in for its slug
      def shorthands(page)
        base = page[:slug].split("/").last
        [base, base.sub(/\A\d+-/, "")].uniq
      end

      # @param query [String, Symbol] what the user asked for
      # @return [String] a one-sentence cause naming the nearest slugs
      def missing_cause(query)
        near = pages.map { |page| page[:slug] }.select { |slug| slug.include?(normalize(query)) }.first(3)
        cause = "no shipped documentation page matches #{query.to_s.inspect}"
        near.empty? ? cause : "#{cause} (nearest: #{near.join(", ")})"
      end

      # @param query [String, Symbol] what the user asked for
      # @param matched [Array<Hash>] the entries that matched
      # @return [String] a one-sentence cause naming every candidate
      def ambiguous_cause(query, matched)
        "#{query.to_s.inspect} matches #{matched.size} pages: #{matched.map { |p| p[:slug] }.join(", ")}"
      end

      # Pull the H1 and the opening paragraph out of a markdown page.
      #
      # `**Status:**` paragraphs are skipped — every page in this repo opens
      # with one, and none of them describes what the page is about.
      #
      # @param text [String] the file contents
      # @return [Array(String, String)] title and one-line summary
      def title_and_summary(text)
        lines = text.lines.first(60).map(&:chomp)
        heading = lines.index { |line| line.start_with?("# ") }
        return [nil, ""] unless heading

        [lines[heading].delete_prefix("# ").strip, summary_from(lines.drop(heading + 1))]
      end

      # @param lines [Array<String>] the lines after the H1
      # @return [String] the first paragraph that is not a status banner
      def summary_from(lines)
        fallback = []
        paragraph = []
        lines.each do |line|
          stripped = line.strip.sub(/\A>\s?/, "")
          break if stripped.start_with?("#")
          next paragraph << stripped unless stripped.empty?
          break unless skip?(paragraph)

          fallback = paragraph.dup if fallback.empty?
          paragraph.clear
        end
        truncate(plain_text((skip?(paragraph) ? fallback : paragraph).join(" ")))
      end

      # A paragraph worth skipping: empty, a horizontal rule, or the `**Status:**`
      # banner every page in this repo opens with. None of them says what the
      # page is about — though the status banner is a better summary than
      # nothing, so {summary_from} keeps the first one as a fallback.
      #
      # @param paragraph [Array<String>] the lines collected so far
      # @return [Boolean]
      def skip?(paragraph)
        first = paragraph.first.to_s
        paragraph.empty? || first.start_with?("**Status:**", "Status:") || HORIZONTAL_RULE.match?(first)
      end

      # @param text [String] markdown
      # @return [String] the same text with links, emphasis and quotes removed
      def plain_text(text)
        text.gsub(/\[([^\]]+)\]\([^)]*\)/, '\1')
            .gsub("**", "")
            .delete("`")
            .gsub(/\s+/, " ")
            .strip
      end

      # @param text [String] a one-line summary
      # @return [String] truncated to {SUMMARY_LIMIT} on a word boundary
      def truncate(text)
        return text if text.length <= SUMMARY_LIMIT

        "#{text[0, SUMMARY_LIMIT].rpartition(" ").first}…"
      end
    end
  end
end
