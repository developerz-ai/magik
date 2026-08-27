# frozen_string_literal: true

require "json"
require "optparse"

require_relative "cli/docs_command"

module Magik
  # The `magik` command line.
  #
  # Three commands work today — {version}, {help} and `docs`
  # ({Magik::CLI::DocsCommand}). Every other command named in
  # `docs/idea/00-build-spec.md` is listed by `magik help` with status `planned`
  # and exits non-zero with `MAGIK_COMMAND_NOT_IMPLEMENTED` if you run it. That
  # is deliberate: the CLI tells you the truth about what exists.
  #
  # Every working command supports `--json`, so scripts, CI and agents can
  # consume the output without parsing prose. Errors are emitted as JSON too
  # when `--json` is set, using {Magik::Error#to_h}.
  #
  # Implemented with the stdlib `OptionParser`; Magik takes no third-party CLI
  # dependency.
  #
  # @example Human output
  #   $ magik version
  #   magik 0.0.1 (spec only)
  # @example Machine output
  #   $ magik version --json
  #   {"name":"magik","version":"0.0.1","status":"spec only",...}
  module CLI
    # Exit status for a command that did what it said.
    # @return [Integer]
    EXIT_SUCCESS = 0

    # Exit status for any {Magik::Error} — unknown command, planned command,
    # bad option.
    # @return [Integer]
    EXIT_ERROR = 1

    # Short status label reused in every output format.
    # @return [String]
    STATUS = "spec only"

    # Every command the spec calls for, in the order `magik help` prints them.
    #
    # `:status` is `"ready"` for commands that work today and `"planned"` for
    # commands that only exist in `docs/idea/00-build-spec.md`.
    #
    # @return [Hash{String => Hash{Symbol => String}}]
    COMMANDS = {
      "new" => { summary: "Generate a new Magik application", status: "planned" },
      "generate" => { summary: "Generate a model, screen, action or job", status: "planned" },
      "console" => { summary: "Open an application console", status: "planned" },
      "server" => { summary: "Run the Puma application server, thread-per-request", status: "planned" },
      "worker" => { summary: "Run the background job worker", status: "planned" },
      "test" => { summary: "Run the application test suite", status: "planned" },
      "check" => { summary: "Lint an application against Magik's boot guardrails", status: "planned" },
      "db" => { summary: "Create, migrate, roll back, seed or reset the database", status: "planned" },
      "describe" => { summary: "Print the DSL grammar as data: constructs, options, error codes",
                      status: "planned" },
      "routes" => { summary: "List the routes the screen and API conventions produced", status: "planned" },
      "domains" => { summary: "Report the domain graph and its boundary violations", status: "planned" },
      "errors" => { summary: "Explain a MAGIK_* error code: cause, fix and docs", status: "planned" },
      "docs" => { summary: "Read the documentation shipped inside this gem", status: "ready" },
      "version" => { summary: "Print the magik gem version", status: "ready" },
      "help" => { summary: "List every magik command and its status", status: "ready" }
    }.freeze

    class << self
      # Run the CLI.
      #
      # Never raises for user error: a {Magik::Error} is rendered to `err` (or
      # to `out` as JSON when `--json` is set) and reported as {EXIT_ERROR}.
      #
      # @param argv [Array<String>] the raw command line, usually `ARGV`
      # @param out [IO] stream for command output
      # @param err [IO] stream for error output
      # @return [Integer] a process exit status: {EXIT_SUCCESS} or {EXIT_ERROR}
      # @example
      #   Magik::CLI.start(["version", "--json"]) # => 0
      def start(argv = [], out: $stdout, err: $stderr)
        options = { json: false }
        args = parse_options(Array(argv), options)
        dispatch(args, options, out)
        EXIT_SUCCESS
      rescue Magik::Error => e
        report_error(e, options[:json], out, err)
        EXIT_ERROR
      end

      # Print the gem version.
      #
      # @param out [IO] stream to write to
      # @param json [Boolean] emit JSON instead of prose
      # @return [void]
      def version(out: $stdout, json: false)
        if json
          out.puts JSON.generate(
            name: "magik",
            version: Magik::VERSION,
            status: STATUS,
            ruby: RUBY_VERSION,
            ruby_engine: RUBY_ENGINE
          )
        else
          out.puts "magik #{Magik::VERSION} (#{STATUS})"
        end
      end

      # Print usage and every command in {COMMANDS} with its status.
      #
      # @param out [IO] stream to write to
      # @param json [Boolean] emit JSON instead of prose
      # @return [void]
      def help(out: $stdout, json: false)
        return out.puts(JSON.generate(usage: usage, status: STATUS, commands: commands_as_data)) if json

        out.puts usage
        out.puts
        out.puts "Commands:"
        width = COMMANDS.keys.map(&:length).max
        COMMANDS.each do |name, meta|
          out.puts format("  %-#{width}s  %-8s  %s", name, meta[:status], meta[:summary])
        end
        out.puts
        out.puts "Global options:"
        out.puts "      --json               Emit machine-readable JSON"
        out.puts "  -v, --version            Print the magik gem version"
        out.puts "  -h, --help               Show this message"
        out.puts
        out.puts "Magik is #{STATUS}: `planned` commands are specified in " \
                 "docs/idea/00-build-spec.md and not implemented."
      end

      # The one-line usage banner.
      # @return [String]
      def usage
        "Usage: magik <command> [options]"
      end

      # {COMMANDS} flattened into an array of plain hashes, for JSON output.
      # @return [Array<Hash{Symbol => String}>]
      def commands_as_data
        COMMANDS.map { |name, meta| { name: name, summary: meta[:summary], status: meta[:status] } }
      end

      private

      # @param argv [Array<String>] raw arguments
      # @param options [Hash] mutated with parsed global options
      # @return [Array<String>] the remaining positional arguments
      # @raise [Magik::InvalidOptionError] on an unrecognised flag
      def parse_options(argv, options)
        rest = argv.dup
        parser = OptionParser.new do |o|
          o.banner = usage
          o.on("--json", "Emit machine-readable JSON") { options[:json] = true }
          o.on("-v", "--version", "Print the magik gem version") { options[:command] = "version" }
          o.on("-h", "--help", "Show this message") { options[:command] = "help" }
        end
        parser.parse!(rest)
        rest
      rescue OptionParser::ParseError => e
        raise InvalidOptionError, e.message
      end

      # @param args [Array<String>] positional arguments
      # @param options [Hash] parsed global options
      # @param out [IO] stream for command output
      # @return [void]
      # @raise [Magik::CommandNotImplementedError] for a `planned` command
      # @raise [Magik::UnknownCommandError] for anything else
      # @raise [Magik::Docs::PageNotFoundError] for `docs <unknown-slug>`
      def dispatch(args, options, out)
        command = options[:command] || args.first || "help"

        case command
        when "version" then version(out: out, json: options[:json])
        when "help" then help(out: out, json: options[:json])
        when "docs" then DocsCommand.new(out: out, json: options[:json]).call(args.drop(1))
        else unsupported!(command)
        end
      end

      # @param command [String] the requested command
      # @raise [Magik::CommandNotImplementedError, Magik::UnknownCommandError] always
      # @return [void]
      def unsupported!(command)
        raise CommandNotImplementedError, "`magik #{command}` is planned but not implemented" if COMMANDS.key?(command)

        raise UnknownCommandError, "`#{command}` is not a magik command"
      end

      # @param error [Magik::Error] the error to report
      # @param json [Boolean] emit JSON instead of prose
      # @param out [IO] stream used for JSON output
      # @param err [IO] stream used for prose output
      # @return [void]
      def report_error(error, json, out, err)
        if json
          out.puts JSON.generate(error: error.to_h)
        else
          err.puts error.message
        end
      end
    end
  end
end
