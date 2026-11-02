# frozen_string_literal: true

module Magik
  # Installable progressive web app metadata. Explicitly no offline caching: the server
  # is the single source of truth.
  #
  # Implements: **Phase 8 — i18n, PWA, Notifications** of `docs/idea/00-build-spec.md`.
  #
  # Planned DSL surface, copied from the spec:
  #
  #   * `pwa do name/icon/display end`
  #
  # Status: **Not implemented — spec only.** Every entry point below raises
  # {NotImplementedError}. Nothing here reads config, touches a database or
  # emits a byte of HTML.
  #
  # @see Magik::SUBSYSTEMS
  module PWA
    # The build-spec phase this subsystem implements.
    # @return [String]
    SPEC_PHASE = "Phase 8 — i18n, PWA, Notifications"

    # The DSL this subsystem will expose, verbatim from the spec.
    # @return [Array<String>]
    DSL_SURFACE = [
      "pwa do name/icon/display end"
    ].freeze

    # Implementation status of this subsystem.
    # @return [String]
    STATUS = "Not implemented — spec only"

    # Entry point for the PWA DSL.
    #
    # @param _args [Array] ignored
    # @param _options [Hash] ignored
    # @return [void] never returns
    # @raise [NotImplementedError] always, until Phase 8 lands
    def self.define(*_args, **_options)
      raise NotImplementedError, "Magik::PWA is spec-only; see docs/idea/00-build-spec.md"
    end
  end
end
