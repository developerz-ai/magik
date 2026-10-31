# frozen_string_literal: true

module Magik
  # The migration DSL over Sequel migrations.
  #
  # Implements: **Phase 1 — Foundation** of `docs/idea/00-build-spec.md`.
  #
  # Planned DSL surface, copied from the spec:
  #
  #   * `migrate :Name do up/down end`
  #
  # Status: **Not implemented — spec only.** Every entry point below raises
  # {NotImplementedError}. Nothing here reads config, touches a database or
  # emits a byte of HTML.
  #
  # @see Magik::SUBSYSTEMS
  module Schema
    # The build-spec phase this subsystem implements.
    # @return [String]
    SPEC_PHASE = "Phase 1 — Foundation"

    # The DSL this subsystem will expose, verbatim from the spec.
    # @return [Array<String>]
    DSL_SURFACE = [
      "migrate :Name do up/down end"
    ].freeze

    # Implementation status of this subsystem.
    # @return [String]
    STATUS = "Not implemented — spec only"

    # Entry point for the Schema DSL.
    #
    # @param _args [Array] ignored
    # @param _options [Hash] ignored
    # @return [void] never returns
    # @raise [NotImplementedError] always, until Phase 1 lands
    def self.define(*_args, **_options)
      raise NotImplementedError, "Magik::Schema is spec-only; see docs/idea/00-build-spec.md"
    end
  end
end
