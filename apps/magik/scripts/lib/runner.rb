# frozen_string_literal: true

require "json"
require_relative "registry"
require_relative "result"

module MagikScripts
  # Turns a {MagikScripts::Check} subclass into a standalone program.
  #
  # Every check gets the same command line, because a contract an agent has to
  # re-learn per script is not a contract:
  #
  #     ruby scripts/checks/<name>.rb            human output
  #     ruby scripts/checks/<name>.rb --json     one JSON object on stdout, nothing else
  #     ruby scripts/checks/<name>.rb --help     the check's header comment, verbatim
  #
  # and the same exit status, which is `bin/check`'s so the two agree:
  #
  #     0    the check is satisfied
  #     1    the repository is wrong — the findings say where
  #     64   bad usage (`EX_USAGE`): an unknown flag
  #     69   a tool the check needs is not installed (`EX_UNAVAILABLE`).
  #          Nothing is broken; the fix is the install command it prints.
  #
  # `--help` is rendered from the header {MagikScripts::Registry} already parses,
  # so the usage text cannot rot away from the discovery metadata.
  module Runner
    # Bad usage, sysexits-style.
    # @return [Integer]
    EXIT_USAGE = 64

    # Flags every check answers to, whatever else it declares.
    # @return [Array<String>]
    UNIVERSAL_FLAGS = %w[--json --help -h].freeze

    module_function

    # Run one check as a program.
    #
    # @param source_file [String] the check's own `__FILE__`
    # @param check_class [Class] a {MagikScripts::Check} subclass
    # @param argv [Array<String>] the command line
    # @param out [IO] stdout
    # @param err [IO] stderr
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

    # @param argv [Array<String>] the command line
    # @param extra_flags [Hash{String => Symbol}] from `Check.flags`
    # @return [Hash{Symbol => Object}] `:json`, `:help`, `:extra`, `:error`
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

    # @param entry [MagikScripts::Registry::Entry]
    # @param arg [String] the offending argument
    # @param err [IO]
    # @return [Integer] {EXIT_USAGE}
    def usage_error(entry, arg, err)
      err.puts "#{entry.name}: unknown argument #{arg.inspect}"
      err.puts "  fix: #{entry.command} --help"
      EXIT_USAGE
    end

    # @param entry [MagikScripts::Registry::Entry]
    # @param check_class [Class]
    # @param out [IO]
    # @return [Integer] 0
    def help(entry, check_class, out)
      out.puts "Usage: #{entry.command} [#{(UNIVERSAL_FLAGS + check_class.flags.keys).join(" | ")}]"
      out.puts
      out.puts entry.summary
      out.puts
      out.puts entry.description unless entry.description.empty?
      out.puts
      out.puts "Exit status: 0 satisfied · 1 the repo is wrong · 64 bad usage · 69 a tool is missing."
      out.puts "Cost order in bin/check: #{entry.order}."
      0
    end

    # @param entry [MagikScripts::Registry::Entry]
    # @param result [MagikScripts::Result]
    # @param elapsed [Integer] milliseconds
    # @param json [Boolean]
    # @param out [IO]
    # @return [void]
    def emit(entry, result, elapsed, json:, out:)
      if json
        document = { check: entry.name, summary: entry.summary, order: entry.order, path: entry.path,
                     duration_ms: elapsed }.merge(result.to_h)
        out.puts JSON.pretty_generate(document)
      else
        out.puts render(entry, result, elapsed)
      end
    end

    # @param entry [MagikScripts::Registry::Entry]
    # @param result [MagikScripts::Result]
    # @param elapsed [Integer] milliseconds
    # @return [String]
    def render(entry, result, elapsed)
      label = result.pass? ? "pass" : result.status.upcase
      head = "#{entry.name}: #{label} (#{elapsed}ms)"
      return "#{head} — #{result.got}" if result.pass?

      body = [head, "  expected: #{result.expected}", "  got:      #{result.got}", ""]
      body += result.findings.map { |finding| "#{finding.render("  ")}\n" }
      (body + ["  fix: #{result.fix}"]).join("\n")
    end
  end
end
