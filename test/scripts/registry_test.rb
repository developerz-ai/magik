# frozen_string_literal: true

require "fileutils"
require "tmpdir"

require_relative "helper"

# The discovery contract `bin/check` globs. If this test goes red, `bin/check`
# either loses a step or gains a duplicate one — and a check that silently drops
# out of discovery is a check that has silently stopped gating.
class MagikScriptsRegistryTest < Minitest::Test
  Registry = MagikScripts::Registry

  def teardown
    Array(@fixtures).each { |dir| FileUtils.remove_entry(dir) }
    super
  end

  def test_every_check_in_the_tree_declares_a_readable_header
    entries = Registry.discover

    refute_empty entries, "scripts/checks/ is empty — the gate has nothing to run"
    entries.each do |entry|
      assert_match Registry::NAME_FORMAT, entry.name
      assert_match(/\S/, entry.summary, "#{entry.path} has a blank @summary")
      assert_operator entry.order, :>, 0, "#{entry.path} has a non-positive @order"
    end
  end

  def test_discovery_is_in_cost_order_and_total
    orders = Registry.discover.map(&:order)

    assert_equal orders.sort, orders
    assert_equal orders.uniq, orders, "two checks claim the same @order, so the run order is undefined"
  end

  def test_every_check_names_its_own_file
    Registry.discover.each do |entry|
      assert_equal "scripts/checks/#{entry.name.tr("-", "_")}.rb", entry.path
    end
  end

  def test_a_header_is_parsed_into_name_summary_order_and_prose
    entry = Registry.parse(fixture(<<~RUBY))
      # @check   demo
      # @summary Does a thing.
      # @order   42
      #
      # Why it does the thing.

      puts 1
    RUBY

    assert_equal "demo", entry.name
    assert_equal "Does a thing.", entry.summary
    assert_equal 42, entry.order
    assert_equal "Why it does the thing.", entry.description
  end

  def test_a_file_with_no_header_is_an_error_carrying_its_own_fix
    error = assert_raises(Registry::HeaderError) { Registry.parse(fixture("puts 1\n")) }

    assert_includes error.message, "@check"
    assert_includes error.message, "fix:"
  end

  def test_a_name_that_does_not_match_its_filename_is_an_error
    error = assert_raises(Registry::HeaderError) do
      Registry.parse(fixture("# @check   other\n# @summary x\n# @order 1\n", as: "mismatch.rb"))
    end

    assert_includes error.message, "wants the file named other.rb"
  end

  def test_a_malformed_name_is_an_error
    error = assert_raises(Registry::HeaderError) do
      Registry.parse(fixture("# @check   Not A Name\n# @summary x\n# @order 1\n"))
    end

    assert_includes error.message, "must match"
  end

  def test_duplicate_names_and_orders_are_errors
    a = MagikScripts::Registry::Entry.new(name: "a", summary: "x", order: 1, description: "", path: "a.rb")
    b = MagikScripts::Registry::Entry.new(name: "a", summary: "x", order: 2, description: "", path: "b.rb")

    error = assert_raises(Registry::HeaderError) { Registry.assert_unique!([a, b], :name) }

    assert_includes error.message, "a.rb, b.rb"
  end

  private

  # Write a check-shaped file into a temp dir named after its declared @check.
  #
  # @param body [String] the file contents
  # @param as [String, nil] an explicit basename, to test a mismatch
  # @return [String] an absolute path
  def fixture(body, as: nil)
    name = body[/@check\s+(\S+)/, 1] || "demo"
    dir = Dir.mktmpdir("magik-registry")
    path = File.join(dir, as || "#{name.tr("-", "_")}.rb")
    File.write(path, body)
    @fixtures = (@fixtures || []) << dir
    path
  end
end
