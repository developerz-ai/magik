# frozen_string_literal: true

module MagikScripts
  # The executable copy of the tier table.
  #
  # `docs/architecture/02-boundaries.md` says it plainly: *"The table is
  # duplicated in `01-module-map.md` and will have an executable copy in
  # `bin/check`. Prose and code must agree; when they diverge, the code is
  # right and the prose is a bug."* This module is that copy, and
  # `scripts/checks/boundaries.rb` re-parses both documents on every run so the
  # duplication cannot rot in silence.
  #
  # There is deliberately no exceptions table. Per the same document: *"the
  # first sideways exception means a tier is wrong. Fix the tier."*
  module Tiers
    # Subsystem => tier. A subsystem may require **strictly lower** tiers only.
    # @return [Hash{String => Integer}]
    TABLE = {
      "core" => 0,
      "schema" => 1, "router" => 1, "i18n" => 1,
      "model" => 2, "render" => 2, "realtime" => 2, "jobs" => 2,
      "action" => 3, "ledger" => 3, "api" => 3, "auth" => 3, "notify" => 3, "pwa" => 3,
      "billing" => 4, "admin" => 4, "domains" => 4,
      "check" => 5, "testing" => 5,
      "cli" => 6
    }.freeze

    # The documents that restate {TABLE} in prose and must agree with it.
    # @return [Array<String>]
    DOCUMENTS = ["docs/architecture/02-boundaries.md", "docs/architecture/01-module-map.md"].freeze

    # How a document writes one row: `tier 2   model, render, realtime, jobs`.
    # @return [Regexp]
    DOC_ROW = /^\s*tier\s+(\d+)\s+(.+?)\s*$/

    module_function

    # @param subsystem [String] a subsystem name
    # @return [Integer, nil] its tier, or nil when it is not a subsystem
    def tier_of(subsystem)
      TABLE[subsystem.to_s]
    end

    # May `from` require `to`?
    #
    # @param from [String] the requiring subsystem
    # @param to [String] the required subsystem
    # @return [Boolean] true when the require goes strictly down a tier
    def allows?(from, to)
      a = tier_of(from)
      b = tier_of(to)
      return false if a.nil? || b.nil?

      a > b
    end

    # Every subsystem `subsystem` is allowed to require, sorted by tier.
    #
    # @param subsystem [String]
    # @return [Array<String>]
    def allowed_for(subsystem)
      tier = tier_of(subsystem)
      return [] if tier.nil?

      TABLE.select { |_, t| t < tier }.keys.sort
    end

    # {TABLE} rendered the way the documents write it, one line per tier.
    #
    # @return [String]
    def render
      TABLE.values.uniq.sort.map do |tier|
        "tier #{tier}   #{TABLE.select { |_, t| t == tier }.keys.join(", ")}"
      end.join("\n")
    end

    # Pull a tier table out of Markdown. Pure, so the negative case is a
    # fixture string rather than an edit to a document this repo owns.
    #
    # @param text [String] Markdown containing `tier N  a, b, c` lines
    # @return [Hash{String => Integer}] subsystem => tier, empty when absent
    def parse_doc(text)
      text.to_s.scan(DOC_ROW).each_with_object({}) do |(tier, names), out|
        names.split(",").map(&:strip).reject(&:empty?).each { |name| out[name] = Integer(tier, 10) }
      end
    end
  end
end
