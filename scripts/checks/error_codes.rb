#!/usr/bin/env ruby
# frozen_string_literal: true

# @check   error-codes
# @summary Every shipped MAGIK_* code is well-formed, unique, fixable, and documented.
# @order   20
#
# `CLAUDE.md`: *"Every one carries a concrete cause and a runnable `fix:` — a
# command, never advice."* `docs/architecture/03-error-codes.md` adds the format
# and the stability promise. This check turns all of that into a build error.
#
# It asserts six things about the error classes reachable from the `Magik`
# namespace:
#
#   MAGIK_ERROR_CODE_MALFORMED      a code that does not match Magik::Error::CODE_FORMAT
#   MAGIK_ERROR_CODE_UNDECLARED     a subclass that inherited its code instead of
#                                   declaring one — two conditions under one name
#   MAGIK_ERROR_CODE_DUPLICATE      one code owned by two classes
#   MAGIK_ERROR_FIX_ADVICE          a fix: that tells the reader to think rather
#                                   than to run something
#   MAGIK_ERROR_CODE_UNDOCUMENTED   a code that ships and is not in wiki/Error-Codes.md
#   MAGIK_ERROR_CODE_PHANTOM        a code wiki/Error-Codes.md calls live that
#                                   nothing in lib/ actually raises
#
# Drift is checked in **both** directions, and only against the wiki page's
# "Live today" section. Every other table on that page is explicitly seeded from
# the guardrails and raised by nothing — holding a reserved name to the same rule
# would make the check fail for being honest. The day the catalogue is generated
# (that page says it will be), this check is what proves the generator ran.

require_relative "../lib/scripts"
require_relative "../lib/library"

module MagikScripts
  module Checks
    # The `MAGIK_*` catalogue, as an assertion.
    class ErrorCodes < Check
      # The page that documents the shipped codes.
      # @return [String]
      CATALOGUE = "wiki/Error-Codes.md"

      # The heading whose table lists codes that actually exist today.
      # @return [String]
      LIVE_SECTION = "Live today"

      # A code as the catalogue writes it: inside backticks, in a table cell.
      # @return [Regexp]
      CODE_IN_PROSE = /`(MAGIK_[A-Z0-9_]+)`/

      # Phrases that turn a `fix:` back into advice. The repo's own rule: *"A
      # `fix:` reading 'do the right thing' is a bug"* (`wiki/Error-Codes.md`).
      # @return [Array<Regexp>]
      ADVICE = [
        /\bcheck your\b/i, /\bmake sure\b/i, /\btry again\b/i, /\bas appropriate\b/i,
        /\bif necessary\b/i, /\bdo the right thing\b/i, /\bsomething went wrong\b/i,
        /\bcontact support\b/i, /\breview the\b/i
      ].freeze

      # One error class, flattened to data so the rules are pure.
      Declared = Struct.new(:name, :code, :fix, :own_code, :own_fix, :at, :base, keyword_init: true)

      # Every finding implied by `declared` and by what the catalogue documents.
      #
      # @param declared [Array<MagikScripts::Checks::ErrorCodes::Declared>]
      # @param documented [Array<String>] codes the catalogue calls live
      # @param format [Regexp] `Magik::Error::CODE_FORMAT`
      # @return [Array<MagikScripts::Finding>]
      def self.audit(declared:, documented:, format:)
        shape(declared, format) + duplicates(declared) + drift(declared, documented)
      end

      # @param declared [Array<MagikScripts::Checks::ErrorCodes::Declared>]
      # @param format [Regexp]
      # @return [Array<MagikScripts::Finding>]
      def self.shape(declared, format)
        declared.flat_map do |error|
          [malformed(error, format), undeclared(error), advice(error)].compact
        end
      end

      # @param error [MagikScripts::Checks::ErrorCodes::Declared]
      # @param format [Regexp]
      # @return [MagikScripts::Finding, nil]
      def self.malformed(error, format)
        return nil if format.match?(error.code)

        Finding.new(code: "MAGIK_ERROR_CODE_MALFORMED", at: error.at,
                    cause: "#{error.name} carries #{error.code.inspect}, which is not MAGIK_<SUBSYSTEM>_<CONDITION>",
                    fix: "rename the code in #{error.at} to match #{format.source}")
      end

      # @param error [MagikScripts::Checks::ErrorCodes::Declared]
      # @return [MagikScripts::Finding, nil]
      def self.undeclared(error)
        return nil if error.base || error.own_code

        Finding.new(code: "MAGIK_ERROR_CODE_UNDECLARED", at: error.at,
                    cause: "#{error.name} inherits #{error.code}; two conditions raised under one code " \
                           "cannot be told apart by a log pipeline or a test",
                    fix: "add `code \"MAGIK_...\"` to #{error.name} in #{error.at}")
      end

      # @param error [MagikScripts::Checks::ErrorCodes::Declared]
      # @return [MagikScripts::Finding, nil]
      def self.advice(error)
        return nil if error.fix.to_s.strip.empty?

        matched = ADVICE.find { |pattern| pattern.match?(error.fix) }
        return nil if matched.nil?

        Finding.new(code: "MAGIK_ERROR_FIX_ADVICE", at: error.at,
                    cause: "#{error.code}'s fix: reads #{error.fix.inspect}, which tells the reader to " \
                           "think rather than to run something",
                    fix: "replace the fix: on #{error.name} in #{error.at} with a command, " \
                         "a call to paste, or an edit naming a file")
      end

      # @param declared [Array<MagikScripts::Checks::ErrorCodes::Declared>]
      # @return [Array<MagikScripts::Finding>]
      def self.duplicates(declared)
        declared.group_by(&:code).filter_map do |code, group|
          next if group.size < 2

          Finding.new(code: "MAGIK_ERROR_CODE_DUPLICATE", at: group.map(&:at).min,
                      cause: "#{code} is claimed by #{group.map(&:name).sort.join(" and ")}; " \
                             "one code is owned by exactly one condition",
                      fix: "give all but one of #{group.map(&:name).sort.join(", ")} a new code")
        end
      end

      # @param declared [Array<MagikScripts::Checks::ErrorCodes::Declared>]
      # @param documented [Array<String>]
      # @return [Array<MagikScripts::Finding>]
      def self.drift(declared, documented)
        shipped = declared.map(&:code).uniq
        undocumented(shipped, documented) + phantom(shipped, documented)
      end

      # @param shipped [Array<String>]
      # @param documented [Array<String>]
      # @return [Array<MagikScripts::Finding>]
      def self.undocumented(shipped, documented)
        (shipped - documented).sort.map do |code|
          Finding.new(code: "MAGIK_ERROR_CODE_UNDOCUMENTED", at: CATALOGUE,
                      cause: "#{code} is raised by this gem and is absent from #{CATALOGUE}'s " \
                             "\"#{LIVE_SECTION}\" table, so nobody who hits it can look it up",
                      fix: "add a row for #{code} to the \"#{LIVE_SECTION}\" table in #{CATALOGUE}")
        end
      end

      # @param shipped [Array<String>]
      # @param documented [Array<String>]
      # @return [Array<MagikScripts::Finding>]
      def self.phantom(shipped, documented)
        (documented - shipped).sort.map do |code|
          Finding.new(code: "MAGIK_ERROR_CODE_PHANTOM", at: CATALOGUE,
                      cause: "#{CATALOGUE} lists #{code} under \"#{LIVE_SECTION}\", and no Magik::Error " \
                             "subclass in lib/ declares it",
                      fix: "declare #{code} in lib/, or move its row out of \"#{LIVE_SECTION}\" " \
                           "into the planned tables below it in #{CATALOGUE}")
        end
      end

      # The codes a Markdown page presents as live. Pure, so the test can feed
      # it a page rather than edit the real one.
      #
      # @param markdown [String] the catalogue page
      # @return [Array<String>] codes in the "Live today" section, deduplicated
      def self.documented_codes(markdown)
        body = Markdown.new(markdown).section(LIVE_SECTION)
        return [] if body.nil?

        Markdown.table_rows(body).filter_map { |cells| cells.first[CODE_IN_PROSE, 1] }.uniq
      end

      # @return [MagikScripts::Result]
      def run
        return missing_catalogue unless Repo.exist?(CATALOGUE)

        declared = collect
        return nothing_scanned(corpus: "Magik::Error subclasses", expected: expectation, fix: fix_line) if
          declared.empty?

        documented = self.class.documented_codes(Repo.read(CATALOGUE))
        findings = self.class.audit(declared: declared, documented: documented,
                                    format: Library.load!::Error::CODE_FORMAT)
        return summary(declared, documented) if findings.empty?

        failure(reason: "error_code_drift", expected: expectation, fix: fix_line, findings: findings,
                got: "#{declared.size} error classes, #{documented.size} documented as live, " \
                     "#{findings.size} finding(s)")
      end

      private

      # @return [Array<MagikScripts::Checks::ErrorCodes::Declared>]
      def collect
        base = Library.load!::Error
        Library.error_classes.map do |klass|
          Declared.new(name: klass.name, code: klass.code, fix: klass.fix, at: Library.source_of(klass),
                       own_code: !klass.instance_variable_get(:@code).nil?,
                       own_fix: !klass.instance_variable_get(:@fix).nil?, base: klass == base)
        end
      end

      # @return [MagikScripts::Result]
      def missing_catalogue
        failure(reason: "catalogue_missing", expected: expectation, fix: fix_line,
                got: "#{CATALOGUE} does not exist",
                findings: [Finding.new(code: "MAGIK_ERROR_CODE_UNDOCUMENTED", at: CATALOGUE,
                                       cause: "the catalogue page is gone, so no shipped code can be " \
                                              "looked up by the person who hit it",
                                       fix: "restore #{CATALOGUE} with a \"#{LIVE_SECTION}\" table")])
      end

      # @param declared [Array<MagikScripts::Checks::ErrorCodes::Declared>]
      # @param documented [Array<String>]
      # @return [MagikScripts::Result]
      def summary(declared, documented)
        ok(expected: expectation,
           got: "#{declared.size} error classes, #{declared.map(&:code).uniq.size} unique codes, " \
                "all #{documented.size} documented in #{CATALOGUE}")
      end

      # @return [String]
      def expectation
        "every Magik::Error subclass declares a unique, well-formed MAGIK_* code with a runnable fix:, " \
          "and #{CATALOGUE}'s \"#{LIVE_SECTION}\" table lists exactly those codes"
      end

      # @return [String]
      def fix_line
        "ruby scripts/checks/error_codes.rb   # each finding above names the file to edit"
      end
    end
  end
end

exit MagikScripts::Runner.main(__FILE__, MagikScripts::Checks::ErrorCodes) if $PROGRAM_NAME == __FILE__
