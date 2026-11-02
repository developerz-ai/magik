# frozen_string_literal: true

require "test_helper"

# Covers the entry point: constants, autoloading, and the spec-only contract
# every subsystem stub must honour.
class MagikTest < Minitest::Test
  def test_root_points_at_the_gem_root
    assert_kind_of Pathname, Magik.root
    assert_predicate Magik.root, :absolute?
    assert_path_exists Magik.root.join("lib", "magik.rb").to_s
  end

  def test_root_is_memoised
    assert_same Magik.root, Magik.root
  end

  def test_subsystems_map_is_frozen_and_covers_the_spec
    assert_predicate Magik::SUBSYSTEMS, :frozen?
    expected = %i[
      core cli model schema render action router policy realtime jobs
      ledger api auth billing admin i18n pwa notify testing domains check
    ]

    assert_equal expected.sort, Magik::SUBSYSTEMS.keys.sort
  end

  def test_every_subsystem_has_a_file
    Magik::SUBSYSTEMS.each_key do |file|
      assert_path_exists Magik.root.join("lib", "magik", "#{file}.rb").to_s
    end
  end

  def test_every_subsystem_constant_resolves
    Magik::SUBSYSTEMS.each_value do |const|
      assert_kind_of Module, Magik.const_get(const), "Magik::#{const} did not autoload"
    end
  end

  def test_cli_is_the_only_subsystem_that_is_not_spec_only
    assert_equal Magik::SUBSYSTEMS.keys - [:cli], Magik::SPEC_ONLY_SUBSYSTEMS
    refute_includes Magik::SPEC_ONLY_SUBSYSTEMS, :cli
  end

  def test_spec_only_subsystems_declare_their_status_and_surface
    Magik::SPEC_ONLY_SUBSYSTEMS.each do |file|
      mod = Magik.const_get(Magik::SUBSYSTEMS[file])

      assert_equal "Not implemented — spec only", mod::STATUS
      assert_match(/\S/, mod::SPEC_PHASE)
      refute_empty mod::DSL_SURFACE
      assert_predicate mod::DSL_SURFACE, :frozen?
    end
  end

  def test_spec_only_subsystems_raise_not_implemented_error
    Magik::SPEC_ONLY_SUBSYSTEMS.each do |file|
      const = Magik::SUBSYSTEMS[file]
      mod = Magik.const_get(const)

      error = assert_raises(NotImplementedError) { mod.define(:Example) }

      assert_equal "Magik::#{const} is spec-only; see docs/idea/00-build-spec.md", error.message
    end
  end

  # `DSL_SURFACE` is copied from the spec, so it is where spec drift lands
  # first and silently — a stub still raises either way. These pin the three
  # spellings a reader is most likely to get wrong from memory.
  def test_the_surfaces_use_the_spellings_that_are_valid_ruby
    jobs = Magik::Jobs::DSL_SURFACE.join("\n")

    # `retry` is a Ruby keyword and does not parse as a declaration.
    assert_includes jobs, "retries times:"
    refute_match(/\bdo retry\b/, jobs)

    computed = Magik::Model::DSL_SURFACE.join("\n")

    # A brace block binds to the last call, so the parens are load-bearing.
    assert_includes computed, "computed(:name, :type)"
  end

  # TruffleRuby's threads are genuinely parallel and it has no `fork`, so a test
  # worker is a thread and there is exactly one worker model.
  def test_the_test_runner_parallelises_with_threads_not_ractors
    surface = Magik::Testing::DSL_SURFACE.join("\n")

    assert_includes surface, "one thread per test file group"
    refute_includes surface, "Ractor"
  end

  # Three field types exist so a malformed value fails at boot rather than at
  # first use. A type added after release is a migration for every app that
  # worked around its absence.
  def test_the_model_surface_names_every_type_that_is_a_type
    surface = Magik::Model::DSL_SURFACE.join("\n")

    %w[:money :file :duration].each { |type| assert_includes surface, type }
  end
end
