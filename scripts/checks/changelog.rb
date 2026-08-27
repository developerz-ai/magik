#!/usr/bin/env ruby
# frozen_string_literal: true

# @check   changelog
# @summary CHANGELOG.md is Keep a Changelog, has [Unreleased], and covers Magik::VERSION.
# @order   50
#
# `docs/architecture/00-conventions.md` makes the changelog a shipping
# requirement: *"every user-visible change adds a CHANGELOG.md entry in the same
# commit."* A rule enforced by review erodes; this is the same rule enforced by
# the gate.
#
#   MAGIK_CHANGELOG_MISSING          no CHANGELOG.md
#   MAGIK_CHANGELOG_FORMAT_UNDECLARED   the page does not name Keep a Changelog
#   MAGIK_CHANGELOG_NO_UNRELEASED    no `## [Unreleased]` to write the next entry into
#   MAGIK_CHANGELOG_VERSION_MISSING  lib/magik/version.rb names a version the log
#                                    has never heard of
#   MAGIK_CHANGELOG_HEADING          a `## [x]` heading with no ` - YYYY-MM-DD` date
#   MAGIK_CHANGELOG_ORDER            releases are not newest-first
#   MAGIK_CHANGELOG_LINK_MISSING     a section with no `[x]: <url>` link definition
#   MAGIK_CHANGELOG_UNKNOWN_SECTION  a `###` that is not a Keep a Changelog change type
#
# `Notes` is accepted alongside the six Keep a Changelog types. `0.0.1` uses it
# to say what has *not* been measured, which is this repo's central honesty
# rule and does not fit under Added, Changed, Deprecated, Removed, Fixed or
# Security.

require_relative "../lib/scripts"
require_relative "../lib/library"

module MagikScripts
  module Checks
    # `CHANGELOG.md`, held to its own declared format.
    class Changelog < Check
      # The file under test.
      # @return [String]
      PATH = "CHANGELOG.md"

      # The format the page must declare it follows.
      # @return [String]
      FORMAT_URL = "keepachangelog.com"

      # The heading that the next change gets written into.
      # @return [String]
      UNRELEASED = "Unreleased"

      # `## [0.0.1] - 2026-08-26`, and the unreleased form without a date.
      # @return [Regexp]
      HEADING = /^##\s+\[([^\]]+)\](?:\s+-\s+(\d{4}-\d{2}-\d{2}))?\s*$/

      # `[0.0.1]: https://...`
      # @return [Regexp]
      LINK_DEFINITION = /^\[([^\]]+)\]:\s+\S+/

      # `### Added`
      # @return [Regexp]
      SUBSECTION = /^###\s+(.+?)\s*$/

      # The six Keep a Changelog change types, plus `Notes` — see the header.
      # @return [Array<String>]
      SECTIONS = %w[Added Changed Deprecated Removed Fixed Security Notes].freeze

      # Every finding implied by a changelog and a version. Pure, so the test
      # feeds it strings rather than editing the real file.
      #
      # @param markdown [String] the contents of `CHANGELOG.md`
      # @param version [String] `Magik::VERSION`
      # @return [Array<MagikScripts::Finding>]
      def self.audit(markdown, version)
        headings = markdown.scan(HEADING)
        links = markdown.scan(LINK_DEFINITION).flatten
        format_declared(markdown) + unreleased(headings) + covers(headings, version) +
          dated(headings) + ordered(headings) + linked(headings, links) + sections(markdown)
      end

      # @param markdown [String]
      # @return [Array<MagikScripts::Finding>]
      def self.format_declared(markdown)
        return [] if markdown.include?(FORMAT_URL)

        [Finding.new(code: "MAGIK_CHANGELOG_FORMAT_UNDECLARED", at: PATH,
                     cause: "#{PATH} does not link #{FORMAT_URL}, so the format it is being held to " \
                            "is not stated anywhere a reader can find it",
                     fix: "add the Keep a Changelog link to the preamble of #{PATH}")]
      end

      # @param headings [Array<Array<String>>] `[label, date]` pairs
      # @return [Array<MagikScripts::Finding>]
      def self.unreleased(headings)
        return [] if headings.any? { |(label, _)| label == UNRELEASED }

        [Finding.new(code: "MAGIK_CHANGELOG_NO_UNRELEASED", at: PATH,
                     cause: "#{PATH} has no `## [#{UNRELEASED}]` heading, so the next change has " \
                            "nowhere to be written as it lands",
                     fix: "add `## [#{UNRELEASED}]` above the newest release heading in #{PATH}")]
      end

      # @param headings [Array<Array<String>>]
      # @param version [String]
      # @return [Array<MagikScripts::Finding>]
      def self.covers(headings, version)
        return [] if headings.any? { |(label, _)| label == version }

        [Finding.new(code: "MAGIK_CHANGELOG_VERSION_MISSING", at: PATH,
                     cause: "lib/magik/version.rb is stamped #{version} and #{PATH} has no " \
                            "`## [#{version}]` section; the released version has no release notes",
                     fix: "add `## [#{version}] - #{Time.now.strftime("%Y-%m-%d")}` to #{PATH}, " \
                          "moving the [#{UNRELEASED}] entries into it")]
      end

      # @param headings [Array<Array<String>>]
      # @return [Array<MagikScripts::Finding>]
      def self.dated(headings)
        headings.filter_map do |(label, date)|
          next if label == UNRELEASED || !date.nil?

          Finding.new(code: "MAGIK_CHANGELOG_HEADING", at: PATH,
                      cause: "`## [#{label}]` carries no release date, so nobody can tell when it shipped",
                      fix: "write it as `## [#{label}] - YYYY-MM-DD` in #{PATH}")
        end
      end

      # @param headings [Array<Array<String>>]
      # @return [Array<MagikScripts::Finding>]
      def self.ordered(headings)
        released = headings.map(&:first).reject { |label| label == UNRELEASED }
        sorted = released.sort_by { |label| Gem::Version.new(label) }.reverse
        return [] if released == sorted || released.any? { |label| !semver?(label) }

        [Finding.new(code: "MAGIK_CHANGELOG_ORDER", at: PATH,
                     cause: "#{PATH} lists #{released.join(", ")}; Keep a Changelog is newest-first, " \
                            "which is #{sorted.join(", ")}",
                     fix: "reorder the `## [x]` sections of #{PATH} to #{sorted.join(", ")}")]
      end

      # @param headings [Array<Array<String>>]
      # @param links [Array<String>] the labels with a link definition
      # @return [Array<MagikScripts::Finding>]
      def self.linked(headings, links)
        (headings.map(&:first) - links).map do |label|
          Finding.new(code: "MAGIK_CHANGELOG_LINK_MISSING", at: PATH,
                      cause: "`[#{label}]` is a heading with no `[#{label}]: <url>` definition, so the " \
                             "link renders as literal brackets",
                      fix: "add a `[#{label}]: https://github.com/developerz-ai/magik/...` line to " \
                           "the bottom of #{PATH}")
        end
      end

      # @param markdown [String]
      # @return [Array<MagikScripts::Finding>]
      def self.sections(markdown)
        markdown.scan(SUBSECTION).flatten.uniq.filter_map do |name|
          next if SECTIONS.include?(name)

          Finding.new(code: "MAGIK_CHANGELOG_UNKNOWN_SECTION", at: PATH,
                      cause: "`### #{name}` is not a Keep a Changelog change type; the types are " \
                             "#{SECTIONS.join(", ")}",
                      fix: "rename `### #{name}` in #{PATH} to one of #{SECTIONS.join(", ")}")
        end
      end

      # @param label [String]
      # @return [Boolean]
      def self.semver?(label)
        Gem::Version.correct?(label)
      end

      # @return [MagikScripts::Result]
      def run
        return absent unless Repo.exist?(PATH)

        version = Library.load!::VERSION
        findings = self.class.audit(Repo.read(PATH), version)
        return summary(version) if findings.empty?

        failure(reason: "changelog_invalid", expected: expectation, fix: fix_line, findings: findings,
                got: "#{findings.size} problem(s) in #{PATH}")
      end

      private

      # @return [MagikScripts::Result]
      def absent
        failure(reason: "changelog_missing", expected: expectation,
                fix: "restore #{PATH} — see https://#{FORMAT_URL}/en/1.1.0/ for the format",
                got: "#{PATH} does not exist",
                findings: [Finding.new(code: "MAGIK_CHANGELOG_MISSING", at: PATH,
                                       cause: "there is no #{PATH}, so no released change is recorded",
                                       fix: "create #{PATH} with an `## [#{UNRELEASED}]` section")])
      end

      # @param version [String]
      # @return [MagikScripts::Result]
      def summary(version)
        headings = Repo.read(PATH).scan(HEADING).map(&:first)
        ok(expected: expectation,
           got: "#{PATH}: #{headings.size} sections, [#{UNRELEASED}] present, #{version} covered")
      end

      # @return [String]
      def expectation
        "#{PATH} declares Keep a Changelog, has an [#{UNRELEASED}] section, covers Magik::VERSION, " \
          "and lists dated, linked releases newest-first"
      end

      # @return [String]
      def fix_line
        "ruby scripts/checks/changelog.rb   # each finding above names the edit to #{PATH}"
      end
    end
  end
end

exit MagikScripts::Runner.main(__FILE__, MagikScripts::Checks::Changelog) if $PROGRAM_NAME == __FILE__
