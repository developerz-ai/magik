# frozen_string_literal: true

require "json"

require_relative "../docs"

module Magik
  module CLI
    # `magik docs` — the documentation shipped inside this gem, served locally.
    #
    # This is the command an agent runs **instead of a web search**. It answers
    # from files that came out of the same `.gem` as the code, so the reference
    # always matches the installed version, and it answers in milliseconds
    # because there is no network in the path.
    #
    # Four subcommands, and `--json` on every one of them:
    #
    # | Command | Prints |
    # |---|---|
    # | `magik docs` / `magik docs list` | the catalogue, grouped by audience |
    # | `magik docs <slug>` | one page, as raw markdown |
    # | `magik docs search <term>` | matching pages, with line numbers |
    # | `magik docs path` | {Magik::Docs.root}, for your own grep and glob |
    #
    # `magik docs path` is the important one: it turns the shipped manual into a
    # directory an agent can point its existing file tools at, which beats any
    # output format this command could invent.
    #
    # `list`, `search` and `path` are subcommand names, not slugs: if a shipped
    # page is ever called one of them, the subcommand wins and the page is still
    # reachable by its full slug.
    #
    # @example The whole reference, greppable
    #   $ grep -rn "tenant_id" "$(magik docs path)"
    # @see Magik::Docs
    class DocsCommand
      # Widest line `magik docs` prints before it clips a summary or a match.
      #
      # @return [Integer]
      LINE_WIDTH = 108

      # Closing hints on `magik docs list`, in the order an agent needs them.
      #
      # @return [Array<String>]
      HINTS = [
        "Read a page:   magik docs <slug>",
        "Search:        magik docs search <term>",
        "Grep it all:   grep -rn \"<term>\" \"$(magik docs path)\"",
        "As data:       magik docs list --json"
      ].freeze

      # @param out [IO] stream for command output
      # @param json [Boolean] emit JSON instead of prose
      # @example
      #   Magik::CLI::DocsCommand.new(out: $stdout).call([])
      def initialize(out:, json: false)
        @out = out
        @json = json
      end

      # Run a `magik docs` subcommand.
      #
      # @param args [Array<String>] the arguments after `docs`
      # @return [void]
      # @raise [Magik::Docs::PageNotFoundError] if a slug names no shipped page
      # @raise [Magik::Docs::AmbiguousPageError] if a shorthand slug is ambiguous
      # @raise [Magik::Docs::MissingTermError] if `search` is given no term
      # @raise [Magik::Docs::UnavailableError] if the gem shipped without its docs
      # @example
      #   Magik::CLI::DocsCommand.new(out: $stdout).call(["search", "ledger"])
      def call(args)
        rest = Array(args)
        case rest.first
        when nil, "list" then list
        when "path" then print_path
        when "search" then search(rest.drop(1).join(" "))
        else page(rest.first)
        end
      end

      private

      # The catalogue, grouped by audience.
      # @return [void]
      def list
        return @out.puts(JSON.generate(list_payload)) if @json

        @out.puts "magik #{Magik::VERSION} ships #{Docs.pages.size} documentation pages."
        @out.puts "Root: #{Docs.root}"
        Docs::AUDIENCE_ORDER.each { |audience| print_group(audience) }
        @out.puts
        HINTS.each { |hint| @out.puts hint }
      end

      # @param audience [String] an audience key
      # @return [void]
      def print_group(audience)
        group = Docs.pages.select { |page| page[:audience] == audience }
        return if group.empty?

        width = group.map { |page| page[:slug].length }.max
        @out.puts
        @out.puts "#{Docs::AUDIENCE_LABELS.fetch(audience, audience)} [#{audience}]"
        group.each do |page|
          blurb = page[:summary].empty? ? page[:title] : page[:summary]
          @out.puts format("  %-#{width}s  %s", page[:slug], clip(blurb, LINE_WIDTH - width))
        end
      end

      # One page, raw. Raw because the reader is an agent, not a pager.
      #
      # @param slug [String] a slug, a shipped path or an unambiguous shorthand
      # @return [void]
      def page(slug)
        entry = Docs.find(slug)
        body = Docs.read(slug)
        return @out.puts(JSON.generate(page_payload(entry, body))) if @json

        @out.print body
        @out.puts unless body.end_with?("\n")
      end

      # @param term [String] the substring to look for
      # @return [void]
      def search(term)
        results = Docs.search(term)
        return @out.puts(JSON.generate(search_payload(term, results))) if @json
        return print_no_matches(term) if results.empty?

        @out.puts "#{results.size} of #{Docs.pages.size} shipped pages contain #{term.inspect}:"
        results.each { |result| print_result(result) }
      end

      # @param result [Hash] one entry from {Magik::Docs.search}
      # @return [void]
      def print_result(result)
        @out.puts
        @out.puts "#{result[:slug]}  (#{result[:path]})"
        result[:matches].each do |match|
          @out.puts format("  %<line>6d  %<text>s", line: match[:line], text: clip(match[:text], LINE_WIDTH - 10))
        end
      end

      # @param term [String] the term that matched nothing
      # @return [void]
      def print_no_matches(term)
        @out.puts "No shipped page contains #{term.inspect}."
        @out.puts "Try `magik docs list`, or grep the tree: grep -rni #{term.inspect} \"$(magik docs path)\""
      end

      # The directory, and nothing else, so `$(magik docs path)` is usable.
      # @return [void]
      def print_path
        return @out.puts(JSON.generate(command: "docs.path", root: Docs.root.to_s, pages: Docs.pages.size)) if @json

        @out.puts Docs.root.to_s
      end

      # @return [Hash] the `docs.list` JSON payload
      def list_payload
        { command: "docs.list", version: Magik::VERSION, root: Docs.root.to_s,
          audiences: Docs::AUDIENCE_LABELS, count: Docs.pages.size, pages: Docs.pages }
      end

      # @param entry [Hash] a catalogue entry
      # @param body [String] the page's raw markdown
      # @return [Hash] the `docs.page` JSON payload
      def page_payload(entry, body)
        { command: "docs.page", version: Magik::VERSION, root: Docs.root.to_s,
          page: entry, content: body }
      end

      # @param term [String] the search term
      # @param results [Array<Hash>] the matches
      # @return [Hash] the `docs.search` JSON payload
      def search_payload(term, results)
        { command: "docs.search", version: Magik::VERSION, root: Docs.root.to_s,
          term: term, count: results.size, results: results }
      end

      # @param text [String] the text to fit
      # @param width [Integer] the space available
      # @return [String] `text`, clipped on a character boundary with an ellipsis
      def clip(text, width)
        limit = [width, 20].max
        text.length <= limit ? text : "#{text[0, limit - 1]}…"
      end
    end
  end
end
