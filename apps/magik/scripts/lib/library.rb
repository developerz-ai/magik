# frozen_string_literal: true

require_relative "repo"

module MagikScripts
  # Loads the gem out of `lib/` and answers questions about it.
  #
  # Three checks need the *runtime* truth rather than the source text:
  # `Magik::SPEC_ONLY_SUBSYSTEMS` is a constant, an error class's code is the
  # result of walking its superclass chain, and `magik help`'s command list is
  # a Hash. Reading those with a regex would be a second, worse implementation
  # of Ruby.
  #
  # Loading is idempotent and forces every {Magik::SUBSYSTEMS} autoload, because
  # a constant that has not been referenced does not exist yet and a check that
  # walks the namespace would silently see nothing.
  module Library
    module_function

    # Require `magik` from this checkout's `lib/`, never from an installed gem.
    #
    # @return [Module] `Magik`
    def load!
      return Object.const_get(:Magik) if @loaded

      lib = Repo.path("lib").to_s
      $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
      require "magik"
      magik = Object.const_get(:Magik)
      magik::SUBSYSTEMS.each_value { |const| magik.const_get(const) }
      @loaded = true
      magik
    end

    # @return [Hash{Symbol => Symbol}] `Magik::SUBSYSTEMS`
    def subsystems
      load!::SUBSYSTEMS
    end

    # @return [Array<Symbol>] `Magik::SPEC_ONLY_SUBSYSTEMS`
    def spec_only
      load!::SPEC_ONLY_SUBSYSTEMS
    end

    # Every `Magik::Error` and subclass reachable from the `Magik` namespace,
    # `Magik::Error` itself included — it ships `MAGIK_ERROR` as its default.
    #
    # `ObjectSpace` is deliberately not used: run from a test it would also see
    # the fixture classes the test just defined, and the check would report on
    # its own scaffolding.
    #
    # @return [Array<Class>] sorted by constant name
    def error_classes
      magik = load!
      found = {}
      walk(magik, found, {}.compare_by_identity)
      found.values.sort_by { |klass| klass.name.to_s }
    end

    # Where a constant is defined, relative to the repo root.
    #
    # @param klass [Module] any constant with a name
    # @return [String] e.g. `"lib/magik.rb:212"`, or `"unknown"`
    def source_of(klass)
      location = Object.const_source_location(klass.name.to_s)
      return "unknown" if location.nil? || location.first.nil?

      "#{Pathname.new(location.first).relative_path_from(Repo.root)}:#{location.last}"
    end

    # @param mod [Module] the namespace to walk
    # @param found [Hash{String => Class}] accumulator, keyed by constant name
    # @param seen [Hash] identity-keyed cycle guard
    # @return [void]
    def walk(mod, found, seen)
      return if seen[mod]

      seen[mod] = true
      error = Object.const_get(:Magik)::Error
      mod.constants(false).each do |name|
        value = mod.const_get(name)
        next unless value.is_a?(Module) && value.name.to_s.start_with?("Magik")

        found[value.name] = value if value.is_a?(Class) && value <= error
        walk(value, found, seen)
      end
    end
  end
end
