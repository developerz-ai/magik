# frozen_string_literal: true

require "test_helper"

# The MAGIK_* error convention: a stable code, a cause, and a runnable fix.
class MagikErrorTest < Minitest::Test
  # A subclass declared exactly as framework code will declare one.
  class DeclaredError < Magik::Error
    code "MAGIK_DECLARED"
    fix "run `magik help`"
  end

  # A subclass that declares nothing, to prove defaults are inherited.
  class InheritedError < DeclaredError; end

  def test_error_is_a_standard_error
    assert_operator Magik::Error, :<, StandardError
  end

  def test_carries_code_cause_and_fix
    error = Magik::Error.new("the ledger does not balance", code: "MAGIK_LEDGER_UNBALANCED", fix: "run `magik check`")

    assert_equal "MAGIK_LEDGER_UNBALANCED", error.code
    assert_equal "the ledger does not balance", error.cause_text
    assert_equal "run `magik check`", error.fix
  end

  def test_message_is_the_canonical_two_line_render
    error = Magik::Error.new("boom", code: "MAGIK_BOOM", fix: "duck")

    assert_equal "MAGIK_BOOM: boom\n  fix: duck", error.message
  end

  def test_to_h_is_json_ready
    error = Magik::Error.new("boom", code: "MAGIK_BOOM", fix: "duck")

    assert_equal({ code: "MAGIK_BOOM", cause: "boom", fix: "duck" }, error.to_h)
  end

  def test_subclass_defaults_come_from_the_class_dsl
    error = DeclaredError.new("something went sideways")

    assert_equal "MAGIK_DECLARED", error.code
    assert_equal "run `magik help`", error.fix
  end

  def test_defaults_are_inherited_by_subclasses
    assert_equal "MAGIK_DECLARED", InheritedError.code
    assert_equal "run `magik help`", InheritedError.fix
  end

  def test_base_class_has_usable_defaults
    error = Magik::Error.new("something went sideways")

    assert_equal Magik::Error::DEFAULT_CODE, error.code
    assert_equal Magik::Error::DEFAULT_FIX, error.fix
  end

  def test_code_must_match_the_magik_format
    assert_raises(ArgumentError) { Magik::Error.new("boom", code: "boom") }
    assert_raises(ArgumentError) { Magik::Error.new("boom", code: "MAGIK_lower") }
    assert_raises(ArgumentError) { Magik::Error.new("boom", code: "OTHER_THING") }
    assert_raises(ArgumentError) { Class.new(Magik::Error) { code "nope" } }
  end

  def test_fix_cannot_be_blank
    assert_raises(ArgumentError) { Magik::Error.new("boom", code: "MAGIK_BOOM", fix: "   ") }
  end

  def test_shipped_error_classes_declare_stable_codes
    assert_equal "MAGIK_COMMAND_NOT_IMPLEMENTED", Magik::CommandNotImplementedError.code
    assert_equal "MAGIK_UNKNOWN_COMMAND", Magik::UnknownCommandError.code
    assert_equal "MAGIK_INVALID_OPTION", Magik::InvalidOptionError.code
    [Magik::CommandNotImplementedError, Magik::UnknownCommandError, Magik::InvalidOptionError].each do |klass|
      assert_match Magik::Error::CODE_FORMAT, klass.code
      assert_match(/\S/, klass.fix)
    end
  end

  def test_raise_with_a_class_and_a_cause_works
    error = assert_raises(Magik::UnknownCommandError) do
      raise Magik::UnknownCommandError, "`nope` is not a magik command"
    end

    assert_equal "MAGIK_UNKNOWN_COMMAND", error.code
    assert_includes error.message, "fix:"
  end
end
