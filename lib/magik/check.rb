# frozen_string_literal: true

module Magik
  # The guardrail linter. The guardrails are the product: ledgers must balance, `field
  # :card_number` is refused, domain boundaries hold, screens and actions hold no
  # in-process state, timestamps carry a timezone.
  #
  # Implements: **Build order step 13 — `magik check` linter** of `docs/idea/00-build-spec.md`.
  #
  # Planned DSL surface, copied from the spec:
  #
  #   * `magik check --scale — warns on queries missing tenant_id in WHERE`
  #   * `boot guardrails enforced as a standalone lint pass`
  #
  # Status: **Not implemented — spec only.** Every entry point below raises
  # {NotImplementedError}. Nothing here reads config, touches a database or
  # emits a byte of HTML.
  #
  # @see Magik::SUBSYSTEMS
  module Check
    # The build-spec phase this subsystem implements.
    # @return [String]
    SPEC_PHASE = "Build order step 13 — `magik check` linter"

    # The DSL this subsystem will expose, verbatim from the spec.
    # @return [Array<String>]
    DSL_SURFACE = [
      "magik check --scale — warns on queries missing tenant_id in WHERE",
      "boot guardrails enforced as a standalone lint pass"
    ].freeze

    # Implementation status of this subsystem.
    # @return [String]
    STATUS = "Not implemented — spec only"

    # Entry point for the Check DSL.
    #
    # @param _args [Array] ignored
    # @param _options [Hash] ignored
    # @return [void] never returns
    # @raise [NotImplementedError] always, until Build order step 13 lands
    def self.define(*_args, **_options)
      raise NotImplementedError, "Magik::Check is spec-only; see docs/idea/00-build-spec.md"
    end
  end
end
