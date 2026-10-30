# frozen_string_literal: true

# The check library for this application's own rules.
#
# One file, no dependencies beyond the standard library, deliberately small: a
# new check should be a short file, not a project.
#
# The contract — the header format, the three statuses, the exit codes, the JSON
# shape — is identical to the magik framework repository's `scripts/lib/`, so an
# agent that has learned one has learned both.
#
# FRAMEWORK-OWNED: `magik generate agents --update` replaces this file. Your
# rules go in `scripts/checks/`, which is never touched. See scripts/README.md.
#
# @see AppScripts::Check
module AppScripts
  # The application root — the directory holding `config/app.rb`.
  #
  # Nothing here changes the process's working directory: a check must be
  # runnable from a subdirectory, and `Dir.chdir` in a library is a trap for
  # the next caller. Every path a check reports is root-relative, so a finding
  # can be pasted straight into an editor.
  module Root
    # Directories no check walks, whatever it is looking for.
    EXCLUDED = %w[vendor doc pkg tmp log coverage node_modules .git .bundle].freeze

    module_function

    # @return [String] absolute path to the application root
    def path(*parts) = File.expand_path(File.join(*parts), dir)

    # @return [String]
    def dir = @dir ||= File.expand_path("../..", __dir__)

    # @param rel [String] root-relative path
    # @return [Boolean]
    def exist?(rel) = File.exist?(path(rel))

    # @param rel [String] root-relative path
    # @return [String] file contents
    def read(rel) = File.read(path(rel), encoding: "UTF-8")

    # @param pattern [String] a Dir.glob pattern, root-relative
    # @return [Array<String>] sorted, root-relative paths
    def glob(pattern)
      Dir.glob(pattern, base: dir).reject { |rel| EXCLUDED.include?(rel.split("/").first) }.sort
    end

    # @param haystack [String] file contents
    # @param needle [String, Regexp]
    # @return [Integer, nil] 1-based line number of the first match
    def line_of(haystack, needle)
      haystack.each_line.with_index(1) do |line, number|
        return number if needle.is_a?(Regexp) ? needle.match?(line) : line.include?(needle)
      end
      nil
    end
  end

  # One violation: a stable code, a cause naming real identifiers, a runnable
  # fix, and the place to go and edit.
  Finding = Struct.new(:code, :cause, :fix, :at, keyword_init: true) do
    # @return [String] the rendering a human reads
    def render(indent = "  ")
      head = at.nil? ? code : "#{code} (#{at})"
      ["#{indent}#{head}", "#{indent}  cause: #{cause}", "#{indent}  fix:   #{fix}"].join("\n")
    end

    # @return [Hash] the `--json` rendering; nil fields are dropped
    def to_h = { code: code, cause: cause, fix: fix, at: at }.compact

    # @return [Array<String>] so two runs report in one order
    def sort_key = [at.to_s, code.to_s, cause.to_s]
  end

  # The verdict of one check: three statuses, not two.
  #
  # `missing` is an environment that has not been set up; `fail` is an app that
  # is wrong. Both exit non-zero — a check you could not run is not a check you
  # passed — but they read differently and have different fixes.
  class Result
    PASS = "pass"
    FAIL = "fail"
    MISSING = "missing"

    # sysexits-style: 69 is EX_UNAVAILABLE.
    EXIT_CODES = { PASS => 0, FAIL => 1, MISSING => 69 }.freeze

    attr_reader :status, :reason, :expected, :got, :fix, :findings

    # A satisfied check. `got` must say what was actually inspected, because
    # "no violations" and "nothing was looked at" are otherwise one sentence.
    def self.ok(got:, expected:, reason: nil) = new(status: PASS, expected: expected, got: got, reason: reason)

    def self.failure(reason:, expected:, fix:, findings: [], got: nil)
      new(status: FAIL, reason: reason, expected: expected, fix: fix, findings: findings,
          got: got || "#{findings.size} finding#{"s" unless findings.size == 1}")
    end

    def self.missing_tool(tool:, install:, expected:)
      new(status: MISSING, reason: "tool_not_installed:#{tool}", expected: expected,
          got: "`#{tool}` is not runnable here", fix: install)
    end

    def initialize(status:, expected:, got:, reason: nil, fix: nil, findings: [])
      @status = status
      @expected = expected
      @got = got
      @reason = reason
      @fix = fix
      @findings = findings.sort_by(&:sort_key).freeze
      freeze
    end

    def pass? = status == PASS
    def fail? = status == FAIL
    def missing? = status == MISSING
    def exit_code = EXIT_CODES.fetch(status)

    def to_h
      { ok: pass?, status: status, exit_code: exit_code, reason: reason,
        expected: expected, got: got, fix: fix, findings: findings.map(&:to_h) }
    end
  end

  # The contract every file in `scripts/checks/` implements: one question about
  # this application, answered by `#run` as a {Result}.
  #
  # A check is a program, not a plugin. It runs standalone
  # (`ruby scripts/checks/<name>.rb`), speaks `--json`, exits 0 / 1 / 64 / 69,
  # and requiring its file must not run it — the entry point is guarded by
  # `if $PROGRAM_NAME == __FILE__` so a test can load it.
  #
  # **Split the pure rule from the collector.** A class method that takes data
  # and returns findings is what a test exercises with fixtures; `#run` is the
  # thin half that reads the real tree. A rule that can only be tested by
  # editing the app has no negative case.
  #
  # @abstract Subclass and override {#run}.
  class Check
    # Extra flags this check accepts, as flag => option key.
    # @return [Hash{String => Symbol}]
    def self.flags = {}

    attr_reader :options

    def initialize(**options)
      @options = options
    end

    # @abstract
    # @return [AppScripts::Result]
    def run
      raise NotImplementedError, "#{self.class}#run must return an AppScripts::Result"
    end

    private

    def ok(got:, expected:, reason: nil) = Result.ok(got: got, expected: expected, reason: reason)

    def failure(reason:, expected:, fix:, findings: [], got: nil)
      Result.failure(reason: reason, expected: expected, fix: fix, findings: findings, got: got)
    end

    def missing_tool(tool:, install:, expected:)
      Result.missing_tool(tool: tool, install: install, expected: expected)
    end

    # The precondition for this rule is absent **by design**, so there is
    # nothing to assert and that is correct rather than suspicious.
    #
    # This is the one place an app check departs from the framework repo's
    # library, and the departure is deliberate. There, an empty corpus is always
    # a failure: `lib/magik/**/*.rb` matching nothing means somebody moved a
    # directory and the check went quiet instead of red. Here, a flat app with
    # no `domains/` and an app with no migrations yet are both ordinary, and
    # failing a fresh app's gate would teach its owner to ignore the gate.
    #
    # **Use it only when absence is a legitimate state of the app**, and say so
    # in `got`. If a glob that should have matched comes back empty, that is a
    # {#failure} — never this.
    def not_applicable(because:, expected:)
      Result.ok(got: "not applicable — #{because}", expected: expected, reason: "not_applicable")
    end
  end

  # Discovery: what checks exist and in what order they run. This is the
  # contract `bin/check` globs.
  #
  # Metadata is read from a comment header, not from Ruby:
  #
  #     # @check   i18n-coverage
  #     # @summary Every t() key resolves in every declared locale.
  #     # @order   30
  #
  # Reading a header costs one read, loads nothing, and cannot run a check by
  # accident — so `bin/check --list` stays honest even when a check is broken.
  module Registry
    GLOB = "scripts/checks/*.rb"
    HEADER_SCAN_LINES = 40
    NAME_FORMAT = /\A[a-z][a-z0-9]*(?:-[a-z0-9]+)*\z/

    # A check that quietly drops out of discovery is a check that stops gating,
    # so a bad header is a hard error and never a skip.
    class HeaderError < StandardError; end

    Entry = Struct.new(:name, :summary, :order, :description, :path, keyword_init: true) do
      def command = "ruby #{path}"
      def to_h = { name: name, summary: summary, order: order, path: path }
    end

    module_function

    # @return [Array<Entry>] every check, cheapest first
    def discover
      entries = Root.glob(GLOB).map { |rel| parse(rel) }.sort_by { |e| [e.order, e.name] }
      %i[name order].each { |field| assert_unique!(entries, field) }
      entries
    end

    # @param file [String] path to a check, absolute or root-relative
    # @return [Entry]
    def parse(file)
      rel = relative(file)
      lines = header_lines(rel)
      entry = Entry.new(name: tag(lines, rel, "check"), summary: tag(lines, rel, "summary"),
                        order: Integer(tag(lines, rel, "order"), 10),
                        description: description(lines), path: rel)
      validate!(entry, rel)
      entry
    end

    # Resolve a path to a root-relative one, whatever the caller had.
    #
    # `__FILE__` is relative to the working directory and a discovered path is
    # relative to the app root, and a check must run from either — so try the
    # working directory first and fall back to the root.
    #
    # @param file [String] absolute, cwd-relative or root-relative
    # @return [String] root-relative
    def relative(file)
      from_cwd = File.expand_path(file.to_s)
      absolute = File.exist?(from_cwd) ? from_cwd : File.expand_path(file.to_s, Root.dir)
      absolute.delete_prefix("#{Root.dir}/")
    end

    def header_lines(rel)
      out = []
      started = false
      Root.read(rel).each_line.first(HEADER_SCAN_LINES).each do |line|
        stripped = line.chomp
        next if !started && !stripped.start_with?("# @")

        started = true
        break unless stripped.start_with?("#")

        out << stripped.sub(/\A#\s?/, "")
      end
      out
    end

    def tag(lines, rel, name)
      value = lines.filter_map { |l| l[/\A@#{name}\s+(\S.*)\z/, 1] }.first
      raise HeaderError, header_error(rel, "no `# @#{name} ...` line") if value.nil?

      value.strip
    end

    def description(lines)
      last_tag = lines.rindex { |l| l.start_with?("@") } || -1
      lines[(last_tag + 1)..].to_a.join("\n").strip
    end

    def validate!(entry, rel)
      unless NAME_FORMAT.match?(entry.name)
        raise HeaderError, header_error(rel, "@check #{entry.name.inspect} must match #{NAME_FORMAT.source}")
      end

      expected = entry.name.tr("-", "_")
      return if File.basename(rel, ".rb") == expected

      raise HeaderError, header_error(rel, "@check #{entry.name.inspect} wants the file named #{expected}.rb")
    end

    def assert_unique!(entries, field)
      dupes = entries.group_by { |e| e[field] }.select { |_, group| group.size > 1 }
      return if dupes.empty?

      detail = dupes.map { |value, group| "@#{field} #{value} claimed by #{group.map(&:path).join(", ")}" }
      raise HeaderError, "scripts/checks: #{detail.join("; ")}\n" \
                         "  fix: give each check a unique @#{field} in its header comment"
    end

    def header_error(rel, detail)
      "#{rel}: #{detail}\n  fix: add the discovery header to #{rel} — see scripts/README.md"
    end
  end

  # Turns a {Check} subclass into a standalone program, with the same command
  # line and the same exit status for every check — because a contract an agent
  # has to re-learn per script is not a contract.
  #
  #     ruby scripts/checks/<name>.rb            human output
  #     ruby scripts/checks/<name>.rb --json     one JSON object on stdout
  #     ruby scripts/checks/<name>.rb --help     the header comment, verbatim
  #
  #     0   satisfied · 1  the app is wrong · 64  bad usage · 69  a tool is missing
  module Runner
    EXIT_USAGE = 64
    UNIVERSAL_FLAGS = %w[--json --help -h].freeze

    module_function

    # @param source_file [String] the check's own `__FILE__`
    # @param check_class [Class] an {AppScripts::Check} subclass
    # @return [Integer] the process exit status
    def main(source_file, check_class, argv = ARGV, out: $stdout, err: $stderr)
      entry = Registry.parse(source_file)
      options = parse(argv, check_class.flags)
      return usage_error(entry, options[:error], err) if options[:error]
      return help(entry, check_class, out) if options[:help]

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = check_class.new(**options.fetch(:extra)).run
      elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round

      emit(entry, result, elapsed, json: options[:json], out: out)
      result.exit_code
    end

    def parse(argv, extra_flags)
      parsed = { json: false, help: false, extra: {}, error: nil }
      Array(argv).each do |arg|
        case arg
        when "--json" then parsed[:json] = true
        when "-h", "--help" then parsed[:help] = true
        else
          key = extra_flags[arg]
          key ? parsed[:extra][key] = true : parsed[:error] ||= arg
        end
      end
      parsed
    end

    def usage_error(entry, arg, err)
      err.puts "#{entry.name}: unknown argument #{arg.inspect}"
      err.puts "  fix: #{entry.command} --help"
      EXIT_USAGE
    end

    def help(entry, check_class, out)
      out.puts "Usage: #{entry.command} [#{(UNIVERSAL_FLAGS + check_class.flags.keys).join(" | ")}]"
      out.puts
      out.puts entry.summary
      out.puts
      out.puts entry.description unless entry.description.empty?
      out.puts
      out.puts "Exit status: 0 satisfied · 1 the app is wrong · 64 bad usage · 69 a tool is missing."
      out.puts "Cost order in bin/check: #{entry.order}."
      0
    end

    def emit(entry, result, elapsed, json:, out:)
      require "json"
      if json
        out.puts JSON.pretty_generate(entry.to_h.merge(duration_ms: elapsed).merge(result.to_h))
      else
        out.puts render(entry, result, elapsed)
      end
    end

    def render(entry, result, elapsed)
      label = result.pass? ? "pass" : result.status.upcase
      head = format("%s: %s (%dms)", entry.name, label, elapsed)
      return "#{head} — #{result.got}" if result.pass?

      body = [head, "  expected: #{result.expected}", "  got:      #{result.got}", ""]
      body += result.findings.map { |finding| "#{finding.render("  ")}\n" }
      (body + ["  fix: #{result.fix}"]).join("\n")
    end
  end
end
