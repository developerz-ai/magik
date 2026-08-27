#!/usr/bin/env ruby
# frozen_string_literal: true

# @check   error-codes
# @summary Every MAGIK_* code, shipped or reserved, is well-formed, unique, fixable, and documented.
# @order   20
#
# `CLAUDE.md`: *"Every one carries a concrete cause and a runnable `fix:` — a
# command, never advice."* `docs/architecture/03-error-codes.md` adds the format
# and the stability promise. This check turns all of that into a build error.
#
# **Three corpora, because a name is taken the day it is written down.** The
# error classes in `lib/` are eight; the names reserved by the two catalogue
# pages are a hundred and sixteen, and until this check grew a second half they
# drifted freely — the wiki reached 82 codes in a looser `MAGIK_<CONDITION>`
# shape, sixteen of them a second name for a guardrail the spec had already
# named. The third corpus is `bin/`, which used the project's prefix under no
# rule at all until `DEV` was given one.
#
# Over the **shipped classes** reachable from the `Magik` namespace:
#
#   MAGIK_ERROR_CODE_MALFORMED       a code that does not match Magik::Error::CODE_FORMAT
#   MAGIK_ERROR_CODE_UNDECLARED      a subclass that inherited its code instead of
#                                    declaring one — two conditions under one name
#   MAGIK_ERROR_CODE_DUPLICATE       one code owned by two classes
#   MAGIK_ERROR_FIX_ADVICE           a fix: that tells the reader to think rather
#                                    than to run something
#   MAGIK_ERROR_CODE_UNDOCUMENTED    a code that ships and is not in wiki/Error-Codes.md
#   MAGIK_ERROR_CODE_PHANTOM         a code wiki/Error-Codes.md calls live that
#                                    nothing in lib/ actually raises
#   MAGIK_ERROR_CODE_ROOT_MISCLAIMED MAGIK_ERROR on a class that is not Magik::Error,
#                                    or Magik::Error carrying something else
#
# Over the **reserved catalogue** — the `Code` column of every table in
# `docs/idea/03-guardrails.md` and `wiki/Error-Codes.md`
# ({MagikScripts::Checks::ReservedCodes}):
#
#   MAGIK_ERROR_CODE_MALFORMED       a reserved name with no condition part
#   MAGIK_ERROR_CODE_UNKNOWN_SUBSYSTEM  a token outside the closed set
#   MAGIK_ERROR_CODE_NEAR_DUPLICATE  two codes naming one condition
#   MAGIK_ERROR_CODE_RETIRED_SPELLING  a spelling an earlier clean-up replaced
#   MAGIK_ERROR_CODE_UNCATALOGUED    a guardrail the spec names and the manual does not
#
# Over the **developer scripts** in `bin/`, which ship to nobody and can never
# reach an app author ({MagikScripts::Checks::DevCodes}):
#
#   MAGIK_ERROR_CODE_DEV_MALFORMED   a code raised by bin/ that is not MAGIK_DEV_<CONDITION>
#   MAGIK_ERROR_CODE_DEV_UNFIXABLE   a code raised by bin/ whose printed block has no fix: line
#   MAGIK_ERROR_FIX_ADVICE           the same rule as above, over a dev script's fix:
#
# A `DEV` code is deliberately **not** asked for in `wiki/Error-Codes.md`: that
# page is the app author's manual, and an app author cannot run `bin/setup`.
# Nor is `bin/` grepped for the prefix — `MAGIK_YARD_MIN_COVERAGE` and
# `MAGIK_DOCS_ROOT` are environment variables, not codes, and a check that
# could not tell the two apart would demand that configuration be renamed. A
# code is recognised by the `CODE: cause` rendering the repo prescribes, the
# same way the catalogue half recognises one by a table's `Code` column.
#
# Drift between `lib/` and the page is checked in **both** directions, and only
# against the wiki page's "Live today" section: every other table there is
# explicitly seeded from the guardrails and raised by nothing, so holding a
# reserved name to the *shipped* rules would make the check fail for being
# honest. Reserved names are held to the *format* rules instead, which is what
# they can satisfy. The day the catalogue is generated (that page says it will
# be), this check is what proves the generator ran.

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

      # The base class's code. It names no subsystem and no condition because
      # it has neither — see `docs/architecture/03-error-codes.md`.
      # @return [String]
      ROOT_CODE = "MAGIK_ERROR"

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
        shape(declared, format) + duplicates(declared) + drift(declared, documented) + root(declared)
      end

      # `MAGIK_ERROR` is the root code, and the rule is an equivalence rather
      # than an allowlist: a class carries it **if and only if** it is
      # `Magik::Error` itself. An allowlist grows; a rule with exactly one
      # satisfying object cannot.
      #
      # @param declared [Array<MagikScripts::Checks::ErrorCodes::Declared>]
      # @return [Array<MagikScripts::Finding>]
      def self.root(declared)
        declared.filter_map do |error|
          next if (error.code == ROOT_CODE) == (error.base ? true : false)

          Finding.new(code: "MAGIK_ERROR_CODE_ROOT_MISCLAIMED", at: error.at,
                      cause: "#{error.name} carries #{error.code}, and #{ROOT_CODE} belongs to the " \
                             "base class alone — it is the one error that names no subsystem because " \
                             "it has none",
                      fix: root_fix(error))
        end
      end

      # @param error [MagikScripts::Checks::ErrorCodes::Declared]
      # @return [String]
      def self.root_fix(error)
        return "restore `code \"#{ROOT_CODE}\"` on the base class in #{error.at}" if error.base

        "give #{error.name} a MAGIK_<SUBSYSTEM>_<CONDITION> code in #{error.at}"
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
        absent = ReservedCodes::PAGES.reject { |page| Repo.exist?(page) }
        return missing_page(absent.first) unless absent.empty?

        declared = collect
        return empty_corpus("Magik::Error subclasses") if declared.empty?

        catalogued = ReservedCodes::PAGES.flat_map { |page| ReservedCodes.catalogued(Repo.read(page), page) }
        bare = ReservedCodes::PAGES.find { |page| catalogued.none? { |entry| entry.page == page } }
        return empty_corpus("`Code` columns in #{bare}") if bare

        raised = dev_codes
        return empty_corpus(DevCodes::CORPUS) if raised.empty?

        verdict(declared, catalogued, raised)
      end

      private

      # {MagikScripts::Check#nothing_scanned} with this check's expectation and
      # fix line filled in. Three corpora ask the same question, and a
      # per-corpus copy of the two constant arguments is two more places for
      # them to drift.
      #
      # @param corpus [String] what was searched for, and found nothing of
      # @return [MagikScripts::Result]
      def empty_corpus(corpus)
        nothing_scanned(corpus: corpus, expected: expectation, fix: fix_line)
      end

      # The three audits, joined. Split from {#run} so that reading `run` shows
      # what is collected and reading this shows what is asserted.
      #
      # @param declared [Array<MagikScripts::Checks::ErrorCodes::Declared>]
      # @param catalogued [Array<MagikScripts::Checks::ReservedCodes::Code>]
      # @param raised [Array<MagikScripts::Checks::DevCodes::Code>]
      # @return [MagikScripts::Result]
      def verdict(declared, catalogued, raised)
        documented = self.class.documented_codes(Repo.read(CATALOGUE))
        findings = self.class.audit(declared: declared, documented: documented,
                                    format: Library.load!::Error::CODE_FORMAT) +
                   ReservedCodes.audit(catalogued: catalogued) + DevCodes.audit(raised: raised)
        return summary(declared, documented, catalogued, raised) if findings.empty?

        failure(reason: "error_code_drift", expected: expectation, fix: fix_line, findings: findings,
                got: "#{declared.size} error classes, #{documented.size} documented as live, " \
                     "#{catalogued.uniq(&:code).size} reserved names, #{raised.size} dev-script " \
                     "codes, #{findings.size} finding(s)")
      end

      # Every `MAGIK_*` code the repository's own `bin/` scripts raise. Read
      # from the tree here so that {DevCodes.raised} stays a pure function the
      # test can feed a script body to.
      #
      # @return [Array<MagikScripts::Checks::DevCodes::Code>]
      def dev_codes
        Repo.glob(DevCodes::SCRIPTS).flat_map { |script| DevCodes.raised(Repo.read(script), script) }
      end

      # @return [Array<MagikScripts::Checks::ErrorCodes::Declared>]
      def collect
        base = Library.load!::Error
        Library.error_classes.map do |klass|
          Declared.new(name: klass.name, code: klass.code, fix: klass.fix, at: Library.source_of(klass),
                       own_code: !klass.instance_variable_get(:@code).nil?,
                       own_fix: !klass.instance_variable_get(:@fix).nil?, base: klass == base)
        end
      end

      # @param page [String] the catalogue page that is gone
      # @return [MagikScripts::Result]
      def missing_page(page)
        failure(reason: "catalogue_missing", expected: expectation, fix: fix_line,
                got: "#{page} does not exist",
                findings: [Finding.new(code: "MAGIK_ERROR_CODE_UNDOCUMENTED", at: page,
                                       cause: "a catalogue page is gone, so the codes it named can no " \
                                              "longer be looked up by the person who hit one",
                                       fix: "restore #{page} with its `Code` tables")])
      end

      # @param declared [Array<MagikScripts::Checks::ErrorCodes::Declared>]
      # @param documented [Array<String>]
      # @param catalogued [Array<MagikScripts::Checks::ReservedCodes::Code>]
      # @param raised [Array<MagikScripts::Checks::DevCodes::Code>]
      # @return [MagikScripts::Result]
      def summary(declared, documented, catalogued, raised)
        ok(expected: expectation,
           got: "#{declared.size} error classes, #{declared.map(&:code).uniq.size} unique codes, " \
                "all #{documented.size} documented in #{CATALOGUE}; #{catalogued.uniq(&:code).size} " \
                "reserved names across #{ReservedCodes::PAGES.size} catalogues, well-formed and " \
                "unique; #{raised.size} MAGIK_#{DevCodes::TOKEN}_* codes in #{DevCodes::SCRIPTS}, " \
                "each with a runnable fix:")
      end

      # @return [String]
      def expectation
        "every Magik::Error subclass declares a unique, well-formed MAGIK_* code with a runnable fix:, " \
          "#{CATALOGUE}'s \"#{LIVE_SECTION}\" table lists exactly those codes, every reserved " \
          "name in #{ReservedCodes::PAGES.join(" and ")} is MAGIK_<SUBSYSTEM>_<CONDITION> with one " \
          "code per condition, and every code #{DevCodes::SCRIPTS} raises is " \
          "MAGIK_#{DevCodes::TOKEN}_<CONDITION> with a fix: of its own"
      end

      # @return [String]
      def fix_line
        "ruby scripts/checks/error_codes.rb   # each finding above names the file to edit"
      end
    end

    # The reserved half of the error-codes check: every `MAGIK_*` name written
    # down in a catalogue page, held to the format rather than to `lib/`.
    #
    # `docs/architecture/03-error-codes.md` says every reserved name is *"a
    # reserved name, not a shipped one"*, which is exactly why it is cheap to
    # rule on now and permanent if nobody does. The rules here are the four the
    # drift of 2026-08-26 would have caught: an unknown token, a name with no
    # condition, two codes for one condition, and a guardrail the spec names
    # that the manual never lists.
    #
    # **The spec wins every disagreement.** `docs/idea/03-guardrails.md` is the
    # design; `wiki/Error-Codes.md` is the manual written from it. So the
    # containment rule runs in one direction only: a code on the spec page that
    # the manual omits is a finding, and a manual-only code is not — the manual
    # documents runtime failures the guardrail page never had reason to name.
    class ReservedCodes
      # The design, and the page that wins a disagreement.
      # @return [String]
      SPEC = "docs/idea/03-guardrails.md"

      # The manual, written from the spec.
      # @return [String]
      MANUAL = "wiki/Error-Codes.md"

      # Both catalogues, in the order a finding should be read in.
      # @return [Array<String>]
      PAGES = [SPEC, MANUAL].freeze

      # The closed `<SUBSYSTEM>` token set from
      # `docs/architecture/03-error-codes.md#the-allowed-subsystem-tokens`.
      # Four groups, and the page carries the reasoning for each:
      #
      # * the owning module under `lib/magik/`, uppercased — the twenty-one
      #   subsystems of the module map, plus `DOCS`, which ships;
      # * `DOMAIN` and `TEST`, the two singular spellings already in the
      #   catalogue, naming the declaration rather than the directory;
      # * `BOOT`, `CONFIG`, `SCALE`, `BOUNDARY` — stages and cross-cutting
      #   concerns owned by `core` and `check`, where `CORE` would hide which;
      # * `COMPONENT`, `LAYOUT`, `WEBHOOK`, `FLOW` — constructs whose owning
      #   subsystem's name would bury them.
      #
      # The page names a thirty-first token, `DEV`, and it is deliberately
      # absent here: it belongs to `bin/`, and a `MAGIK_DEV_*` code in an
      # app-facing catalogue would be documenting a script the reader cannot
      # run. {MagikScripts::Checks::DevCodes} holds that corpus instead.
      #
      # Adding a token is an architecture change: a row on that page, and this
      # line, in one commit.
      #
      # @return [Array<String>]
      SUBSYSTEMS = %w[
        ACTION ADMIN API AUTH BILLING BOOT BOUNDARY CHECK CLI COMPONENT CONFIG CORE DOCS DOMAIN
        FLOW I18N JOBS LAYOUT LEDGER MODEL NOTIFY POLICY PWA REALTIME RENDER ROUTER SCALE SCHEMA
        TEST WEBHOOK
      ].freeze

      # The one code that names no subsystem, because it is the absence of one.
      # @return [String]
      ROOT_CODE = ErrorCodes::ROOT_CODE

      # `MAGIK_<SUBSYSTEM>_<CONDITION>` — a token, then at least one more word.
      # Stricter than `Magik::Error::CODE_FORMAT`, which must keep admitting
      # {ROOT_CODE} at runtime.
      # @return [Regexp]
      FORMAT = /\AMAGIK_([A-Z0-9]+)(?:_[A-Z0-9]+)+\z/

      # Spellings an earlier clean-up replaced, mapped to the code that
      # replaced them. This is the stability promise pointed backwards: a
      # retired name may never return, for the same reason a shipped one may
      # never move. Sixteen collapsed onto a guardrail the spec had already
      # named; three CLI codes were renamed into the format before anything
      # depended on them; one named a family rather than a condition; and two
      # claimed a `HARNESS` token that is not a subsystem and never became one.
      #
      # @return [Hash{String => String}]
      RETIRED = {
        "MAGIK_PAN_FIELD_FORBIDDEN" => "MAGIK_MODEL_FORBIDDEN_FIELD",
        "MAGIK_TIMEZONE_UNSPECIFIED" => "MAGIK_RENDER_TIMESTAMP_NO_ZONE",
        "MAGIK_TENANT_SCOPE_MISSING" => "MAGIK_SCALE_UNSCOPED_QUERY",
        "MAGIK_MISSING_TENANT" => "MAGIK_MODEL_NO_TENANT",
        "MAGIK_ROUTE_COLLISION" => "MAGIK_ROUTER_PATH_CONFLICT",
        "MAGIK_MONEY_FLOAT" => "MAGIK_MODEL_FLOAT_MONEY",
        "MAGIK_DOMAIN_BOUNDARY_VIOLATION" => "MAGIK_DOMAIN_BOUNDARY",
        "MAGIK_STATEFUL_ACTION" => "MAGIK_ACTION_STATEFUL",
        "MAGIK_STATEFUL_SCREEN" => "MAGIK_RENDER_SCREEN_STATEFUL",
        "MAGIK_IMMUTABLE_RECORD" => "MAGIK_MODEL_IMMUTABLE_VIOLATION",
        "MAGIK_MIGRATION_IRREVERSIBLE" => "MAGIK_SCHEMA_IRREVERSIBLE",
        "MAGIK_IDEMPOTENCY_REQUIRED" => "MAGIK_ACTION_IDEMPOTENCY_REQUIRED",
        "MAGIK_LEDGER_APPEND_ONLY" => "MAGIK_LEDGER_ENTRY_MUTATED",
        "MAGIK_BACKEND_UNKNOWN" => "MAGIK_CONFIG_UNKNOWN_BACKEND",
        "MAGIK_OFFLINE_UNSUPPORTED" => "MAGIK_PWA_OFFLINE_UNSUPPORTED",
        "MAGIK_EVENT_UNPUBLISHED" => "MAGIK_DOMAIN_UNKNOWN_EVENT",
        "MAGIK_UNKNOWN_COMMAND" => "MAGIK_CLI_UNKNOWN_COMMAND",
        "MAGIK_COMMAND_NOT_IMPLEMENTED" => "MAGIK_CLI_COMMAND_NOT_IMPLEMENTED",
        "MAGIK_INVALID_OPTION" => "MAGIK_CLI_INVALID_OPTION",
        "MAGIK_CONFIG_INVALID" => "MAGIK_CONFIG_MISSING_KEY or MAGIK_CONFIG_INVALID_VALUE",
        "MAGIK_HARNESS_STALE" => "MAGIK_CLI_HARNESS_STALE",
        "MAGIK_HARNESS_MARKERS_MISSING" => "MAGIK_CLI_HARNESS_MARKERS_MISSING"
      }.freeze

      # Words that mean the same thing to a reader and therefore must not
      # produce two codes. Kept deliberately short: a wide synonym table
      # collapses conditions that are genuinely different.
      # @return [Hash{String => String}]
      SYNONYMS = { "NO" => "MISSING", "UNSPECIFIED" => "MISSING", "ABSENT" => "MISSING" }.freeze

      # Words that carry no condition of their own — every code is a failure,
      # so saying so adds nothing and hides a duplicate.
      # @return [Array<String>]
      NOISE = %w[VIOLATION VIOLATED FAILED FAILURE ERROR].freeze

      # One reserved name, and where it is written down.
      Code = Struct.new(:code, :page, :line, keyword_init: true) do
        # @return [String] `path:line`, pasteable into an editor
        def at
          "#{page}:#{line}"
        end
      end

      # Every finding implied by the reserved catalogue.
      #
      # @param catalogued [Array<MagikScripts::Checks::ReservedCodes::Code>]
      # @return [Array<MagikScripts::Finding>]
      def self.audit(catalogued:)
        shape(catalogued) + retired(catalogued) + near_duplicates(catalogued) + uncatalogued(catalogued)
      end

      # @param catalogued [Array<MagikScripts::Checks::ReservedCodes::Code>]
      # @return [Array<MagikScripts::Finding>]
      def self.shape(catalogued)
        catalogued.uniq(&:code).filter_map do |entry|
          next if entry.code == ROOT_CODE

          match = FORMAT.match(entry.code)
          next malformed(entry) if match.nil?

          unknown_subsystem(entry, match[1]) unless SUBSYSTEMS.include?(match[1])
        end
      end

      # @param entry [MagikScripts::Checks::ReservedCodes::Code]
      # @return [MagikScripts::Finding]
      def self.malformed(entry)
        Finding.new(code: "MAGIK_ERROR_CODE_MALFORMED", at: entry.at,
                    cause: "#{entry.code} has no <CONDITION> part, so it names a category rather than " \
                           "a specific mistake",
                    fix: "rename it in #{entry.at} to MAGIK_<SUBSYSTEM>_<CONDITION>")
      end

      # @param entry [MagikScripts::Checks::ReservedCodes::Code]
      # @param token [String] the subsystem token it used
      # @return [MagikScripts::Finding]
      def self.unknown_subsystem(entry, token)
        Finding.new(code: "MAGIK_ERROR_CODE_UNKNOWN_SUBSYSTEM", at: entry.at,
                    cause: "#{entry.code} claims the subsystem token #{token}, which is not one of " \
                           "the #{SUBSYSTEMS.size} an app-facing catalogue may use " \
                           "(docs/architecture/03-error-codes.md)",
                    fix: "rename the code in #{entry.at} to one of: #{SUBSYSTEMS.join(" ")}")
      end

      # @param catalogued [Array<MagikScripts::Checks::ReservedCodes::Code>]
      # @return [Array<MagikScripts::Finding>]
      def self.retired(catalogued)
        catalogued.uniq(&:code).filter_map do |entry|
          winner = RETIRED[entry.code]
          next if winner.nil?

          Finding.new(code: "MAGIK_ERROR_CODE_RETIRED_SPELLING", at: entry.at,
                      cause: "#{entry.code} was retired in favour of #{winner}; two spellings of one " \
                             "condition is the drift this rule exists to stop coming back",
                      fix: "replace #{entry.code} with #{winner} in #{entry.at}")
        end
      end

      # Two codes naming one condition. The test is deliberately narrow — the
      # same words, reordered, or with the subsystem token added — because that
      # is the shape the real drift took (`MAGIK_STATEFUL_ACTION` beside
      # `MAGIK_ACTION_STATEFUL`) and a looser test would flag
      # `MAGIK_LAYOUT_MISSING` against `MAGIK_POLICY_UNDECLARED`. What it misses,
      # {RETIRED} remembers by name.
      #
      # A code whose key is empty — {ROOT_CODE} is the only one — is skipped:
      # it names no condition, so it cannot be a second name for one.
      #
      # @param catalogued [Array<MagikScripts::Checks::ReservedCodes::Code>]
      # @return [Array<MagikScripts::Finding>]
      def self.near_duplicates(catalogued)
        named = catalogued.uniq(&:code).reject { |entry| key(entry.code).empty? }
        named.combination(2).filter_map do |first, second|
          next unless one_condition?(first.code, second.code)

          Finding.new(code: "MAGIK_ERROR_CODE_NEAR_DUPLICATE", at: [first.at, second.at].min,
                      cause: "#{first.code} (#{first.at}) and #{second.code} (#{second.at}) name one " \
                             "condition with two codes, so no log pipeline can match both",
                      fix: "delete one of them and point every reference at the other, " \
                           "then add the retired spelling to RETIRED in scripts/checks/error_codes.rb")
        end
      end

      # @param first [String]
      # @param second [String]
      # @return [Boolean]
      def self.one_condition?(first, second)
        left = key(first)
        right = key(second)
        return true if left == right

        prefixed?(first, left, right) || prefixed?(second, right, left)
      end

      # @param code [String] the longer candidate
      # @param long [Array<String>] its key
      # @param short [Array<String>] the other key
      # @return [Boolean] true when `long` is `short` plus `code`'s own subsystem token
      def self.prefixed?(code, long, short)
        return false unless long.size == short.size + 1

        token = code.delete_prefix("MAGIK_").split("_").first
        SUBSYSTEMS.include?(token) && (long - [token]) == short
      end

      # A code reduced to the condition it names: its words, normalised and
      # sorted, so order and noise cannot hide a second name for one rule.
      #
      # @param code [String]
      # @return [Array<String>]
      def self.key(code)
        code.delete_prefix("MAGIK_").split("_")
            .map { |word| SYNONYMS.fetch(word, word) }
            .reject { |word| NOISE.include?(word) }
            .sort
      end

      # @param catalogued [Array<MagikScripts::Checks::ReservedCodes::Code>]
      # @return [Array<MagikScripts::Finding>]
      def self.uncatalogued(catalogued)
        by_page = catalogued.group_by(&:page)
        manual = (by_page[MANUAL] || []).map(&:code)
        (by_page[SPEC] || []).uniq(&:code).reject { |entry| manual.include?(entry.code) }.map do |entry|
          Finding.new(code: "MAGIK_ERROR_CODE_UNCATALOGUED", at: entry.at,
                      cause: "#{entry.code} is a guardrail in #{SPEC} and appears in no table in " \
                             "#{MANUAL}, so an app author who hits it cannot look it up",
                      fix: "add a row for #{entry.code} to #{MANUAL}")
        end
      end

      # Every code in the `Code` column of every table on a page. The column is
      # found by its header rather than by position, because the two pages
      # shape their tables differently and a position would silently read the
      # wrong column the day one of them gains a field.
      #
      # @param markdown [String] the page
      # @param page [String] its root-relative path, for findings
      # @return [Array<MagikScripts::Checks::ReservedCodes::Code>]
      def self.catalogued(markdown, page)
        table = { header: nil, column: nil }
        markdown.each_line.with_index(1).flat_map { |line, number| scan(line.strip, number, page, table) }
      end

      # One line of a page, against the table state carried between lines. A
      # blank line ends a table and clears the state, so the next table finds
      # its own `Code` column instead of inheriting the previous one's.
      #
      # @param stripped [String] the line, trimmed
      # @param number [Integer] the 1-based line
      # @param page [String]
      # @param table [Hash] mutable `:header` / `:column` state
      # @return [Array<MagikScripts::Checks::ReservedCodes::Code>]
      def self.scan(stripped, number, page, table)
        unless stripped.start_with?("|")
          table[:header] = nil
          table[:column] = nil
          return []
        end

        if Markdown.separator?(stripped)
          table[:column] = table[:header]&.index { |cell| cell.casecmp?("code") }
          return []
        end

        if table[:column].nil?
          table[:header] = Markdown.cells(stripped)
          return []
        end

        row(Markdown.cells(stripped)[table[:column]], page, number)
      end

      # @param cell [String, nil] the row's `Code` cell
      # @param page [String]
      # @param number [Integer] the 1-based line
      # @return [Array<MagikScripts::Checks::ReservedCodes::Code>]
      def self.row(cell, page, number)
        cell.to_s.scan(ErrorCodes::CODE_IN_PROSE).flatten.map do |code|
          Code.new(code: code, page: page, line: number)
        end
      end
    end

    # The third corpus: the `MAGIK_*` codes this repository's own developer
    # scripts raise. `bin/` ships to nobody — it is not in the gem, it is not
    # generated into an app, and no app author can reach one — so
    # `wiki/Error-Codes.md` would be lying if it listed these, and this half
    # deliberately never asks it to. That is the one rule it drops.
    #
    # It keeps every other one, because the codes keep the `MAGIK_` prefix, and
    # that is why this class exists at all. An agent working in this repository
    # reads `MAGIK_DEV_NO_RAKE` off its terminal and searches for it exactly the
    # way it searches for `MAGIK_LEDGER_UNBALANCED`: the string has to be
    # findable, and it must not collide with a name the framework will want
    # later. A token of its own is what buys both.
    #
    # **A code is recognised by its rendering, not by its prefix.**
    # `MAGIK_YARD_MIN_COVERAGE` and `MAGIK_DOCS_ROOT` are environment
    # variables, and a check that grepped for `MAGIK_*` would call both
    # malformed codes and demand that configuration be renamed into a format
    # that does not apply to it. {RAISED} matches the `CODE: cause` line an
    # error is *printed* as — the same discipline as {ReservedCodes}, which
    # reads a table's `Code` column rather than the whole page.
    class DevCodes
      # The scripts this half reads, as a {MagikScripts::Repo.glob} pattern.
      # @return [String]
      SCRIPTS = "bin/*"

      # The one `<SUBSYSTEM>` token a developer script may claim.
      # @return [String]
      TOKEN = "DEV"

      # What an empty run calls the corpus, so the failure names what was
      # looked for rather than where it looked.
      # @return [String]
      CORPUS = "`MAGIK_#{TOKEN}_*: cause` lines in #{SCRIPTS}".freeze

      # `MAGIK_DEV_<CONDITION>`, and nothing else.
      # @return [Regexp]
      FORMAT = /\AMAGIK_#{TOKEN}(?:_[A-Z0-9]+)+\z/

      # What {rename} strips before it puts the token back: the prefix, and the
      # token if the code already carried it.
      # @return [Regexp]
      OWN_PREFIX = /\A#{TOKEN}_?/

      # A code as a script prints it: the name, a colon, then the cause. An
      # environment variable is never written this way, which is the whole
      # point of matching the rendering instead of the prefix.
      # @return [Regexp]
      RAISED = /\b(MAGIK_[A-Z0-9_]+):/

      # The `fix:` line, and everything after the colon.
      # @return [Regexp]
      FIX = /\bfix:\s*(.+)/

      # How far below the code line a `fix:` may sit — the block a reader sees
      # in one screenful. Bounded rather than open-ended, so the `fix:` of the
      # *next* failure two hundred lines down cannot satisfy this one.
      # @return [Integer]
      BLOCK = 24

      # One code, the line that prints it, and the fix: printed with it.
      Code = Struct.new(:code, :script, :line, :fix, keyword_init: true) do
        # @return [String] `path:line`, pasteable into an editor
        def at
          "#{script}:#{line}"
        end
      end

      # Every finding implied by what `bin/` raises.
      #
      # @param raised [Array<MagikScripts::Checks::DevCodes::Code>]
      # @return [Array<MagikScripts::Finding>]
      def self.audit(raised:)
        raised.flat_map { |entry| [malformed(entry), unfixable(entry), advice(entry)].compact }
      end

      # @param entry [MagikScripts::Checks::DevCodes::Code]
      # @return [MagikScripts::Finding, nil]
      def self.malformed(entry)
        return nil if FORMAT.match?(entry.code)

        Finding.new(code: "MAGIK_ERROR_CODE_DEV_MALFORMED", at: entry.at,
                    cause: "#{entry.script} prints #{entry.code}, and a developer script's codes are " \
                           "MAGIK_#{TOKEN}_<CONDITION> so that they cannot collide with a framework " \
                           "code an app author can actually hit",
                    fix: "rename #{entry.code} to #{rename(entry.code)} in #{entry.at}")
      end

      # The name it should have had. Concrete on purpose: a `fix:` line is
      # something somebody pastes, and `MAGIK_DEV_<CONDITION>` is not.
      #
      # @param code [String]
      # @return [String]
      def self.rename(code)
        condition = code.delete_prefix("MAGIK_").sub(OWN_PREFIX, "")
        condition.empty? ? "MAGIK_#{TOKEN}_<CONDITION>" : "MAGIK_#{TOKEN}_#{condition}"
      end

      # @param entry [MagikScripts::Checks::DevCodes::Code]
      # @return [MagikScripts::Finding, nil]
      def self.unfixable(entry)
        return nil unless entry.fix.to_s.strip.empty?

        Finding.new(code: "MAGIK_ERROR_CODE_DEV_UNFIXABLE", at: entry.at,
                    cause: "#{entry.code} is printed with no fix: line in the #{BLOCK} lines below " \
                           "it, so it says what is wrong and never what to run",
                    fix: "add a fix: line naming the command that resolves it, below #{entry.at}")
      end

      # The same rule {ErrorCodes.advice} applies to a shipped class, over the
      # text a script prints. One list of phrases, so the two corpora cannot
      # disagree about what counts as advice.
      #
      # @param entry [MagikScripts::Checks::DevCodes::Code]
      # @return [MagikScripts::Finding, nil]
      def self.advice(entry)
        return nil if entry.fix.to_s.strip.empty?
        return nil if ErrorCodes::ADVICE.none? { |pattern| pattern.match?(entry.fix) }

        Finding.new(code: "MAGIK_ERROR_FIX_ADVICE", at: entry.at,
                    cause: "#{entry.code}'s fix: reads #{entry.fix.inspect}, which tells the reader to " \
                           "think rather than to run something",
                    fix: "replace the fix: line below #{entry.at} with a command")
      end

      # Every code a script prints, with the fix: that follows it. Pure, so the
      # test can hand it a script body instead of editing `bin/`.
      #
      # @param source [String] the script
      # @param script [String] its root-relative path, for findings
      # @return [Array<MagikScripts::Checks::DevCodes::Code>]
      def self.raised(source, script)
        lines = source.lines
        lines.each_with_index.filter_map do |line, index|
          name = line[RAISED, 1]
          next if name.nil?

          Code.new(code: name, script: script, line: index + 1, fix: fix_after(lines, index))
        end
      end

      # @param lines [Array<String>] the whole script
      # @param index [Integer] the 0-based line the code was printed on
      # @return [String, nil] the fix text, or nil when the block carries none
      def self.fix_after(lines, index)
        line = lines[index + 1, BLOCK].to_a.find { |candidate| FIX.match?(candidate) }
        line.nil? ? nil : trim(line[FIX, 1])
      end

      # The fix text with the shell or Ruby that carried it trimmed off: a
      # redirect, a closing quote and a closing paren belong to the line that
      # printed the fix, not to the fix.
      #
      # @param text [String]
      # @return [String]
      def self.trim(text)
        text.strip.sub(/\s*>&\d+\s*\z/, "").sub(/["')]+\s*\z/, "").strip
      end
    end
  end
end

exit MagikScripts::Runner.main(__FILE__, MagikScripts::Checks::ErrorCodes) if $PROGRAM_NAME == __FILE__
