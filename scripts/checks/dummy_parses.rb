#!/usr/bin/env ruby
# frozen_string_literal: true

# @check   dummy-parses
# @summary Every file under dummy/ is syntactically valid Ruby — and nothing more.
# @order   70
#
# `.rubocop.yml` says why `dummy/**` is excluded from lint, and in saying it
# names the one property the reference application has:
#
#   > Aspirational DSL for a framework that does not exist yet. It parses, and
#   > that is the only property it has.
#
# This check asserts exactly that claim and refuses to assert any more of it.
# It never loads a file, never requires one, never resolves a constant: `model
# :Invoice do ... end` is a design document, and running it would raise
# NoMethodError for a DSL nobody has written. Parsing is the whole test, and it
# is a real one — `dummy/` is what `wiki/Project-Layout.md` points readers at,
# and a demo app with a syntax error is a demo app nobody can read.
#
#   MAGIK_DEV_DUMMY_PARSE_ERROR   a file under dummy/ is not valid Ruby
#
# The day `magik server` can boot `dummy/`, this check is replaced by one that
# boots it. Until then, do not widen it: an assertion the reference app cannot
# satisfy would be pressure to write fake framework code, which is the exact
# failure mode this repository is designed against.

require "English"
require "stringio"
require "tempfile"

require_relative "../lib/scripts"

module MagikScripts
  module Checks
    # The reference app parses. That is all this proves.
    class DummyParses < Check
      # Everything this check reads.
      # @return [String]
      CORPUS = "dummy/**/*.rb"

      # Compile one file without running it.
      #
      # `RubyVM::InstructionSequence` is CRuby's; TruffleRuby is the production
      # runtime and does not have it, so `ruby -c` is the fallback. Both answer
      # the same question, and the check must run on the runtime this framework
      # targets.
      #
      # @param source [String] the file's contents
      # @param path [String] its root-relative path, for the message
      # @return [String, nil] the parse error, or nil when it compiles
      def self.parse_error(source, path)
        return shell_parse_error(source, path) unless defined?(RubyVM::InstructionSequence)

        quietly { RubyVM::InstructionSequence.compile(source, path) }
        nil
      rescue SyntaxError, StandardError => e
        e.message.to_s.lines.first.to_s.strip
      end

      # Parse `source` by shelling out, for engines with no
      # `RubyVM::InstructionSequence` — which is every engine that matters here,
      # because TruffleRuby is the production runtime and does not have it.
      #
      # THE SOURCE IS WRITTEN TO A TEMPORARY FILE rather than `ruby -c` being
      # pointed at `path`, and that is the whole point of this method. `path` is
      # a LABEL for the message, not necessarily a file: a caller may hand this
      # a string that is on nobody's disk. Reading the path instead would make
      # the two engines answer different questions about different bytes, and
      # would report `No such file or directory` as though it were a syntax
      # error. CI caught exactly that on `truffleruby-head` and nowhere else,
      # which is the argument for the engine being in the matrix at all.
      #
      # @param source [String] the file's contents — this is what gets parsed
      # @param path [String] its root-relative path, used only in the message
      # @return [String, nil] the parse error, or nil when it compiles
      # @example
      #   MagikScripts::Checks::DummyParses.shell_parse_error("def broken(\n", "dummy/app/models/magik_example.rb")
      #   # => "dummy/app/models/magik_example.rb:1: syntax error, unexpected end-of-input, expecting ')'"
      def self.shell_parse_error(source, path)
        Tempfile.create(["magik-parse", ".rb"]) do |file|
          file.write(source)
          file.close

          out = IO.popen(["ruby", "-c", file.path], err: %i[child out], &:read)
          return nil if $CHILD_STATUS&.success?

          normalise(out.to_s.lines.first.to_s, file.path, path)
        end
      end

      # Reduce one line of `ruby -c` stderr to the same string the in-process
      # branch produces, so a reader cannot tell which engine found the error.
      #
      # THREE ENGINES, THREE SHAPES, and this method exists because two of them
      # were discovered in CI rather than on a laptop:
      #
      #   CRuby 3.2      "<tmp>: <tmp>:1: syntax error, ... (SyntaxError)"
      #   CRuby 3.3-3.4  "ruby: <tmp>:1: syntax errors found"      # Prism
      #   in process     "<path>:1: syntax error, ..."             # the target
      #
      # 3.2 prefixes with the FILENAME and 3.4 prefixes with the PROGNAME, which
      # is why stripping "a repeated path" fixed one engine and broke the other.
      # The rule that covers both: drop any leading `<anything>: ` that sits
      # directly in front of `<path>:`, and leave a message that has no prefix
      # alone.
      #
      # @param raw [String] one line of the parser's stderr
      # @param tmp [String] the temporary file the parser actually read
      # @param path [String] the path the reader should be told to open
      # @return [String] the normalised message
      # @example
      #   MagikScripts::Checks::DummyParses.normalise(
      #     "ruby: /tmp/t.rb:1: syntax errors found", "/tmp/t.rb", "dummy/app/models/magik_example.rb"
      #   ) # => "dummy/app/models/magik_example.rb:1: syntax errors found"
      def self.normalise(raw, tmp, path)
        raw.strip
           .gsub(tmp, path)
           .sub(/\A.*?:\s+(?=#{Regexp.escape(path)}:)/, "")
           .sub(/\s+\(SyntaxError\)\z/, "")
      end

      # Run a block with warnings silenced. Compiling emits `warning: assigned
      # but unused variable` for perfectly valid source, and a warning is not
      # the question being asked.
      #
      # @yield the block to run
      # @return [Object] the block's value
      def self.quietly
        original = $stderr
        verbose = $VERBOSE
        $stderr = StringIO.new
        $VERBOSE = nil
        yield
      ensure
        $stderr = original
        $VERBOSE = verbose
      end

      # @param path [String] a root-relative path
      # @param message [String] the parse error
      # @return [MagikScripts::Finding]
      def self.finding(path, message)
        Finding.new(code: "MAGIK_DEV_DUMMY_PARSE_ERROR", at: path,
                    cause: "#{path} is not valid Ruby: #{message}",
                    fix: "ruby -c #{path}   # then fix the syntax it names")
      end

      # @return [MagikScripts::Result]
      def run
        files = Repo.glob(CORPUS, dummy: true)
        return nothing_scanned(corpus: CORPUS, expected: expectation, fix: fix_line) if files.empty?

        findings = files.filter_map do |path|
          message = self.class.parse_error(Repo.read(path), path)
          self.class.finding(path, message) if message
        end
        return ok(expected: expectation, got: "#{files.size} files under dummy/ parse") if findings.empty?

        failure(reason: "dummy_parse_error", expected: expectation, fix: fix_line, findings: findings,
                got: "#{findings.size} of #{files.size} files under dummy/ are not valid Ruby")
      end

      private

      # @return [String]
      def expectation
        "every file matching #{CORPUS} compiles as Ruby — the only property the reference " \
          "application has while the framework is spec only"
      end

      # @return [String]
      def fix_line
        "ruby scripts/checks/dummy_parses.rb   # each finding above names the file and the syntax error"
      end
    end
  end
end

exit MagikScripts::Runner.main(__FILE__, MagikScripts::Checks::DummyParses) if $PROGRAM_NAME == __FILE__
