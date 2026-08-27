# frozen_string_literal: true

module Magik
  # Double-entry ledgers with boot-time balance validation and append-only entries, plus
  # the audit and multi-step flow primitives that fintech work needs.
  #
  # Implements: **Phase 5 — Money & Compliance** of `docs/idea/00-build-spec.md`.
  #
  # Planned DSL surface, copied from the spec:
  #
  #   * `ledger :Name do account; entry do debit/credit/guard end end`
  #   * `audited + immutable_after: model annotations`
  #   * `flow :Name do step ... end — multi-step wizards`
  #
  # Status: **Not implemented — spec only.** Every entry point below raises
  # {NotImplementedError}. Nothing here reads config, touches a database or
  # emits a byte of HTML.
  #
  # @see Magik::SUBSYSTEMS
  module Ledger
    # The build-spec phase this subsystem implements.
    # @return [String]
    SPEC_PHASE = "Phase 5 — Money & Compliance"

    # The DSL this subsystem will expose, verbatim from the spec.
    # @return [Array<String>]
    DSL_SURFACE = [
      "ledger :Name do account; entry do debit/credit/guard end end",
      "audited + immutable_after: model annotations",
      "flow :Name do step ... end — multi-step wizards"
    ].freeze

    # Implementation status of this subsystem.
    # @return [String]
    STATUS = "Not implemented — spec only"

    # Entry point for the Ledger DSL.
    #
    # @param _args [Array] ignored
    # @param _options [Hash] ignored
    # @return [void] never returns
    # @raise [NotImplementedError] always, until Phase 5 lands
    def self.define(*_args, **_options)
      raise NotImplementedError, "Magik::Ledger is spec-only; see docs/idea/00-build-spec.md"
    end
  end
end
