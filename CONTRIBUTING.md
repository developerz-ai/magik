# Contributing to Magik

Magik is **pre-alpha and spec only** — the framework is not implemented, and `As of 2026-08-26` the
work is building it from [`docs/idea/00-build-spec.md`](docs/idea/00-build-spec.md). Contributions
are welcome on exactly that basis: a change here implements a section of the spec, or it fixes the
ground work that supports doing so.

Read [`CLAUDE.md`](CLAUDE.md) before your first change — it is the contract, and it applies to
humans too. Its "guesses this repo will punish" section is the short list of things this repo does
differently from what a Ruby developer would assume. `AGENTS.md` is a symlink to the same file, so
every agent convention lives in one place and cannot drift.

## Setup

```sh
bin/setup      # dependencies and the local toolchain; idempotent, safe to re-run after any pull
bin/check      # the gate. Green means the tree is shippable
```

Requirements: **CRuby ≥ 3.2** and Bundler. Nothing else is assumed. Postgres and friends are
available through [`docker/compose.yml`](docker/compose.yml) and
[`.devcontainer/`](.devcontainer/) if you want them, and `bin/setup` names anything missing.

**TruffleRuby is the production runtime and is not required locally.** It is not expected to be
installed on a contributor's machine; anything TruffleRuby-specific is verified in
[CI](.github/workflows/ci.yml). Do not add a local hook that needs it.

| Command | Does |
|---|---|
| `bin/setup` | fresh clone to working |
| **`bin/check`** | **the gate — run this before every push** |
| `rake test` | the Minitest suite — runs on bare Ruby, no bundle needed |
| `rake yard` | the API docs, published to <https://developerz-ai.github.io/magik/api/> · coverage: `rake docs:coverage` |
| `rake -T` | every task available — `build`, `check`, `docs:coverage`, `rubocop`, `test`, `yard` |
| `rake rubocop` | lint · `bundle exec rubocop -A` to autocorrect |
| `bin/release` | the release pre-flight — it prints the commands and runs none of them |
| `bin/console` | an IRB session with the gem loaded |
| `bin/dev` | the CLI against [`dummy/`](dummy/) |
| `ruby -Ilib exe/magik version --json` | the CLI, from source |

## The gate

**`bin/check` — green means shippable.** `--only <step>` runs one step, `--json` gives the summary
as data, `--list` names the steps. CI runs the same thing
([`.github/workflows/ci.yml`](.github/workflows/ci.yml)); there is no second checklist and no
CI-only step. If a check is worth running before a merge, it belongs in `bin/check` where you can
run it too.

`rake test` passing is not the gate. A change that lints clean, tests green and leaves `rake yard`
with an undocumented public method is not done.

`rake test` needs only Ruby and Rake. **RuboCop and YARD come from `bundle install`** and their
tasks abort with an install hint when the gem is missing — an aborted task is not a passing one, so
run `bin/setup` before claiming the gate is green.

## Every change is spec-backed

**A change traces to a section of [`docs/idea/00-build-spec.md`](docs/idea/00-build-spec.md), and
the PR names it.** Not a paraphrase — the heading, so a reviewer can open the file and compare.

```
Implements: docs/idea/00-build-spec.md § "Phase 1 — Foundation" (the :money field type)
```

Three consequences worth stating plainly:

- **No section, no change.** A good idea with nowhere to trace back to is a proposal about the spec
  (below), not a pull request.
- **The spec wins.** If the code and the spec disagree, the code is wrong — even when the code is
  better. Change the spec first, then the code.
- **Do not implement more than the section says.** Speculative surface is the expensive kind: it
  has to be documented, tested, supported and eventually deprecated.

## Proposing a change to the spec itself

**That is a discussion, not a pull request.** Open a GitHub Discussion (or an issue labelled
`spec`) describing the problem, the sections affected, what would have to change downstream, and
what you would lose by not doing it. A spec change is agreed first and edited once — a PR that
quietly rewrites a spec section alongside an implementation will be declined even when the
implementation is good, because it makes the source of truth negotiable in a code review.

The thirteen non-negotiable architecture decisions (TruffleRuby, Rack+Puma, Sequel, no SPA
framework, opt-in realtime, no offline, no heavy client compute, multi-tenant by default, stateless
servers, integer-cents money, mandatory swap points, domain modules, and authorization evaluated in
exactly one place) are exactly that. Arguing one is a discussion about the project's identity, and
it is a fair discussion to have — in the open, before any code.

Read them in the spec rather than from that list —
[`docs/idea/00-build-spec.md`](docs/idea/00-build-spec.md) § "Non-negotiable Architecture
Decisions" is the wording that counts, and two of them carry a measurement rather than an argument:
`ruby scripts/probes/runtime.rb --json` is what decisions 1 and 2 rest on.

## Code rules

The full contract is [`CLAUDE.md`](CLAUDE.md) and
[`docs/architecture/00-conventions.md`](docs/architecture/00-conventions.md). The ones that will
send a PR back:

| Rule | Detail |
|---|---|
| **SOLID, SRP hardest** | one class, one reason to change. Small objects with one job; no god objects; new behaviour arrives as a new registered object, never as another branch in a growing `case`; depend on the narrow role you use, not on the neighbouring module. Applies to Magik's internals **and** to the code Magik generates into a user's app. Full treatment: [`docs/architecture/00-conventions.md`](docs/architecture/00-conventions.md) |
| **Minitest, never RSpec** | `test/`, files named `*_test.rb`. There is no `spec/` |
| **Sequel, never ActiveRecord** | wrapped, never hidden. Explicit queries |
| **A test that would catch a real regression** | `assert true` is not a test. A bug fix starts with the failing test that reproduces it |
| **YARD on every public method** | `@param`, `@return`, `@raise`, and an `@example` on anything a user calls. `rake yard` clean |
| **Errors carry a `MAGIK_*` code** | `MAGIK_<SUBSYSTEM>_<CONDITION>` plus a concrete cause and a **runnable** `fix:` line. A `fix:` that gives advice instead of a command is a defect |
| **No unimplemented behaviour claimed** | stubs `raise NotImplementedError` with a message naming the phase. Never a plausible empty answer |
| **No float money** | integer cents, in code, in fixtures, in examples |
| **RuboCop owns style** | do not argue with the formatter, run `bundle exec rubocop -A` |
| **New dependencies need a reason in the PR** | the spec's "libraries to wrap" list is the default answer |
| **Date-stamp claims that can rot** | `As of 2026-08-26`, beside the command that re-derives them |

## Docs are part of the change

- **YARD** on every public method you add or touch. `rake yard` is in the gate.
- **A doc page** when the shape is new: `docs/architecture/` for how a subsystem works,
  [`wiki/`](wiki/) for the reference manual, `docs/idea/` only when the *rationale* changed.
- **Fix the status tables you just invalidated.** [`README.md`](README.md), [`CLAUDE.md`](CLAUDE.md)
  and [`ROADMAP.md`](ROADMAP.md) all carry rows that say "not implemented". Landing a feature and
  leaving those rows behind is the single most likely defect in this repository right now — a
  status outliving its fact is worse than no status.

## CHANGELOG

**Every user-visible change gets an entry under `## [Unreleased]` in
[`CHANGELOG.md`](CHANGELOG.md), in the same PR.** Keep a Changelog format:
`Added` / `Changed` / `Deprecated` / `Removed` / `Fixed` / `Security`.

`## [Unreleased]` *is* the release notes — [`PUBLISHING.md`](PUBLISHING.md) promotes that section
verbatim at release time. Write it for the person upgrading, not for the person who wrote the code.

## Branches and commits

Branch from `main` as `<type>/<slug>` — `feat/money-type`, `fix/uuid7-ordering`, `docs/ledger-page`.

**[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)**, imperative mood, lower
case:

```
feat(model): :money field type refuses a Float at declaration
fix(cli): magik version --json exits 0 with valid JSON
docs(ledger): state that boot-time balance validation is not implemented
test(schema): migration DSL round-trips a uuid7 primary key
chore(deps): bump rubocop to 1.81
```

Types: `feat` `fix` `perf` `refactor` `docs` `test` `chore` `ci` `build`. The scope is the subsystem
module (`model`, `render`, `ledger`, …). A `!` after the scope marks a breaking change — before
1.0.0 that means a minor bump and a `BREAKING` note in the changelog entry.

## Pull requests

- **One concern per PR.** A refactor and a feature in one diff get the least useful review.
- **`bin/check` green before you push.** A red PR is not ready for review; say so in the description
  if you are opening it for discussion anyway.
- **Name the spec section** you are implementing (above).
- **Say what is *not* done.** A known gap named in the PR is information; a known gap found in
  review is a round-trip.
- **`Closes #N`** in the body when it closes an issue.
- **New `MAGIK_*` codes go in a table in the PR description** — code, cause, `fix:` — so the
  reviewer can check the `fix:` line is a command that actually exists.
- Ship the guard with the fix: a defect that can recur gets its test in the same PR.

Agents write most of the code here, and it is reviewed exactly as a human's would be: on the merits.
Neither "an agent wrote it" nor "a human wrote it" is an argument.

## Reporting

Bugs and feature requests: GitHub Issues. **Security issues: do not open an issue** —
[`SECURITY.md`](SECURITY.md) has the private route.

By contributing you agree your work is licensed under the [MIT License](LICENSE), and to the
[Code of Conduct](CODE_OF_CONDUCT.md).
