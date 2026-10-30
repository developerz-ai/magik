# frozen_string_literal: true

module MagikScripts
  # One violation, in the shape `docs/architecture/03-error-codes.md` prescribes:
  # a stable code, a cause naming real identifiers, a runnable fix, and the
  # place to go and edit.
  #
  # These are **repo-internal** codes, and every one of them is `MAGIK_DEV_*`.
  # A `MAGIK_` code is either a framework code, whose token comes from the
  # closed set and which an app author can hit — or a repo-internal one, which
  # this repository's own scripts and checks emit and which ships to nobody.
  # There is no third kind (`docs/architecture/03-error-codes.md`).
  #
  # So a finding is deliberately **not** in `wiki/Error-Codes.md`: that page is
  # the app author's manual, and nobody outside this checkout can run a check.
  # The `DEV_` in front of a code on a gate's output is signal — it says *this
  # is about the repository, not about your app*.
  # {MagikScripts::Checks::FindingCodes} holds every code below to that rule.
  #
  # @see MagikScripts::Result
  Finding = Struct.new(:code, :cause, :fix, :at, keyword_init: true) do
    # The rendering a human reads. Aligned so `cause` and `fix` line up, and
    # the fix is always the last thing on the screen.
    #
    # @param indent [String] leading whitespace for the block
    # @return [String]
    def render(indent = "  ")
      head = at.nil? ? code : "#{code} (#{at})"
      ["#{indent}#{head}", "#{indent}  cause: #{cause}", "#{indent}  fix:   #{fix}"].join("\n")
    end

    # The rendering `--json` carries. Nil fields are dropped so the schema is
    # additive-only and a consumer never has to distinguish nil from absent.
    #
    # @return [Hash{Symbol => String}]
    def to_h
      { code: code, cause: cause, fix: fix, at: at }.compact
    end

    # Findings sort by where they are, then by what they are, so two runs over
    # one tree report in one order and a diff of two runs is readable.
    #
    # @return [Array<String>]
    def sort_key
      [at.to_s, code.to_s, cause.to_s]
    end
  end
end
