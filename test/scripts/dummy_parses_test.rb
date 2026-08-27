# frozen_string_literal: true

require_relative "helper"

# The reference app parses, and that is all this check may ever assert.
class MagikScriptsDummyParsesTest < Minitest::Test
  DummyParses = MagikScripts::Checks::DummyParses

  def test_broken_ruby_is_reported_with_the_parser_s_own_message
    message = DummyParses.parse_error("def broken(\n", "dummy/app/models/x.rb")

    refute_nil message
    finding = DummyParses.finding("dummy/app/models/x.rb", message)

    assert_equal "MAGIK_DUMMY_PARSE_ERROR", finding.code
    assert_equal "dummy/app/models/x.rb", finding.at
    assert_includes finding.fix, "ruby -c dummy/app/models/x.rb"
  end

  def test_valid_ruby_is_silent
    assert_nil DummyParses.parse_error("model :Invoice do\nend\n", "dummy/app/models/invoice.rb")
  end

  def test_an_undefined_dsl_method_is_not_a_parse_error
    assert_nil DummyParses.parse_error("screen :Dashboard do\n  live :orders\nend\n", "dummy/x.rb")
  end

  def test_the_check_walks_dummy_which_every_other_check_skips
    assert_empty MagikScripts::Repo.glob(MagikScripts::Checks::DummyParses::CORPUS)
    refute_empty MagikScripts::Repo.glob(MagikScripts::Checks::DummyParses::CORPUS, dummy: true)
  end

  def test_every_file_in_the_real_reference_app_parses
    status, out, = run_script("scripts/checks/dummy_parses.rb")

    assert_equal 0, status, out
  end
end
