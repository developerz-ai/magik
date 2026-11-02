# frozen_string_literal: true

require "rake/testtask"

# Every dev tool below is optional at load time: a bare `ruby -Ilib -Itest` run
# and `rake test` must work on a machine that has only Ruby and Rake. Tasks
# whose gem is missing are still defined, but fail loudly with an install hint.

Rake::TestTask.new(:test) do |t|
  t.description = "Run the Minitest suite"
  t.libs = %w[lib test]
  t.warning = false
  t.test_files = FileList["test/**/*_test.rb"]
end

begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new(:rubocop) do |t|
    t.options = ["--display-cop-names"]
  end
rescue LoadError
  desc "Run RuboCop (gem not installed)"
  task :rubocop do
    abort "rubocop is not installed. fix: run `bundle install`"
  end
end

begin
  require "yard"
  YARD::Rake::YardocTask.new(:yard) do |t|
    t.stats_options = ["--list-undoc"]
  end

  YARD_AVAILABLE = true
rescue LoadError
  desc "Build YARD documentation (gem not installed)"
  task :yard do
    abort "yard is not installed. fix: run `bundle install`"
  end

  YARD_AVAILABLE = false
end

namespace :docs do
  desc "Report YARD documentation coverage and list undocumented objects"
  task :coverage do
    abort "yard is not installed. fix: run `bundle install`" unless YARD_AVAILABLE

    sh "yard stats --list-undoc"
  end
end

desc "Build magik-VERSION.gem in the working directory (does not publish)"
task :build do
  sh "gem build magik.gemspec"
end

desc "Run the full gate: tests, lint, docs coverage"
task check: %i[test rubocop docs:coverage]

# Default gate: tests then lint.
task default: %i[test rubocop]
