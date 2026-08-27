# frozen_string_literal: true

module Magik
  # The model DSL — a thin, explicit wrapper over Sequel. No lazy-loading magic, no
  # implicit N+1.
  #
  # Implements: **Phase 1 — Foundation** of `docs/idea/00-build-spec.md`.
  #
  # Planned DSL surface, copied from the spec:
  #
  #   * `model :Name do field/computed/belongs_to/has_many/validate/scope end`
  #   * `computed(:name, :type) { ... }` — the parens are load-bearing: a brace
  #     block binds to the last call, so without them it binds to the symbol
  #   * `:money field type, integer-cents backed (floats forbidden)`
  #   * `:file field type — an attachment; max_size: and content_types: required`
  #   * `:duration field type — a unit-suffixed string coerced at boot ("14d")`
  #   * `UUIDv7 primary keys`
  #   * `tenant_id auto-injection`
  #
  # Status: **Not implemented — spec only.** Every entry point below raises
  # {NotImplementedError}. Nothing here reads config, touches a database or
  # emits a byte of HTML.
  #
  # @see Magik::SUBSYSTEMS
  module Model
    # The build-spec phase this subsystem implements.
    # @return [String]
    SPEC_PHASE = "Phase 1 — Foundation"

    # The DSL this subsystem will expose, verbatim from the spec.
    # @return [Array<String>]
    DSL_SURFACE = [
      "model :Name do field/computed/belongs_to/has_many/validate/scope end",
      "computed(:name, :type) { ... } — a derived field",
      ":money field type, integer-cents backed (floats forbidden)",
      ":file field type — an attachment, max_size: and content_types: required",
      ":duration field type — a unit-suffixed string coerced at boot",
      "UUIDv7 primary keys",
      "tenant_id auto-injection"
    ].freeze

    # Implementation status of this subsystem.
    # @return [String]
    STATUS = "Not implemented — spec only"

    # Entry point for the Model DSL.
    #
    # @param _args [Array] ignored
    # @param _options [Hash] ignored
    # @return [void] never returns
    # @raise [NotImplementedError] always, until Phase 1 lands
    def self.define(*_args, **_options)
      raise NotImplementedError, "Magik::Model is spec-only; see docs/idea/00-build-spec.md"
    end
  end
end
