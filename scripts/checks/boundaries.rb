#!/usr/bin/env ruby
# frozen_string_literal: true

# @check   boundaries
# @summary Requires and constant references inside lib/magik/ go down a tier only.
# @order   10
#
# `docs/architecture/02-boundaries.md` states the rule: imports go DOWN a tier
# only — never sideways within a tier, never upward — and a subsystem reaches
# another only through its front door, `lib/magik/<other>.rb`. The same document
# says the table "will have an executable copy"; `scripts/lib/tiers.rb` is it,
# and this check is what makes the copy authoritative:
#
#     tier 0   core
#     tier 1   schema, router, i18n
#     tier 2   model, render, realtime, jobs
#     tier 3   action, ledger, api, auth, notify, pwa
#     tier 4   billing, admin, domains
#     tier 5   check, testing
#     tier 6   cli
#
# Three findings:
#
#   MAGIK_DEV_BOUNDARY_TIER               a sideways or upward require, or a
#                                         sideways or upward constant reference
#   MAGIK_DEV_BOUNDARY_INTERNAL_REQUIRE   reaching past another subsystem's front
#                                         door, even when the tier would allow it
#   MAGIK_DEV_BOUNDARY_TABLE_DRIFT        a document restates the table and no
#                                         longer agrees with the code
#
# `lib/magik.rb` and `lib/magik/version.rb` are exempt and are not subsystems.
# The entry point's whole job is to know every subsystem — it registers the
# autoloads — and the version constant belongs to all of them.
#
# Today every subsystem is a single spec-only file that requires nothing but the
# standard library, so this check cannot fail on requires yet. That is exactly
# why it exists now: the first `require "magik/render"` typed into
# `lib/magik/model/` is the moment the architecture starts to rot, and the run
# after that one is where it has to be caught.

require_relative "../lib/scripts"
require_relative "../lib/library"
require_relative "../lib/ruby_source"

module MagikScripts
  module Checks
    # Tier and front-door enforcement over `lib/magik/`.
    class Boundaries < Check
      # A sideways or upward dependency.
      # @return [String]
      TIER_CODE = "MAGIK_DEV_BOUNDARY_TIER"

      # A require that reaches past another subsystem's front door.
      # @return [String]
      INTERNAL_CODE = "MAGIK_DEV_BOUNDARY_INTERNAL_REQUIRE"

      # A document whose tier table no longer matches `scripts/lib/tiers.rb`.
      # @return [String]
      DRIFT_CODE = "MAGIK_DEV_BOUNDARY_TABLE_DRIFT"

      # Everything this check reads.
      # @return [String]
      CORPUS = "lib/**/*.rb"

      # Ruby that lives under `lib/` and is not framework source. Generator
      # templates are files copied into somebody else's application: they sit
      # inside the `cli` directory, but their requires and constants describe an
      # app's dependency graph, not Magik's, and holding them to Magik's tier
      # table would be checking the wrong repository.
      # @return [String]
      TEMPLATES = "lib/magik/cli/templates/"

      # How many table differences a drift finding spells out before eliding.
      # A cause is a diagnosis, not a dump: past a handful of rows the answer
      # is "the block was rewritten", and the fix line already carries the
      # correct block verbatim.
      # @return [Integer]
      DIFFERENCES_SHOWN = 6

      # One file, with the subsystem that owns it. `subsystem` is nil for the
      # exempt entry point and version file.
      Source = Struct.new(:path, :subsystem, :body, keyword_init: true)

      # Which subsystem a path belongs to.
      #
      # @param path [String] a root-relative path
      # @return [String, nil] the subsystem name, or nil when the path is not
      #   inside one
      def self.owner(path)
        name = path[%r{\Alib/magik/([a-z0-9_]+)(?:/|\.rb\z)}, 1]
        Tiers::TABLE.key?(name.to_s) ? name : nil
      end

      # @param subsystem [String]
      # @return [String] the only file another subsystem may require
      def self.front_door(subsystem)
        "lib/magik/#{subsystem}.rb"
      end

      # Every tier and front-door violation in `sources`. Pure: the test feeds
      # it fixtures, so the negative case never touches the real tree.
      #
      # @param sources [Array<MagikScripts::Checks::Boundaries::Source>]
      # @return [Array<MagikScripts::Finding>]
      def self.violations(sources)
        sources.reject { |source| source.subsystem.nil? }
               .flat_map { |source| require_findings(source) + reference_findings(source) }
      end

      # @param source [MagikScripts::Checks::Boundaries::Source]
      # @return [Array<MagikScripts::Finding>]
      def self.require_findings(source)
        RubySource.requires(source.body).filter_map do |statement|
          target, past_door = resolve(source, statement)
          next if target.nil? || target == source.subsystem

          at = "#{source.path}:#{statement.line}"
          next internal_finding(source, target, statement, at) if past_door

          tier_finding(source, target, at, "requires") unless Tiers.allows?(source.subsystem, target)
        end
      end

      # @param source [MagikScripts::Checks::Boundaries::Source]
      # @return [Array<MagikScripts::Finding>]
      def self.reference_findings(source)
        RubySource.constant_refs(source.body).filter_map do |reference|
          target = subsystem_for_constant(reference.name)
          next if target.nil? || target == source.subsystem
          next if Tiers.allows?(source.subsystem, target)

          tier_finding(source, target, "#{source.path}:#{reference.line}", "names #{reference.name}, owned by")
        end
      end

      # Where a require points, and whether it reaches past the front door.
      #
      # @param source [MagikScripts::Checks::Boundaries::Source]
      # @param statement [MagikScripts::RubySource::Require]
      # @return [Array(String, Boolean), Array(nil, nil)]
      def self.resolve(source, statement)
        path =
          if statement.relative
            File.expand_path(statement.spec, "/#{File.dirname(source.path)}").delete_prefix("/")
          else
            statement.spec.start_with?("magik/") ? "lib/#{statement.spec}" : nil
          end
        return [nil, nil] if path.nil?

        path = "#{path}.rb" unless path.end_with?(".rb")
        target = owner(path)
        [target, !target.nil? && path != front_door(target)]
      end

      # @param name [String] a constant path such as `"Magik::Render"` or `"Render"`
      # @return [String, nil] the subsystem that owns it
      def self.subsystem_for_constant(name)
        constants[name.delete_prefix("Magik::")]
      end

      # Subsystem constant name => subsystem file basename.
      # @return [Hash{String => String}]
      def self.constants
        @constants ||= Library.subsystems.to_h { |file, const| [const.to_s, file.to_s] }
      end

      # @param source [MagikScripts::Checks::Boundaries::Source]
      # @param target [String] the subsystem being reached for
      # @param at [String] `file:line`
      # @param verb [String] how the dependency is expressed
      # @return [MagikScripts::Finding]
      def self.tier_finding(source, target, at, verb)
        from = source.subsystem
        allowed = Tiers.allowed_for(from)
        may_use = allowed.empty? ? "nothing at all — it is the bottom tier" : allowed.join(", ")
        Finding.new(
          code: TIER_CODE, at: at,
          cause: "#{from} (tier #{Tiers.tier_of(from)}) #{verb} #{target} (tier #{Tiers.tier_of(target)}); " \
                 "dependencies go down a tier only, never sideways and never up",
          fix: "delete the dependency at #{at} — #{from} may use: #{may_use}. " \
               "If the edge is right, the tier is wrong: argue it in docs/architecture/02-boundaries.md " \
               "and change scripts/lib/tiers.rb in the same commit"
        )
      end

      # @param source [MagikScripts::Checks::Boundaries::Source]
      # @param target [String] the subsystem being reached into
      # @param statement [MagikScripts::RubySource::Require]
      # @param at [String] `file:line`
      # @return [MagikScripts::Finding]
      def self.internal_finding(source, target, statement, at)
        Finding.new(
          code: INTERNAL_CODE, at: at,
          cause: "#{source.subsystem} requires #{statement.spec.inspect}, an internal file of #{target}; " \
                 "#{front_door(target)} is the only file another subsystem may require",
          fix: "require \"magik/#{target}\" at #{at}, and expose what you need from " \
               "#{front_door(target)}"
        )
      end

      # Every document that restates the tier table and no longer agrees with
      # `scripts/lib/tiers.rb`. Pure: `documents` is path => Markdown text.
      #
      # @param documents [Hash{String => String}]
      # @return [Array<MagikScripts::Finding>]
      def self.drift(documents)
        documents.filter_map do |path, text|
          stated = Tiers.parse_doc(text)
          next if stated == Tiers::TABLE

          Finding.new(code: DRIFT_CODE, at: path, cause: drift_cause(path, stated),
                      fix: "edit the `tier N` block in #{path} to read exactly:\n#{indent(Tiers.render)}")
        end
      end

      # @param path [String] the document
      # @param stated [Hash{String => Integer}] what it says
      # @return [String]
      def self.drift_cause(path, stated)
        return "#{path} states no `tier N   ...` table; the tier rule has no prose left to check against" if
          stated.empty?

        differences = (stated.keys | Tiers::TABLE.keys).filter_map do |name|
          next if stated[name] == Tiers::TABLE[name]

          "#{name}: doc says #{stated[name].inspect}, scripts/lib/tiers.rb says #{Tiers::TABLE[name].inspect}"
        end
        shown = differences.first(DIFFERENCES_SHOWN).join("; ")
        elided = differences.size - DIFFERENCES_SHOWN
        shown += " (and #{elided} more)" if elided.positive?
        "#{path} disagrees with the executable table — #{shown}"
      end

      # @param text [String]
      # @return [String] the same text, indented for a fix line
      def self.indent(text)
        text.lines.map { |line| "           #{line}" }.join
      end

      # @return [MagikScripts::Result]
      def run
        sources = collect
        return nothing_scanned(corpus: CORPUS, expected: expectation, fix: fix_line) if sources.empty?

        findings = self.class.violations(sources) + self.class.drift(documents)
        return summary(sources) if findings.empty?

        failure(reason: "boundary_violation", expected: expectation, fix: fix_line, findings: findings,
                got: "#{findings.size} violation(s) across #{sources.size} files")
      end

      private

      # @return [Array<MagikScripts::Checks::Boundaries::Source>]
      def collect
        Repo.glob(CORPUS).reject { |path| path.start_with?(TEMPLATES) }.map do |path|
          Source.new(path: path, subsystem: self.class.owner(path), body: Repo.read(path))
        end
      end

      # @return [Hash{String => String}] the documents that restate the table
      def documents
        Tiers::DOCUMENTS.select { |path| Repo.exist?(path) }.to_h { |path| [path, Repo.read(path)] }
      end

      # @param sources [Array<MagikScripts::Checks::Boundaries::Source>]
      # @return [MagikScripts::Result]
      def summary(sources)
        owned = sources.count(&:subsystem)
        ok(expected: expectation,
           got: "#{sources.size} files scanned (#{owned} inside a subsystem), " \
                "#{Tiers::TABLE.size} subsystems tiered, #{documents.size} documents agree")
      end

      # @return [String]
      def expectation
        "every require and constant reference inside lib/magik/ names a strictly lower tier " \
          "through that subsystem's front door, and every document restating the tier table agrees " \
          "with scripts/lib/tiers.rb"
      end

      # @return [String]
      def fix_line
        "ruby scripts/checks/boundaries.rb   # each finding above names the edit that clears it"
      end
    end
  end
end

exit MagikScripts::Runner.main(__FILE__, MagikScripts::Checks::Boundaries) if $PROGRAM_NAME == __FILE__
