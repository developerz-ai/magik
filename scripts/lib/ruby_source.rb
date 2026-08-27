# frozen_string_literal: true

require "ripper"

module MagikScripts
  # Reads Ruby source with Ruby's own lexer.
  #
  # A regex over source text cannot tell `require "magik/model"` from the same
  # words inside a doc comment or a heredoc, and every check that tried has
  # eventually reported on its own documentation. `Ripper` is stdlib on CRuby
  # and TruffleRuby alike, it needs no gem, and it answers exactly the two
  # questions the boundary rules ask: what does this file require, and which
  # constants does its **code** name.
  #
  # What it therefore cannot see, on purpose:
  #
  # 1. a dynamic `require "magik/#{name}"` — the specifier is not a literal, so
  #    it is skipped. `lib/magik.rb`'s autoload loop is the only one in the tree
  #    and that file is exempt from the tier rules anyway.
  # 2. a constant reached through `const_get` or `Object.const_get`.
  # 3. a bare nested reference (`Model::Definition` inside `Magik::Action`)
  #    whose first segment is not itself a subsystem constant.
  module RubySource
    # One `require` or `require_relative` with a literal specifier.
    Require = Struct.new(:spec, :relative, :line, keyword_init: true)

    # One constant named by code — never by a comment, string or symbol.
    ConstRef = Struct.new(:name, :line, keyword_init: true)

    # Tokens that carry no meaning for either rule.
    # @return [Array<Symbol>]
    NOISE = %i[on_sp on_comment on_ignored_nl on_nl on_lparen on_rparen].freeze

    # The two require forms. `load` and `autoload` are deliberately absent:
    # neither appears in `lib/` outside the exempt entry point.
    # @return [Array<String>]
    REQUIRE_METHODS = %w[require require_relative].freeze

    module_function

    # @param source [String] Ruby source
    # @return [Array<Array>] `Ripper.lex` output with whitespace and comments removed
    def tokens(source)
      (Ripper.lex(source) || []).reject { |token| NOISE.include?(token[1]) }
    end

    # Every `require`/`require_relative` with a literal string specifier.
    #
    # @param source [String] Ruby source
    # @return [Array<MagikScripts::RubySource::Require>]
    def requires(source)
      list = tokens(source)
      list.each_with_index.filter_map do |(pos, type, text), index|
        next unless type == :on_ident && REQUIRE_METHODS.include?(text)

        spec = literal_string(list, index + 1)
        next if spec.nil?

        Require.new(spec: spec, relative: text == "require_relative", line: pos[0])
      end
    end

    # The specifier only when it is one whole literal — `"magik/model"`, never
    # `"magik/#{name}"`. An interpolated require is a specifier this reader
    # cannot know, and half of one is worse than none: it would report the
    # autoload loop in `lib/magik.rb` as a require of a subsystem called `""`.
    #
    # @param list [Array<Array>] tokens
    # @param index [Integer] where the string should begin
    # @return [String, nil]
    def literal_string(list, index)
      beg, body, fin = list[index, 3]
      return nil unless beg && body && fin
      return nil unless beg[1] == :on_tstring_beg && body[1] == :on_tstring_content
      return nil unless fin[1] == :on_tstring_end

      body[2]
    end

    # Every constant named by code, as a `Magik::Foo` path or a bare `Foo`.
    #
    # Symbols are excluded — `:Core` in a Hash literal lexes as a constant token
    # and is a *name*, not a reference — and so are `module Foo` / `class Foo`
    # declarations, which define rather than reach for a constant.
    #
    # @param source [String] Ruby source
    # @return [Array<MagikScripts::RubySource::ConstRef>]
    def constant_refs(source)
      list = tokens(source)
      list.each_with_index.filter_map do |(pos, type, text), index|
        next unless type == :on_const
        next if declaration?(list, index) || symbol?(list, index) || scoped?(list, index)
        next if assignment?(list, index)

        name = qualified(list, index) || text
        ConstRef.new(name: name, line: pos[0])
      end
    end

    # @param list [Array<Array>] tokens
    # @param index [Integer]
    # @return [Boolean] true for `module Foo` and `class Foo`
    def declaration?(list, index)
      previous = list[index - 1]
      index.positive? && previous[1] == :on_kw && %w[module class].include?(previous[2])
    end

    # Assignment operators, so `SUBSYSTEMS = {...}` reads as a definition
    # rather than as a reach for a constant that does not exist yet.
    # @return [Array<String>]
    ASSIGNMENT = ["=", "||=", "&&=", "|=", "&=", "^=", "+=", "-=", "*=", "/=", "%=", "**=",
                  "<<=", ">>="].freeze

    # @param list [Array<Array>] tokens
    # @param index [Integer]
    # @return [Boolean] true for `FOO = ...`
    def assignment?(list, index)
      following = list[index + 1]
      !following.nil? && following[1] == :on_op && ASSIGNMENT.include?(following[2])
    end

    # @param list [Array<Array>] tokens
    # @param index [Integer]
    # @return [Boolean] true for `:Foo` and `foo: :Foo`
    def symbol?(list, index)
      index.positive? && list[index - 1][1] == :on_symbeg
    end

    # @param list [Array<Array>] tokens
    # @param index [Integer]
    # @return [Boolean] true when this constant is the right half of `A::B`,
    #   already reported as part of the qualified name
    def scoped?(list, index)
      index.positive? && list[index - 1][1] == :on_op && list[index - 1][2] == "::"
    end

    # @param list [Array<Array>] tokens
    # @param index [Integer]
    # @return [String, nil] `"Magik::Model"` when the next two tokens are `::Foo`
    def qualified(list, index)
      separator = list[index + 1]
      target = list[index + 2]
      return nil unless separator && target && separator[1] == :on_op && separator[2] == "::"
      return nil unless target[1] == :on_const

      "#{list[index][2]}::#{target[2]}"
    end
  end
end
