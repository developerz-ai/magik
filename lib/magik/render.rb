# frozen_string_literal: true

module Magik
  # The UI DSL. Compiles components and screens to server-rendered HTML plus htmx
  # attributes. There is no SPA framework and there never will be.
  #
  # Implements: **Phase 2 — Rendering & Actions** of `docs/idea/00-build-spec.md`.
  #
  # Planned DSL surface, copied from the spec:
  #
  #   * `component :Name do prop; body do ... end end`
  #   * `screen :Name do state/body end`
  #   * `kit: button, form, field, data_table, modal, toast, card, list, grid, tabs, stat, chart`
  #   * `theme system: design tokens, light/dark mode via CSS vars`
  #
  # Status: **Not implemented — spec only.** Every entry point below raises
  # {NotImplementedError}. Nothing here reads config, touches a database or
  # emits a byte of HTML.
  #
  # @see Magik::SUBSYSTEMS
  module Render
    # The build-spec phase this subsystem implements.
    # @return [String]
    SPEC_PHASE = "Phase 2 — Rendering & Actions"

    # The DSL this subsystem will expose, verbatim from the spec.
    # @return [Array<String>]
    DSL_SURFACE = [
      "component :Name do prop; body do ... end end",
      "screen :Name do state/body end",
      "kit: button, form, field, data_table, modal, toast, card, list, grid, tabs, stat, chart",
      "theme system: design tokens, light/dark mode via CSS vars"
    ].freeze

    # Implementation status of this subsystem.
    # @return [String]
    STATUS = "Not implemented — spec only"

    # Entry point for the Render DSL.
    #
    # @param _args [Array] ignored
    # @param _options [Hash] ignored
    # @return [void] never returns
    # @raise [NotImplementedError] always, until Phase 2 lands
    def self.define(*_args, **_options)
      raise NotImplementedError, "Magik::Render is spec-only; see docs/idea/00-build-spec.md"
    end
  end
end
