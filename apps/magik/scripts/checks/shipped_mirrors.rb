#!/usr/bin/env ruby
# frozen_string_literal: true

# @check   shipped-mirrors
# @summary Every packaged docs/ page is a fresh render of its checkout original.
# @order   75
#
# The shipped manual links design pages: wiki pages point at
# `docs/idea/04-swap-points.md`, the build spec at `docs/idea/02-dsl-surface.md`,
# `llms.txt` maps all of them. In a checkout those links can resolve against the
# repository two levels up. In an INSTALLED gem there is no repository — the link
# a reader follows instead is whatever was rendered into the page: a mutable
# `main` URL showing whatever `main` carries today, not what the installed gem
# does. That is the version-blindness failure
# docs/architecture/09-shipped-docs.md exists to prevent, and it is silent.
#
# So the gem packages a GENERATED mirror of every checkout-root docs/ page at
# the same path relative to the gem root — `docs/idea/00-build-spec.md` (the
# path `Magik::Error::DEFAULT_FIX` and every spec-only stub's error message
# name), all of `docs/architecture/`, `docs/idea/`, `docs/ops/` — and shipped
# pages link those copies, so an installed gem's reader is never sent to `main`
# for a page the gem carries.
#
# The mirrors are GENERATED, and this check is their only writer:
#
#     ruby apps/magik/scripts/checks/shipped_mirrors.rb            are they current?
#     ruby apps/magik/scripts/checks/shipped_mirrors.rb --write    make them current
#
#   MAGIK_DEV_SHIPPED_MIRRORS_STALE          a committed copy differs from a fresh render
#   MAGIK_DEV_SHIPPED_MIRRORS_MISSING        a source page has no mirror
#   MAGIK_DEV_SHIPPED_MIRRORS_UNREFRESHABLE  reading a source or writing a mirror raised
#
# The render: the original carried verbatim, fenced blocks untouched, line count
# included. A prose link whose target resolves to a page the gem packages
# (`llms.txt`, `wiki/**/*.md`, `docs/**/*.md` — the same list shipped_links.rb
# judges relative links against) is rewritten to that packaged copy's path
# relative to the mirror's own directory, so it resolves inside the installed
# gem and is version-matched by construction. Every other target — repository
# process pages, `dummy/`, `.claude/`, directories — becomes an absolute
# repository URL: raw for files, blob when the link carries a #fragment (the
# only shape where the anchor lands), tree for directories. Those are the
# targets no packaged equivalent exists for, and shipped_links.rb holds the
# line that no link to a PACKAGED page may take that route. A provenance banner
# naming the source, the version and the regenerating command is appended.

require "fileutils"

require_relative "../lib/scripts"
require_relative "../lib/library"

module MagikScripts
  module Checks
    # The packaged mirrors of the checkout's docs/ trees versus the originals
    # they are rendered from.
    class ShippedMirrors < Check
      # The checkout-root pages the gem mirrors, as an app-root-relative glob:
      # the repository's docs/ trees, two levels up.
      # @return [String]
      SOURCE_GLOB = "../../docs/**/*.md"

      # The app-root-relative prefix that spells a checkout-root path.
      # @return [String]
      CHECKOUT_PREFIX = "../../"

      # The repository the rewritten non-packaged links point at.
      # @return [String]
      REPO = "developerz-ai/magik"

      # The three repository URL shapes a rewritten link can take: raw bytes
      # for files, blob when the link carries a #fragment (the anchor lands
      # only on a rendered page), tree for directories.
      # @return [Hash{Symbol => String}]
      URL_BASES = {
        raw: "https://raw.githubusercontent.com/#{REPO}/main/",
        blob: "https://github.com/#{REPO}/blob/main/",
        tree: "https://github.com/#{REPO}/tree/main/"
      }.freeze

      # The app-root-relative globs a rewritten link may point INTO: exactly the
      # documentation a packaged page may link gem-relatively — the same list
      # `shipped_links.rb` holds relative links to, minus the checkout-only
      # `../` spellings. A target matching one of these exists in the gem, so
      # the mirror links the gem's copy; anything else gets a repository URL.
      # @return [Array<String>]
      LINK_TARGET_GLOBS = ["llms.txt", "wiki/**/*.md", "docs/**/*.md"].freeze

      # The same link shape `MagikScripts::Markdown::LINK` matches, plus the
      # optional quoted title as its own group, because a rewrite has to carry
      # the title through.
      # @return [Regexp]
      LINK = /\[([^\]\n]*)\]\(([^)\s]+)((?:\s+"[^"]*")?)\)/

      # `--write` regenerates the mirrors instead of comparing.
      # @return [Hash{String => Symbol}]
      def self.flags
        { "--write" => :write }
      end

      # Every checkout-root docs page, as app-root-relative (`../../docs/…`)
      # paths, sorted.
      #
      # @return [Array<String>]
      def self.sources
        checkout_docs = Repo.root.join("..", "..")
        return [] unless checkout_docs.directory?

        Dir.glob("docs/**/*.md", base: checkout_docs.to_s).sort.map { |rel| "#{CHECKOUT_PREFIX}#{rel}" }
      end

      # Where a source's mirror lands, app-root-relative — the path the error
      # fix lines and the shipped links point at.
      #
      # @param source [String] an app-root-relative source path
      # @return [String]
      def self.mirror_for(source)
        source.delete_prefix(CHECKOUT_PREFIX)
      end

      # The source's repo-root-relative directory — the directory its relative
      # links resolve against.
      #
      # @param source [String] an app-root-relative source path
      # @return [String]
      def self.source_dir(source)
        File.dirname(mirror_for(source))
      end

      # The mirror as it should be on disk right now. Pure.
      #
      # @param source_body [String] the original page
      # @param version [String] `Magik::VERSION`, named in the banner
      # @param source [String] the original's app-root-relative path
      # @param link_target_globs [Array<String>] the globs a rewritten link may point into
      # @return [String]
      def self.render(source_body, version:, source:, link_target_globs: LINK_TARGET_GLOBS)
        rewritten = rewrite(source_body, source: source, link_target_globs: link_target_globs)
        rewritten = "#{rewritten}\n" unless rewritten.end_with?("\n")

        "#{rewritten}\n#{banner(version: version, source: source)}"
      end

      # The source with every prose link target repointed. Fenced blocks keep
      # their lines untouched, line count included.
      #
      # @param source_body [String] the original page
      # @param source [String] the original's app-root-relative path
      # @param link_target_globs [Array<String>]
      # @return [String]
      def self.rewrite(source_body, source:, link_target_globs:)
        blanked = Markdown.new(source_body).without_fences.lines
        dir = source_dir(source)

        source_body.lines.each_with_index.map do |line, index|
          next line if blanked[index] == "\n"

          rewrite_line(line, source_dir: dir, link_target_globs: link_target_globs)
        end.join
      end

      # @param line [String] one prose line of the original
      # @param source_dir [String] the original's repo-root-relative directory
      # @param link_target_globs [Array<String>]
      # @return [String]
      def self.rewrite_line(line, source_dir:, link_target_globs:)
        line.gsub(LINK) do
          text = Regexp.last_match(1)
          target = Regexp.last_match(2)
          title = Regexp.last_match(3)
          new_target = rewrite_target(target, source_dir: source_dir, link_target_globs: link_target_globs)

          next Regexp.last_match(0) if new_target == target

          "[#{text}](#{new_target}#{title})"
        end
      end

      # One link target. Resolved from the ORIGINAL's directory — its author
      # had the repository around it; the mirror's reader does not. A target
      # the gem packages becomes the packaged copy's path relative to the
      # mirror page; everything else becomes an absolute repository URL. Pure.
      #
      # @param target [String] the link target as written
      # @param source_dir [String] repo-root-relative directory of the original
      # @param link_target_globs [Array<String>]
      # @return [String]
      def self.rewrite_target(target, source_dir:, link_target_globs: LINK_TARGET_GLOBS)
        return target if target.start_with?("http://", "https://", "mailto:", "#", "<")
        return target if target.include?("{") || target.include?("$")

        path, fragment = target.split("#", 2)
        return target if path.nil? || path.empty?

        repo_rel =
          if path.start_with?("/")
            # A `/`-leading target is repository-root-relative in this repo's
            # docs (bin/check's docs step resolves it from the checkout root),
            # and an installed gem has no filesystem root for it to resolve
            # against — so it takes the same pipeline, rooted at the repository.
            path.delete_prefix("/")
          else
            rel = File.expand_path(path, "/#{source_dir}").delete_prefix("/")
            return target if rel.start_with?("..") # outside the repository — not rewritable

            rel
          end

        app_rel = repo_rel.delete_prefix("apps/magik/")
        if packaged_target?(app_rel, link_target_globs)
          anchor = fragment && !fragment.empty? ? "##{fragment}" : ""

          return "#{relative_to(app_rel, from_dir: source_dir)}#{anchor}"
        end

        repository_url(repo_rel, fragment)
      end

      # Does the gem package a page at this app-root-relative path? Pure
      # pattern arithmetic on the glob list, never a filesystem read: a mirror
      # is rendered before the copy it links to exists.
      #
      # @param app_rel [String] a path relative to the gem root
      # @param globs [Array<String>]
      # @return [Boolean]
      def self.packaged_target?(app_rel, globs)
        globs.any? { |glob| File.fnmatch(glob, app_rel, File::FNM_PATHNAME) }
      end

      # The path from a page in `from_dir` to an app-root-relative target, as
      # pure string work on virtual roots — no cwd, no filesystem. Pure.
      #
      # @param app_rel [String] the target, relative to the gem root
      # @param from_dir [String] the linking page's repo-root-relative directory
      # @return [String]
      def self.relative_to(app_rel, from_dir:)
        target = Pathname.new(File.expand_path("/#{app_rel}"))
        base = Pathname.new(File.expand_path("/#{from_dir}"))

        target.relative_path_from(base).to_s
      end

      # The absolute repository URL for a target the gem does not carry: blob
      # when the link carries a #fragment, tree for directories, raw for files.
      #
      # @param repo_rel [String] the target, repo-root-relative
      # @param fragment [String, nil]
      # @return [String]
      def self.repository_url(repo_rel, fragment)
        if fragment && !fragment.empty?
          "#{URL_BASES[:blob]}#{repo_rel}##{fragment}"
        elsif File.extname(repo_rel).empty?
          "#{URL_BASES[:tree]}#{repo_rel}"
        else
          "#{URL_BASES[:raw]}#{repo_rel}"
        end
      end

      # The provenance banner, appended after the verbatim original.
      #
      # @param version [String]
      # @param source [String] the original's app-root-relative path
      # @return [String]
      def self.banner(version:, source:)
        <<~BANNER
          ---

          ## About this copy

          **Generated file — do not edit.** This page is the packaged mirror of the repository's
          `#{mirror_for(source)}` at Magik #{version}, rendered by
          `apps/magik/scripts/checks/shipped_mirrors.rb`. An installed gem has no repository around it,
          so every link whose target the gem packages points at that packaged copy — version-matched by
          construction — and every other link points at the repository. Regenerate after editing the
          original:

          ```bash
          ruby apps/magik/scripts/checks/shipped_mirrors.rb --write
          ```
        BANNER
      end

      # Every mirror, as `mirror path => rendered body`, from the checkout
      # originals as they are right now. Reading a missing or unreadable source
      # raises — {#run} turns that into MAGIK_DEV_SHIPPED_MIRRORS_UNREFRESHABLE.
      #
      # @param version [String]
      # @return [Hash{String => String}]
      def self.render_all(version:)
        sources.to_h do |source|
          [mirror_for(source), render(Repo.read(source), version: version, source: source)]
        end
      end

      # The findings implied by expected renders against committed mirrors.
      # Pure, so the test can hand it a mutated mirror: a compare that stopped
      # comparing fails the suite here, not the gate.
      #
      # @param fresh [Hash{String => String}] mirror path => expected body
      # @param mirrors [Hash{String => String, nil}] mirror path => committed body,
      #   nil when the mirror does not exist
      # @return [Array<MagikScripts::Finding>]
      def self.compare(fresh, mirrors:)
        fresh.filter_map do |mirror, expected|
          committed = mirrors[mirror]
          if committed.nil?
            missing_finding(mirror)
          elsif committed != expected
            stale_finding(mirror)
          end
        end
      end

      # @param mirror [String] the mirror's app-root-relative path
      # @return [MagikScripts::Finding]
      def self.stale_finding(mirror)
        Finding.new(code: "MAGIK_DEV_SHIPPED_MIRRORS_STALE", at: mirror,
                    cause: "#{mirror} is not the render of its checkout original that this tree produces — " \
                           "the original moved or changed, or the banner's version stamp is stale",
                    fix: "ruby apps/magik/scripts/checks/shipped_mirrors.rb --write   # then commit #{mirror}")
      end

      # @param mirror [String] the mirror's app-root-relative path
      # @return [MagikScripts::Finding]
      def self.missing_finding(mirror)
        Finding.new(code: "MAGIK_DEV_SHIPPED_MIRRORS_MISSING", at: mirror,
                    cause: "#{mirror} does not exist, so an installed gem ships without a page that " \
                           "shipped links and error fix lines point at",
                    fix: "ruby apps/magik/scripts/checks/shipped_mirrors.rb --write   # then commit #{mirror}")
      end

      # @return [MagikScripts::Result]
      def run
        sources = self.class.sources
        return nothing_scanned(corpus: SOURCE_GLOB, expected: expectation, fix: fix_line) if sources.empty?

        return regenerate if options[:write]

        judge
      rescue StandardError => e
        unrefreshable(e)
      end

      private

      # The compare half of {#run}: render everything, read the committed
      # mirrors, hold the fresh render up against them. Split from {#run} so
      # its rescue covers exactly what can raise.
      #
      # @return [MagikScripts::Result]
      def judge
        fresh = self.class.render_all(version: Library.load!::VERSION)
        mirrors = fresh.keys.to_h { |mirror| [mirror, Repo.exist?(mirror) ? Repo.read(mirror) : nil] }
        findings = self.class.compare(fresh, mirrors: mirrors)
        return summary(fresh) if findings.empty?

        failure(reason: "shipped_mirrors_stale", expected: expectation, fix: fix_line, findings: findings,
                got: "#{findings.size} of #{fresh.size} packaged mirrors are not a fresh render of " \
                     "their checkout original")
      end

      # @param fresh [Hash{String => String}]
      # @return [MagikScripts::Result]
      def regenerate
        fresh = self.class.render_all(version: Library.load!::VERSION)
        fresh.each do |mirror, body|
          file = Repo.path(mirror)
          FileUtils.mkdir_p(file.dirname.to_s)
          file.write(body)
        end

        ok(expected: expectation,
           got: "wrote #{fresh.size} mirrors under docs/, generated from the checkout's docs/ originals")
      end

      # @param error [Exception] whatever reading a source, rendering it, or
      #   writing a mirror raised
      # @return [MagikScripts::Result]
      def unrefreshable(error)
        detail = "#{error.class}: #{error.message.lines.first.to_s.strip}"
        failure(reason: "shipped_mirrors_unrefreshable", expected: expectation, fix: refresh_fix,
                findings: [Finding.new(code: "MAGIK_DEV_SHIPPED_MIRRORS_UNREFRESHABLE", at: SOURCE_GLOB,
                                       cause: "rendering the checkout originals into the packaged mirrors " \
                                              "raised #{detail}",
                                       fix: refresh_fix)],
                got: detail)
      end

      # @param fresh [Hash{String => String}]
      # @return [MagikScripts::Result]
      def summary(fresh)
        ok(expected: expectation,
           got: "#{fresh.size} packaged mirrors are current, generated from the checkout's docs/ originals")
      end

      # A runnable recovery, on checkout-root paths: the sources are the
      # repository's docs/ tree at the checkout root, so git restores them, and
      # the mirrors are regenerated by this check's own `--write`.
      #
      # @return [String]
      def refresh_fix
        "git checkout -- docs   # then rerun: ruby apps/magik/scripts/checks/shipped_mirrors.rb --write"
      end

      # @return [String]
      def expectation
        "every packaged page under docs/ is exactly what " \
          "`ruby apps/magik/scripts/checks/shipped_mirrors.rb --write` writes: its checkout original " \
          "verbatim, prose links to packaged pages rewritten gem-relative, every other prose link an " \
          "absolute repository URL, the provenance banner appended"
      end

      # @return [String]
      def fix_line
        "ruby apps/magik/scripts/checks/shipped_mirrors.rb --write   # then commit the mirrors it writes"
      end
    end
  end
end

# __FILE__ is relative to the launch directory; the registry resolves absolute paths from any cwd.
if $PROGRAM_NAME == __FILE__
  exit MagikScripts::Runner.main(File.expand_path(__FILE__), MagikScripts::Checks::ShippedMirrors)
end
