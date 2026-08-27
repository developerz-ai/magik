# frozen_string_literal: true

module Magik
  # Background jobs on a Postgres-backed transactional queue (Que-style) by default,
  # swappable to Kafka.
  #
  # Implements: **Phase 4 — Jobs & Async** of `docs/idea/00-build-spec.md`.
  #
  # Planned DSL surface, copied from the spec:
  #
  #   * `job :Name do retry; schedule :cron/:every; perform do |args| end end`
  #   * `magik worker — horizontally scalable worker process`
  #
  # Status: **Not implemented — spec only.** Every entry point below raises
  # {NotImplementedError}. Nothing here reads config, touches a database or
  # emits a byte of HTML.
  #
  # @see Magik::SUBSYSTEMS
  module Jobs
    # The build-spec phase this subsystem implements.
    # @return [String]
    SPEC_PHASE = "Phase 4 — Jobs & Async"

    # The DSL this subsystem will expose, verbatim from the spec.
    # @return [Array<String>]
    DSL_SURFACE = [
      "job :Name do retry; schedule :cron/:every; perform do |args| end end",
      "magik worker — horizontally scalable worker process"
    ].freeze

    # Implementation status of this subsystem.
    # @return [String]
    STATUS = "Not implemented — spec only"

    # Entry point for the Jobs DSL.
    #
    # @param _args [Array] ignored
    # @param _options [Hash] ignored
    # @return [void] never returns
    # @raise [NotImplementedError] always, until Phase 4 lands
    def self.define(*_args, **_options)
      raise NotImplementedError, "Magik::Jobs is spec-only; see docs/idea/00-build-spec.md"
    end
  end
end
