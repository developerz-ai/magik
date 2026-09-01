# frozen_string_literal: true

source "https://rubygems.org"

# Runtime dependencies (currently none) come from magik.gemspec.
gemspec

group :development, :test do
  # Task runner — `rake -T` lists the gate.
  gem "rake", "~> 13.0"

  # Test framework. Minitest, never RSpec (docs/idea/00-build-spec.md, Phase 9).
  gem "minitest", "~> 6.0"
  gem "minitest-reporters", "~> 1.6"
  gem "simplecov", "~> 0.22", require: false

  # Lint.
  gem "rubocop", "~> 1.0", require: false
  gem "rubocop-minitest", "~> 0.35", require: false
  gem "rubocop-performance", "~> 1.0", require: false
  gem "rubocop-rake", "~> 0.6", require: false

  # Docs. redcarpet is YARD's markdown provider.
  gem "redcarpet", "~> 3.6", require: false
  gem "yard", "~> 0.9", require: false
end
