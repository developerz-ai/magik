# frozen_string_literal: true

module Magik
  # Opt-in realtime. Default is plain request/response; nothing costs anything until a
  # screen declares `live` or a `channel` exists.
  #
  # Implements: **Phase 3 — Realtime (opt-in)** of `docs/idea/00-build-spec.md`.
  #
  # Planned DSL surface, copied from the spec:
  #
  #   * `live :state_var, on: "channel:name"`
  #   * `channel :name do subscribe_to/on_create/on_update end`
  #   * `broadcast "channel", :event, payload`
  #   * `presence for online/cursor tracking`
  #   * `backend: Postgres LISTEN/NOTIFY (default) → Redis pub/sub (swap via config)`
  #
  # Status: **Not implemented — spec only.** Every entry point below raises
  # {NotImplementedError}. Nothing here reads config, touches a database or
  # emits a byte of HTML.
  #
  # @see Magik::SUBSYSTEMS
  module Realtime
    # The build-spec phase this subsystem implements.
    # @return [String]
    SPEC_PHASE = "Phase 3 — Realtime (opt-in)"

    # The DSL this subsystem will expose, verbatim from the spec.
    # @return [Array<String>]
    DSL_SURFACE = [
      "live :state_var, on: \"channel:name\"",
      "channel :name do subscribe_to/on_create/on_update end",
      "broadcast \"channel\", :event, payload",
      "presence for online/cursor tracking",
      "backend: Postgres LISTEN/NOTIFY (default) → Redis pub/sub (swap via config)"
    ].freeze

    # Implementation status of this subsystem.
    # @return [String]
    STATUS = "Not implemented — spec only"

    # Entry point for the Realtime DSL.
    #
    # @param _args [Array] ignored
    # @param _options [Hash] ignored
    # @return [void] never returns
    # @raise [NotImplementedError] always, until Phase 3 lands
    def self.define(*_args, **_options)
      raise NotImplementedError, "Magik::Realtime is spec-only; see docs/idea/00-build-spec.md"
    end
  end
end
