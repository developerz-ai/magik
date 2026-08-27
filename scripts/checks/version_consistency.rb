#!/usr/bin/env ruby
# frozen_string_literal: true

# @check   version-consistency
# @summary Magik::VERSION, the gemspec, the changelog and every doc stamp agree.
# @order   60
#
# `CLAUDE.md`: *"the version lives in lib/magik/version.rb — it is the ONLY
# place a version is stated."* Every other statement of it is a copy, and a copy
# is a thing that goes stale. This check finds the copies and holds them to the
# original.
#
#   MAGIK_DEV_VERSION_GEMSPEC_MISMATCH    magik.gemspec does not read version.rb
#   MAGIK_DEV_VERSION_CHANGELOG_MISMATCH  the newest release in CHANGELOG.md is not
#                                         the version this tree is stamped at
#   MAGIK_DEV_VERSION_STAMP_STALE         a document states a magik version that is
#                                         no longer the one in version.rb
#   MAGIK_DEV_VERSION_UNSTAMPED           no document states the version at all, so
#                                         this check is asleep rather than satisfied
#
# Only stamps that **name magik** are read. A bare `1.2.3` in prose is a
# version of something else more often than not: `v1.0.0` in `CONTRIBUTING.md`
# is part of the Conventional Commits URL, and `v0.1.0-rc1` in `PUBLISHING.md`
# is an example of the tag format. Matching those would make the check fail for
# documents that are correct, which is how a check gets switched off.

require_relative "../lib/scripts"
require_relative "../lib/library"

module MagikScripts
  module Checks
    # One version, stated in many places, checked against the one that counts.
    class VersionConsistency < Check
      # The single source of truth.
      # @return [String]
      SOURCE = "lib/magik/version.rb"

      # Documents that may state the version.
      # @return [Array<String>]
      PAGES = ["*.md", "wiki/*.md", "docs/**/*.md", "llms.txt"].freeze

      # Ways a document names the gem's own version. Each one mentions magik,
      # so a version belonging to something else cannot match.
      # @return [Array<Regexp>]
      STAMPS = [
        /\bmagik[- ]v?(\d+\.\d+\.\d+)/,
        /Magik::VERSION\s*#\s*=>\s*"(\d+\.\d+\.\d+)"/,
        /gem\s+["']magik["'][^\n]*?(\d+\.\d+\.\d+)/
      ].freeze

      # `"version": "0.0.1"` — read only inside a fenced block that also names
      # magik, so another tool's JSON cannot be mistaken for this gem's.
      # @return [Regexp]
      JSON_STAMP = /"version"\s*:\s*"(\d+\.\d+\.\d+)"/

      # One version claim, and where it is made.
      Stamp = Struct.new(:version, :at, :context, keyword_init: true)

      # Every finding implied by a set of stamps. Pure.
      #
      # @param stamps [Array<MagikScripts::Checks::VersionConsistency::Stamp>]
      # @param version [String] `Magik::VERSION`
      # @return [Array<MagikScripts::Finding>]
      def self.audit(stamps, version)
        return [unstamped(version)] if stamps.empty?

        stamps.reject { |stamp| stamp.version == version }.map { |stamp| stale(stamp, version) }
      end

      # @param stamp [MagikScripts::Checks::VersionConsistency::Stamp]
      # @param version [String]
      # @return [MagikScripts::Finding]
      def self.stale(stamp, version)
        Finding.new(code: "MAGIK_DEV_VERSION_STAMP_STALE", at: stamp.at,
                    cause: "#{stamp.at} states magik #{stamp.version} (#{stamp.context.strip.inspect}) " \
                           "and #{SOURCE} is stamped #{version}",
                    fix: "change #{stamp.version} to #{version} at #{stamp.at}")
      end

      # @param version [String]
      # @return [MagikScripts::Finding]
      def self.unstamped(version)
        Finding.new(code: "MAGIK_DEV_VERSION_UNSTAMPED", at: SOURCE,
                    cause: "no document in #{PAGES.join(", ")} states a magik version, so this check " \
                           "compared #{version} against nothing and would pass whatever #{SOURCE} said",
                    fix: "state the version in README.md the way the CLI prints it — `magik #{version}` " \
                         "— or delete this check")
      end

      # Every version this document claims for magik. Pure.
      #
      # @param text [String] the document
      # @param path [String] its root-relative path
      # @return [Array<MagikScripts::Checks::VersionConsistency::Stamp>]
      def self.stamps(text, path)
        direct(text, path) + json(text, path)
      end

      # @param text [String]
      # @param path [String]
      # @return [Array<MagikScripts::Checks::VersionConsistency::Stamp>]
      def self.direct(text, path)
        text.each_line.with_index(1).flat_map do |line, number|
          STAMPS.flat_map do |pattern|
            line.scan(pattern).flatten.map do |found|
              Stamp.new(version: found, at: "#{path}:#{number}", context: line)
            end
          end
        end
      end

      # @param text [String]
      # @param path [String]
      # @return [Array<MagikScripts::Checks::VersionConsistency::Stamp>]
      def self.json(text, path)
        Markdown.new(text).fences.select { |fence| fence.body.include?("magik") }.flat_map do |fence|
          fence.body.each_line.with_index(1).flat_map do |line, offset|
            line.scan(JSON_STAMP).flatten.map do |found|
              Stamp.new(version: found, at: "#{path}:#{fence.line + offset}", context: line)
            end
          end
        end
      end

      # @return [MagikScripts::Result]
      def run
        version = Library.load!::VERSION
        pages = documents
        return nothing_scanned(corpus: PAGES.join(" "), expected: expectation, fix: fix_line) if pages.empty?

        stamps = pages.flat_map { |path| self.class.stamps(Repo.read(path), path) }
        findings = gemspec(version) + changelog(version) + self.class.audit(stamps, version)
        return summary(version, pages, stamps) if findings.empty?

        drifted(findings, stamps, pages, version)
      end

      private

      # @param findings [Array<MagikScripts::Finding>]
      # @param stamps [Array<MagikScripts::Checks::VersionConsistency::Stamp>]
      # @param pages [Array<String>]
      # @param version [String]
      # @return [MagikScripts::Result]
      def drifted(findings, stamps, pages, version)
        failure(reason: "version_drift", expected: expectation, fix: fix_line, findings: findings,
                got: "#{stamps.size} version stamps in #{pages.size} documents, " \
                     "#{findings.size} disagree with #{SOURCE} (#{version})")
      end

      # @return [Array<String>] every document that may state a version
      def documents
        PAGES.flat_map { |pattern| Repo.glob(pattern) }.uniq.sort
      end

      # @param version [String]
      # @return [Array<MagikScripts::Finding>]
      def gemspec(version)
        spec = Gem::Specification.load(Repo.path("magik.gemspec").to_s)
        return [] if spec.nil? || spec.version.to_s == version

        [Finding.new(code: "MAGIK_DEV_VERSION_GEMSPEC_MISMATCH", at: "magik.gemspec",
                     cause: "magik.gemspec packages #{spec.version}, and #{SOURCE} is stamped #{version}",
                     fix: "make magik.gemspec read Magik::VERSION rather than restating it")]
      end

      # @param version [String]
      # @return [Array<MagikScripts::Finding>]
      def changelog(version)
        newest = newest_release
        return [] if newest.nil? || newest == version

        [Finding.new(code: "MAGIK_DEV_VERSION_CHANGELOG_MISMATCH", at: "CHANGELOG.md",
                     cause: "the newest release in CHANGELOG.md is #{newest}, and #{SOURCE} is " \
                            "stamped #{version}",
                     fix: "add a `## [#{version}]` section to CHANGELOG.md, or correct #{SOURCE}")]
      end

      # @return [String, nil] the newest dated release label in the changelog
      def newest_release
        return nil unless Repo.exist?("CHANGELOG.md")

        Repo.read("CHANGELOG.md").scan(/^##\s+\[([^\]]+)\]\s+-\s+\d{4}-\d{2}-\d{2}/).flatten
            .select { |label| Gem::Version.correct?(label) }
            .max_by { |label| Gem::Version.new(label) }
      end

      # @param version [String]
      # @param pages [Array<String>]
      # @param stamps [Array<MagikScripts::Checks::VersionConsistency::Stamp>]
      # @return [MagikScripts::Result]
      def summary(version, pages, stamps)
        ok(expected: expectation,
           got: "#{version} in #{SOURCE}, the gemspec, CHANGELOG.md and all #{stamps.size} " \
                "doc stamps across #{pages.size} documents")
      end

      # @return [String]
      def expectation
        "every statement of the magik version — the gemspec, the newest CHANGELOG.md release, and " \
          "every doc stamp — matches #{SOURCE}"
      end

      # @return [String]
      def fix_line
        "ruby scripts/checks/version_consistency.rb   # each finding above names the file and line"
      end
    end
  end
end

exit MagikScripts::Runner.main(__FILE__, MagikScripts::Checks::VersionConsistency) if $PROGRAM_NAME == __FILE__
