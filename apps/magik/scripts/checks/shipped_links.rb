#!/usr/bin/env ruby
# frozen_string_literal: true

# @check   shipped-links
# @summary Every link a packaged page carries resolves inside the gem.
# @order   45
#
# `wiki/`, `llms.txt` and the generated build-spec mirror ship inside the gem.
# A relative link inside them is resolved by the reader's filesystem — and in
# an installed gem there is no repository above the gem root, so a link that
# climbs out with `../`, or one that lands on a file the gemspec does not
# package, dangles. The checkout-level link scan (`bin/check --only docs`)
# cannot see this: from a checkout every such link resolves, because the
# repository is right there. This check reads the links the way an installed
# gem's reader would, against the same glob list `magik.gemspec` packages
# (`Magik::Docs::PACKAGED_GLOBS`, minus the checkout-only `../` spellings).
#
# A link passes when it is absolute (`http://`, `https://`, `mailto:`, `<…>`),
# a pure `#fragment`, a template placeholder, or a relative path that stays
# inside the gem root AND names a packaged file. Links to repository-only pages
# are absolute repository URLs — the same mechanism llms.txt uses — and this
# check deliberately does not verify those: it is a filesystem test, not a web
# crawler.
#
#   MAGIK_DEV_SHIPPED_LINK_ESCAPES     the link climbs out of the gem root
#   MAGIK_DEV_SHIPPED_LINK_UNPACKAGED  the link stays inside but names an unpackaged file

require_relative "../lib/scripts"
require_relative "../lib/library"

module MagikScripts
  module Checks
    # Shipped pages' links versus what an installed gem actually contains.
    class ShippedLinks < Check
      # Target prefixes this check never judges: absolute URLs, pure fragments,
      # and autolinks written with angle brackets.
      # @return [Array<String>]
      SKIPPED_PREFIXES = %w[http:// https:// mailto: # <].freeze

      # Every packaged page, as app-root-relative paths, derived from the one
      # glob list the gemspec also packages by.
      # @return [Array<String>]
      def self.packaged_pages
        globs = Library.load!::Docs::PACKAGED_GLOBS.reject { |glob| glob.start_with?("../") }

        globs.flat_map { |glob| Repo.glob(glob) }.uniq.sort
      end

      # Every finding implied by a set of links. Pure.
      #
      # @param links [Array<MagikScripts::Markdown::Link>]
      # @param page [String] the page's app-root-relative path
      # @param packaged [Array<String>] app-root-relative paths an installed gem contains
      # @return [Array<MagikScripts::Finding>]
      def self.audit(links, page:, packaged:)
        base = File.dirname(page)

        links.filter_map { |link| verdict(link, page: page, base: base, packaged: packaged) }
      end

      # Resolve a link target the way a POSIX filesystem would, but against the
      # app root as the root — pure string arithmetic, no cwd, and no clamping
      # at `/`: a link that climbs past the gem root comes back wearing the
      # `../` prefix, instead of silently landing back inside it (which is
      # exactly what `File.expand_path` against an absolute base would do).
      #
      # @param path [String] a relative link target, fragment stripped
      # @param base [String] the app-root-relative directory it resolves against
      # @return [String] app-root-relative, or `../`-prefixed when it escapes
      def self.resolve(path, base)
        parts = base.split("/").reject { |segment| segment.empty? || segment == "." }
        ups = 0
        path.split("/").each do |segment|
          case segment
          when "", "." then next
          when ".." then parts.empty? ? ups += 1 : parts.pop
          else parts << segment
          end
        end

        prefix = ups.positive? ? ("../" * ups) : ""
        "#{prefix}#{parts.join("/")}"
      end

      # @param link [MagikScripts::Markdown::Link]
      # @param page [String]
      # @param base [String] the app-root-relative directory the link resolves against
      # @param packaged [Array<String>]
      # @return [MagikScripts::Finding, nil]
      def self.verdict(link, page:, base:, packaged:)
        target = link.target
        return nil if SKIPPED_PREFIXES.any? { |prefix| target.start_with?(prefix) }
        return nil if target.include?("{") || target.include?("$")

        path = target.split("#").first.to_s
        return nil if path.empty? || path.start_with?("/")

        resolved = resolve(path, base)
        if resolved.start_with?("../")
          escapes(link, page: page, resolved: resolved)
        elsif !packaged.include?(resolved)
          unpackaged(link, page: page, resolved: resolved)
        end
      end

      # @param link [MagikScripts::Markdown::Link]
      # @param page [String]
      # @param resolved [String] where the target lands, app-root-relative
      # @return [MagikScripts::Finding]
      def self.escapes(link, page:, resolved:)
        Finding.new(
          code: "MAGIK_DEV_SHIPPED_LINK_ESCAPES", at: "#{page}:#{link.line}",
          cause: "#{page}:#{link.line} links to #{link.target.inspect}, which resolves to #{resolved.inspect} " \
                 "— outside the gem root, so it dangles in an installed gem, where the repository does " \
                 "not exist",
          fix: "point the link at a packaged page, or rewrite it as an absolute repository URL " \
               "(https://raw.githubusercontent.com/developerz-ai/magik/main/...)"
        )
      end

      # @param link [MagikScripts::Markdown::Link]
      # @param page [String]
      # @param resolved [String] where the target lands, app-root-relative
      # @return [MagikScripts::Finding]
      def self.unpackaged(link, page:, resolved:)
        Finding.new(
          code: "MAGIK_DEV_SHIPPED_LINK_UNPACKAGED", at: "#{page}:#{link.line}",
          cause: "#{page}:#{link.line} links to #{link.target.inspect}, which stays inside the gem root but " \
                 "names #{resolved.inspect} — a file `magik.gemspec` does not package",
          fix: "add #{resolved.inspect} to the packaged globs, or rewrite the link as an absolute " \
               "repository URL (https://raw.githubusercontent.com/developerz-ai/magik/main/...)"
        )
      end

      # @return [MagikScripts::Result]
      def run
        packaged = self.class.packaged_pages
        pages = collect
        total = pages.sum { |entry| entry[:links].size }
        return nothing_scanned(corpus: corpus, expected: expectation, fix: fix_line) if total.zero?

        findings = pages.flat_map do |entry|
          self.class.audit(entry[:links], page: entry[:page], packaged: packaged)
        end
        return summary(packaged, pages, total, findings) if findings.empty?

        failure(reason: "dangling_shipped_link", expected: expectation, fix: fix_line, findings: findings,
                got: "#{findings.size} of #{total} links across #{pages.size} packaged pages do not " \
                     "resolve inside the gem")
      end

      private

      # @return [Array<Hash{Symbol => Object}>] one `{page:, links:}` per page that has links
      def collect
        self.class.packaged_pages.filter_map do |page|
          links = Markdown.new(Repo.read(page), path: page).links
          next if links.empty?

          { page: page, links: links }
        end
      end

      # @return [String]
      def corpus
        Library.load!::Docs::PACKAGED_GLOBS.reject { |glob| glob.start_with?("../") }.join(" ")
      end

      # @param packaged [Array<String>]
      # @param pages [Array<Hash{Symbol => Object}>]
      # @param total [Integer]
      # @param findings [Array<MagikScripts::Finding>]
      # @return [MagikScripts::Result]
      def summary(packaged, pages, total, findings)
        ok(expected: expectation,
           got: "#{total} links across #{pages.size} of #{packaged.size} packaged pages, " \
                "#{findings.size} that do not resolve inside the gem")
      end

      # @return [String]
      def expectation
        "every relative link in a packaged page (Magik::Docs::PACKAGED_GLOBS, minus the checkout-only " \
          "../ spellings) resolves to another packaged file inside the gem root"
      end

      # @return [String]
      def fix_line
        "ruby apps/magik/scripts/checks/shipped_links.rb   # each finding names the page and line to correct"
      end
    end
  end
end

# __FILE__ is relative to the launch directory; the registry resolves absolute paths from any cwd.
if $PROGRAM_NAME == __FILE__
  exit MagikScripts::Runner.main(File.expand_path(__FILE__), MagikScripts::Checks::ShippedLinks)
end
