# frozen_string_literal: true

require_relative "repo"

module MagikScripts
  # Discovery: what checks exist, what each one answers, and in what order they
  # should run. This is the contract `bin/check` globs.
  #
  # Metadata is read from a **comment header**, not from Ruby:
  #
  #     # @check   boundaries
  #     # @summary Requires inside lib/magik/ go down a tier only.
  #     # @order   10
  #     #
  #     # Prose. Everything from here to the end of the comment block is the
  #     # check's `--help` text.
  #
  # Reading a header costs one `File.foreach`, loads no gem, and cannot run a
  # check by accident — so `bin/check --list` stays honest even when a check is
  # syntactically broken. It is also the only copy: the `Check` subclass does
  # not restate its name, so the two cannot drift apart.
  module Registry
    # Where checks live, relative to the repo root.
    # @return [String]
    GLOB = "scripts/checks/*.rb"

    # How far into a file to look for the header before giving up. Generous
    # enough for a shebang, the magic comment and a blank line; small enough
    # that a file with no header fails fast.
    # @return [Integer]
    HEADER_SCAN_LINES = 40

    # A check's name is lowercase, hyphen-separated, and matches its file
    # basename with `_` for `-`. Both halves are enforced, so `--only` can name
    # a check and a reader can find its file.
    # @return [Regexp]
    NAME_FORMAT = /\A[a-z][a-z0-9]*(?:-[a-z0-9]+)*\z/

    # Raised when a file in {GLOB} does not declare a readable header. It is a
    # hard error, never a skip: a check that quietly drops out of discovery is
    # a check that stops gating.
    class HeaderError < StandardError; end

    # One discovered check.
    Entry = Struct.new(:name, :summary, :order, :description, :path, keyword_init: true) do
      # @return [String] the command that runs this check on its own
      def command
        "ruby #{path}"
      end

      # @return [Hash{Symbol => Object}] for `--json` and the manifest
      def to_h
        { name: name, summary: summary, order: order, path: path }
      end
    end

    module_function

    # Every check, cheapest first. Ties break on name so the order is total.
    #
    # @return [Array<MagikScripts::Registry::Entry>]
    # @raise [MagikScripts::Registry::HeaderError] if any check has no header,
    #   or if two checks claim one name or one order
    def discover
      entries = Repo.glob(GLOB).map { |rel| parse(rel) }.sort_by { |e| [e.order, e.name] }
      assert_unique!(entries, :name)
      assert_unique!(entries, :order)
      entries
    end

    # @param name [String] a check name, as declared in its header
    # @return [MagikScripts::Registry::Entry, nil]
    def find(name)
      discover.find { |entry| entry.name == name }
    end

    # Read one check's header.
    #
    # @param file [String, Pathname] path to a check, absolute or root-relative
    # @return [MagikScripts::Registry::Entry]
    # @raise [MagikScripts::Registry::HeaderError] on a missing or malformed header
    def parse(file)
      rel = relative(file)
      lines = header_lines(rel)
      entry = Entry.new(name: tag(lines, rel, "check"), summary: tag(lines, rel, "summary"),
                        order: Integer(tag(lines, rel, "order"), 10), description: description(lines),
                        path: rel)
      validate!(entry, rel)
      entry
    end

    # @param file [String, Pathname] any path
    # @return [String] the same path relative to the repo root
    def relative(file)
      absolute = File.expand_path(file.to_s, Repo.root.to_s)
      Pathname.new(absolute).relative_path_from(Repo.root).to_s
    end

    # The leading comment block, `# ` stripped, up to the first non-comment line.
    #
    # @param rel [String] root-relative path
    # @return [Array<String>]
    def header_lines(rel)
      out = []
      started = false
      Repo.path(rel).each_line.first(HEADER_SCAN_LINES).each do |line|
        stripped = line.chomp
        next if !started && !stripped.start_with?("# @")

        started = true
        break unless stripped.start_with?("#")

        out << stripped.sub(/\A#\s?/, "")
      end
      out
    end

    # @param lines [Array<String>] from {header_lines}
    # @param rel [String] root-relative path, for the error message
    # @param name [String] the tag to read, without the `@`
    # @return [String] the tag's value
    # @raise [MagikScripts::Registry::HeaderError] when the tag is absent or blank
    def tag(lines, rel, name)
      value = lines.filter_map { |l| l[/\A@#{name}\s+(\S.*)\z/, 1] }.first
      raise HeaderError, header_error(rel, "no `# @#{name} ...` line") if value.nil?

      value.strip
    end

    # Everything after the last `@tag` line: the check's `--help` prose.
    #
    # @param lines [Array<String>] from {header_lines}
    # @return [String]
    def description(lines)
      last_tag = lines.rindex { |l| l.start_with?("@") } || -1
      lines[(last_tag + 1)..].to_a.join("\n").strip
    end

    # @param entry [MagikScripts::Registry::Entry]
    # @param rel [String] root-relative path
    # @return [void]
    # @raise [MagikScripts::Registry::HeaderError]
    def validate!(entry, rel)
      unless NAME_FORMAT.match?(entry.name)
        raise HeaderError, header_error(rel, "@check #{entry.name.inspect} must match #{NAME_FORMAT.source}")
      end

      expected = entry.name.tr("-", "_")
      return if File.basename(rel, ".rb") == expected

      raise HeaderError, header_error(rel, "@check #{entry.name.inspect} wants the file named #{expected}.rb")
    end

    # @param entries [Array<MagikScripts::Registry::Entry>]
    # @param field [Symbol] `:name` or `:order`
    # @return [void]
    # @raise [MagikScripts::Registry::HeaderError] on a duplicate
    def assert_unique!(entries, field)
      dupes = entries.group_by { |e| e[field] }.select { |_, group| group.size > 1 }
      return if dupes.empty?

      detail = dupes.map { |value, group| "@#{field} #{value} claimed by #{group.map(&:path).join(", ")}" }
      raise HeaderError, "scripts/checks: #{detail.join("; ")}\n  " \
                         "fix: give each check a unique @#{field} in its header comment"
    end

    # @param rel [String] root-relative path
    # @param detail [String] what is wrong
    # @return [String] a message carrying its own fix
    def header_error(rel, detail)
      "#{rel}: #{detail}\n  " \
        "fix: add the discovery header to #{rel} — see scripts/README.md, " \
        "\"The discovery contract\""
    end
  end
end
