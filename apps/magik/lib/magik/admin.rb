# frozen_string_literal: true

module Magik
  # Auto-generated CRUD admin panels over declared models.
  #
  # Implements: **Phase 7 — Auth, Billing, Admin** of `docs/idea/00-build-spec.md`.
  #
  # Planned DSL surface, copied from the spec:
  #
  #   * `admin_panel :Model, policy: %i[Model administer] do
  #     list do fields/filterable/searchable end; show; form end`
  #
  # `policy:` is **required** here — the admin is by construction the surface
  # with the broadest data access in an application, so an `admin_panel` without
  # one does not boot ({Magik::Policy}, `MAGIK_POLICY_UNDECLARED`).
  #
  # Status: **Not implemented — spec only.** Every entry point below raises
  # {NotImplementedError}. Nothing here reads config, touches a database or
  # emits a byte of HTML.
  #
  # @see Magik::SUBSYSTEMS
  module Admin
    # The build-spec phase this subsystem implements.
    # @return [String]
    SPEC_PHASE = "Phase 7 — Auth, Billing, Admin"

    # The DSL this subsystem will expose, verbatim from the spec.
    # @return [Array<String>]
    DSL_SURFACE = [
      "admin_panel :Model, policy: %i[Model administer] do list do fields/filterable/searchable " \
      "end; show; form end"
    ].freeze

    # Implementation status of this subsystem.
    # @return [String]
    STATUS = "Not implemented — spec only"

    # Entry point for the Admin DSL.
    #
    # @param _args [Array] ignored
    # @param _options [Hash] ignored
    # @return [void] never returns
    # @raise [NotImplementedError] always, until Phase 7 lands
    def self.define(*_args, **_options)
      raise NotImplementedError, "Magik::Admin is spec-only; see docs/idea/00-build-spec.md"
    end
  end
end
