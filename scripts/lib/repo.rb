# frozen_string_literal: true

require "pathname"

module MagikScripts
  # Where the repository is, and which of its files a check may look at.
  #
  # Every path a check reports is **relative to the repo root**, so a finding
  # can be pasted straight into an editor from any working directory. Nothing
  # here changes the process's cwd: a check that shells out must be runnable
  # from a subdirectory, and `Dir.chdir` in a library is a trap for the next
  # caller.
  #
  # The exclusion list is the same one `.rubocop.yml` uses, minus `dummy/`.
  # `dummy/` is excluded by default and opted **in** per check, because it is
  # the one directory whose contents are deliberately not Ruby anybody runs
  # (see `dummy/README.md`): a check that walks it by accident is asserting
  # something about a design document.
  module Repo
    # Directories no check ever walks, whatever it is looking for. Build
    # output, vendored gems, generated docs and coverage reports are not
    # source, and a finding inside one of them is noise.
    #
    # @return [Array<String>]
    EXCLUDED = %w[vendor doc pkg tmp node_modules coverage .git .yardoc .bundle .devcontainer].freeze

    # The reference application. Opted in explicitly, never by default.
    # @return [String]
    DUMMY = "dummy"

    module_function

    # The repository root — the directory holding `magik.gemspec`.
    #
    # @return [Pathname] absolute, resolved
    def root
      @root ||= Pathname.new(File.expand_path("../..", __dir__))
    end

    # Build an absolute path under the repo root.
    #
    # @param parts [Array<String>] path segments relative to the root
    # @return [Pathname]
    def path(*parts)
      root.join(*parts)
    end

    # @param rel [String] a path relative to the repo root
    # @return [Boolean]
    def exist?(rel)
      path(rel).exist?
    end

    # Read a repo file as UTF-8 text.
    #
    # @param rel [String] a path relative to the repo root
    # @return [String]
    def read(rel)
      path(rel).read(encoding: "UTF-8")
    end

    # Every path matching `pattern`, relative to the root, honouring
    # {EXCLUDED} and — unless asked otherwise — skipping `dummy/`.
    #
    # @param pattern [String] a `Dir.glob` pattern, e.g. `"lib/**/*.rb"`
    # @param dummy [Boolean] include `dummy/` in the result
    # @return [Array<String>] sorted, root-relative paths
    def glob(pattern, dummy: false)
      Dir.glob(pattern, base: root.to_s).reject { |rel| excluded?(rel, dummy: dummy) }.sort
    end

    # @param rel [String] a root-relative path
    # @param dummy [Boolean] treat `dummy/` as included
    # @return [Boolean] true when no check should look at this path
    def excluded?(rel, dummy: false)
      top = rel.split("/").first
      return true if EXCLUDED.include?(top)

      !dummy && top == DUMMY
    end

    # The 1-based line number of the first line of `haystack` matching
    # `needle`, or nil. Used to turn a regex hit into a `file:line` finding.
    #
    # @param haystack [String] file contents
    # @param needle [String, Regexp] what to look for
    # @return [Integer, nil]
    def line_of(haystack, needle)
      haystack.each_line.with_index(1) do |line, number|
        return number if needle.is_a?(Regexp) ? needle.match?(line) : line.include?(needle)
      end
      nil
    end
  end
end
