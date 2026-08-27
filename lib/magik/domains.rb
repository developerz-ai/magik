# frozen_string_literal: true

module Magik
  # The domain module system for large apps, with boot-time boundary enforcement: a
  # domain reaches another domain only through its published interface or events.
  #
  # Implements: **Build order step 12 — Domain module system** of `docs/idea/00-build-spec.md`.
  #
  # Planned DSL surface, copied from the spec:
  #
  #   * `domains/<name>/domain.rb declares depends_on, exposes, publishes_events`
  #   * `boot-time enforcement of cross-domain access`
  #
  # Status: **Not implemented — spec only.** Every entry point below raises
  # {NotImplementedError}. Nothing here reads config, touches a database or
  # emits a byte of HTML.
  #
  # @see Magik::SUBSYSTEMS
  module Domains
    # The build-spec phase this subsystem implements.
    # @return [String]
    SPEC_PHASE = "Build order step 12 — Domain module system"

    # The DSL this subsystem will expose, verbatim from the spec.
    # @return [Array<String>]
    DSL_SURFACE = [
      "domains/<name>/domain.rb declares depends_on, exposes, publishes_events",
      "boot-time enforcement of cross-domain access"
    ].freeze

    # Implementation status of this subsystem.
    # @return [String]
    STATUS = "Not implemented — spec only"

    # Entry point for the Domains DSL.
    #
    # @param _args [Array] ignored
    # @param _options [Hash] ignored
    # @return [void] never returns
    # @raise [NotImplementedError] always, until Build order step 12 lands
    def self.define(*_args, **_options)
      raise NotImplementedError, "Magik::Domains is spec-only; see docs/idea/00-build-spec.md"
    end
  end
end
