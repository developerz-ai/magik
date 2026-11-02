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

# The fifth rule: the `magik` commands the shipped manual's fix cells name. A
# fix cell is a promise — "run this and the problem goes away" — and the
# promise is false when the command is not in the CLI registry: the reader
# pastes it and gets MAGIK_CLI_UNKNOWN_COMMAND instead.
class MagikScriptsFixCommandsTest < Minitest::Test
  Fixes = MagikScripts::Checks::FixCommands

  # The check under test, reading fixture fix cells instead of the real
  # manual's — the half of the rule that decides which cells to read.
  class FixtureErrorCodes < MagikScripts::Checks::ErrorCodes
    # @param commands [Array<String>] the commands the fixture cell names
    # @param cells [Array<MagikScripts::Checks::FixCommands::Cell>, nil] the
    #   cells the fixture manual carries; nil means the one cell naming
    #   `commands`, and an empty array means a manual with no fix column
    def initialize(commands: [], cells: nil, **)
      super(**)
      @commands = commands
      @cells = cells
    end

    private

    # @return [Array<MagikScripts::Checks::FixCommands::Cell>]
    def fix_cells
      return @cells unless @cells.nil?

      [Fixes::Cell.new(page: "wiki/Error-Codes.md", line: 3, commands: @commands)]
    end
  end

  def test_a_fix_cell_naming_an_unregistered_command_is_reported
    page = <<~MD
      | Code | Fix |
      |---|---|
      | `MAGIK_POLICY_UNKNOWN_VERB` | `magik registry --kind policy --json` lists every verb |
    MD
    finding = only(cells(page), %w[check])

    assert_equal "MAGIK_DEV_ERROR_FIX_UNKNOWN_COMMAND", finding.code
    assert_equal "p.md:3", finding.at
    assert_includes finding.cause, "Magik::CLI::COMMANDS"
    assert_includes finding.fix, "p.md:3"
  end

  def test_a_fix_cell_naming_a_registered_command_is_silent
    assert_empty audit(cells(page_with("magik check --scale")), %w[check])
  end

  # `planned` counts. `magik help` listing a command as planned is itself the
  # documentation that it exists as an idea, and running it exits
  # MAGIK_CLI_COMMAND_NOT_IMPLEMENTED — a promise the binary keeps.
  def test_a_planned_command_is_allowed
    assert_includes registered, "check"

    assert_empty audit(cells(page_with("magik check --scale")), registered)
  end

  # The registry decides, not the design page: a command planned in a design
  # document is not a command, so a cell naming one is the finding.
  def test_a_command_that_is_only_planned_in_a_design_document_is_reported
    finding = only(cells(page_with("magik registry --json")), %w[check])

    assert_equal "MAGIK_DEV_ERROR_FIX_UNKNOWN_COMMAND", finding.code
  end

  # A command in an example is an illustration; a command in a fix cell is an
  # instruction, and only the instruction has to run.
  def test_a_command_outside_a_fix_column_is_not_read
    page = <<~MD
      | Code | Means | Fix |
      |---|---|---|
      | `MAGIK_POLICY_UNKNOWN_VERB` | `magik registry --json` | correct the verb |
    MD

    assert_empty audit(cells(page), %w[check])
  end

  def test_a_command_in_a_fenced_block_is_not_read
    page = <<~MD
      ```text
      | Code | Fix |
      |---|---|
      | `MAGIK_POLICY_UNKNOWN_VERB` | `magik registry --json` |
      ```
    MD

    assert_empty Fixes.cells(page, "p.md")
  end

  # A run of pipe lines with no separator row is not a table: there is no
  # header to read a fix column from, so the block contributes no cell.
  def test_a_block_with_no_separator_row_reads_no_cell
    page = <<~MD
      | Code | Fix |
      | `MAGIK_POLICY_UNKNOWN_VERB` | `magik registry --json` |
    MD

    assert_empty cells(page)
  end

  # A block whose first line is the separator has no header above it. Read
  # without the guard, the row *below* the separator is taken for the header —
  # the block's last row, wrapped around — and a table with no header at all
  # yields a fix column nobody wrote.
  def test_a_block_whose_first_line_is_the_separator_reads_no_cell
    page = <<~MD
      |---|---|
      | Code | Fix |
    MD

    assert_empty cells(page)
  end

  # The framework's own name in prose is not a command. `the magik gem` is a
  # sentence about what this repository ships, and reading `gem` out of it as
  # a subcommand would report a promise the reader was never given.
  def test_the_name_of_the_framework_in_prose_is_not_a_command
    page = <<~MD
      | Code | Fix |
      |---|---|
      | `MAGIK_POLICY_UNKNOWN_VERB` | read the magik gem's own policy file |
    MD

    assert_empty cells(page).flat_map(&:commands)
  end

  # The name after the binary is one token: `magik check_scale` is a command
  # the registry does not have, not `check` with a suffix to ignore. Reading
  # `check` out of it would clear a command the CLI cannot run, and reading
  # nothing out of it would let the cell past the gate unremarked — so the
  # whole token is captured and the registry rejects it.
  def test_a_command_token_is_read_whole_and_held_to_the_registry
    page = <<~MD
      | Code | Fix |
      |---|---|
      | `MAGIK_POLICY_UNKNOWN_VERB` | `magik check_scale` |
    MD

    assert_equal %w[check_scale], cells(page).first.commands

    finding = only(cells(page), %w[check])

    assert_equal "MAGIK_DEV_ERROR_FIX_UNKNOWN_COMMAND", finding.code
    assert_includes finding.cause, "magik check_scale"
  end

  # The unknown-command finding carries a `fix:` of its own, and that fix is a
  # command: the registry to read, and the cell to edit. An instruction to
  # edit the manual leaves an agent with nothing to run.
  def test_the_unknown_command_finding_carries_a_runnable_fix
    page = <<~MD
      | Code | Fix |
      |---|---|
      | `MAGIK_POLICY_UNKNOWN_VERB` | `magik registry --json` |
    MD
    finding = only(cells(page), %w[check])

    assert_includes finding.fix, "ruby -Iapps/magik/lib apps/magik/exe/magik help --json"
    assert_includes finding.fix, "p.md:3"
  end

  # The other branch of the command pattern: a cell that *begins* with the
  # command, unbackticked. The manual writes every command in backticks, so
  # this shape is the easy one to lose — and a cell written without them must
  # still name a command the registry lists.
  def test_a_cell_that_begins_with_an_unbackticked_command_is_read
    page = <<~MD
      | Code | Fix |
      |---|---|
      | `MAGIK_SCALE_UNSCOPED_QUERY` | magik check --scale |
    MD

    assert_equal %w[check], cells(page).first.commands
  end

  # And the command that branch finds is held to the registry like any other:
  # matching the cell's first word is not a softer rule.
  def test_an_unbackticked_command_is_held_to_the_registry
    page = <<~MD
      | Code | Fix |
      |---|---|
      | `MAGIK_POLICY_UNKNOWN_VERB` | magik registry --json |
    MD

    assert_equal "MAGIK_DEV_ERROR_FIX_UNKNOWN_COMMAND", only(cells(page), %w[check]).code
  end

  # The column is found by its header, not by its position: two tables on the
  # same page put it in different places.
  def test_the_fix_column_is_found_by_its_header_not_its_position
    page = <<~MD
      | Fix | Code |
      |---|---|
      | `magik registry --json` | `MAGIK_POLICY_UNKNOWN_VERB` |
    MD

    assert_equal %w[registry], cells(page).first.commands
  end

  def test_a_fix_column_headed_with_a_colon_is_read
    page = <<~MD
      | Code | fix: |
      |---|---|
      | `MAGIK_POLICY_UNKNOWN_VERB` | `magik registry --json` |
    MD

    assert_equal %w[registry], cells(page).first.commands
  end

  # The manual writes `\|` inside a fix cell — `can :read do \|actor,
  # invoice\|` — and a naive split cuts the cell in half and shifts every
  # later one, which would hide a command written after the escape.
  def test_a_fix_cell_whose_pipes_are_escaped_is_read_whole
    page = <<~MD
      | Code | Fix |
      |---|---|
      | `MAGIK_POLICY_NULL_PASSES` | deny the `nil` — `can :read do \\|actor, invoice\\| then run `magik check` |
    MD

    assert_equal %w[check], cells(page).first.commands
  end

  # The corrected advice is pinned: the manual the framework ships names no
  # command the CLI does not have. The assertion fails if the rule stops
  # reading the page — the corpus would be empty — and if a cell regresses.
  def test_the_real_manual_names_no_unregistered_command
    found = Fixes.cells(MagikScripts::Repo.read(Fixes::MANUAL), Fixes::MANUAL)

    refute_empty found, "the rule read no fix cells from #{Fixes::MANUAL}"
    assert_empty Fixes.audit(cells: found, commands: registered)
  end

  # A corpus that quietly shrinks is the failure mode `Check#nothing_scanned`
  # exists to prevent: a rule that matches nothing must not look like a rule
  # that found nothing wrong.
  def test_the_real_manual_names_commands_at_all
    found = Fixes.cells(MagikScripts::Repo.read(Fixes::MANUAL), Fixes::MANUAL)

    refute_empty found.flat_map(&:commands)
  end

  # The rule is worth what the check does with it, so this drives
  # `ErrorCodes#run` end to end: a fix cell naming a command the registry does
  # not have must fail the check, with the code and the cell to edit.
  def test_the_check_fails_on_a_fix_cell_naming_an_unregistered_command
    result = FixtureErrorCodes.new(commands: ["registry"]).run

    assert_predicate result, :fail?
    finding = result.findings.find { |entry| entry.code == "MAGIK_DEV_ERROR_FIX_UNKNOWN_COMMAND" }

    refute_nil finding, "the check did not report the unregistered command"
    assert_equal "wiki/Error-Codes.md:3", finding.at
    assert_includes finding.fix, "wiki/Error-Codes.md:3"
  end

  # The whole token is what the run judges. A cell naming `magik check_scale`
  # used to yield no command at all, so the run passed a cell the reader
  # cannot run; the token is captured whole and the run reports it.
  def test_the_check_fails_on_a_command_token_the_registry_does_not_have
    result = FixtureErrorCodes.new(commands: ["check_scale"]).run

    assert_predicate result, :fail?
    finding = result.findings.find { |entry| entry.code == "MAGIK_DEV_ERROR_FIX_UNKNOWN_COMMAND" }

    refute_nil finding, "the check did not report the unregistered command"
    assert_includes finding.cause, "magik check_scale"
  end

  # A manual whose fix cells name no command at all has not been checked:
  # the rule would look like it had found nothing wrong.
  def test_a_manual_naming_no_command_at_all_is_not_scanned
    result = FixtureErrorCodes.new(commands: []).run

    assert_predicate result, :fail?
    assert_includes result.findings.map(&:code), "MAGIK_DEV_CHECK_NOTHING_SCANNED"
  end

  # A manual with no fix column at all has not been checked either: the rule
  # finds no cells to read, and a rule that reads nothing looks exactly like a
  # rule that found nothing wrong.
  #
  # The corpus the finding names is the fix columns themselves, not the
  # commands inside them: two guards ask the same question over two corpora,
  # and this one pins the first.
  def test_a_manual_with_no_fix_column_is_not_scanned
    result = FixtureErrorCodes.new(cells: []).run

    assert_predicate result, :fail?
    finding = result.findings.find { |entry| entry.code == "MAGIK_DEV_CHECK_NOTHING_SCANNED" }

    refute_nil finding, "the check did not report the empty corpus"
    assert_equal Fixes::CORPUS, finding.at
  end

  private

  # @param markdown [String] a page
  # @return [Array<MagikScripts::Checks::FixCommands::Cell>]
  def cells(markdown)
    Fixes.cells(markdown, "p.md")
  end

  # @param command [String] a command to put in a fix cell
  # @return [String] a page whose fix cell names it
  def page_with(command)
    <<~MD
      | Code | Fix |
      |---|---|
      | `MAGIK_SCALE_UNSCOPED_QUERY` | `#{command}` |
    MD
  end

  # @param cells [Array<MagikScripts::Checks::FixCommands::Cell>]
  # @param commands [Array<String>] the commands the registry names
  # @return [Array<MagikScripts::Finding>]
  def audit(cells, commands)
    Fixes.audit(cells: cells, commands: commands)
  end

  # @param cells [Array<MagikScripts::Checks::FixCommands::Cell>]
  # @param commands [Array<String>]
  # @return [MagikScripts::Finding]
  def only(cells, commands)
    findings = audit(cells, commands)

    assert_equal 1, findings.size, "expected one finding, got #{findings.map(&:code)}"
    findings.first
  end

  # @return [Array<String>] the commands the CLI registry names
  def registered
    MagikScripts::Library.load!::CLI::COMMANDS.keys
  end
end
