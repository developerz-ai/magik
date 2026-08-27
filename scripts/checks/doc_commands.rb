#!/usr/bin/env ruby
# frozen_string_literal: true

# @check   doc-commands
# @summary Every shell command a doc shows in a fenced block is one this repo provides.
# @order   40
#
# A documented command that does not exist is the single most common way
# agent-facing documentation goes wrong, and it is the most expensive: an agent
# reads `bin/dev`, runs it, gets `No such file or directory`, and spends a loop
# deciding whether the repo is broken or the doc is.
#
# So every command shown in a `bash`/`sh` fence in `README.md`, `CLAUDE.md`,
# `CONTRIBUTING.md` and `wiki/**.md` must be one of:
#
#   * on the allowlist below — a program the reader is assumed to have;
#   * `bin/<name>`, and that file exists and is executable;
#   * `rake <task>`, and `rake -T` lists it;
#   * `magik <command>`, and `Magik::CLI::COMMANDS` names it — including
#     commands marked `planned`, because `magik help` listing a command as
#     planned is itself the documentation that it exists as an idea.
#
#   MAGIK_DEV_DOC_COMMAND_MISSING        `bin/x` or `exe/x` is documented and absent
#   MAGIK_DEV_DOC_COMMAND_UNKNOWN        a program neither allowlisted nor provided here
#   MAGIK_DEV_DOC_SUBCOMMAND_UNKNOWN     `magik x` or `rake x` where x is not a command
#   MAGIK_DEV_DOC_SLASH_COMMAND_UNKNOWN  `/x` with no `.claude/commands/x.md`, in this
#                                        repo or in the app template `magik new` writes
#
# Only fenced blocks are read. A command in a table cell or a sentence is prose
# a human is reading; a command in a fence is one an agent will paste. Only
# shell-tagged fences are read, so `ruby`, `text` and `json` examples are left
# alone. That is the check's blind spot and it is deliberate: widening it means
# parsing English.

require "English"

require_relative "../lib/scripts"
require_relative "../lib/library"
require_relative "../lib/shell"

module MagikScripts
  module Checks
    # Documented commands versus the commands this repo actually provides.
    class DocCommands < Check
      # Fence languages whose contents are commands rather than examples.
      # @return [Array<String>]
      SHELL_LANGS = %w[bash sh shell zsh console].freeze

      # The pages an agent is told to trust.
      # @return [Array<String>]
      PAGES = ["README.md", "CLAUDE.md", "CONTRIBUTING.md", "wiki/*.md"].freeze

      # Programs a reader is assumed to have. Everything else must be something
      # this repository ships, which is the point of the check.
      # @return [Array<String>]
      ALLOWED = %w[
        apt-get asdf brew cat cd chmod cp curl diff docker docker-compose echo export find git grep
        head irb jq lefthook ls mkdir mv nproc open pwd rbenv rm sed sort ssh tail tar tree wc which
        xargs bundle gem ruby rubocop yard code npx
      ].freeze

      # Repository-provided prefixes: the file must exist and, for `bin/`, be
      # executable.
      # @return [Array<String>]
      LOCAL_PREFIXES = %w[bin/ exe/ ./bin/ ./exe/ script/ scripts/].freeze

      # Where agent slash commands live. `/feature` in a fence is a command a
      # reader is being told to run just as much as `bin/check` is, and it is
      # provided by a file, so it can be checked like one.
      #
      # Two directories, because two audiences: `.claude/commands/` is for
      # somebody working on the framework, and the app template's copy is what
      # `magik new` writes into a generated app. `README.md` documents the
      # generated app's loop, so both are commands this repository provides.
      # @return [Array<String>]
      SLASH_COMMANDS = [".claude/commands", "lib/magik/cli/templates/app/.claude/commands"].freeze

      # One command, with where it was documented.
      Sighting = Struct.new(:tokens, :at, :raw, keyword_init: true)

      # What this repository actually provides, as data, so the rule is pure.
      Surface = Struct.new(:executables, :rake_tasks, :magik_commands, :slash_commands,
                           keyword_init: true)

      # Every finding implied by a set of sightings. Pure.
      #
      # @param sightings [Array<MagikScripts::Checks::DocCommands::Sighting>]
      # @param surface [MagikScripts::Checks::DocCommands::Surface]
      # @return [Array<MagikScripts::Finding>]
      def self.audit(sightings, surface)
        sightings.filter_map { |sighting| verdict(sighting, surface) }
      end

      # @param sighting [MagikScripts::Checks::DocCommands::Sighting]
      # @param surface [MagikScripts::Checks::DocCommands::Surface]
      # @return [MagikScripts::Finding, nil]
      def self.verdict(sighting, surface)
        head = sighting.tokens.first
        return slash(sighting, surface.slash_commands, head) if head.start_with?("/") && !head.include?(".")
        return local(sighting, surface, head) if LOCAL_PREFIXES.any? { |p| head.start_with?(p) }
        return subcommand(sighting, surface.magik_commands, "magik", "lib/magik/cli.rb") if head == "magik"
        return subcommand(sighting, surface.rake_tasks, "rake", "Rakefile") if head == "rake"
        return nil if ALLOWED.include?(head)

        Finding.new(code: "MAGIK_DEV_DOC_COMMAND_UNKNOWN", at: sighting.at,
                    cause: "#{sighting.raw.inspect} starts with #{head.inspect}, which is neither on " \
                           "doc-commands' allowlist nor a command this repository provides",
                    fix: "replace #{head.inspect} at #{sighting.at} with a command this repo ships, " \
                         "or add it to ALLOWED in scripts/checks/doc_commands.rb with the reason " \
                         "a reader is assumed to have it")
      end

      # @param sighting [MagikScripts::Checks::DocCommands::Sighting]
      # @param known [Array<String>] the slash commands this repo ships
      # @param head [String] e.g. `"/feature"`
      # @return [MagikScripts::Finding, nil]
      def self.slash(sighting, known, head)
        name = head.delete_prefix("/")
        return nil if known.include?(name)

        Finding.new(code: "MAGIK_DEV_DOC_SLASH_COMMAND_UNKNOWN", at: sighting.at,
                    cause: "#{sighting.at} shows #{head} as a command to run, and no " \
                           "#{name}.md exists in #{SLASH_COMMANDS.join(" or ")} — this repo " \
                           "ships: #{known.sort.map { |c| "/#{c}" }.join(", ")}",
                    fix: "add #{SLASH_COMMANDS.first}/#{name}.md, or correct the command " \
                         "at #{sighting.at}")
      end

      # @param sighting [MagikScripts::Checks::DocCommands::Sighting]
      # @param surface [MagikScripts::Checks::DocCommands::Surface]
      # @param head [String] the documented path
      # @return [MagikScripts::Finding, nil]
      def self.local(sighting, surface, head)
        path = head.delete_prefix("./")
        return nil if surface.executables.include?(path)

        Finding.new(code: "MAGIK_DEV_DOC_COMMAND_MISSING", at: sighting.at,
                    cause: "#{sighting.at} tells the reader to run #{head}, and #{path} is missing or " \
                           "not executable in this checkout",
                    fix: "create #{path} and `chmod +x #{path}`, or correct the command at #{sighting.at}")
      end

      # @param sighting [MagikScripts::Checks::DocCommands::Sighting]
      # @param known [Array<String>] the subcommands that exist
      # @param program [String] `"magik"` or `"rake"`
      # @param source [String] the file that defines them
      # @return [MagikScripts::Finding, nil]
      def self.subcommand(sighting, known, program, source)
        name = sighting.tokens[1]
        return nil if name.nil? || name.start_with?("-") || known.include?(name)

        Finding.new(code: "MAGIK_DEV_DOC_SUBCOMMAND_UNKNOWN", at: sighting.at,
                    cause: "#{sighting.raw.inspect} names #{program} #{name}, and #{source} does not " \
                           "define it — #{known.size} #{program} commands exist: #{known.sort.join(", ")}",
                    fix: "add #{name} to #{source}, or correct the command at #{sighting.at}")
      end

      # Every command a Markdown page presents as runnable. Pure.
      #
      # @param markdown [String] the page
      # @param path [String] its root-relative path, for `at`
      # @return [Array<MagikScripts::Checks::DocCommands::Sighting>]
      def self.sightings(markdown, path)
        Markdown.new(markdown).fences.select { |fence| SHELL_LANGS.include?(fence.lang) }
                .flat_map do |fence|
          Shell.commands(fence.body).map do |command|
            Sighting.new(tokens: command.tokens, raw: command.raw, at: "#{path}:#{fence.line + command.line}")
          end
        end
      end

      # @return [MagikScripts::Result]
      def run
        tasks = rake_tasks
        return missing_rake if tasks.nil?

        sightings = collect
        return nothing_scanned(corpus: PAGES.join(" "), expected: expectation, fix: fix_line) if sightings.empty?

        findings = self.class.audit(sightings, surface(tasks))
        return summary(sightings, findings) if findings.empty?

        failure(reason: "undocumented_command", expected: expectation, fix: fix_line, findings: findings,
                got: "#{findings.size} of #{sightings.size} documented commands do not exist here")
      end

      private

      # @return [Array<MagikScripts::Checks::DocCommands::Sighting>]
      def collect
        pages.flat_map { |path| self.class.sightings(Repo.read(path), path) }
      end

      # @return [Array<String>] the documentation this check reads, sorted
      def pages
        PAGES.flat_map { |pattern| Repo.glob(pattern) }.uniq.sort
      end

      # @param tasks [Array<String>] from {#rake_tasks}
      # @return [MagikScripts::Checks::DocCommands::Surface]
      def surface(tasks)
        Surface.new(executables: executables, rake_tasks: tasks, slash_commands: slash_commands,
                    magik_commands: Library.load!::CLI::COMMANDS.keys)
      end

      # @return [Array<String>] every runnable file this repo ships
      def executables
        Repo.glob("{bin,exe}/*").select { |path| Repo.path(path).executable? } +
          Repo.glob("scripts/**/*.rb")
      end

      # @return [Array<String>] the agent slash commands this repo ships
      def slash_commands
        SLASH_COMMANDS.flat_map { |dir| Repo.glob("#{dir}/*.md") }
                      .map { |path| File.basename(path, ".md") }.uniq
      end

      # The repo's own task list, asked of Rake rather than parsed out of the
      # Rakefile — the Rakefile builds tasks from globs and rescues missing
      # gems, so reading it with a regex would answer a different question.
      #
      # @return [Array<String>, nil] nil when rake cannot run here
      def rake_tasks
        out = IO.popen(["rake", "-T", "-f", Repo.path("Rakefile").to_s], chdir: Repo.root.to_s,
                                                                         err: File::NULL, &:read)
        return nil unless $CHILD_STATUS&.success?

        out.scan(/^rake\s+(\S+)/).flatten.map { |task| task.split("[").first }.uniq
      rescue Errno::ENOENT
        nil
      end

      # @return [MagikScripts::Result]
      def missing_rake
        missing_tool(tool: "rake", install: "bin/setup   # rake is a development dependency in the Gemfile",
                     expected: expectation)
      end

      # @param sightings [Array<MagikScripts::Checks::DocCommands::Sighting>]
      # @param findings [Array<MagikScripts::Finding>]
      # @return [MagikScripts::Result]
      def summary(sightings, findings)
        ok(expected: expectation,
           got: "#{sightings.size} commands in #{pages.size} pages, #{findings.size} that do not exist")
      end

      # @return [String]
      def expectation
        "every command in a shell fence in #{PAGES.join(", ")} is allowlisted, or is a bin/ script, " \
          "rake task or magik command this repository actually provides"
      end

      # @return [String]
      def fix_line
        "ruby scripts/checks/doc_commands.rb   # each finding above names the page and line to correct"
      end
    end
  end
end

exit MagikScripts::Runner.main(__FILE__, MagikScripts::Checks::DocCommands) if $PROGRAM_NAME == __FILE__
