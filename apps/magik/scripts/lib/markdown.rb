# frozen_string_literal: true

module MagikScripts
  # Just enough Markdown to check a document, and no more.
  #
  # This is not a parser and must never grow into one. It answers the four
  # questions the checks actually ask — where the fenced blocks are, what the
  # prose links to, what a named section contains, and what a table's rows say —
  # and every answer carries a **line number**, because a finding that cannot
  # name `file:line` is a finding somebody has to go and search for.
  #
  # {#without_fences} blanks fenced blocks *in place*, keeping the line count,
  # so a line number taken from the stripped text still points at the original
  # file. That is the whole reason it is not a `gsub`.
  class Markdown
    # One fenced code block.
    Fence = Struct.new(:lang, :body, :line, keyword_init: true)

    # One inline link found in prose.
    Link = Struct.new(:text, :target, :line, keyword_init: true)

    # The opening of a fenced block: three or more backticks or tildes, then an
    # optional info string whose first word is the language.
    # @return [Regexp]
    FENCE_OPEN = /\A\s*(`{3,}|~{3,})\s*([A-Za-z0-9_+-]*)/

    # `[text](target)`, with an optional quoted title.
    # @return [Regexp]
    LINK = /\[([^\]\n]*)\]\(([^)\s]+)(?:\s+"[^"]*")?\)/

    # @return [String] the document, verbatim
    attr_reader :source

    # @return [String, nil] where it came from, for findings
    attr_reader :path

    # @param source [String] Markdown text
    # @param path [String, nil] the root-relative path, used in findings
    def initialize(source, path: nil)
      @source = source
      @path = path
    end

    # Every fenced code block, in document order.
    #
    # @return [Array<MagikScripts::Markdown::Fence>]
    def fences
      @fences ||= collect_fences
    end

    # The document with every fenced block replaced by blank lines, so line
    # numbers still line up with the original.
    #
    # @return [String]
    def without_fences
      @without_fences ||= blank_fenced_lines
    end

    # Every inline link outside a fenced block. A link inside an example is an
    # illustration, not a promise that the path exists.
    #
    # @return [Array<MagikScripts::Markdown::Link>]
    def links
      without_fences.each_line.with_index(1).flat_map do |line, number|
        line.scan(LINK).map { |text, target| Link.new(text: text, target: target, line: number) }
      end
    end

    # The body of one ATX section: everything after the heading, up to the next
    # heading at the same level or higher.
    #
    # @param title [String, Regexp] the heading text, without the `#`s
    # @return [String, nil] the section body, or nil when there is no such heading
    def section(title)
      lines = source.lines
      start = lines.index { |line| heading_matches?(line, title) }
      return nil if start.nil?

      level = lines[start][/\A(#+)/, 1].length
      rest = lines[(start + 1)..] || []
      stop = rest.index { |line| (line[/\A(#+)\s/, 1] || "").length.between?(1, level) }
      (stop ? rest.first(stop) : rest).join
    end

    # The cells of every pipe-table row in `text`, header and separator rows
    # dropped. The header is recognised by the separator underneath it, which
    # is the only thing that distinguishes it from a data row.
    #
    # @param text [String] a section body, or the whole document
    # @return [Array<Array<String>>] one array of trimmed cells per row
    def self.table_rows(text)
      rows = []
      text.to_s.each_line do |line|
        stripped = line.strip
        next unless stripped.start_with?("|")

        next rows.pop if separator?(stripped)

        rows << cells(stripped)
      end
      rows
    end

    # @param line [String] a stripped table line
    # @return [Boolean] true for `|---|:--|`
    def self.separator?(line)
      line.match?(/\A\|[\s:|-]+\|\z/)
    end

    # @param line [String] a stripped table line
    # @return [Array<String>] its trimmed cells
    def self.cells(line)
      line.delete_prefix("|").delete_suffix("|").split("|").map(&:strip)
    end

    private

    # @param line [String] a candidate heading line
    # @param title [String, Regexp] what to match after the `#`s
    # @return [Boolean]
    def heading_matches?(line, title)
      text = line.chomp[/\A#+\s+(.*)\z/, 1]
      return false if text.nil?

      title.is_a?(Regexp) ? title.match?(text.strip) : text.strip.casecmp?(title.to_s)
    end

    # @return [Array<MagikScripts::Markdown::Fence>]
    def collect_fences
      out = []
      open = nil
      body = []
      source.each_line.with_index(1) do |line, number|
        if open.nil?
          match = FENCE_OPEN.match(line)
          open = { marker: match[1], lang: match[2].downcase, line: number } if match
        elsif line.strip == open[:marker]
          out << Fence.new(lang: open[:lang], body: body.join, line: open[:line])
          open = nil
          body = []
        else
          body << line
        end
      end
      out.freeze
    end

    # @return [String] the source with fenced lines emptied, line count intact
    def blank_fenced_lines
      fenced = fences.each_with_object({}) do |fence, set|
        (fence.line..(fence.line + fence.body.lines.size + 1)).each { |n| set[n] = true }
      end
      source.each_line.with_index(1).map { |line, number| fenced[number] ? "\n" : line }.join
    end
  end
end
