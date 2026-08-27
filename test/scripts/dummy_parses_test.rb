# frozen_string_literal: true

require_relative "helper"

# The reference app parses, and that is all this check may ever assert.
class MagikScriptsDummyParsesTest < Minitest::Test
  DummyParses = MagikScripts::Checks::DummyParses

  def test_broken_ruby_is_reported_with_the_parser_s_own_message
    message = DummyParses.parse_error("def broken(\n", "dummy/app/models/magik_example.rb")

    refute_nil message
    finding = DummyParses.finding("dummy/app/models/magik_example.rb", message)

    assert_equal "MAGIK_DEV_DUMMY_PARSE_ERROR", finding.code
    assert_equal "dummy/app/models/magik_example.rb", finding.at
    assert_includes finding.fix, "ruby -c dummy/app/models/magik_example.rb"
  end

  def test_valid_ruby_is_silent
    assert_nil DummyParses.parse_error("model :Invoice do\nend\n", "dummy/app/models/invoice.rb")
  end

  def test_an_undefined_dsl_method_is_not_a_parse_error
    assert_nil DummyParses.parse_error("screen :Dashboard do\n  live :orders\nend\n",
                                       "dummy/app/models/magik_example.rb")
  end

  # The three tests above run whichever branch of `parse_error` this engine has.
  # These run the OTHER one on purpose.
  #
  # `parse_error` compiles in-process on CRuby and shells out everywhere else,
  # and TruffleRuby -- the production runtime -- is everywhere else. That branch
  # therefore never executes on a contributor's laptop, and it shipped with a
  # real bug: it ignored the `source` it was handed and re-read `path` from
  # disk, so a caller passing a string with a label that is on nobody's disk got
  # `No such file or directory` reported as a syntax error. Only
  # `truffleruby-head` in CI was red, and only for one of the three.
  #
  # A branch that only one engine runs needs a test that every engine runs.
  def test_the_shell_branch_parses_the_source_it_is_given_not_the_path
    # A path that is deliberately on nobody's disk. The source is valid, so the
    # answer is nil -- reading the path would raise LoadError instead.
    assert_nil DummyParses.shell_parse_error("screen :Dashboard do\n  live :orders\nend\n",
                                             "dummy/app/models/magik_example.rb")
  end

  def test_the_shell_branch_reports_the_real_path_not_the_temporary_one
    message = DummyParses.shell_parse_error("def broken(\n", "dummy/app/models/magik_example.rb")

    refute_nil message
    assert_includes message, "dummy/app/models/magik_example.rb"
    refute_includes message, "magik-parse"
  end

  # Both branches answer the same question about the same bytes. This is the
  # property that made the bug invisible: they only agree when the caller's
  # `source` happens to be what is at `path`, which is true in production use
  # and false in every unit test.
  def test_both_branches_agree_on_valid_and_on_broken_source
    valid  = "model :Invoice do\nend\n"
    broken = "def broken(\n"

    assert_nil DummyParses.parse_error(valid, "dummy/app/models/invoice.rb")
    assert_nil DummyParses.shell_parse_error(valid, "dummy/app/models/invoice.rb")

    refute_nil DummyParses.parse_error(broken, "dummy/app/models/magik_example.rb")
    refute_nil DummyParses.shell_parse_error(broken, "dummy/app/models/magik_example.rb")

    # Not merely "both report something" -- the SAME something. A reader should
    # not be able to tell which engine produced a finding, and a `fix:` line is
    # only stable if the message above it is.
    assert_equal DummyParses.parse_error(broken, "dummy/app/models/magik_example.rb"),
                 DummyParses.shell_parse_error(broken, "dummy/app/models/magik_example.rb")
  end

  # The normaliser, against the ACTUAL stderr each engine produces.
  #
  # These three strings are transcribed from real runs, not invented: 3.2 from a
  # laptop, 3.3/3.4 and truffleruby-head from the CI legs that went red. Two of
  # the three shapes were discovered only after a push, because no laptop runs
  # all three -- so they are pinned here, where every engine checks them.
  TMP = "/tmp/magik-parse20260101-1-abcdef.rb"
  REAL = "dummy/app/models/magik_example.rb"

  def test_normalise_strips_the_cruby_3_2_filename_prefix
    raw = "#{TMP}: #{TMP}:1: syntax error, unexpected end-of-input, expecting ')' (SyntaxError)"

    assert_equal "#{REAL}:1: syntax error, unexpected end-of-input, expecting ')'",
                 DummyParses.normalise(raw, TMP, REAL)
  end

  def test_normalise_strips_the_prism_progname_prefix
    # Ruby 3.3 and 3.4 print the PROGNAME, not the filename. Stripping "a
    # repeated path" fixed 3.2 and broke these two.
    raw = "ruby: #{TMP}:1: syntax errors found"

    assert_equal "#{REAL}:1: syntax errors found", DummyParses.normalise(raw, TMP, REAL)
  end

  def test_normalise_leaves_an_unprefixed_message_alone
    raw = "#{TMP}:1: syntax error, unexpected end-of-input"

    assert_equal "#{REAL}:1: syntax error, unexpected end-of-input",
                 DummyParses.normalise(raw, TMP, REAL)
  end

  def test_normalise_never_leaks_the_temporary_path
    [
      "#{TMP}: #{TMP}:1: syntax error (SyntaxError)",
      "ruby: #{TMP}:1: syntax errors found",
      "#{TMP}:1: syntax error"
    ].each do |raw|
      result = DummyParses.normalise(raw, TMP, REAL)

      refute_includes result, TMP, "leaked the temporary path from: #{raw}"
      refute_includes result, "magik-parse", "leaked the temp prefix from: #{raw}"
      assert result.start_with?(REAL), "did not start with the real path: #{result}"
    end
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
