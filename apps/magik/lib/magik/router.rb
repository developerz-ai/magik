# frozen_string_literal: true

module Magik
  # Convention-driven routing: an action name becomes a path, a screen auto-routes. Also
  # the dev server and hot reload entry point.
  #
  # Implements: **Phase 2 — Rendering & Actions (build order step 4)** of `docs/idea/00-build-spec.md`.
  #
  # Planned DSL surface, copied from the spec:
  #
  #   * `convention: action name → path`
  #   * `screens are auto-routed by name`
  #
  # Status: **Not implemented — spec only.** Every entry point below raises
  # {NotImplementedError}. Nothing here reads config, touches a database or
  # emits a byte of HTML.
  #
  # @see Magik::SUBSYSTEMS
  module Router
    # The build-spec phase this subsystem implements.
    # @return [String]
    SPEC_PHASE = "Phase 2 — Rendering & Actions (build order step 4)"

    # The DSL this subsystem will expose, verbatim from the spec.
    # @return [Array<String>]
    DSL_SURFACE = [
      "convention: action name → path",
      "screens are auto-routed by name"
    ].freeze

    # Implementation status of this subsystem.
    # @return [String]
    STATUS = "Not implemented — spec only"

    # Entry point for the Router DSL.
    #
    # @param _args [Array] ignored
    # @param _options [Hash] ignored
    # @return [void] never returns
    # @raise [NotImplementedError] always, until Phase 2 lands
    def self.define(*_args, **_options)
      raise NotImplementedError, "Magik::Router is spec-only; see docs/idea/00-build-spec.md"
    end
  end
end
