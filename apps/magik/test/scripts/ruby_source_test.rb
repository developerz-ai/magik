# frozen_string_literal: true

require_relative "helper"

# The Ripper-backed source reader. The cases that matter are the ones a regex
# gets wrong: a require inside a doc comment, a constant inside a string, and
# `:Core` in `lib/magik.rb`'s SUBSYSTEMS map, which lexes as a constant token
# and is a name rather than a reference.
class MagikScriptsRubySourceTest < Minitest::Test
  RubySource = MagikScripts::RubySource

  def test_requires_carry_their_specifier_kind_and_line
    statements = RubySource.requires(%(require "json"\nrequire_relative "../version"\n))

    assert_equal %w[json ../version], statements.map(&:spec)
    assert_equal [false, true], statements.map(&:relative)
    assert_equal [1, 2], statements.map(&:line)
  end

  def test_a_require_in_a_comment_is_not_a_require
    assert_empty RubySource.requires(%(# require "magik/render"\n))
  end

  def test_a_require_in_a_string_is_not_a_require
    assert_empty RubySource.requires(%(EXAMPLE = 'require "magik/render"'\n))
  end

  def test_a_dynamic_require_is_skipped_rather_than_guessed_at
    assert_empty RubySource.requires(%(SUBS.each { |f| require "magik/\#{f}" }\n))
  end

  def test_a_qualified_constant_is_reported_once_under_its_full_path
    names = RubySource.constant_refs(%(x = Magik::Render.compile\n)).map(&:name)

    assert_equal ["Magik::Render"], names
  end

  def test_a_symbol_is_a_name_not_a_reference
    assert_empty RubySource.constant_refs(%(SUBSYSTEMS = { core: :Core }.freeze\n))
  end

  def test_a_module_declaration_defines_rather_than_reaches
    assert_empty RubySource.constant_refs(%(module Render\nend\n))
    assert_empty RubySource.constant_refs(%(class Realtime\nend\n))
  end

  def test_a_constant_in_a_comment_is_not_a_reference
    assert_empty RubySource.constant_refs(%(# @see Magik::Realtime\n))
  end

  def test_the_real_entry_point_requires_only_what_it_says_it_does
    statements = RubySource.requires(MagikScripts::Repo.read("lib/magik.rb"))

    assert_equal %w[pathname magik/version], statements.map(&:spec)
  end
end
