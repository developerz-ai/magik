#!/usr/bin/env ruby
# frozen_string_literal: true

# @check   spec-only-drift
# @summary Magik::SPEC_ONLY_SUBSYSTEMS matches which subsystems actually refuse to run.
# @order   30
#
# This repository's loudest rule is that it never claims unimplemented
# behaviour. `Magik::SPEC_ONLY_SUBSYSTEMS` is the machine-readable form of that
# claim, and `CLAUDE.md`, `README.md`, `ROADMAP.md` and `wiki/Known-Gaps.md` are
# all downstream of it. A list that stops matching the code turns every one of
# those pages into a lie in the same instant.
#
# So the list is checked against the modules themselves, in both directions:
#
#   MAGIK_DEV_SPEC_ONLY_IMPLEMENTED   listed as spec only, but `.define` no longer
#                                     raises NotImplementedError — a phase landed
#                                     and the list was not updated
#   MAGIK_DEV_SPEC_ONLY_UNLISTED      not on the list, yet still raises — the docs
#                                     now promise something that refuses to run
#   MAGIK_DEV_SPEC_ONLY_STATUS_DRIFT  the module's own STATUS constant disagrees
#                                     with the list
#   MAGIK_DEV_SPEC_ONLY_UNKNOWN       the list names a subsystem that is not in
#                                     Magik::SUBSYSTEMS
#
# `.define` is called for real rather than grepped for, because `raise
# NotImplementedError` in a file proves nothing about whether the entry point
# reaches it. This is safe precisely because the stubs do nothing else: the day
# a `.define` has side effects, it is no longer spec only and this check is what
# says so.

require_relative "../lib/scripts"
require_relative "../lib/library"

module MagikScripts
  module Checks
    # `Magik::SPEC_ONLY_SUBSYSTEMS` versus what the modules actually do.
    class SpecOnlyDrift < Check
      # The status string a spec-only subsystem declares. Pinned here so the
      # phrase cannot drift stub by stub into twenty synonyms.
      # @return [String]
      SPEC_ONLY_STATUS = "Not implemented — spec only"

      # One subsystem, observed. `raises` is nil when there is no `.define`.
      Observed = Struct.new(:name, :constant, :listed, :defines, :raises, :status, :at, :known,
                            keyword_init: true)

      # Every finding implied by a set of observations. Pure.
      #
      # @param observed [Array<MagikScripts::Checks::SpecOnlyDrift::Observed>]
      # @return [Array<MagikScripts::Finding>]
      def self.audit(observed)
        observed.flat_map do |subsystem|
          next [unknown(subsystem)] unless subsystem.known

          [drifted(subsystem), status_drift(subsystem)].compact
        end
      end

      # @param subsystem [MagikScripts::Checks::SpecOnlyDrift::Observed]
      # @return [MagikScripts::Finding, nil]
      def self.drifted(subsystem)
        return implemented(subsystem) if subsystem.listed && !subsystem.raises
        return unlisted(subsystem) if !subsystem.listed && subsystem.raises

        nil
      end

      # @param subsystem [MagikScripts::Checks::SpecOnlyDrift::Observed]
      # @return [MagikScripts::Finding]
      def self.implemented(subsystem)
        detail = subsystem.defines ? "no longer raises NotImplementedError" : "has no .define at all"
        Finding.new(code: "MAGIK_DEV_SPEC_ONLY_IMPLEMENTED", at: subsystem.at,
                    cause: "Magik::SPEC_ONLY_SUBSYSTEMS lists :#{subsystem.name}, but " \
                           "#{subsystem.constant}.define #{detail}",
                    fix: "remove :#{subsystem.name} from SPEC_ONLY_SUBSYSTEMS in lib/magik.rb, set " \
                         "#{subsystem.constant}::STATUS to what is true now, and update the status " \
                         "tables in README.md, ROADMAP.md and wiki/Known-Gaps.md in the same commit")
      end

      # @param subsystem [MagikScripts::Checks::SpecOnlyDrift::Observed]
      # @return [MagikScripts::Finding]
      def self.unlisted(subsystem)
        Finding.new(code: "MAGIK_DEV_SPEC_ONLY_UNLISTED", at: subsystem.at,
                    cause: "#{subsystem.constant}.define raises NotImplementedError, and " \
                           "Magik::SPEC_ONLY_SUBSYSTEMS does not list :#{subsystem.name} — the docs " \
                           "generated from that list promise behaviour that refuses to run",
                    fix: "add :#{subsystem.name} to SPEC_ONLY_SUBSYSTEMS in lib/magik.rb, or implement " \
                         "#{subsystem.constant}.define")
      end

      # @param subsystem [MagikScripts::Checks::SpecOnlyDrift::Observed]
      # @return [MagikScripts::Finding, nil]
      def self.status_drift(subsystem)
        expected = subsystem.listed ? SPEC_ONLY_STATUS : nil
        return nil if expected.nil? || subsystem.status == expected

        Finding.new(code: "MAGIK_DEV_SPEC_ONLY_STATUS_DRIFT", at: subsystem.at,
                    cause: "#{subsystem.constant}::STATUS is #{subsystem.status.inspect}, and the " \
                           "subsystem is listed as spec only, which reads #{expected.inspect}",
                    fix: "set STATUS to #{expected.inspect} in #{subsystem.at}")
      end

      # @param subsystem [MagikScripts::Checks::SpecOnlyDrift::Observed]
      # @return [MagikScripts::Finding]
      def self.unknown(subsystem)
        Finding.new(code: "MAGIK_DEV_SPEC_ONLY_UNKNOWN", at: "lib/magik.rb",
                    cause: "SPEC_ONLY_SUBSYSTEMS names :#{subsystem.name}, which is not a key of " \
                           "Magik::SUBSYSTEMS, so nothing resolves it",
                    fix: "remove :#{subsystem.name} from SPEC_ONLY_SUBSYSTEMS in lib/magik.rb, " \
                         "or add it to SUBSYSTEMS with its file")
      end

      # @return [MagikScripts::Result]
      def run
        observed = collect
        return nothing_scanned(corpus: "Magik::SUBSYSTEMS", expected: expectation, fix: fix_line) if
          observed.empty?

        findings = self.class.audit(observed)
        return summary(observed) if findings.empty?

        failure(reason: "spec_only_drift", expected: expectation, fix: fix_line, findings: findings,
                got: "#{observed.size} subsystems, #{findings.size} disagreement(s) with " \
                     "Magik::SPEC_ONLY_SUBSYSTEMS")
      end

      private

      # @return [Array<MagikScripts::Checks::SpecOnlyDrift::Observed>]
      def collect
        magik = Library.load!
        listed = Library.spec_only.map(&:to_sym)
        known = Library.subsystems.keys.map(&:to_sym)
        rows = known.map { |name| observe(magik, name, listed.include?(name), true) }
        rows + (listed - known).map { |name| observe(magik, name, true, false) }
      end

      # @param magik [Module] the `Magik` module
      # @param name [Symbol] a subsystem file basename
      # @param listed [Boolean] whether SPEC_ONLY_SUBSYSTEMS names it
      # @param known [Boolean] whether SUBSYSTEMS names it
      # @return [MagikScripts::Checks::SpecOnlyDrift::Observed]
      def observe(magik, name, listed, known)
        constant = known ? magik.const_get(magik::SUBSYSTEMS[name]) : nil
        Observed.new(name: name, constant: constant ? constant.name : "Magik::?", listed: listed,
                     known: known, defines: constant.respond_to?(:define),
                     raises: constant && refuses?(constant),
                     status: constant && safe_const(constant, :STATUS),
                     at: known ? "lib/magik/#{name}.rb" : "lib/magik.rb")
      end

      # Does this module's entry point actually refuse to run?
      #
      # @param constant [Module]
      # @return [Boolean]
      def refuses?(constant)
        return false unless constant.respond_to?(:define)

        constant.define
        false
      rescue NotImplementedError
        true
      rescue StandardError
        false
      end

      # @param constant [Module]
      # @param name [Symbol] a constant name
      # @return [Object, nil]
      def safe_const(constant, name)
        constant.const_defined?(name) ? constant.const_get(name) : nil
      end

      # @param observed [Array<MagikScripts::Checks::SpecOnlyDrift::Observed>]
      # @return [MagikScripts::Result]
      def summary(observed)
        spec_only = observed.count(&:listed)
        ok(expected: expectation,
           got: "#{observed.size} subsystems: #{spec_only} spec only and refusing to run, " \
                "#{observed.size - spec_only} not")
      end

      # @return [String]
      def expectation
        "every subsystem in Magik::SPEC_ONLY_SUBSYSTEMS raises NotImplementedError from .define and " \
          "declares STATUS #{SPEC_ONLY_STATUS.inspect}, and no subsystem outside the list does"
      end

      # @return [String]
      def fix_line
        "ruby scripts/checks/spec_only_drift.rb   # then edit SPEC_ONLY_SUBSYSTEMS in lib/magik.rb"
      end
    end
  end
end

exit MagikScripts::Runner.main(__FILE__, MagikScripts::Checks::SpecOnlyDrift) if $PROGRAM_NAME == __FILE__
