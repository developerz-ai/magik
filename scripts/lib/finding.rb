# frozen_string_literal: true

module MagikScripts
  # One violation, in the shape `docs/architecture/03-error-codes.md` prescribes:
  # a stable code, a cause naming real identifiers, a runnable fix, and the
  # place to go and edit.
  #
  # These are **check-stage** codes. They are not `Magik::Error` subclasses and
  # they are not in `wiki/Error-Codes.md`'s live table, because nothing in
  # `lib/` raises them — they belong to the `check` subsystem, which is spec
  # only (`docs/architecture/01-module-map.md`). They use the framework's code
  # format on purpose, so that when `lib/magik/check/errors.rb` is written the
  # catalogue entries already exist and keep their names.
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
