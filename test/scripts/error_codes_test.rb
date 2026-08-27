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

    assert_equal "MAGIK_ERROR_CODE_MALFORMED", finding.code
    assert_includes finding.cause, "not MAGIK_<SUBSYSTEM>_<CONDITION>"
  end

  def test_a_subclass_that_inherits_its_code_is_reported
    finding = only(declared(own_code: false), %w[MAGIK_A])

    assert_equal "MAGIK_ERROR_CODE_UNDECLARED", finding.code
    assert_includes finding.fix, "add `code"
  end

  def test_the_base_class_may_carry_the_default_code
    assert_empty ErrorCodes.audit(declared: declared(own_code: false, base: true),
                                  documented: %w[MAGIK_A], format: FORMAT)
  end

  def test_two_classes_claiming_one_code_are_reported
    pair = declared(name: "Magik::A") + declared(name: "Magik::B")
    finding = ErrorCodes.audit(declared: pair, documented: %w[MAGIK_A], format: FORMAT).first

    assert_equal "MAGIK_ERROR_CODE_DUPLICATE", finding.code
    assert_includes finding.cause, "Magik::A and Magik::B"
  end

  def test_a_fix_that_is_advice_rather_than_a_command_is_reported
    finding = only(declared(fix: "check your configuration and try again"), %w[MAGIK_A])

    assert_equal "MAGIK_ERROR_FIX_ADVICE", finding.code
    assert_includes finding.fix, "replace the fix:"
  end

  def test_a_shipped_code_that_no_page_documents_is_reported
    finding = only(declared, [])

    assert_equal "MAGIK_ERROR_CODE_UNDOCUMENTED", finding.code
    assert_equal "wiki/Error-Codes.md", finding.at
  end

  def test_a_documented_code_that_nothing_raises_is_reported
    finding = ErrorCodes.audit(declared: declared, documented: %w[MAGIK_A MAGIK_GHOST],
                               format: FORMAT).first

    assert_equal "MAGIK_ERROR_CODE_PHANTOM", finding.code
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
