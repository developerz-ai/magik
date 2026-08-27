# frozen_string_literal: true

module Magik
  # REST APIs and webhooks in both directions, with auto pagination, filtering and
  # sorting.
  #
  # Implements: **Phase 6 — API & Integration** of `docs/idea/00-build-spec.md`.
  #
  # Planned DSL surface, copied from the spec:
  #
  #   * `api :V1 do resource :name do index/show/create/update/destroy end end`
  #   * `webhook :incoming, :name do verify_signature; on :event end`
  #   * `webhook :outgoing, :name do fires_on; deliver_to; sign_with end`
  #   * `auth: :bearer, :api_key, :jwt; rate limiting by plan`
  #
  # Status: **Not implemented — spec only.** Every entry point below raises
  # {NotImplementedError}. Nothing here reads config, touches a database or
  # emits a byte of HTML.
  #
  # @see Magik::SUBSYSTEMS
  module API
    # The build-spec phase this subsystem implements.
    # @return [String]
    SPEC_PHASE = "Phase 6 — API & Integration"

    # The DSL this subsystem will expose, verbatim from the spec.
    # @return [Array<String>]
    DSL_SURFACE = [
      "api :V1 do resource :name do index/show/create/update/destroy end end",
      "webhook :incoming, :name do verify_signature; on :event end",
      "webhook :outgoing, :name do fires_on; deliver_to; sign_with end",
      "auth: :bearer, :api_key, :jwt; rate limiting by plan"
    ].freeze

    # Implementation status of this subsystem.
    # @return [String]
    STATUS = "Not implemented — spec only"

    # Entry point for the API DSL.
    #
    # @param _args [Array] ignored
    # @param _options [Hash] ignored
    # @return [void] never returns
    # @raise [NotImplementedError] always, until Phase 6 lands
    def self.define(*_args, **_options)
      raise NotImplementedError, "Magik::API is spec-only; see docs/idea/00-build-spec.md"
    end
  end
end
