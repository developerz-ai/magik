# frozen_string_literal: true

require_relative "finding"

module MagikScripts
  # The verdict of one check: three statuses, not two.
  #
  # `missing` is an environment that has not been set up; `fail` is a repo that
  # is wrong. Both exit non-zero — a check you could not run is not a check you
  # passed — but they read differently and they have different fixes. The exit
  # codes are `bin/check`'s, so a check run standalone and the same check run
  # through the gate are machine-indistinguishable.
  class Result
    # Every status a check can return.
    # @return [String]
    PASS = "pass"
    # @see PASS
    FAIL = "fail"
    # @see PASS
    MISSING = "missing"

    # Exit status per status value, sysexits-style: 69 is `EX_UNAVAILABLE`.
    # @return [Hash{String => Integer}]
    EXIT_CODES = { PASS => 0, FAIL => 1, MISSING => 69 }.freeze

    # @return [String] one of {PASS}, {FAIL}, {MISSING}
    attr_reader :status
    # @return [String, nil] a machine-matchable reason slug
    attr_reader :reason
    # @return [String] one sentence: what the check wanted to be true
    attr_reader :expected
    # @return [String] what it found instead
    attr_reader :got
    # @return [String, nil] the runnable command that makes the check green
    attr_reader :fix
    # @return [Array<MagikScripts::Finding>] one per violation, sorted
    attr_reader :findings

    # A satisfied check. `got` must say what was actually inspected — "21 files
    # scanned" — because "no violations" and "nothing was looked at" are the
    # same sentence otherwise.
    #
    # @param got [String] what was inspected, with counts
    # @param expected [String] the property that holds
    # @return [MagikScripts::Result]
    def self.ok(got:, expected:)
      new(status: PASS, expected: expected, got: got)
    end

    # A repo that is wrong.
    #
    # @param reason [String] a slug like `"tier_violation"`
    # @param expected [String] the property that should hold
    # @param fix [String] a runnable command
    # @param findings [Array<MagikScripts::Finding>] one per violation
    # @param got [String, nil] overrides the summary rendered from `findings`
    # @return [MagikScripts::Result]
    def self.failure(reason:, expected:, fix:, findings: [], got: nil)
      new(status: FAIL, reason: reason, expected: expected, fix: fix, findings: findings,
          got: got || "#{findings.size} finding#{"s" unless findings.size == 1}")
    end

    # A tool the check needs is not installed. The fix is the install command,
    # never a change to the repo.
    #
    # @param tool [String] the executable that is missing
    # @param install [String] the command that gets it
    # @param expected [String] what the check would have asserted
    # @return [MagikScripts::Result]
    def self.missing_tool(tool:, install:, expected:)
      new(status: MISSING, reason: "tool_not_installed:#{tool}", expected: expected,
          got: "`#{tool}` is not runnable here, on PATH or in this checkout's bundle", fix: install)
    end

    # @param status [String] one of {PASS}, {FAIL}, {MISSING}
    # @param expected [String] the property the check asserts
    # @param got [String] what it found
    # @param reason [String, nil] a machine-matchable slug
    # @param fix [String, nil] a runnable command
    # @param findings [Array<MagikScripts::Finding>] one per violation
    def initialize(status:, expected:, got:, reason: nil, fix: nil, findings: [])
      @status = status
      @expected = expected
      @got = got
      @reason = reason
      @fix = fix
      @findings = findings.sort_by(&:sort_key).freeze
      freeze
    end

    # @return [Boolean]
    def pass?
      status == PASS
    end

    # @return [Boolean]
    def fail?
      status == FAIL
    end

    # @return [Boolean]
    def missing?
      status == MISSING
    end

    # @return [Integer] the process exit status this verdict deserves
    def exit_code
      EXIT_CODES.fetch(status)
    end

    # @return [Hash{Symbol => Object}] the `--json` body, minus the metadata
    #   the runner adds
    def to_h
      { ok: pass?, status: status, exit_code: exit_code, reason: reason, expected: expected,
        got: got, fix: fix, findings: findings.map(&:to_h) }
    end
  end
end
