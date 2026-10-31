# frozen_string_literal: true

require_relative "repo"
require_relative "result"

module MagikScripts
  # The contract every file in `scripts/checks/` implements: one question about
  # this repository, answered by `#run` as a {MagikScripts::Result}.
  #
  # A check is a **program**, not a plugin. It runs standalone
  # (`ruby scripts/checks/<name>.rb`), it speaks `--json`, it exits 0 / 1 / 69,
  # and requiring its file must not run it — the entry point is guarded by
  # `if $PROGRAM_NAME == __FILE__`, so its own test can load it.
  #
  # Two rules that are not optional:
  #
  # * **Zero inputs is a failure, never a pass.** A glob that matches nothing
  #   reads exactly like a clean tree. Use {#nothing_scanned} rather than
  #   returning `ok` with a count of zero.
  # * **Split the pure rule from the collector.** The class method that takes
  #   data and returns findings is what the test exercises with fixtures; `#run`
  #   is the thin half that reads the real tree. A rule that can only be tested
  #   by editing the repo has no negative case.
  #
  # Metadata — name, summary, cost order — is **not** declared here. It lives in
  # the `@check` / `@summary` / `@order` header of the check's own file, where
  # {MagikScripts::Registry} can read it without loading Ruby. One source, so a
  # renamed check cannot disagree with itself.
  #
  # @abstract Subclass and override {#run}.
  class Check
    # The finding code every check raises when its corpus is empty.
    # @return [String]
    NOTHING_SCANNED = "MAGIK_DEV_CHECK_NOTHING_SCANNED"

    # Flags this check accepts beyond the universal ones, as flag => option key.
    # The runner turns `--write` into `options[:write] = true`.
    #
    # @return [Hash{String => Symbol}]
    def self.flags
      {}
    end

    # @return [Hash{Symbol => Object}] parsed extra flags, from {Check.flags}
    attr_reader :options

    # @param options [Hash{Symbol => Object}] parsed extra flags
    def initialize(**options)
      @options = options
    end

    # Answer this check's question about the repository.
    #
    # @abstract
    # @return [MagikScripts::Result]
    # @raise [NotImplementedError] unless the subclass overrides it
    def run
      raise NotImplementedError, "#{self.class}#run must return a MagikScripts::Result"
    end

    private

    # @param got [String] what was inspected, with a count
    # @param expected [String] the property that holds
    # @return [MagikScripts::Result]
    def ok(got:, expected:)
      Result.ok(got: got, expected: expected)
    end

    # @param reason [String] a machine-matchable slug
    # @param expected [String] the property that should hold
    # @param fix [String] a runnable command
    # @param findings [Array<MagikScripts::Finding>] one per violation
    # @param got [String, nil] overrides the rendered summary
    # @return [MagikScripts::Result]
    def failure(reason:, expected:, fix:, findings: [], got: nil)
      Result.failure(reason: reason, expected: expected, fix: fix, findings: findings, got: got)
    end

    # @param tool [String] the executable that is missing
    # @param install [String] the command that gets it
    # @param expected [String] what the check would have asserted
    # @return [MagikScripts::Result]
    def missing_tool(tool:, install:, expected:)
      Result.missing_tool(tool: tool, install: install, expected: expected)
    end

    # The empty-corpus verdict. A check whose glob matched nothing has not
    # proved anything, and saying "pass" there is the one failure mode that
    # survives every refactor: the day somebody moves a directory, the check
    # goes quiet instead of red.
    #
    # @param corpus [String] what was searched for, e.g. `"lib/magik/**/*.rb"`
    # @param expected [String] the property the check asserts when it can run
    # @param fix [String] a runnable command
    # @return [MagikScripts::Result]
    def nothing_scanned(corpus:, expected:, fix:)
      cause = "#{corpus} matched no files under #{Repo.root}, so this check asserted nothing"
      failure(reason: "nothing_scanned", expected: expected, fix: fix,
              got: "0 files matched #{corpus}",
              findings: [Finding.new(code: NOTHING_SCANNED, cause: cause, fix: fix, at: corpus)])
    end
  end
end
