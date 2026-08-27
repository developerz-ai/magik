# Changelog

All notable changes to Magik. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Magik is **one gem** with subsystem modules — there is no lockstep across packages and no
per-package version. The single version lives in
[`lib/magik/version.rb`](lib/magik/version.rb); [`PUBLISHING.md`](PUBLISHING.md) owns how it is
stamped and released.

**Semver does not apply below 0.1.0.** Anything in a `0.0.x` release may change or disappear
without notice, and `0.0.1` in particular ships no API at all.

`## [Unreleased]` is the release notes — write the entry as the change lands, not at release time.

## [Unreleased]

Nothing yet.

## [0.0.1] - 2026-08-26

**A name reservation and the repository's ground work. No framework functionality.**

This release exists so the gem name `magik` is held on RubyGems and so the release path is proven
end to end before there is anything worth releasing. Installing it gives you a version constant and
a CLI that can print it. Nothing else.

What is explicitly **not** in this release: `App.define`, `model`, `migrate`, `component`, `screen`,
`action`, `channel`, `job`, `ledger`, `api`, `auth`, `billing`, `admin_panel`, the router, the
server, the test DSL, and every generator. Every one of them is
[specified](docs/idea/00-build-spec.md) and unimplemented. See the status callout in
[`README.md`](README.md).

### Added

- **The gem skeleton**, with **zero runtime dependencies** — [`magik.gemspec`](magik.gemspec),
  `Gemfile`, [`Rakefile`](Rakefile), `lib/magik.rb`, [`lib/magik/version.rb`](lib/magik/version.rb)
  and `exe/magik`. `required_ruby_version` is `">= 3.2"`; TruffleRuby is the production runtime
  target and CRuby is supported for tooling and development. `lib/magik.rb` is plain `autoload` over
  a `Magik::SUBSYSTEMS` map, so requiring the gem reads one file. The gems Magik intends to wrap are
  listed in the gemspec as comments, to be added by the phase that needs each one.
- **`Magik::Error`** — the `MAGIK_*` error-code convention, implemented and tested rather than
  described: a stable code, a one-sentence cause, a runnable `fix:` line, a deterministic rendered
  message, and `#to_h` for `--json`. Three subclasses cover the CLI's own failures.
- **`magik version` and `magik help`** — a working CLI, both with `--json`. `help` lists every
  command the spec names and marks each `ready` or `planned`, because "not built yet" and "not a
  command" are different facts.
- **19 spec-only subsystem stubs** under `lib/magik/`, one per planned subsystem: `core`, `model`,
  `schema`, `render`, `action`, `router`, `realtime`, `jobs`, `ledger`, `api`, `auth`, `billing`,
  `admin`, `i18n`, `pwa`, `notify`, `testing`, `domains`, `check`. Each documents its `SPEC_PHASE`,
  its `DSL_SURFACE` verbatim from the spec, and a `STATUS`; every `.define` raises
  `NotImplementedError` naming the spec rather than returning a plausible empty answer. `cli` is the
  twentieth subsystem and the only one with real behaviour.
- **The build spec**, [`docs/idea/00-build-spec.md`](docs/idea/00-build-spec.md), as the source of
  truth, plus the `docs/idea/`, [`docs/architecture/`](docs/architecture/) and
  [`docs/ops/README.md`](docs/ops/README.md) documentation sets, the [`wiki/`](wiki/) reference
  manual, [`ROADMAP.md`](ROADMAP.md) and [`llms.txt`](llms.txt).
- **The agent workflow** — [`CLAUDE.md`](CLAUDE.md) (with `AGENTS.md` symlinked to it) and
  [`.claude/`](.claude/README.md) with its agents and slash commands.
- **The developer environment** — `bin/setup`, `bin/check` (the gate, with `--only`, `--json` and
  `--list`), `bin/dev`, `bin/console`, `bin/release` (a release pre-flight that prints and never
  publishes), `docker/compose.yml`, [`.devcontainer/`](.devcontainer/) and
  [`lefthook.yml`](lefthook.yml).
- **Minitest** as the test framework, under `test/` as `*_test.rb`, run by `rake test` — and passing
  on bare Ruby, with no bundle installed. Never RSpec: a spec decision.
- **`rake -T`** — `build`, `check`, `docs:coverage`, `rubocop`, `test`, `yard`. The RuboCop and YARD
  tasks are defined even when their gem is absent, and abort with an install hint rather than
  passing vacuously.
- **RuboCop** (with `rubocop-minitest`, `rubocop-rake`, `rubocop-performance`) via
  [`.rubocop.yml`](.rubocop.yml), and **YARD** via [`.yardopts`](.yardopts).
- **CI and release plumbing** — [`.github/workflows/ci.yml`](.github/workflows/ci.yml),
  [`release.yml`](.github/workflows/release.yml) and
  [`docs.yml`](.github/workflows/docs.yml), which publishes the YARD docs to
  <https://developerz-ai.github.io/magik/api/>. Releases publish to RubyGems over trusted publishing
  (OIDC), with `rubygems_mfa_required` set on the gem; [`PUBLISHING.md`](PUBLISHING.md) documents
  the one-time manual bootstrap that 0.0.1 itself requires.
- **Project governance** — [`CONTRIBUTING.md`](CONTRIBUTING.md), [`SECURITY.md`](SECURITY.md),
  [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) and [`LICENSE`](LICENSE) (MIT).

### Notes

- **Nothing here has been benchmarked, deployed, or run against a real database.** No number in
  this repository is a measurement.
- `0.0.1` is published **by hand**: RubyGems cannot attach a trusted publisher to a gem that does
  not exist yet, so the first push is manual and every release after it goes through the workflow.
  [`PUBLISHING.md`](PUBLISHING.md) has the exact steps.

[Unreleased]: https://github.com/developerz-ai/magik/compare/v0.0.1...HEAD
[0.0.1]: https://github.com/developerz-ai/magik/releases/tag/v0.0.1
