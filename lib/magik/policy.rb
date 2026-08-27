# frozen_string_literal: true

module Magik
  # Authorization: one rule per resource verb, evaluated identically in every
  # surface that projects from a declaration — screens, actions, API resources,
  # channels, jobs and the admin panel.
  #
  # Implements: **Phase 2 — Rendering & Actions** of `docs/idea/00-build-spec.md`
  # (architecture decision 13, added by amendment on 2026-08-26).
  #
  # Planned DSL surface, copied from the spec:
  #
  #   * `policy :Name do default :deny; can :verb do |actor, record| ... end end`
  #   * `screen/action/channel/job/api ..., policy: %i[Name verb]`
  #   * `roles`/`staff_roles` on the app composition root
  #
  # Two decisions carried from the audit that found this gap
  # (`docs/idea/10-saas-coverage.md`), both load-bearing:
  #
  # 1. **Phase 2, not Phase 7.** Adding a `policy:` argument to six constructs
  #    after those constructs exist is the retrofit the spec itself calls
  #    unsurvivable when it says it about `tenant_id`.
  # 2. **Tier 1, not tier 3 beside {Magik::Auth}.** {Magik::Render} and
  #    {Magik::Realtime} sit at tier 2 and must evaluate policies, and imports
  #    go strictly down a tier. So the evaluator takes the actor as an opaque
  #    value — exactly as {Magik::Router} takes a path without knowing what a
  #    screen is — and `auth` at tier 3 supplies it.
  #
  # Authorization is deliberately **not** a swap point: a second backend is a
  # second authorization system, which is how frameworks of this shape die.
  #
  # Status: **Not implemented — spec only.** Every entry point below raises
  # {NotImplementedError}.
  #
  # @see Magik::SUBSYSTEMS
  # @see Magik::Auth
  module Policy
    # The build-spec phase this subsystem implements.
    # @return [String]
    SPEC_PHASE = "Phase 2 — Rendering & Actions"

    # The DSL this subsystem will expose, verbatim from the spec.
    # @return [Array<String>]
    DSL_SURFACE = [
      "policy :Name do default :deny; can :verb do |actor, record| ... end end",
      "screen/action/channel/job/api ..., policy: %i[Name verb]",
      "roles :owner, :admin, :member, :viewer, default: :member"
    ].freeze

    # Implementation status of this subsystem.
    # @return [String]
    STATUS = "Not implemented — spec only"

    # Entry point for the Policy DSL.
    #
    # @param _args [Array] ignored
    # @param _options [Hash] ignored
    # @return [void] never returns
    # @raise [NotImplementedError] always, until Phase 2 lands
    def self.define(*_args, **_options)
      raise NotImplementedError, "Magik::Policy is spec-only; see docs/idea/00-build-spec.md"
    end
  end
end
