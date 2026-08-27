# frozen_string_literal: true

module Magik
  # The test DSL, compiling to Minitest (never RSpec), with auto-inferred factories and
  # a parallel runner.
  #
  # Implements: **Phase 9 — Testing** of `docs/idea/00-build-spec.md`.
  #
  # Planned DSL surface, copied from the spec:
  #
  #   * `test :Name do it "..." do expect(...) end end`
  #   * `helpers: perform_action, render_screen, concurrently(n), travel_to`
  #   * `helpers: assert_enqueued, assert_broadcast, assert_notified`
  #   * `parallel: one thread per test file group, workers: :auto, transactional rollback per test`
  #   * `magik test, magik test --watch, magik test --changed`
  #
  # A worker is a **thread**, and there is exactly one worker model. TruffleRuby's
  # threads are genuinely parallel — that is why it is the production runtime — and
  # it implements no `fork`, so there is no forked worker to fall back to
  # (`docs/architecture/12-runtime-verification.md`).
  #
  # Status: **Not implemented — spec only.** Every entry point below raises
  # {NotImplementedError}. Nothing here reads config, touches a database or
  # emits a byte of HTML.
  #
  # @see Magik::SUBSYSTEMS
  module Testing
    # The build-spec phase this subsystem implements.
    # @return [String]
    SPEC_PHASE = "Phase 9 — Testing"

    # The DSL this subsystem will expose, verbatim from the spec.
    # @return [Array<String>]
    DSL_SURFACE = [
      "test :Name do it \"...\" do expect(...) end end",
      "helpers: perform_action, render_screen, concurrently(n), travel_to",
      "helpers: assert_enqueued, assert_broadcast, assert_notified",
      "parallel: one thread per test file group, workers: :auto, transactional rollback per test",
      "magik test, magik test --watch, magik test --changed"
    ].freeze

    # Implementation status of this subsystem.
    # @return [String]
    STATUS = "Not implemented — spec only"

    # Entry point for the Testing DSL.
    #
    # @param _args [Array] ignored
    # @param _options [Hash] ignored
    # @return [void] never returns
    # @raise [NotImplementedError] always, until Phase 9 lands
    def self.define(*_args, **_options)
      raise NotImplementedError, "Magik::Testing is spec-only; see docs/idea/00-build-spec.md"
    end
  end
end
