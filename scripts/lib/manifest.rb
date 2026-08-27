# frozen_string_literal: true

require "digest"
require "json"

require_relative "library"
require_relative "registry"
require_relative "repo"
require_relative "tiers"

module MagikScripts
  # Builds `magik.manifest.json`: what is in this repository, as one file an
  # agent can read instead of twenty.
  #
  # Everything in it is **derived**. Nothing is typed in, so nothing can be
  # typed in wrong: the subsystems come from `Magik::SUBSYSTEMS`, their tiers
  # from {MagikScripts::Tiers}, their phase and status from each module's own
  # constants, the error codes from the classes themselves, and the check list
  # from the headers {MagikScripts::Registry} parses. A field nobody can derive
  # does not belong in the manifest.
  #
  # `build_id` is the full SHA-256 of the canonical body. It is never truncated:
  # a shortened digest is a collision the drift check would read as "fresh".
  module Manifest
    # Where the manifest lives.
    # @return [String]
    PATH = "magik.manifest.json"

    # The schema version. Bump it when a key is removed or changes meaning;
    # adding a key is additive and does not.
    # @return [Integer]
    SCHEMA = 1

    # Top-level keys, in the order they are written. Fixed, so two runs on one
    # tree produce identical bytes and a diff shows only real change.
    # @return [Array<String>]
    KEY_ORDER = %w[schema build_id generator gem tiers subsystems error_codes checks].freeze

    module_function

    # The manifest as it should be on disk right now.
    #
    # @return [Hash{String => Object}]
    def build
      body = {
        "schema" => SCHEMA,
        "generator" => "scripts/checks/manifest.rb",
        "gem" => gem_section,
        "tiers" => tier_section,
        "subsystems" => subsystem_section,
        "error_codes" => error_section,
        "checks" => Registry.discover.map { |entry| entry.to_h.transform_keys(&:to_s) }
      }
      order(body.merge("build_id" => build_id(body)))
    end

    # @return [Hash{String => String}]
    def gem_section
      magik = Library.load!
      { "name" => "magik", "version" => magik::VERSION, "status" => magik::CLI::STATUS,
        "spec" => "docs/idea/00-build-spec.md" }
    end

    # @return [Hash{String => Array<String>}] tier number as a string => subsystems
    def tier_section
      Tiers::TABLE.values.uniq.sort.to_h do |tier|
        [tier.to_s, Tiers::TABLE.select { |_, t| t == tier }.keys]
      end
    end

    # @return [Array<Hash{String => Object}>] one row per subsystem, sorted by name
    def subsystem_section
      magik = Library.load!
      spec_only = magik::SPEC_ONLY_SUBSYSTEMS.map(&:to_s)
      rows = magik::SUBSYSTEMS.map do |file, const|
        mod = magik.const_get(const)
        { "name" => file.to_s, "constant" => mod.name, "tier" => Tiers.tier_of(file.to_s),
          "phase" => constant_or_nil(mod, :SPEC_PHASE), "status" => constant_or_nil(mod, :STATUS),
          "spec_only" => spec_only.include?(file.to_s), "file" => "lib/magik/#{file}.rb" }
      end
      rows.sort_by { |row| row["name"] }
    end

    # @return [Array<Hash{String => String}>] one row per shipped error code
    def error_section
      rows = Library.error_classes.map do |klass|
        { "code" => klass.code, "class" => klass.name, "fix" => klass.fix,
          "at" => Library.source_of(klass) }
      end
      rows.sort_by { |row| row["code"] }
    end

    # @param mod [Module]
    # @param name [Symbol]
    # @return [Object, nil]
    def constant_or_nil(mod, name)
      mod.const_defined?(name) ? mod.const_get(name) : nil
    end

    # The full SHA-256 of the body, with `build_id` itself excluded.
    #
    # @param body [Hash{String => Object}]
    # @return [String] 64 hex characters
    def build_id(body)
      Digest::SHA256.hexdigest(canonical(body.except("build_id")))
    end

    # A key-sorted, whitespace-free rendering, used only for hashing and
    # comparison — never for the bytes on disk.
    #
    # @param value [Object]
    # @return [String]
    def canonical(value)
      JSON.generate(sorted(value))
    end

    # @param value [Object]
    # @return [Object] the same value with every Hash key-sorted
    def sorted(value)
      case value
      when Hash then value.keys.sort.to_h { |key| [key, sorted(value[key])] }
      when Array then value.map { |element| sorted(element) }
      else value
      end
    end

    # @param body [Hash{String => Object}]
    # @return [Hash{String => Object}] the same keys in {KEY_ORDER}
    def order(body)
      KEY_ORDER.select { |key| body.key?(key) }.to_h { |key| [key, body[key]] }
    end

    # The exact bytes the file should contain, trailing newline included.
    #
    # @param manifest [Hash{String => Object}]
    # @return [String]
    def serialise(manifest)
      "#{JSON.pretty_generate(manifest)}\n"
    end

    # @return [Hash{String => Object}, nil] the committed manifest, or nil when
    #   it is absent or not readable as a JSON object
    def read
      return nil unless Repo.exist?(PATH)

      parsed = JSON.parse(Repo.read(PATH))
      parsed.is_a?(Hash) ? parsed : nil
    rescue JSON::ParserError
      nil
    end

    # Which sections of the committed manifest no longer describe the code.
    #
    # Compared section by section rather than byte by byte, so the report says
    # *what* went stale. A body that matches under a mismatched `build_id` is a
    # hand edit and is still drift.
    #
    # @param on_disk [Hash{String => Object}, nil]
    # @param fresh [Hash{String => Object}]
    # @return [Array<String>] empty when the file is current
    def drift(on_disk, fresh)
      return ["#{PATH} is missing, unreadable, or not a JSON object"] if on_disk.nil?

      differences = (KEY_ORDER - ["build_id"])
                    .reject { |key| canonical(on_disk[key]) == canonical(fresh[key]) }
                    .map { |key| "#{key} differs" }
      return differences unless differences.empty?
      return [] if on_disk["build_id"] == fresh["build_id"]

      ["build_id differs — the body matches but the digest was hand-edited"]
    end

    # Write the manifest to disk.
    #
    # @param manifest [Hash{String => Object}]
    # @return [Integer] bytes written
    def write(manifest)
      Repo.path(PATH).write(serialise(manifest))
    end
  end
end
