# frozen_string_literal: true

module Magik
  # The released version of the `magik` gem.
  #
  # `0.0.1` is a **name-reservation release**: the gem name is claimed on
  # RubyGems, the public surface is a CLI shim plus documented, spec-only
  # subsystem stubs. No framework behaviour from `docs/idea/00-build-spec.md`
  # is implemented.
  #
  # The value follows [Semantic Versioning](https://semver.org). While the
  # major version is `0`, minor bumps may break the public API.
  #
  # @return [String] a frozen `MAJOR.MINOR.PATCH` string
  # @example Read the version at runtime
  #   require "magik"
  #   Magik::VERSION # => "0.0.1"
  VERSION = "0.0.1"
end
