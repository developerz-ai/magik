#!/usr/bin/env ruby
# frozen_string_literal: true

# @check   build-spec-mirror
# @summary The packaged build-spec mirror is a fresh render of the original.
# @order   75
#
# `Magik::Error::DEFAULT_FIX` (apps/magik/lib/magik.rb) and every spec-only
# stub's error message tell the reader to see `docs/idea/00-build-spec.md`.
# In a checkout that path is the repository's own file, two levels up. In an
# INSTALLED gem there is no repository around the gem — so the gem packages a
# generated mirror of the spec at the same path relative to the gem root,
# `docs/idea/00-build-spec.md` beside `lib/`, and `magik docs
# docs/idea/00-build-spec` serves the page the fix lines name.
#
# The mirror is GENERATED, and this check is its only writer:
#
#     ruby apps/magik/scripts/checks/build_spec_mirror.rb            is it current?
#     ruby apps/magik/scripts/checks/build_spec_mirror.rb --write    make it current
#
#   MAGIK_DEV_BUILD_SPEC_MIRROR_STALE       the committed copy differs from a fresh render
#   MAGIK_DEV_BUILD_SPEC_MIRROR_MISSING     the mirror is absent
#   MAGIK_DEV_BUILD_SPEC_MIRROR_UNREFRESHABLE  reading the original or writing the mirror raised
#
# The render is deliberately small: the original is carried verbatim, links
# outside fences are rewritten to absolute repository URLs — raw for files,
# blob when the link carries a #fragment (the only shape where the anchor
# lands), tree for directories — so they resolve from an installed gem's
# filesystem, and a provenance banner naming the version and the regenerating
# command is appended. Links inside fences are never touched: a link inside an
# example is illustration, not a promise that the path exists.

require "fileutils"

require_relative "../lib/scripts"
require_relative "../lib/library"

module MagikScripts
  module Checks
    # The build spec's packaged mirror versus the original it is rendered from.
    class BuildSpecMirror < Check
      # The original, app-root-relative: the checkout-root file, two levels up.
      # @return [String]
      SOURCE = "../../docs/idea/00-build-spec.md"

      # The mirror, app-root-relative — the path the error fix lines name.
      # @return [String]
      MIRROR = "docs/idea/00-build-spec.md"

      # The repository the rewritten links point at.
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

      # The same link shape `MagikScripts::Markdown::LINK` matches, plus the
      # optional quoted title as its own group, because a rewrite has to carry
      # the title through. Markdown::LINK itself is left alone — doc-commands
      # destructures its two captures.
      # @return [Regexp]
      LINK = /\[([^\]\n]*)\]\(([^)\s]+)((?:\s+"[^"]*")?)\)/

      # `--write` regenerates the mirror instead of comparing.
      # @return [Hash{String => Symbol}]
      def self.flags
        { "--write" => :write }
      end

      # The mirror as it should be on disk right now. Pure.
      #
      # @param source [String] the original build spec
      # @param version [String] `Magik::VERSION`, named in the banner
      # @return [String]
      def self.render(source, version:)
        body = rewritten(source)
        body = "#{body}\n" unless body.end_with?("\n")
        "#{body}\n#{banner(version: version)}"
      end

      # The source with every prose link target made absolute. Fenced blocks
      # keep their lines untouched, line count included.
      #
      # @param source [String] the original build spec
      # @return [String]
      def self.rewritten(source)
        blanked = Markdown.new(source).without_fences.lines
        source.lines.each_with_index.map do |line, index|
          next line if blanked[index] == "\n"

          rewrite_line(line)
        end.join
      end

      # @param line [String] one prose line of the original
      # @return [String]
      def self.rewrite_line(line)
        line.gsub(LINK) do
          text = Regexp.last_match(1)
          target = Regexp.last_match(2)
          title = Regexp.last_match(3)
          new_target = rewrite_target(target)

          next Regexp.last_match(0) if new_target == target

          "[#{text}](#{new_target}#{title})"
        end
      end

      # One link target, resolved from the ORIGINAL's directory — not the
      # mirror's, whose reader has no repository around it — as an absolute
      # repository URL. Pure.
      #
      # @param target [String] the link target as written
      # @param source_dir [String] repo-root-relative directory of the original
      # @return [String]
      def self.rewrite_target(target, source_dir: "docs/idea")
        return target if target.start_with?("http://", "https://", "mailto:", "#", "<")
        return target if target.include?("{") || target.include?("$")

        path, fragment = target.split("#", 2)
        return target if path.nil? || path.empty? || path.start_with?("/")

        repo_rel = File.expand_path(path, "/#{source_dir}").delete_prefix("/")
        return target if repo_rel.start_with?("..") # outside the repository — not rewritable

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
      # @return [String]
      def self.banner(version:)
        <<~BANNER
          ---

          ## About this copy

          **Generated file — do not edit.** This page is the packaged mirror of the repository's
          [`docs/idea/00-build-spec.md`](#{URL_BASES[:raw]}docs/idea/00-build-spec.md) at Magik #{version}.
          `Magik::Error::DEFAULT_FIX` and every spec-only stub's error message name the path
          `docs/idea/00-build-spec.md`; an installed gem has no repository around it, so this copy is
          what makes that path resolve. Links above point at the repository instead of at sibling
          files, so they work from an installed gem's filesystem. Regenerate after editing the
          original:

          ```bash
          ruby apps/magik/scripts/checks/build_spec_mirror.rb --write
          ```
        BANNER
      end

      # @param error [Exception]
      # @return [MagikScripts::Finding]
      def self.source_finding(error)
        Finding.new(code: "MAGIK_DEV_BUILD_SPEC_SOURCE_UNREADABLE", at: SOURCE,
                    cause: "the mirror is rendered from #{SOURCE}, which raised #{error.class}: " \
                           "#{error.message.lines.first.to_s.strip}",
                    fix: "restore #{SOURCE}   # the mirror is generated from it")
      end

      # @return [MagikScripts::Result]
      def run
        fresh = self.class.render(Repo.read(SOURCE), version: Library.load!::VERSION)
        return regenerate(fresh) if options[:write]

        compare(fresh)
      rescue StandardError => e
        unrefreshable(e)
      end

      private

      # @param fresh [String] the fresh render
      # @return [MagikScripts::Result]
      def compare(fresh)
        return missing unless Repo.exist?(MIRROR)
        return summary if Repo.read(MIRROR) == fresh

        failure(reason: "build_spec_mirror_stale", expected: expectation, fix: fix_line,
                findings: [stale_finding],
                got: "#{MIRROR} differs from a fresh render of #{SOURCE}")
      end

      # @param error [Exception] whatever reading the original, rendering it, or
      #   writing the mirror raised
      # @return [MagikScripts::Result]
      def unrefreshable(error)
        detail = "#{error.class}: #{error.message.lines.first.to_s.strip}"
        failure(reason: "build_spec_mirror_unrefreshable", expected: expectation, fix: refresh_fix,
                findings: [Finding.new(code: "MAGIK_DEV_BUILD_SPEC_MIRROR_UNREFRESHABLE", at: MIRROR,
                                       cause: "refreshing #{MIRROR} from #{SOURCE} raised #{detail}",
                                       fix: refresh_fix)],
                got: detail)
      end

      # @param fresh [String] the fresh render
      # @return [MagikScripts::Result]
      def regenerate(fresh)
        file = Repo.path(MIRROR)
        FileUtils.mkdir_p(file.dirname.to_s)
        bytes = file.write(fresh)

        ok(expected: expectation, got: "wrote #{bytes} bytes to #{MIRROR}")
      end

      # @return [MagikScripts::Result]
      def missing
        failure(reason: "build_spec_mirror_missing", expected: expectation, fix: fix_line,
                findings: [Finding.new(code: "MAGIK_DEV_BUILD_SPEC_MIRROR_MISSING", at: MIRROR,
                                       cause: "#{MIRROR} does not exist, so the path the error fix lines " \
                                              "name resolves nowhere in an installed gem",
                                       fix: fix_line)],
                got: "#{MIRROR} is absent")
      end

      # @return [MagikScripts::Finding]
      def stale_finding
        Finding.new(code: "MAGIK_DEV_BUILD_SPEC_MIRROR_STALE", at: MIRROR,
                    cause: "#{MIRROR} is not the render of #{SOURCE} this tree produces — the original " \
                           "moved, or the banner's version stamp is stale",
                    fix: fix_line)
      end

      # @return [MagikScripts::Result]
      def summary
        ok(expected: expectation,
           got: "#{MIRROR} is current: #{Repo.read(MIRROR).lines.size} lines, generated from #{SOURCE}")
      end

      # @return [String]
      def refresh_fix
        "restore #{SOURCE} and check its links   # the mirror is generated from it, then rerun --write"
      end

      # @return [String]
      def expectation
        "#{MIRROR} is exactly what `ruby apps/magik/scripts/checks/build_spec_mirror.rb --write` writes: " \
          "the original verbatim, prose links made absolute, the provenance banner appended"
      end

      # @return [String]
      def fix_line
        "ruby apps/magik/scripts/checks/build_spec_mirror.rb --write   # then commit #{MIRROR}"
      end
    end
  end
end

# __FILE__ is relative to the launch directory; the registry resolves absolute paths from any cwd.
if $PROGRAM_NAME == __FILE__
  exit MagikScripts::Runner.main(File.expand_path(__FILE__), MagikScripts::Checks::BuildSpecMirror)
end
