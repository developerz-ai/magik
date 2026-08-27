#!/usr/bin/env ruby
# frozen_string_literal: true

# @check   migration-safety
# @summary A destructive migration carries an explicit acknowledgement, and no two migrations share a prefix.
# @order   30
#
# Migrations in a Magik app are hand-written and append-only. Two failure modes
# are worth a gate:
#
#   APP_MIGRATION_DESTRUCTIVE_UNACKNOWLEDGED
#     `drop_table`, `drop_column`, `remove_column`, `rename_column`,
#     `rename_table` and `drop_index` destroy data or break a running deploy's
#     old code. None of them is forbidden — a schema that can never shrink is
#     its own problem — but each must be a decision somebody wrote down. Add
#     the acknowledgement line above the operation:
#
#         # magik:destructive acknowledged — the column has been unused since
#         # 2026-07 and the data is in the ledger.
#
#     That is one line an author has to type, and it turns an accident into a
#     sentence a reviewer can disagree with.
#
#   APP_MIGRATION_PREFIX_DUPLICATE
#     Two migrations claiming one ordinal apply in an order that depends on the
#     filesystem, which means two machines can end up with different schemas.
#
# An app with no migrations yet is not applicable — a pass.

require_relative "../lib/scripts"

module AppScripts
  module Checks
    # Migration hygiene, as an assertion.
    class MigrationSafety < Check
      # Where migrations live, and the ordinal that sequences them.
      GLOB = "db/migrations/*.rb"
      PREFIX = /\A(\d+)_/

      # Operations that destroy data or break a rolling deploy.
      DESTRUCTIVE = /^\s*(drop_table|drop_column|remove_column|rename_column|rename_table|drop_index)\b/

      # The opt-in. Anywhere in the file, because a migration is short and
      # requiring it on the exact preceding line is a rule people fight.
      ACKNOWLEDGEMENT = /#\s*magik:destructive\s+acknowledged/

      # One migration, flattened to data so the rule below is pure.
      Migration = Struct.new(:path, :prefix, :body, keyword_init: true)

      # The pure rule. Give it migrations, get findings — no filesystem, so a
      # test can hand it a fixture and assert the negative case.
      #
      # @param migrations [Array<Migration>]
      # @return [Array<AppScripts::Finding>]
      def self.findings_for(migrations)
        duplicate_prefixes(migrations) + unacknowledged(migrations)
      end

      # @return [Array<AppScripts::Finding>]
      def self.duplicate_prefixes(migrations)
        migrations.group_by(&:prefix).reject { |prefix, group| prefix.nil? || group.size < 2 }
                  .map do |prefix, group|
          Finding.new(code: "APP_MIGRATION_PREFIX_DUPLICATE", at: group.first.path,
                      cause: "#{group.size} migrations claim ordinal #{prefix}: #{group.map(&:path).join(", ")}",
                      fix: "renumber all but one — a later ordinal, never an earlier one, " \
                           "because an applied migration is frozen")
        end
      end

      # @return [Array<AppScripts::Finding>]
      def self.unacknowledged(migrations)
        migrations.reject { |migration| ACKNOWLEDGEMENT.match?(migration.body) }.flat_map do |migration|
          migration.body.each_line.with_index(1).filter_map do |line, number|
            operation = line[DESTRUCTIVE, 1]
            next if operation.nil?

            Finding.new(code: "APP_MIGRATION_DESTRUCTIVE_UNACKNOWLEDGED", at: "#{migration.path}:#{number}",
                        cause: "`#{operation}` destroys data or breaks the running deploy's old code, " \
                               "and this migration carries no acknowledgement",
                        fix: "add `# magik:destructive acknowledged — <why it is safe>` to " \
                             "#{migration.path}, above the operation")
          end
        end
      end

      # @return [AppScripts::Result]
      def run
        paths = Root.glob(GLOB)
        return not_applicable(because: "no migrations yet — db/migrations/ is empty", expected: expectation) if
          paths.empty?

        migrations = paths.map do |rel|
          Migration.new(path: rel, prefix: File.basename(rel)[PREFIX, 1], body: Root.read(rel))
        end
        findings = self.class.findings_for(migrations)
        return failure(reason: "unsafe_migration", expected: expectation, fix: fix_line, findings: findings) if
          findings.any?

        ok(expected: expectation, got: "#{migrations.size} migrations scanned, ordinals unique")
      end

      private

      # @return [String]
      def expectation
        "every destructive migration carries `# magik:destructive acknowledged — <why>`, " \
          "and every migration has a unique ordinal"
      end

      # @return [String]
      def fix_line
        "ruby scripts/checks/migration_safety.rb   # each finding names the file and the line"
      end
    end
  end
end

exit AppScripts::Runner.main(__FILE__, AppScripts::Checks::MigrationSafety) if $PROGRAM_NAME == __FILE__
