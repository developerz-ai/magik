# frozen_string_literal: true

module Magik
  # Application composition root: the `App.define` boot process, the Sequel connection,
  # and the config swap points every opinionated default must honour.
  #
  # Implements: **Phase 1 — Foundation** of `docs/idea/00-build-spec.md`.
  #
  # Planned DSL surface, copied from the spec:
  #
  #   * `App.define :Name do ... end`
  #   * `tenant_by :subdomain`
  #   * `swap points: db, cache, jobs, search, realtime backends`
  #
  # Status: **Not implemented — spec only.** Every entry point below raises
  # {NotImplementedError}. Nothing here reads config, touches a database or
  # emits a byte of HTML.
  #
  # @see Magik::SUBSYSTEMS
  module Core
    # The build-spec phase this subsystem implements.
    # @return [String]
    SPEC_PHASE = "Phase 1 — Foundation"

    # The DSL this subsystem will expose, verbatim from the spec.
    # @return [Array<String>]
    DSL_SURFACE = [
      "App.define :Name do ... end",
      "tenant_by :subdomain",
      "swap points: db, cache, jobs, search, realtime backends"
    ].freeze

    # Implementation status of this subsystem.
    # @return [String]
    STATUS = "Not implemented — spec only"

    # Entry point for the Core DSL.
    #
    # @param _args [Array] ignored
    # @param _options [Hash] ignored
    # @return [void] never returns
    # @raise [NotImplementedError] always, until Phase 1 lands
    def self.define(*_args, **_options)
      raise NotImplementedError, "Magik::Core is spec-only; see docs/idea/00-build-spec.md"
    end
  end
end
