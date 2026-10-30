# frozen_string_literal: true

require "fileutils"
require "open3"
require "tmpdir"
require "test_helper"

# The two shell entry points of the development cycle, `bin/dev` (the test
# watch loop) and `bin/stop` (the compose teardown), exercised as processes
# rather than read as text.
#
# Every case is hermetic. A case runs its script with PATH naming a sandbox
# `bin/` directory that holds only a `dirname` stand-in plus the stubs that
# case writes first: the real docker is never contacted, "docker absent" is a
# real absence rather than a mocked return value, and the real `bin/check`
# never runs from inside the suite — `bin/dev` reaches it only through a stub
# placed beside a byte-identical copy of itself in the sandbox.
class DevScriptsTest < Minitest::Test
  REPO = File.expand_path("..", __dir__).freeze

  def self.find_tool(name, *fallbacks)
    candidates = fallbacks + ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).map { |dir| File.join(dir, name) }

    candidates.find { |path| File.file?(path) && File.executable?(path) }
  end

  BASH = find_tool("bash", "/bin/bash").freeze
  DIRNAME = find_tool("dirname", "/usr/bin/dirname", "/bin/dirname").freeze
  FIND = find_tool("find", "/usr/bin/find", "/bin/find").freeze
  CAT = find_tool("cat", "/usr/bin/cat", "/bin/cat").freeze

  # What `bin/dev` must exec watchexec with: `--clear`, then one `--watch` per
  # WATCH_PATHS entry and per WATCH_FILES entry — the same set the entr,
  # fswatch and inotifywait branches feed their watchers — then the command.
  # No `--exts`: that whitelist filter is what dropped Rakefile and Gemfile.
  EXPECTED_WATCHEXEC_ARGS = %w[
    --clear
    --watch lib --watch exe --watch test
    --watch Rakefile --watch Gemfile --watch magik.gemspec
    -- ./bin/check --only test
  ].freeze

  # The exact docker argv a stop may produce, one element per stub-log line:
  # the probe, then the stop — the compose.yml `bin/setup --services` used, the
  # swap profile so Redis stops too, and the one verb, `stop`. Element-wise, so
  # a `down`, a `-v` or any extra flag fails the equality, not just a substring.
  STOP_AND_NOTHING_ELSE = %w[
    compose version
    compose -f docker/compose.yml --profile swap stop
  ].freeze

  # The exact argv the entr branch runs entr with on every restart, and the one
  # the fswatch branch execs fswatch with — the watcher's own flags, then
  # `./bin/check --only test` (entr) or every WATCH_PATHS/WATCH_FILES entry
  # (fswatch). Element-wise, so a changed flag fails the equality, not a grep.
  ENTR_ARGS = %w[-c -d ./bin/check --only test].freeze
  FSWATCH_ARGS = %w[-o -r lib exe test Rakefile Gemfile magik.gemspec].freeze

  def setup
    skip "bash, dirname, find and cat are required to run the dev scripts" if
      BASH.nil? || DIRNAME.nil? || FIND.nil? || CAT.nil?
  end

  # --- bin/stop ----------------------------------------------------------------

  def test_stop_exits_zero_when_docker_is_not_on_path
    in_sandbox do |_root, bin|
      status, output = run_script(File.join(REPO, "bin", "stop"), bin)

      assert_equal 0, status, "docker absent is 'nothing was started here to stop':\n#{output}"
      assert_includes output, "docker is not on PATH"
      assert_includes output, "fix: sudo apt-get install -y docker.io docker-compose-v2",
                      "the fix: is a command a reader can paste, not advice:\n#{output}"
    end
  end

  def test_stop_exits_zero_and_attempts_no_stop_when_the_compose_plugin_is_unavailable
    in_sandbox do |root, bin|
      log = File.join(root, "docker.log")
      write_stub(bin, "docker", log, "exit 1")

      status, output = run_script(File.join(REPO, "bin", "stop"), bin)

      assert_equal 0, status, "a missing compose plugin is 'nothing to stop':\n#{output}"
      assert_includes output, "compose plugin is not available"
      assert_includes output, "fix: sudo apt-get install -y docker-compose-v2",
                      "the fix: is a command a reader can paste, not advice:\n#{output}"
      assert_equal %w[compose version], logged(log)
    end
  end

  def test_stop_passes_the_project_file_and_the_swap_profile_and_runs_only_the_stop_verb
    in_sandbox do |root, bin|
      log = File.join(root, "docker.log")
      write_stub(bin, "docker", log, "exit 0")

      status, output = run_script(File.join(REPO, "bin", "stop"), bin)

      assert_equal 0, status, "a successful stop stays exit 0:\n#{output}"
      assert_equal STOP_AND_NOTHING_ELSE, logged(log)
      refute_includes logged(log).join(" "), " down ",
                      "bin/stop stops containers, never compose down"
      refute_includes logged(log).join(" "), "-v",
                      "no -v: the magik-postgres-data and magik-redis-data volumes keep their data"
    end
  end

  def test_stop_exits_zero_even_when_compose_stop_fails
    in_sandbox do |root, bin|
      log = File.join(root, "docker.log")
      write_stub(bin, "docker", log, <<~SH)
        if [ "$1" = compose ] && [ "$2" = version ]; then
          exit 0
        fi
        exit 1
      SH

      status, output = run_script(File.join(REPO, "bin", "stop"), bin)

      assert_equal 0, status, "teardown is idempotent: exit 0 in every path, compose failure included:\n#{output}"
      assert_includes output, "compose stop failed"
      assert_equal STOP_AND_NOTHING_ELSE, logged(log)
    end
  end

  # --- bin/dev -----------------------------------------------------------------

  def test_dev_derives_the_watchexec_arguments_from_watch_paths_and_watch_files
    in_sandbox do |root, bin|
      # bin/dev opens with `cd "$(dirname "$0")/.."` and runs `./bin/check` from
      # there, so the sandbox carries a byte-identical copy of the script with a
      # stub check beside it: the real gate never runs inside this suite.
      FileUtils.cp(File.join(REPO, "bin", "dev"), File.join(bin, "dev"))
      FileUtils.chmod(0o755, File.join(bin, "dev"))

      check_log = File.join(root, "check.log")
      write_stub(bin, "check", check_log, "exit 0")

      watch_log = File.join(root, "watchexec.log")
      write_stub(bin, "watchexec", watch_log, "exit 0")

      status, output = run_script(File.join(bin, "dev"), bin)

      assert_equal 0, status, "the watcher stub's exit becomes bin/dev's exit (it is exec'd):\n#{output}"
      assert_equal ["--only", "test"], logged(check_log), "the up-front run: one check, the default step"
      assert_equal EXPECTED_WATCHEXEC_ARGS, logged(watch_log)
      refute_includes logged(watch_log), "--exts",
                      "--exts is the whitelist filter that dropped Rakefile and Gemfile"
    end
  end

  def test_dev_feeds_entr_a_list_that_ends_at_eof_and_restarts_it_with_the_same_argv
    in_sandbox do |root, bin|
      # The entr branch lists files with `find`, so the sandbox carries the real
      # find beside the dirname stand-in — `set -e` would stop bin/dev the
      # moment find was missing — plus a miniature of the repo layout:
      # lib/magik.rb and test/dev_scripts_test.rb are its only *.rb files (the
      # non-*.rb exe/magik and test/notes.txt must not appear) and the
      # WATCH_FILES are appended verbatim, whether or not they exist here.
      FileUtils.ln_s(FIND, File.join(bin, "find"))
      FileUtils.cp(File.join(REPO, "bin", "dev"), File.join(bin, "dev"))
      FileUtils.chmod(0o755, File.join(bin, "dev"))
      %w[lib exe test].each { |dir| FileUtils.mkdir_p(File.join(root, dir)) }
      FileUtils.touch([File.join(root, "lib", "magik.rb"),
                       File.join(root, "exe", "magik"),
                       File.join(root, "test", "dev_scripts_test.rb"),
                       File.join(root, "test", "notes.txt")])

      check_log = File.join(root, "check.log")
      write_stub(bin, "check", check_log, "exit 0")

      # entr reads its list from stdin up to EOF and only then starts to
      # watch, so the stub records that list before deciding its exit: the
      # first invocation ends clean (entr runs on), the second one ends
      # non-zero (bin/dev must stop with it, not swallow it).
      entr_log = File.join(root, "entr.log")
      stdin_log = File.join(root, "entr_stdin.log")
      restarted = File.join(root, "entr.restarted")
      write_stub(bin, "entr", entr_log, <<~SH)
        while read -r line; do
          printf '%s\\n' "$line" >> "#{stdin_log}"
        done
        if [ -f "#{restarted}" ]; then
          exit 1
        fi
        : > "#{restarted}"
      SH

      status, output = run_script(File.join(bin, "dev"), bin)

      list = %w[lib/magik.rb test/dev_scripts_test.rb Rakefile Gemfile magik.gemspec]

      assert_equal 1, status,
                   "a watcher that dies non-zero must stop the script — not exit 0, not the no-watcher 69:\n#{output}"
      assert_equal ENTR_ARGS + ENTR_ARGS, logged(entr_log),
                   "entr is restarted with the same argv once its list ends at EOF"
      assert_equal list + list, logged(stdin_log),
                   "the list entr reads is finite and ends at EOF, so entr actually watches"
      assert_equal %w[--only test], logged(check_log),
                   "the up-front run only — the stub entr never runs the check"
      assert_includes output, "==> watcher: entr"
      refute_includes output, "MAGIK_DEV_NO_WATCHER",
                      "the entr branch never falls through to the no-watcher refusal"
    end
  end

  def test_dev_exits_zero_when_fswatch_ends_instead_of_falling_through_to_the_no_watcher_refusal
    in_sandbox do |root, bin|
      FileUtils.cp(File.join(REPO, "bin", "dev"), File.join(bin, "dev"))
      FileUtils.chmod(0o755, File.join(bin, "dev"))

      check_log = File.join(root, "check.log")
      write_stub(bin, "check", check_log, "exit 0")

      # A watcher that emits no events and exits 0 ends the exec'd pipeline;
      # the branch's trailing `exit 0` must hold the exit contract rather than
      # fall through to the no-watcher refusal (69). No other watcher is
      # stubbed here, so falling through is the only way one could appear.
      fswatch_log = File.join(root, "fswatch.log")
      write_stub(bin, "fswatch", fswatch_log, "exit 0")

      status, output = run_script(File.join(bin, "dev"), bin)

      assert_equal 0, status,
                   "a finished fswatch holds exit 0, never the no-watcher refusal (69):\n#{output}"
      assert_equal FSWATCH_ARGS, logged(fswatch_log),
                   "one invocation: the flags, then every watched path and file, no --exts"
      assert_equal %w[--only test], logged(check_log),
                   "the up-front run only — the stub emitted nothing, so no rerun happened"
      assert_includes output, "==> watcher: fswatch"
      refute_includes output, "MAGIK_DEV_NO_WATCHER",
                      "the exit 0 guard stands between a finished fswatch and the refusal"
    end
  end

  def test_dev_once_runs_the_step_exactly_once_and_never_asks_for_a_watcher
    in_sandbox do |root, bin|
      FileUtils.cp(File.join(REPO, "bin", "dev"), File.join(bin, "dev"))
      FileUtils.chmod(0o755, File.join(bin, "dev"))

      check_log = File.join(root, "check.log")
      write_stub(bin, "check", check_log, "exit 0")

      # No watcher is installed in this sandbox, and --once must not need one:
      # it runs the step and exits with the step's verdict. The script is
      # copied beside the stub because it opens with `cd "$(dirname "$0")/.."`
      # and reaches the gate through `./bin/check`.
      status, output = run_script(File.join(bin, "dev"), bin, "--once")

      assert_equal 0, status, "--once runs the step once and exits with its verdict:\n#{output}"
      assert_equal %w[--only test], logged(check_log), "exactly one check, the default step"
      refute_includes output, "MAGIK_DEV_NO_WATCHER", "--once never asks for a watcher"
    end
  end

  def test_dev_refuses_with_the_no_watcher_code_when_no_watcher_is_installed
    in_sandbox do |root, bin|
      FileUtils.cp(File.join(REPO, "bin", "dev"), File.join(bin, "dev"))
      FileUtils.chmod(0o755, File.join(bin, "dev"))

      check_log = File.join(root, "check.log")
      write_stub(bin, "check", check_log, "exit 0")

      # The up-front run happens, then the refusal. Exit 69 means "not
      # installed", not "broken" — nothing in this repository is wrong — and
      # the fix: has to be a command the reader can paste.
      status, output = run_script(File.join(bin, "dev"), bin)

      assert_equal 69, status, "no watcher is 'not installed', not 'broken':\n#{output}"
      assert_includes output, "MAGIK_DEV_NO_WATCHER"
      assert_includes output, "fix: sudo apt-get install -y entr",
                      "the fix: is a command a reader can paste, not advice:\n#{output}"
      assert_equal %w[--only test], logged(check_log), "the up-front run, once"
    end
  end

  private

  # Yields [root, bin]. The bin directory holds the `dirname` stand-in both
  # scripts open with (`cd "$(dirname "$0")/.."`) and the `cat` `bin/dev`
  # prints its messages with — a POSIX tool, not one of the tools under test,
  # so the real one is linked in. The directory is the child's ENTIRE PATH, so
  # a tool is truly absent until a stub for it is written there.
  #
  # @yieldparam root [String] the sandbox root
  # @yieldparam bin [String] the sandbox bin directory, the child's whole PATH
  # @return [void]
  def in_sandbox
    Dir.mktmpdir("magik-dev-scripts") do |root|
      bin = File.join(root, "bin")
      FileUtils.mkdir_p(bin)
      FileUtils.ln_s(DIRNAME, File.join(bin, "dirname"))
      FileUtils.ln_s(CAT, File.join(bin, "cat"))
      yield root, bin
    end
  end

  # Writes an executable stub named +name+ into +bin+. Each invocation appends
  # its arguments, one per line, to +log+, then runs +tail+ as the rest of its
  # body — so a test records exactly what the script tried to run, in order.
  #
  # @param bin [String] the sandbox bin directory
  # @param name [String] the tool to impersonate
  # @param log [String] where invocations are appended
  # @param tail [String] the rest of the stub's shell body
  # @return [void]
  def write_stub(bin, name, log, tail)
    File.write(File.join(bin, name), <<~SH)
      #!/bin/sh
      printf '%s\\n' "$@" >> "#{log}"
      #{tail}
    SH
    FileUtils.chmod(0o755, File.join(bin, name))
  end

  # @param path [String] a stub's log file
  # @return [Array<String>] the arguments of every recorded invocation
  def logged(path)
    return [] unless File.exist?(path)

    File.read(path).split("\n")
  end

  # @param path [String] the script to run
  # @param bin [String] the sandbox bin directory, the child's whole PATH
  # @return [Array(Integer, String)] exit status, combined stdout and stderr
  def run_script(path, bin, *)
    out, status = Open3.capture2e({ "PATH" => bin }, BASH, path, *)
    [status.exitstatus, out]
  end
end
