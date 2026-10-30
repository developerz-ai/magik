# frozen_string_literal: true

require_relative "helper"

# The `MAGIK_*` catalogue rules. Drift is asserted in both directions, because
# a page listing a code nothing raises is exactly as misleading as a code no
# page documents — and only one of those two is the one people remember to check.
class MagikScriptsErrorCodesTest < Minitest::Test
  ErrorCodes = MagikScripts::Checks::ErrorCodes
  FORMAT = /\AMAGIK_[A-Z0-9]+(?:_[A-Z0-9]+)*\z/

  def test_a_malformed_code_is_reported
    finding = only(declared(code: "magik-bad"), %w[magik-bad])

    assert_equal "MAGIK_DEV_ERROR_CODE_MALFORMED", finding.code
    assert_includes finding.cause, "not MAGIK_<SUBSYSTEM>_<CONDITION>"
  end

  def test_a_subclass_that_inherits_its_code_is_reported
    finding = only(declared(own_code: false), %w[MAGIK_A])

    assert_equal "MAGIK_DEV_ERROR_CODE_UNDECLARED", finding.code
    assert_includes finding.fix, "add `code"
  end

  def test_the_base_class_may_carry_the_default_code
    assert_empty ErrorCodes.audit(declared: declared(code: "MAGIK_ERROR", own_code: false, base: true),
                                  documented: %w[MAGIK_ERROR], format: FORMAT)
  end

  def test_a_subclass_claiming_the_root_code_is_reported
    finding = only(declared(code: "MAGIK_ERROR"), %w[MAGIK_ERROR])

    assert_equal "MAGIK_DEV_ERROR_CODE_ROOT_MISCLAIMED", finding.code
    assert_includes finding.fix, "MAGIK_<SUBSYSTEM>_<CONDITION>"
  end

  def test_a_base_class_that_gave_up_the_root_code_is_reported
    finding = only(declared(base: true), %w[MAGIK_A])

    assert_equal "MAGIK_DEV_ERROR_CODE_ROOT_MISCLAIMED", finding.code
    assert_includes finding.fix, "restore"
  end

  def test_two_classes_claiming_one_code_are_reported
    pair = declared(name: "Magik::A") + declared(name: "Magik::B")
    finding = ErrorCodes.audit(declared: pair, documented: %w[MAGIK_A], format: FORMAT).first

    assert_equal "MAGIK_DEV_ERROR_CODE_DUPLICATE", finding.code
    assert_includes finding.cause, "Magik::A and Magik::B"
  end

  def test_a_fix_that_is_advice_rather_than_a_command_is_reported
    finding = only(declared(fix: "check your configuration and try again"), %w[MAGIK_A])

    assert_equal "MAGIK_DEV_ERROR_FIX_ADVICE", finding.code
    assert_includes finding.fix, "replace the fix:"
  end

  def test_a_shipped_code_that_no_page_documents_is_reported
    finding = only(declared, [])

    assert_equal "MAGIK_DEV_ERROR_CODE_UNDOCUMENTED", finding.code
    assert_equal "wiki/Error-Codes.md", finding.at
  end

  def test_a_documented_code_that_nothing_raises_is_reported
    finding = ErrorCodes.audit(declared: declared, documented: %w[MAGIK_A MAGIK_GHOST],
                               format: FORMAT).first

    assert_equal "MAGIK_DEV_ERROR_CODE_PHANTOM", finding.code
    assert_includes finding.cause, "MAGIK_GHOST"
  end

  def test_a_matching_pair_is_silent
    assert_empty ErrorCodes.audit(declared: declared, documented: %w[MAGIK_A], format: FORMAT)
  end

  def test_only_the_live_today_section_is_read
    page = <<~MD
      ## Live today

      | Code | Means |
      |---|---|
      | `MAGIK_A` | a |

      ## Planned

      | Code | Means |
      |---|---|
      | `MAGIK_RESERVED` | not shipped |
    MD

    assert_equal %w[MAGIK_A], ErrorCodes.documented_codes(page)
  end

  def test_a_page_with_no_live_section_documents_nothing
    assert_empty ErrorCodes.documented_codes("# Error codes\n\nnothing here\n")
  end

  def test_the_real_catalogue_and_the_real_classes_are_both_read
    result = ErrorCodes.new.run

    refute_predicate result, :missing?
    refute_empty result.expected
  end

  private

  # @param overrides [Hash] fields to override on the default declaration
  # @return [Array<MagikScripts::Checks::ErrorCodes::Declared>]
  def declared(**overrides)
    defaults = { name: "Magik::A", code: "MAGIK_A", fix: "run `magik help`", own_code: true,
                 own_fix: true, base: false, at: "lib/magik.rb:1" }
    [ErrorCodes::Declared.new(**defaults, **overrides)]
  end

  # @param rows [Array<MagikScripts::Checks::ErrorCodes::Declared>]
  # @param documented [Array<String>]
  # @return [MagikScripts::Finding]
  def only(rows, documented)
    findings = ErrorCodes.audit(declared: rows, documented: documented, format: FORMAT)

    assert_equal 1, findings.size, "expected one finding, got #{findings.map(&:code)}"
    findings.first
  end
end

# The reserved half: names written down in a catalogue page and raised by
# nothing. A name is taken the day it is written, so these are held to the
# format and to one-code-per-condition, which is what a reserved name can
# satisfy — not to `lib/`, which would fail them for being honest.
class MagikScriptsReservedCodesTest < Minitest::Test
  Reserved = MagikScripts::Checks::ReservedCodes

  def test_a_token_outside_the_closed_set_is_reported
    finding = only(code("MAGIK_PAGINATION_UNBOUNDED"))

    assert_equal "MAGIK_DEV_ERROR_CODE_UNKNOWN_SUBSYSTEM", finding.code
    assert_includes finding.cause, "PAGINATION"
    assert_includes finding.fix, "ACTION"
  end

  def test_a_name_with_no_condition_part_is_reported
    finding = only(code("MAGIK_LEDGER"))

    assert_equal "MAGIK_DEV_ERROR_CODE_MALFORMED", finding.code
    assert_includes finding.cause, "no <CONDITION> part"
  end

  def test_the_root_code_is_not_held_to_the_format
    assert_empty Reserved.audit(catalogued: code("MAGIK_ERROR"))
  end

  def test_one_condition_under_two_codes_is_reported
    finding = only(code("MAGIK_ACTION_STATEFUL", line: 4) + code("MAGIK_ACTION_STATEFUL_ERROR", line: 9))

    assert_equal "MAGIK_DEV_ERROR_CODE_NEAR_DUPLICATE", finding.code
  end

  def test_a_reordered_second_name_for_one_condition_is_reported
    findings = Reserved.audit(catalogued: code("MAGIK_MODEL_FLOAT_MONEY") + code("MAGIK_MODEL_MONEY_FLOAT"))

    assert_equal %w[MAGIK_DEV_ERROR_CODE_NEAR_DUPLICATE], findings.map(&:code)
  end

  def test_a_bare_condition_beside_its_prefixed_form_is_reported
    findings = Reserved.audit(catalogued: code("MAGIK_PWA_OFFLINE_UNSUPPORTED") +
                                          code("MAGIK_PWA_UNSUPPORTED_OFFLINE"))

    assert_equal %w[MAGIK_DEV_ERROR_CODE_NEAR_DUPLICATE], findings.map(&:code)
  end

  def test_a_retired_spelling_coming_back_is_reported
    finding = Reserved.audit(catalogued: code("MAGIK_LEDGER_APPEND_ONLY")).first

    assert_equal "MAGIK_DEV_ERROR_CODE_RETIRED_SPELLING", finding.code
    assert_includes finding.cause, "MAGIK_LEDGER_ENTRY_MUTATED"
  end

  # `HARNESS` was never a subsystem, and the two names that claimed it were
  # reserved rather than shipped — so they moved into the format rather than
  # carving an exception into it, and the old spellings may not come back. It is
  # caught twice over, because `HARNESS` is not in the token set either, and that
  # is the point: the rename holds whether or not anybody remembers which of the
  # two rules a returning spelling broke.
  def test_the_retired_harness_spellings_cannot_come_back
    findings = Reserved.audit(catalogued: code("MAGIK_HARNESS_MARKERS_MISSING"))

    assert_equal %w[MAGIK_DEV_ERROR_CODE_RETIRED_SPELLING MAGIK_DEV_ERROR_CODE_UNKNOWN_SUBSYSTEM],
                 findings.map(&:code).sort
    assert(findings.any? { |finding| finding.fix.include?("MAGIK_CLI_HARNESS_MARKERS_MISSING") })
  end

  def test_a_guardrail_the_manual_never_lists_is_reported
    finding = only(code("MAGIK_LEDGER_UNBALANCED", page: Reserved::SPEC))

    assert_equal "MAGIK_DEV_ERROR_CODE_UNCATALOGUED", finding.code
    assert_includes finding.fix, Reserved::MANUAL
  end

  def test_a_guardrail_the_manual_lists_is_silent
    both = code("MAGIK_LEDGER_UNBALANCED", page: Reserved::SPEC) +
           code("MAGIK_LEDGER_UNBALANCED", page: Reserved::MANUAL)

    assert_empty Reserved.audit(catalogued: both)
  end

  def test_a_manual_only_code_is_silent
    assert_empty Reserved.audit(catalogued: code("MAGIK_MODEL_RECORD_NOT_FOUND"))
  end

  # The other half of the one rule, read from the catalogue side: a
  # `MAGIK_DEV_*` code documents a script or a check that ships to nobody, so
  # a row for one in a page an app author reads is a promise they can never
  # collect on.
  def test_a_repo_internal_code_in_an_app_facing_catalogue_is_reported
    finding = only(code("MAGIK_DEV_MANIFEST_DRIFT"))

    assert_equal "MAGIK_DEV_ERROR_CODE_PUBLISHED", finding.code
    assert_includes finding.cause, "ship to nobody"
    assert_includes finding.fix, "delete the MAGIK_DEV_MANIFEST_DRIFT row"
  end

  # Not reported as an unknown token, which would be true and useless: the fix
  # for an unknown token is to rename the code, and renaming this one into a
  # framework token is the one repair that makes it worse.
  def test_a_repo_internal_code_is_not_reported_as_an_unknown_token
    findings = Reserved.audit(catalogued: code("MAGIK_DEV_NO_RAKE"))

    refute_includes findings.map(&:code), "MAGIK_DEV_ERROR_CODE_UNKNOWN_SUBSYSTEM"
  end

  def test_no_repo_internal_code_is_written_into_the_real_catalogues
    found = Reserved::PAGES.flat_map { |page| Reserved.catalogued(MagikScripts::Repo.read(page), page) }

    assert_empty(found.select { |entry| entry.code.start_with?("MAGIK_DEV_") })
  end

  def test_the_code_column_is_found_by_its_header_not_its_position
    page = <<~MD
      | Guardrail | When | Code |
      |---|---|---|
      | balance | boot | `MAGIK_LEDGER_UNBALANCED` |
    MD

    assert_equal %w[MAGIK_LEDGER_UNBALANCED], Reserved.catalogued(page, "p.md").map(&:code)
  end

  def test_a_table_with_no_code_column_contributes_nothing
    page = <<~MD
      | Rule | Detail |
      |---|---|
      | Lookup | see `MAGIK_LEDGER_UNBALANCED` |
    MD

    assert_empty Reserved.catalogued(page, "p.md")
  end

  def test_each_table_finds_its_own_code_column
    page = <<~MD
      | Code | Means |
      |---|---|
      | `MAGIK_LEDGER_UNBALANCED` | debits and credits disagree |

      | Rule | Detail |
      |---|---|
      | Lookup | `MAGIK_NOT_A_CODE` in prose |
    MD

    assert_equal %w[MAGIK_LEDGER_UNBALANCED], Reserved.catalogued(page, "p.md").map(&:code)
  end

  def test_a_cell_naming_two_codes_yields_both
    page = <<~MD
      | Code |
      |---|
      | `MAGIK_RENDER_SCREEN_STATEFUL` · `MAGIK_ACTION_STATEFUL` |
    MD

    assert_equal 2, Reserved.catalogued(page, "p.md").size
  end

  def test_the_real_catalogues_are_read_and_are_not_empty
    found = Reserved::PAGES.flat_map { |page| Reserved.catalogued(MagikScripts::Repo.read(page), page) }

    refute_empty found
    assert(Reserved::PAGES.all? { |page| found.any? { |entry| entry.page == page } })
  end

  private

  # @param name [String] the reserved code
  # @param page [String] which catalogue it is written in
  # @param line [Integer] the 1-based line
  # @return [Array<MagikScripts::Checks::ReservedCodes::Code>]
  def code(name, page: Reserved::MANUAL, line: 1)
    [Reserved::Code.new(code: name, page: page, line: line)]
  end

  # @param catalogued [Array<MagikScripts::Checks::ReservedCodes::Code>]
  # @return [MagikScripts::Finding]
  def only(catalogued)
    findings = Reserved.audit(catalogued: catalogued)

    assert_equal 1, findings.size, "expected one finding, got #{findings.map(&:code)}"
    findings.first
  end
end

# The developer-script half: the `MAGIK_*` codes `bin/` prints. They ship to
# nobody, so the manual is never asked for a row — but they use the project's
# prefix, an agent searches for them the same way, and so they are held to the
# format, to a `DEV` token of their own, and to the fix:-is-a-command rule.
class MagikScriptsDevCodesTest < Minitest::Test
  Dev = MagikScripts::Checks::DevCodes

  def test_a_code_outside_the_dev_token_is_reported
    finding = only(raised(<<~SH))
      echo "MAGIK_NO_RUBY: ruby is not on PATH"
      echo "  fix: install Ruby >= 3.2"
    SH

    assert_equal "MAGIK_DEV_ERROR_CODE_BIN_MALFORMED", finding.code
    assert_includes finding.fix, "rename MAGIK_NO_RUBY to MAGIK_DEV_NO_RUBY"
  end

  def test_a_code_with_no_condition_part_is_reported
    finding = only(raised("echo \"MAGIK_DEV: something\"\necho \"  fix: run bin/setup\"\n"))

    assert_equal "MAGIK_DEV_ERROR_CODE_BIN_MALFORMED", finding.code
    assert_includes finding.fix, "MAGIK_DEV_<CONDITION>"
  end

  def test_a_code_printed_with_no_fix_line_is_reported
    finding = only(raised("echo \"MAGIK_DEV_NO_RAKE: rake is not installed.\"\n"))

    assert_equal "MAGIK_DEV_ERROR_CODE_BIN_UNFIXABLE", finding.code
    assert_includes finding.fix, "add a fix: line"
  end

  def test_a_fix_that_is_advice_rather_than_a_command_is_reported
    finding = only(raised("warn \"MAGIK_DEV_NO_RAKE: rake is missing\"\nwarn \"  fix: make sure rake is installed\"\n"))

    assert_equal "MAGIK_DEV_ERROR_FIX_ADVICE", finding.code
    assert_includes finding.cause, "MAGIK_DEV_NO_RAKE"
  end

  def test_a_well_formed_dev_code_is_silent
    assert_empty Dev.audit(raised: raised(<<~SH))
      echo "MAGIK_DEV_NO_RUBY: ruby is not on PATH" >&2
      echo "  fix: install Ruby >= 3.2 (see .ruby-version), then re-run bin/setup" >&2
    SH
  end

  # The distinction the whole namespace turns on: `MAGIK_` is also this repo's
  # environment-variable prefix, and a check that matched the prefix would
  # demand that configuration be renamed into a code format.
  def test_an_environment_variable_is_not_a_code
    source = <<~RB
      minimum = Float(ENV.fetch("MAGIK_YARD_MIN_COVERAGE", "100"))
      warn "  MAGIK_YARD_MIN_COVERAGE   Documentation-coverage floor (default 100)."
    RB

    assert_empty Dev.raised(source, "bin/check")
  end

  def test_a_fix_further_down_the_script_than_the_block_does_not_count
    source = "echo \"MAGIK_DEV_NO_RAKE: gone\"\n#{"\n" * (Dev::BLOCK + 1)}echo \"  fix: gem install rake\"\n"

    assert_equal "MAGIK_DEV_ERROR_CODE_BIN_UNFIXABLE", only(Dev.raised(source, "bin/rake")).code
  end

  def test_the_real_scripts_are_read_and_every_one_of_them_is_clean
    found = MagikScripts::Repo.glob(Dev::SCRIPTS)
                              .flat_map { |script| Dev.raised(MagikScripts::Repo.read(script), script) }

    refute_empty found
    assert_empty(found.reject { |entry| Dev::FORMAT.match?(entry.code) })
    assert_empty Dev.audit(raised: found)
  end

  private

  # @param source [String] a script body
  # @return [Array<MagikScripts::Checks::DevCodes::Code>]
  def raised(source)
    Dev.raised(source, "bin/setup")
  end

  # @param entries [Array<MagikScripts::Checks::DevCodes::Code>]
  # @return [MagikScripts::Finding]
  def only(entries)
    findings = Dev.audit(raised: entries)

    assert_equal 1, findings.size, "expected one finding, got #{findings.map(&:code)}"
    findings.first
  end
end

# The fourth corpus: the codes this repository's own checks emit as findings.
# They were a namespace of their own under seven invented tokens until they
# were folded into `DEV`, and this is what keeps them there — one rule, stated
# in a line: a `MAGIK_` code is a framework code from the closed set, or it is
# `MAGIK_DEV_*` and ships to nobody.
class MagikScriptsFindingCodesTest < Minitest::Test
  Findings = MagikScripts::Checks::FindingCodes

  def test_a_code_outside_the_dev_token_is_reported
    finding = only(emitted(<<~RB))
      Finding.new(code: "MAGIK_TYPO_DRIFT", cause: "c", fix: "run it", at: "a.rb:1")
    RB

    assert_equal "MAGIK_DEV_ERROR_CODE_FINDING_MALFORMED", finding.code
    assert_includes finding.fix, "rename MAGIK_TYPO_DRIFT to MAGIK_DEV_TYPO_DRIFT"
  end

  # The mistake this half exists for. `MAGIK_MANIFEST_DRIFT` was well formed
  # and passed every other rule; what was wrong with it is that its token said
  # an app author could hit it, and no app author can run a check.
  def test_a_code_claiming_a_framework_token_is_reported
    finding = only(emitted(<<~RB))
      Finding.new(code: "MAGIK_BOUNDARY_TIER", cause: "c", fix: "run it", at: "a.rb:1")
    RB

    assert_equal "MAGIK_DEV_ERROR_CODE_FINDING_FRAMEWORK_TOKEN", finding.code
    assert_includes finding.cause, "BOUNDARY"
    assert_includes finding.fix, "MAGIK_DEV_BOUNDARY_TIER"
  end

  def test_a_finding_built_with_no_fix_is_reported
    finding = only(emitted(<<~RB))
      Finding.new(code: "MAGIK_DEV_NO_FIX",
                  cause: "something is wrong",
                  at: "a.rb:1")
    RB

    assert_equal "MAGIK_DEV_ERROR_CODE_FINDING_UNFIXABLE", finding.code
    assert_includes finding.fix, "add a `fix:` argument"
  end

  def test_a_fix_that_is_advice_rather_than_a_command_is_reported
    finding = only(emitted(<<~RB))
      Finding.new(code: "MAGIK_DEV_ADVICE",
                  cause: "c",
                  fix: "check your configuration")
    RB

    assert_equal "MAGIK_DEV_ERROR_FIX_ADVICE", finding.code
    assert_includes finding.cause, "MAGIK_DEV_ADVICE"
  end

  # A corpus that quietly shrinks is the failure mode `Check#nothing_scanned`
  # exists to prevent, one call site at a time: a code this half cannot read is
  # a code it is not checking, and it says so rather than skipping.
  def test_a_code_argument_that_cannot_be_read_is_reported
    finding = only(emitted("Finding.new(code: pick_a_code(entry), fix: \"run it\")\n"))

    assert_equal "MAGIK_DEV_ERROR_CODE_FINDING_UNRESOLVED", finding.code
    assert_includes finding.cause, "pick_a_code(entry)"
  end

  # Three checks name their codes once and raise them twice, so a bare constant
  # has to resolve or the corpus loses them.
  def test_a_constant_is_resolved_against_its_own_file
    entries = emitted(<<~RB)
      TIER_CODE = "MAGIK_DEV_BOUNDARY_TIER"

      Finding.new(
        code: TIER_CODE, at: at,
        cause: "c",
        fix: "delete the dependency"
      )
    RB

    assert_equal %w[MAGIK_DEV_BOUNDARY_TIER], entries.map(&:code)
    assert_empty Findings.audit(emitted: entries)
  end

  def test_a_constant_from_another_file_is_unresolved_rather_than_guessed
    finding = only(emitted("Finding.new(code: SOMEWHERE_ELSE, fix: \"run it\")\n"))

    assert_equal "MAGIK_DEV_ERROR_CODE_FINDING_UNRESOLVED", finding.code
  end

  # The line the finding reports has to be the line in the file, so the whole
  # point of blanking comments rather than deleting them is that offsets hold.
  def test_the_reported_line_survives_the_comments_above_it
    entries = emitted("# Finding.new(code: X) in prose\n#\nFinding.new(code: \"MAGIK_DEV_A\", fix: \"go\")\n")

    assert_equal 1, entries.size
    assert_equal 3, entries.first.line
  end

  # This file documents the construction it scans for, and so does the check.
  # A rule that flagged its own prose would teach contributors to stop writing
  # it, which is the opposite of what this repository is for.
  def test_prose_describing_a_finding_is_not_a_finding
    assert_empty Findings.emitted("# Finding.new(code: whatever) is how a check reports\n", "scripts/lib/a.rb")
  end

  def test_a_fix_on_the_same_line_as_the_code_counts
    entries = emitted("Finding.new(code: \"MAGIK_DEV_A\", cause: c, fix: f, at: where)\n")

    assert_empty Findings.audit(emitted: entries)
  end

  # The case a window of N lines gets wrong, and the reason the search is
  # bounded by the call's own parentheses instead. Every check has a
  # `nothing_scanned(..., fix: fix_line)` a few lines from its findings, so a
  # window reads that one and passes a finding that has no fix: at all.
  def test_the_next_calls_fix_does_not_satisfy_this_finding
    finding = only(emitted(<<~RB))
      Finding.new(code: "MAGIK_DEV_A",
                  cause: "c",
                  at: "a.rb:1")
      nothing_scanned(corpus: CORPUS, expected: expectation, fix: fix_line)
    RB

    assert_equal "MAGIK_DEV_ERROR_CODE_FINDING_UNFIXABLE", finding.code
  end

  def test_a_call_that_does_not_close_inside_the_block_is_still_read
    source = "Finding.new(code: \"MAGIK_DEV_A\",\n#{"\n" * (Findings::BLOCK + 1)}  fix: \"run it\")\n"

    assert_equal "MAGIK_DEV_ERROR_CODE_FINDING_UNFIXABLE", only(Findings.emitted(source, "scripts/lib/a.rb")).code
  end

  def test_the_real_checks_are_read_and_every_one_of_them_is_clean
    found = MagikScripts::Repo.glob(Findings::SCRIPTS)
                              .flat_map { |script| Findings.emitted(MagikScripts::Repo.read(script), script) }

    refute_empty found
    assert_empty(found.reject { |entry| Findings::FORMAT.match?(entry.code.to_s) })
    assert_empty Findings.audit(emitted: found)
  end

  private

  # @param source [String] a check body
  # @return [Array<MagikScripts::Checks::FindingCodes::Code>]
  def emitted(source)
    Findings.emitted(source, "scripts/checks/example.rb")
  end

  # @param entries [Array<MagikScripts::Checks::FindingCodes::Code>]
  # @return [MagikScripts::Finding]
  def only(entries)
    findings = Findings.audit(emitted: entries)

    assert_equal 1, findings.size, "expected one finding, got #{findings.map(&:code)}"
    findings.first
  end
end
