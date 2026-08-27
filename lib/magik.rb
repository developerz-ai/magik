# frozen_string_literal: true

require "pathname"

require_relative "magik/version"

# Magik is an opinionated, full-stack Ruby framework targeting TruffleRuby:
# one DSL for models, screens, actions, realtime channels, background jobs,
# ledgers, APIs and admin panels, rendered server-side as HTML + htmx.
#
# **Status as of 2026-08-26: spec only.** The product specification lives in
# `docs/idea/00-build-spec.md` and is entirely unimplemented. What ships in
# this gem today is:
#
# * {Magik::VERSION} — the name-reservation version string.
# * {Magik::Error} — the stable `MAGIK_*` error-code convention.
# * {Magik::CLI} — a working `magik version` / `magik help` command line.
# * One documented, spec-only stub module per planned subsystem
#   (see {Magik::SUBSYSTEMS}); every entry point raises {NotImplementedError}.
#
# Nothing in this gem renders a page, talks to a database, or runs a job.
#
# @see https://github.com/developerz-ai/magik
module Magik
  # Every planned subsystem, mapped from its file basename under `lib/magik/`
  # to the constant it defines. Each entry mirrors one area of the build spec.
  #
  # The map drives {https://ruby-doc.org/core/Module.html#method-i-autoload
  # autoload} registration below, so requiring `magik` is cheap: a subsystem
  # file is only read when its constant is first referenced.
  #
  # @return [Hash{Symbol => Symbol}] file basename => constant name
  # @example List the planned subsystems
  #   Magik::SUBSYSTEMS.keys # => [:core, :cli, :model, ...]
  SUBSYSTEMS = {
    core: :Core,
    cli: :CLI,
    model: :Model,
    schema: :Schema,
    render: :Render,
    action: :Action,
    router: :Router,
    policy: :Policy,
    realtime: :Realtime,
    jobs: :Jobs,
    ledger: :Ledger,
    api: :API,
    auth: :Auth,
    billing: :Billing,
    admin: :Admin,
    i18n: :I18n,
    pwa: :PWA,
    notify: :Notify,
    testing: :Testing,
    domains: :Domains,
    check: :Check
  }.freeze

  # The subsystems that are documentation-only: their modules load and carry
  # their spec metadata, but every entry point raises {NotImplementedError}.
  #
  # {Magik::CLI} is deliberately absent — it is the one subsystem with real,
  # useful behaviour today.
  #
  # @return [Array<Symbol>] file basenames, a subset of {SUBSYSTEMS} keys
  SPEC_ONLY_SUBSYSTEMS = (SUBSYSTEMS.keys - [:cli]).freeze

  SUBSYSTEMS.each { |file, const| autoload const, "magik/#{file}" }

  # {Magik::Docs} is deliberately **not** a subsystem: it is not a phase of the
  # build spec and it is not spec-only. It reads the documentation this gem
  # ships inside itself, so an agent can look the DSL up locally instead of over
  # the network. Registered here so `require "magik"` stays cheap.
  #
  # @see Magik::Docs
  autoload :Docs, "magik/docs"

  # Base class for every error Magik raises.
  #
  # Magik errors are not free-form strings. Each one carries three things, and
  # all three are required:
  #
  # 1. a **stable code** matching {CODE_FORMAT} (`MAGIK_SOMETHING`) that is
  #    safe to grep for, link to, and match on in tests and CI;
  # 2. a **cause** — one sentence saying what actually went wrong;
  # 3. a **fix** — a runnable command or a concrete edit, never "check your
  #    configuration".
  #
  # The rendered message is deterministic:
  #
  # ```text
  # MAGIK_LEDGER_UNBALANCED: entries for :Payouts do not balance (debits 1200, credits 900).
  #   fix: run `magik check --ledger Payouts`
  # ```
  #
  # Subclasses declare their defaults with the {code} and {fix} class-level
  # DSL, so a raise site only has to supply the cause.
  #
  # @example Raise a one-off error
  #   raise Magik::Error.new(
  #     "the app has no `App.define` block",
  #     code: "MAGIK_NO_APP",
  #     fix: "run `magik new myapp` to generate one"
  #   )
  # @example Declare a reusable error class
  #   class MissingTenant < Magik::Error
  #     code "MAGIK_MISSING_TENANT"
  #     fix  "add `tenant_by :subdomain` to your App.define block"
  #   end
  #   raise MissingTenant, "query on :Invoice has no tenant_id in WHERE"
  class Error < StandardError
    # The shape every Magik error code must take: `MAGIK_` followed by
    # underscore-separated uppercase words.
    #
    # @return [Regexp]
    CODE_FORMAT = /\AMAGIK_[A-Z0-9]+(?:_[A-Z0-9]+)*\z/

    # Fallback code for {Magik::Error} itself.
    # @return [String]
    DEFAULT_CODE = "MAGIK_ERROR"

    # Fallback fix for {Magik::Error} itself.
    # @return [String]
    DEFAULT_FIX = "read the raised cause above, then see docs/idea/00-build-spec.md"

    class << self
      # Get or set the default error code for this class and its subclasses.
      #
      # Called with an argument it is a writer; called without, a reader that
      # walks up the superclass chain.
      #
      # @param value [String, nil] a code matching {CODE_FORMAT}, or nil to read
      # @return [String] the effective code for this class
      # @raise [ArgumentError] if `value` does not match {CODE_FORMAT}
      def code(value = nil)
        return @code = Error.validate_code!(value) unless value.nil?

        @code || (superclass.respond_to?(:code) ? superclass.code : DEFAULT_CODE)
      end

      # Get or set the default fix line for this class and its subclasses.
      #
      # @param value [String, nil] an actionable fix, or nil to read
      # @return [String] the effective fix for this class
      # @raise [ArgumentError] if `value` is blank
      def fix(value = nil)
        return @fix = Error.validate_fix!(value) unless value.nil?

        @fix || (superclass.respond_to?(:fix) ? superclass.fix : DEFAULT_FIX)
      end

      # @api private
      # @param value [String] candidate error code
      # @return [String] the frozen, validated code
      # @raise [ArgumentError] if the code is malformed
      def validate_code!(value)
        string = value.to_s
        return string.freeze if CODE_FORMAT.match?(string)

        raise ArgumentError, "error code #{string.inspect} must match #{CODE_FORMAT.source}"
      end

      # @api private
      # @param value [String, nil] candidate cause text
      # @param klass [Class] the error class, used as the fallback cause
      # @return [String] a frozen, non-empty cause
      def normalize_cause(value, klass)
        string = value.to_s
        (string.strip.empty? ? klass.name.to_s : string).freeze
      end

      # @api private
      # @param value [String] candidate fix line
      # @return [String] the frozen, validated fix
      # @raise [ArgumentError] if the fix is blank
      def validate_fix!(value)
        string = value.to_s
        return string.freeze unless string.strip.empty?

        raise ArgumentError, "a Magik error needs a non-empty fix: line"
      end
    end

    # The stable, greppable error code.
    # @return [String] e.g. `"MAGIK_UNKNOWN_COMMAND"`
    attr_reader :code

    # What went wrong, in one sentence.
    #
    # Named `cause_text` because `Exception#cause` is reserved by Ruby for the
    # exception that was in flight when this one was raised.
    #
    # @return [String]
    attr_reader :cause_text

    # How to make it stop — a runnable command or a concrete edit.
    # @return [String]
    attr_reader :fix

    # @param cause_text [String] what went wrong, one sentence
    # @param code [String] a code matching {CODE_FORMAT}; defaults to the
    #   class-level {Error.code}
    # @param fix [String] an actionable fix; defaults to the class-level
    #   {Error.fix}
    # @raise [ArgumentError] if the code is malformed or the fix is blank
    def initialize(cause_text = nil, code: self.class.code, fix: self.class.fix)
      @code = Error.validate_code!(code)
      @cause_text = Error.normalize_cause(cause_text, self.class)
      @fix = Error.validate_fix!(fix)
      super(self.class.render(@code, @cause_text, @fix))
    end

    # Render the canonical two-line message for an error triple.
    #
    # @param code [String] the error code
    # @param cause_text [String] what went wrong
    # @param fix [String] how to fix it
    # @return [String] `"CODE: cause\n  fix: fix"`
    def self.render(code, cause_text, fix)
      "#{code}: #{cause_text}\n  fix: #{fix}"
    end

    # The error as plain data, ready for `--json` output or a log line.
    #
    # @return [Hash{Symbol => String}] with keys `:code`, `:cause`, `:fix`
    def to_h
      { code: code, cause: cause_text, fix: fix }
    end
  end

  # Raised when a CLI command is named in the spec but not implemented yet.
  #
  # @see Magik::CLI
  class CommandNotImplementedError < Error
    code "MAGIK_COMMAND_NOT_IMPLEMENTED"
    fix "run `magik help` for the commands that work today; " \
        "track the rest in docs/idea/00-build-spec.md"
  end

  # Raised when a CLI command is not a Magik command at all.
  #
  # @see Magik::CLI
  class UnknownCommandError < Error
    code "MAGIK_UNKNOWN_COMMAND"
    fix "run `magik help` to list every command"
  end

  # Raised when the command line carries a flag Magik does not understand.
  #
  # @see Magik::CLI
  class InvalidOptionError < Error
    code "MAGIK_INVALID_OPTION"
    fix "run `magik help` to list the supported options"
  end

  # The installed gem's root directory — the parent of `lib/`.
  #
  # Useful for locating packaged assets and the specification itself, e.g.
  # `Magik.root.join("docs/idea/00-build-spec.md")`.
  #
  # @return [Pathname] an absolute, resolved path
  # @example
  #   Magik.root.join("lib", "magik.rb").exist? # => true
  def self.root
    @root ||= Pathname.new(File.expand_path("..", __dir__))
  end
end
