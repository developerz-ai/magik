# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"
require "test_helper"

# The gate script `bin/check`, exercised as a process where the property under
# test is the step's effect on the machine rather than a return value.
#
# The build step's artifact path is the subject of its own case. `gem build`
# writes wherever `--output` names, so that path must sit inside a PRIVATE
# directory — a fresh `Dir.mktmpdir` of this run, mode 0700 — and never at a
# fixed, predictable name in the shared system tmpdir, where another local
# user can plant a symlink between the gate's unlink and the write and have
# `gem build` redirected onto a file the developer can overwrite. A regression
# to the shared name fails the case below, not just a read of the source.
class CheckScriptTest < Minitest::Test
  # This suite lives under apps/magik/test/, three levels down, but bin/check
  # stayed at the checkout root and is run from there.
  CHECK = File.expand_path("../../../bin/check", __dir__).freeze

  # The same interpreter as the suite, so the stub's shebang resolves without
  # relying on the sandbox PATH — which carries nothing but the stub.
  RUBY = File.join(RbConfig::CONFIG["bindir"], RbConfig::CONFIG["ruby_install_name"]).freeze

  def test_the_build_step_writes_its_artifact_inside_a_private_tmpdir
    Dir.mktmpdir("magik-check-script") do |scratch|
      log = File.join(scratch, "gem.log")
      out, err, status = run_check("--only", "build", "--json", gem_log: log)

      assert_equal 0, status, "the build step passes on this tree:\n#{err}#{out}"

      # The stub recorded, at the moment `gem build` wrote: the argv it was
      # given, the --output target, and the mode of the directory holding the
      # target. That is the instant a symlink race would fire, so that is the
      # moment the assertion reads.
      argv, target, mode = File.readlines(log).map(&:strip)

      assert_equal "build", argv.split("\t").first, "the stub ran the build, not something else"

      staging = File.dirname(target)

      refute_equal Dir.tmpdir, staging,
                   "the artifact must never sit directly in the shared system tmpdir, where " \
                   "another local user can plant a symlink at a predictable name"
      assert staging.start_with?(Dir.tmpdir), "the artifact is still staged under the system tmpdir"
      assert File.basename(staging).start_with?("magik-gem-build-"),
             "the staging directory is a fresh Dir.mktmpdir of this run, not a fixed shared path"
      assert_equal "700", mode[-3, 3],
                   "the staging directory is private to this user at write time (0700), so no " \
                   "other local user can reach the path gem build writes to"

      data = JSON.parse(out)

      assert(data["ok"])
      assert_equal "pass", data.dig("steps", 0, "status")

      # Nothing survives the run: no artifact, no staging directory, and never
      # again the fixed shared-tmpdir name the step once used.
      refute_path_exists target, "the smoke artifact is cleaned up"
      refute_path_exists staging, "the private staging directory is cleaned up"
      refute_path_exists File.join(Dir.tmpdir, "magik-gem-build-smoke.gem"),
                         "the fixed shared-tmpdir name is gone for good"
    end
  end

  private

  # Runs bin/check with `gem` resolved to a stub that records its argv, the
  # --output target and the mode of the target's directory at write time, then
  # produces the artifact so the step's pass path completes. stdout and stderr
  # are captured separately: stdout carries the JSON the case parses. bin/check's
  # arguments are forwarded anonymously.
  #
  # @param gem_log [String] where the stub appends what it saw
  # @return [Array(String, String, Integer)] stdout, stderr, exit status
  def run_check(*, gem_log:)
    bin = File.dirname(gem_log)
    File.write(File.join(bin, "gem"), <<~RUBY)
      #!#{RUBY}
      require "fileutils"
      output = ARGV[ARGV.index("--output") + 1] if ARGV.index("--output")
      File.open(#{gem_log.inspect}, "a") do |log|
        log.puts(ARGV.join("\\t"))
        next unless output
        log.puts(output)
        log.puts(File.stat(File.dirname(output)).mode.to_s(8))
      end
      FileUtils.touch(output) if output
    RUBY
    FileUtils.chmod(0o755, File.join(bin, "gem"))

    # The suite runs under `bundle exec` — on CI and inside bin/check's own test
    # step alike — and Bundler injects itself into every child: RUBYOPT carries
    # `-rbundler/setup` and BUNDLE_GEMFILE names the root Gemfile. This child's
    # PATH holds nothing but the stub, so a bundler boot dies evaluating the
    # gemspec's `git ls-files` file list — Bundler::GemspecError, "No such file
    # or directory - git" — before bin/check runs a line. A nil value deletes a
    # variable from the child's environment, so the gate under test runs on
    # plain rubygems, exactly as it does for a developer outside the bundle;
    # everything else (HOME, TMPDIR) is inherited untouched.
    injected = /\A(?:BUNDLE|RUBYOPT|RUBYLIB|GEM_HOME|GEM_PATH)/
    env = ENV.to_h { |key, value| injected.match?(key) ? [key, nil] : [key, value] }
    env["PATH"] = bin

    out, err, status = Open3.capture3(env, RUBY, CHECK, *)
    [out, err, status.exitstatus]
  end
end
