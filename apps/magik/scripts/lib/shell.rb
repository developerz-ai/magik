# frozen_string_literal: true

module MagikScripts
  # A quote-aware reader for the shell snippets documentation shows.
  #
  # This is not a shell and must never become one. It exists because the naive
  # version — `line.split.first` — gets four things wrong that the docs in this
  # repo actually contain: a trailing `# comment`, a `|` pipeline, a `&&` chain,
  # and `ruby -e 'require "magik"; puts Magik::VERSION'`, where the `;` and the
  # `"` are inside a quoted argument and must not be split on.
  #
  # What it deliberately does not handle: subshells, process substitution,
  # variable expansion, and the body of a heredoc — heredoc bodies are skipped
  # whole, because they are data being fed to a command, not commands.
  module Shell
    # One command as documentation presents it.
    Command = Struct.new(:tokens, :line, :raw, keyword_init: true)

    # Separators that end one command and begin another.
    # @return [Array<String>]
    SEPARATORS = ["&&", "||", "|", ";"].freeze

    # `VAR=value` prefixes and wrappers that are not the command being run.
    # @return [Regexp]
    PREFIX = /\A(?:[A-Za-z_][A-Za-z0-9_]*=|sudo\z|time\z|env\z|exec\z)/

    # The two quote characters this reader tracks. Backslash escaping inside a
    # quoted word is not modelled; no snippet in this repo's documentation uses
    # it, and guessing wrong there is worse than not guessing.
    # @return [Array<String>]
    QUOTES = ["'", '"'].freeze

    # Shell keywords a line may open with. They are control flow, not programs.
    # @return [Array<String>]
    KEYWORDS = %w[if then else elif fi for while until do done case esac function return].freeze

    module_function

    # Every command in a snippet, in order, with the line it sits on.
    #
    # @param script [String] the body of a fenced shell block
    # @return [Array<MagikScripts::Shell::Command>]
    def commands(script)
      out = []
      pending = +""
      pending_line = 0
      heredoc = nil
      script.each_line.with_index(1) do |raw, number|
        line = raw.chomp
        if heredoc
          heredoc = nil if line.strip == heredoc
          next
        end

        heredoc = heredoc_terminator(line)
        pending_line = number if pending.empty?
        pending << strip_comment(line)
        next if pending.end_with?("\\") && pending.sub!(/\\\z/, " ")

        out.concat(parse(pending, pending_line))
        pending = +""
      end
      out
    end

    # @param text [String] one logical line
    # @param number [Integer] the line it started on
    # @return [Array<MagikScripts::Shell::Command>]
    def parse(text, number)
      segments(text).filter_map do |segment|
        tokens = normalise(tokenize(segment))
        next if tokens.empty? || KEYWORDS.include?(tokens.first)

        Command.new(tokens: tokens, line: number, raw: segment.strip)
      end
    end

    # Remove a trailing `# comment`, ignoring `#` inside quotes.
    #
    # @param line [String]
    # @return [String]
    def strip_comment(line)
      quote = nil
      line.each_char.with_index do |char, index|
        quote = quote_after(quote, line, index)
        return line[0, index].rstrip if quote.nil? && char == "#" && boundary?(line, index)
      end
      line.rstrip
    end

    # Split on `&&`, `||`, `|` and `;` outside quotes.
    #
    # @param line [String]
    # @return [Array<String>]
    def segments(line)
      out = [+""]
      index = 0
      quote = nil
      while index < line.length
        quote = quote_after(quote, line, index)
        separator = quote.nil? && SEPARATORS.find { |s| line[index, s.length] == s }
        if separator
          out << +""
          index += separator.length
        else
          out.last << line[index]
          index += 1
        end
      end
      out.map(&:strip).reject(&:empty?)
    end

    # Split a command into words, dropping the quote characters.
    #
    # @param segment [String]
    # @return [Array<String>]
    def tokenize(segment)
      out = [+""]
      quote = nil
      segment.each_char do |char|
        if quote
          char == quote ? quote = nil : out.last << char
        elsif QUOTES.include?(char)
          quote = char
        elsif char.match?(/\s/)
          out << +""
        else
          out.last << char
        end
      end
      out.reject(&:empty?)
    end

    # Drop `VAR=value`, `sudo`, `time`, `env` and a `bundle exec` wrapper, so
    # the first token left is the program the reader is really being told to run.
    #
    # @param tokens [Array<String>]
    # @return [Array<String>]
    def normalise(tokens)
      rest = tokens.drop_while { |token| PREFIX.match?(token) }
      rest = rest.drop(2) if rest.first(2) == %w[bundle exec]
      rest
    end

    # @param line [String]
    # @return [String, nil] the terminator word of a heredoc opened on this line
    def heredoc_terminator(line)
      line[/<<[-~]?\s*["']?([A-Za-z_][A-Za-z0-9_]*)["']?/, 1]
    end

    # @param quote [String, nil] the quote character currently open
    # @param text [String]
    # @param index [Integer]
    # @return [String, nil] the quote character open *after* this character
    def quote_after(quote, text, index)
      char = text[index]
      return quote if index.positive? && text[index - 1] == "\\"
      return char == quote ? nil : quote unless quote.nil?

      QUOTES.include?(char) ? char : nil
    end

    # @param line [String]
    # @param index [Integer]
    # @return [Boolean] true when a `#` here starts a comment rather than a word
    def boundary?(line, index)
      index.zero? || line[index - 1].match?(/\s/)
    end
  end
end
