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

Documentation and planning only. **No framework behaviour changed, because there is none** — the
spec was amended from measurement and rewritten as a clean v1, and everything below is the rest of
the repository being brought back into agreement with it.

### Added

- **Architecture decision 13 — authorization is evaluated in exactly one place.** Every surface that
  reaches a model — screen, action, API resource, channel, job, admin panel — names a verb in a
  `policy` and the framework evaluates it. There is no second door to the data and no per-surface
  check. The evaluator sits at **tier 1**, below `model`, `render` and `realtime`, because tier 2 has
  to evaluate it and imports go strictly down; it takes the actor as an opaque value and `auth` at
  tier 3 supplies that value later. Authorization is deliberately **not** a swap point.
- **`policy` as the twenty-first subsystem** — `lib/magik/policy.rb`, a spec-only stub like the rest:
  `SPEC_PHASE`, `DSL_SURFACE`, `STATUS`, and a `.define` that raises `NotImplementedError`. Re-derive
  the list with `ruby -Ilib -e 'require "magik"; puts Magik::SUBSYSTEMS.keys.join(" ")'`.
- **Phase 4b — Media**, a new phase between jobs and money, delivered at build step 8. It exists
  because media spans four phases — the `:file` type is phase 1, the upload component phase 2,
  derivatives and transcoding are phase 4 jobs, and signed delivery is blocked on `policy` — and a
  capability whose value arrives only when all four have landed is a phase. It is not optional: the
  mission sentence names ecommerce and marketplaces and both are blocked on it.
- **`layout` and `magik describe`** in the plan — `layout` lands in phase 2 and build step 3 as the
  application shell, so a generated app has a sidebar on its first run; `magik describe` lands in
  phase 1 and build step 2 as the grammar-as-data, derived from the option tables the DSL validates
  against rather than hand-maintained.
- **A fourth executable proof for `1.0.0`** in [`ROADMAP.md`](ROADMAP.md): *a generated app is safe
  and usable on its first run*, proven by three tests rather than a document — a cross-tenant actor
  denied by every generated surface, the generated shell rendering correctly at 375px, and the
  generated signup form throttling without revealing whether an account exists. It exists because the
  three criteria above it can all be true of an application that is insecure and unusable.

### Changed

- **The server is Rack + Puma, thread-per-request — not Falcon.** TruffleRuby's threads are genuinely
  parallel and it implements no fiber scheduler and no `fork`, which makes thread-per-request the
  correct model, Puma the correct server, and clustered workers impossible. Re-derive with
  `ruby scripts/probes/runtime.rb --json`; the provenance is
  [`docs/architecture/12-runtime-verification.md`](docs/architecture/12-runtime-verification.md).
  Corrected in [`.env.example`](.env.example), [`magik.gemspec`](magik.gemspec)'s wrap-target list,
  [`.github/dependabot.yml`](.github/dependabot.yml),
  [`.github/workflows/ci.yml`](.github/workflows/ci.yml) and
  [`CONTRIBUTING.md`](CONTRIBUTING.md).
- **Every count now reads ten phases, thirteen build steps and thirteen non-negotiable decisions.**
  [`ROADMAP.md`](ROADMAP.md), [`llms.txt`](llms.txt) and [`CONTRIBUTING.md`](CONTRIBUTING.md) said
  nine, twelve and twelve.
- **[`ROADMAP.md`](ROADMAP.md) is now ordered by delivery and numbered by phase identity**, and says
  so. It previously renumbered the phases silently, so its "Phase 3" was the spec's phase 9. The
  spec settles the relationship — *where the build order and the phase list disagree, build order
  wins* — and the page now states it instead of hiding it. Domains is labelled spec item 12 rather
  than a phase, matching [`docs/idea/06-phases.md`](docs/idea/06-phases.md).
- **`retries times: 5, backoff: :exponential`, never `retry`.** `retry` is a Ruby keyword and a
  declaration named after it does not parse; `computed(:name, :type) { … }` keeps its parentheses
  because a brace block binds to the last call. Both were found by running a parser over the drafted
  DSL, which is the spec's rule: *a drafted DSL spelling is not designed until it has been parsed.*
- **The TruffleRuby pin in [`.devcontainer/Dockerfile`](.devcontainer/Dockerfile) is `34.0.1`**, and
  its header no longer describes the runtime's concurrency as "Ractors and Fibers" — it is real
  parallel OS threads, verified on both 24.2.1 and 34.0.1.
- **[`llms.txt`](llms.txt) and [`docs/README.md`](docs/README.md) map the pages that exist** —
  `docs/idea/10`–`12` and `docs/architecture/09`–`12` were missing from both, and `llms.txt` still
  described the spec as "kept verbatim", listed two working CLI commands where three run, and named
  twenty subsystems where twenty-one are registered.

### Notes

- **Nothing in this release is a measurement of Magik.** The only numbers anywhere in the repository
  are engine measurements from `scripts/probes/`, and they belong to Ruby, not to this framework.
- **No `MAGIK_*` code named in the spec is implemented.** The codes that a running command can raise
  are the CLI's own; `grep -rhoE '"MAGIK_[A-Z0-9_]+"' lib/ | sort -u` is the only list that is real
  today, and everything in the guardrail catalogue is seeded and raised by nothing.

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
