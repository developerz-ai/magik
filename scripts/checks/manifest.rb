#!/usr/bin/env ruby
# frozen_string_literal: true

# @check   manifest
# @summary magik.manifest.json still describes the tree it was generated from.
# @order   80
#
# One file at the repo root that answers "what is in this repository" — the
# subsystems with their tier, phase and status, the error codes with the file
# that owns each, and the checks with their cost order. It exists so an agent
# reads one file instead of twenty, and it is generated from the tree so it
# cannot describe a repository that no longer exists.
#
#     ruby scripts/checks/manifest.rb            is it current?
#     ruby scripts/checks/manifest.rb --write    make it current
#
#   MAGIK_MANIFEST_DRIFT      the committed file no longer matches the tree
#   MAGIK_MANIFEST_UNBUILDABLE  the generator itself raised
#
# Stale and broken are separate findings on purpose. "Regenerate it" and "the
# generator is broken" are different problems with different fixes, and a step
# that conflates them costs a debugging loop.
#
# It runs last because it is the only check that reads every other check's
# header: a manifest generated before a new check was added would be stale the
# moment it was written.
#
# Regenerating without comparing would prove only that the generator runs — a
# check that cannot fail, which is worse than no check at all. So `--write` is
# a separate mode, and the default mode never writes.

require_relative "../lib/scripts"
require_relative "../lib/manifest"

module MagikScripts
  module Checks
    # `magik.manifest.json` versus the tree it claims to describe.
    class ManifestCheck < Check
      # `--write` regenerates instead of comparing.
      # @return [Hash{String => Symbol}]
      def self.flags
        { "--write" => :write }
      end

      # @param sections [Array<String>] from {MagikScripts::Manifest.drift}
      # @return [MagikScripts::Finding]
      def self.drift_finding(sections)
        Finding.new(code: "MAGIK_MANIFEST_DRIFT", at: Manifest::PATH,
                    cause: "#{Manifest::PATH} no longer describes this tree: #{sections.join(", ")}",
                    fix: "ruby scripts/checks/manifest.rb --write   # then commit #{Manifest::PATH}")
      end

      # @param error [Exception] whatever the generator raised
      # @return [MagikScripts::Finding]
      def self.broken_finding(error)
        Finding.new(code: "MAGIK_MANIFEST_UNBUILDABLE", at: "scripts/lib/manifest.rb",
                    cause: "the generator raised #{error.class}: #{error.message.to_s.lines.first.to_s.strip}",
                    fix: "ruby scripts/checks/manifest.rb --write   # this is a bug in the generator, " \
                         "not stale data")
      end

      # @return [MagikScripts::Result]
      def run
        fresh = Manifest.build
        return regenerate(fresh) if options[:write]

        sections = Manifest.drift(Manifest.read, fresh)
        return summary(fresh) if sections.empty?

        failure(reason: "manifest_drift", expected: expectation, findings: [self.class.drift_finding(sections)],
                fix: "ruby scripts/checks/manifest.rb --write   # then commit #{Manifest::PATH}",
                got: "#{Manifest::PATH}: #{sections.join(", ")}")
      rescue StandardError => e
        failure(reason: "manifest_unbuildable", expected: expectation,
                findings: [self.class.broken_finding(e)], got: "#{e.class}: #{e.message}",
                fix: "ruby scripts/checks/manifest.rb --write   # read the error it prints")
      end

      private

      # @param fresh [Hash{String => Object}]
      # @return [MagikScripts::Result]
      def regenerate(fresh)
        bytes = Manifest.write(fresh)
        ok(expected: expectation, got: "wrote #{bytes} bytes to #{Manifest::PATH} " \
                                       "(build_id #{fresh["build_id"][0, 12]}...)")
      end

      # @param fresh [Hash{String => Object}]
      # @return [MagikScripts::Result]
      def summary(fresh)
        ok(expected: expectation,
           got: "#{Manifest::PATH} is current: #{fresh["subsystems"].size} subsystems, " \
                "#{fresh["error_codes"].size} error codes, #{fresh["checks"].size} checks " \
                "(build_id #{fresh["build_id"][0, 12]}...)")
      end

      # @return [String]
      def expectation
        "#{Manifest::PATH} matches what `ruby scripts/checks/manifest.rb --write` would write, " \
          "section for section and digest for digest"
      end
    end
  end
end

exit MagikScripts::Runner.main(__FILE__, MagikScripts::Checks::ManifestCheck) if $PROGRAM_NAME == __FILE__
