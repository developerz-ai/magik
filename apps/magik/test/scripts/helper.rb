# frozen_string_literal: true

# Bootstrap for the `scripts/` tests.
#
# `scripts/` is not on the load path and is not packaged into the gem, so every
# test reaches it by relative path. Requiring a check file is safe by design:
# each one guards its entry point with `if $PROGRAM_NAME == __FILE__`, so
# loading it defines the class and runs nothing.

require "test_helper"

require_relative "../../scripts/lib/scripts"
require_relative "../../scripts/lib/library"
require_relative "../../scripts/lib/manifest"
require_relative "../../scripts/lib/ruby_source"
require_relative "../../scripts/lib/shell"

# Load every check. Safe by construction: each file guards its entry point with
# `if $PROGRAM_NAME == __FILE__`, so requiring one defines its class and runs
# nothing. Going through the registry rather than a glob means a check that
# loses its discovery header fails here too, not only in `bin/check`.
MagikScripts::Registry.discover.each { |entry| require MagikScripts::Repo.path(entry.path).to_s }

# Helpers shared by the scripts tests.
module ScriptsTestHelpers
  # Run a check as its own program, capturing both streams.
  #
  # @param file [String] the check's path, relative to the repo root
  # @param argv [Array<String>] the command line
  # @return [Array(Integer, String, String)] status, stdout, stderr
  def run_script(file, *argv)
    klass = script_class(file)
    out = StringIO.new
    err = StringIO.new
    status = MagikScripts::Runner.main(MagikScripts::Repo.path(file).to_s, klass, argv.flatten,
                                       out: out, err: err)
    [status, out.string, err.string]
  end

  # The `MagikScripts::Check` subclass a check file defines.
  #
  # @param file [String] the check's path, relative to the repo root
  # @return [Class]
  def script_class(file)
    name = File.basename(file, ".rb").split("_").map(&:capitalize).join
    MagikScripts::Checks.const_get(MagikScripts::Checks.constants.find do |const|
      [name, "#{name}Check"].include?(const.to_s)
    end)
  end
end

module Minitest
  class Test
    include ScriptsTestHelpers
  end
end
