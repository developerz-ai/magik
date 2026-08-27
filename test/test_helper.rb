# frozen_string_literal: true

# Test bootstrap.
#
# Coverage and pretty reporting are *optional*: this suite must run on a bare
# Ruby with nothing but minitest available, e.g.
#
#     ruby -Ilib -Itest test/magik_test.rb
#
# so every development gem is loaded behind a rescue.

begin
  require "simplecov"
  SimpleCov.start do
    enable_coverage :branch
    add_filter "/test/"
    add_group "Library", "lib"
  end
rescue LoadError
  # simplecov is not installed; run without coverage.
end

require "minitest/autorun"

begin
  require "minitest/reporters"
  Minitest::Reporters.use!(
    Minitest::Reporters::ProgressReporter.new(color: true),
    ENV,
    Minitest::ExtensibleBacktraceFilter.default_filter
  )
rescue LoadError
  # minitest-reporters is not installed; use the default reporter.
end

require "stringio"
require "magik"

# Shared helpers for the Magik test suite.
module MagikTestHelpers
  # Run the CLI with captured streams.
  #
  # @param argv [Array<String>] command line
  # @return [Array(Integer, String, String)] status, stdout, stderr
  def run_cli(*argv)
    out = StringIO.new
    err = StringIO.new
    status = Magik::CLI.start(argv.flatten, out: out, err: err)
    [status, out.string, err.string]
  end
end

module Minitest
  class Test
    include MagikTestHelpers
  end
end
