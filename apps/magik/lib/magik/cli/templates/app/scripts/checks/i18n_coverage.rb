#!/usr/bin/env ruby
# frozen_string_literal: true

# @check   i18n-coverage
# @summary Every t("…") key used in this app resolves in every locale file it declares.
# @order   20
#
# A missing translation key is the cheapest bug in a SaaS to prevent and one of
# the more embarrassing to ship: it does not crash, it does not fail a test, it
# renders as a raw key on a customer's screen. The compiler cannot see it and
# neither can a reviewer skimming a diff — but a glob and a YAML parse can.
#
#   APP_I18N_KEY_MISSING     a key used in code with no entry in some locale
#   APP_I18N_NO_LOCALES      keys are used and `locales/` holds no locale at all
#   APP_I18N_LOCALE_UNREADABLE  a locale file that is not parseable YAML
#
# Unused keys are NOT reported. A key present in a locale and absent from code
# is usually a string on a screen nobody has written yet, and failing the gate
# for it teaches people to delete translations.
#
# An app with no `t("…")` calls and no locale files is not applicable — a pass.

require "yaml"
require_relative "../lib/scripts"

module AppScripts
  module Checks
    # Translation coverage, as an assertion.
    class I18nCoverage < Check
      # `t("invoices.new")`, `t('invoices.new')`. An interpolated key is skipped
      # deliberately: it cannot be resolved statically, and guessing is worse
      # than silence.
      KEY_CALL = /\bt\(\s*["']([a-z0-9_]+(?:\.[a-z0-9_]+)*)["']/

      # Where application code lives, flat or domained.
      SOURCES = ["app/**/*.rb", "domains/**/*.rb"].freeze

      # Where locale files live. One file per locale, named for it.
      LOCALES = "locales/*.{yml,yaml}"

      # The pure rule. Give it used keys and locales, get findings — no
      # filesystem, so a test can hand it a fixture and assert the negative case.
      #
      # @param used [Hash{String => String}] key => first `file:line` that uses it
      # @param locales [Hash{String => Array<String>}] locale name => flattened keys
      # @return [Array<AppScripts::Finding>]
      def self.findings_for(used, locales)
        return [] if used.empty?
        return [no_locales_finding(used)] if locales.empty?

        used.flat_map do |key, at|
          locales.filter_map do |locale, defined_keys|
            next if defined_keys.include?(key)

            Finding.new(code: "APP_I18N_KEY_MISSING", at: at,
                        cause: "t(#{key.inspect}) has no entry in locales/#{locale}.yml",
                        fix: "add `#{key}` to locales/#{locale}.yml")
          end
        end
      end

      # @return [AppScripts::Finding]
      def self.no_locales_finding(used)
        key, at = used.first
        Finding.new(code: "APP_I18N_NO_LOCALES", at: at,
                    cause: "#{used.size} translation key(s) are used, starting with #{key.inspect}, " \
                           "and locales/ holds no locale file",
                    fix: "declare a locale in config/app.rb and create locales/en.yml")
      end

      # Flatten a nested locale hash to dotted keys.
      #
      # @param node [Object] a parsed YAML value
      # @param prefix [String] the dotted path so far
      # @return [Array<String>]
      def self.flatten_keys(node, prefix = "")
        return [prefix] unless node.is_a?(Hash)

        node.flat_map do |segment, child|
          flatten_keys(child, prefix.empty? ? segment.to_s : "#{prefix}.#{segment}")
        end
      end

      # @return [AppScripts::Result]
      def run
        used = used_keys
        locale_files = Root.glob(LOCALES)
        return not_applicable(because: "no t(\"…\") calls and no locale files", expected: expectation) if
          used.empty? && locale_files.empty?

        locales, unreadable = read_locales(locale_files)
        findings = unreadable + self.class.findings_for(used, locales)
        return failure(reason: "missing_translations", expected: expectation, fix: fix_line, findings: findings) if
          findings.any?

        ok(expected: expectation,
           got: "#{used.size} keys used, #{locales.size} locale(s), #{locales.values.sum(&:size)} entries")
      end

      private

      # @return [Hash{String => String}] key => the first `file:line` using it
      def used_keys
        SOURCES.flat_map { |pattern| Root.glob(pattern) }.each_with_object({}) do |rel, found|
          Root.read(rel).each_line.with_index(1) do |line, number|
            next if line.lstrip.start_with?("#")

            line.scan(KEY_CALL).flatten.each { |key| found[key] ||= "#{rel}:#{number}" }
          end
        end
      end

      # @return [Array(Hash{String => Array<String>}, Array<AppScripts::Finding>)]
      def read_locales(files)
        locales = {}
        problems = []

        files.each do |rel|
          name = File.basename(rel).sub(/\.ya?ml\z/, "")
          begin
            parsed = YAML.load_file(Root.path(rel), aliases: true) || {}
            # A locale file may or may not nest everything under its own name.
            root = parsed.is_a?(Hash) && parsed.keys == [name] ? parsed.fetch(name) : parsed
            locales[name] = self.class.flatten_keys(root)
          rescue Psych::Exception => e
            problems << Finding.new(code: "APP_I18N_LOCALE_UNREADABLE", at: rel,
                                    cause: "#{rel} is not parseable YAML: #{e.message}",
                                    fix: "ruby -ryaml -e 'YAML.load_file(#{rel.inspect})'")
          end
        end

        [locales, problems]
      end

      # @return [String]
      def expectation
        "every statically resolvable t(\"…\") key has an entry in every locale file this app ships"
      end

      # @return [String]
      def fix_line
        "ruby scripts/checks/i18n_coverage.rb   # each finding names the key and the file to add it to"
      end
    end
  end
end

exit AppScripts::Runner.main(__FILE__, AppScripts::Checks::I18nCoverage) if $PROGRAM_NAME == __FILE__
