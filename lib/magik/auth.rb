# frozen_string_literal: true

module Magik
  # Generated authentication flows, Rodauth-backed.
  #
  # Implements: **Phase 7 — Auth, Billing, Admin** of `docs/idea/00-build-spec.md`.
  #
  # Planned DSL surface, copied from the spec:
  #
  #   * `auth do strategy; oauth_providers; two_factor end`
  #
  # Status: **Not implemented — spec only.** Every entry point below raises
  # {NotImplementedError}. Nothing here reads config, touches a database or
  # emits a byte of HTML.
  #
  # @see Magik::SUBSYSTEMS
  module Auth
    # The build-spec phase this subsystem implements.
    # @return [String]
    SPEC_PHASE = "Phase 7 — Auth, Billing, Admin"

    # The DSL this subsystem will expose, verbatim from the spec.
    # @return [Array<String>]
    DSL_SURFACE = [
      "auth do strategy; oauth_providers; two_factor end"
    ].freeze

    # Implementation status of this subsystem.
    # @return [String]
    STATUS = "Not implemented — spec only"

    # Entry point for the Auth DSL.
    #
    # @param _args [Array] ignored
    # @param _options [Hash] ignored
    # @return [void] never returns
    # @raise [NotImplementedError] always, until Phase 7 lands
    def self.define(*_args, **_options)
      raise NotImplementedError, "Magik::Auth is spec-only; see docs/idea/00-build-spec.md"
    end
  end
end
