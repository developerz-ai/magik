# frozen_string_literal: true

module Magik
  # Mutation handlers, auto-wired to htmx POST requests.
  #
  # Implements: **Phase 2 — Rendering & Actions** of `docs/idea/00-build-spec.md`.
  #
  # Planned DSL surface, copied from the spec:
  #
  #   * `action :name do |params| ... end`
  #   * `idempotent_by on actions — dedupes retried mutations`
  #
  # Status: **Not implemented — spec only.** Every entry point below raises
  # {NotImplementedError}. Nothing here reads config, touches a database or
  # emits a byte of HTML.
  #
  # @see Magik::SUBSYSTEMS
  module Action
    # The build-spec phase this subsystem implements.
    # @return [String]
    SPEC_PHASE = "Phase 2 — Rendering & Actions"

    # The DSL this subsystem will expose, verbatim from the spec.
    # @return [Array<String>]
    DSL_SURFACE = [
      "action :name do |params| ... end",
      "idempotent_by on actions — dedupes retried mutations"
    ].freeze

    # Implementation status of this subsystem.
    # @return [String]
    STATUS = "Not implemented — spec only"

    # Entry point for the Action DSL.
    #
    # @param _args [Array] ignored
    # @param _options [Hash] ignored
    # @return [void] never returns
    # @raise [NotImplementedError] always, until Phase 2 lands
    def self.define(*_args, **_options)
      raise NotImplementedError, "Magik::Action is spec-only; see docs/idea/00-build-spec.md"
    end
  end
end
