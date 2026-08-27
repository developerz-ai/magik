# CLAUDE.md

The working contract for Claude Code inside this repository. Read this once before your first edit;
it is the whole of your footing.

## What this repo is, today

**Magik** — an AI-first, full-stack Ruby framework on TruffleRuby. One DSL for models, screens,
actions, realtime, jobs, ledgers, APIs and admin. Server-rendered HTML plus htmx; no frontend
framework. Its sibling is [Ultimate](https://github.com/developerz-ai/ultimate), the same thesis in
TypeScript on Bun — Magik is that thesis for people who want Ruby and no TS toolchain.

Gem `magik` · module `Magik` · binary `magik` · GitHub `developerz-ai/magik` · MIT.

**The framework is not implemented.** `As of 2026-08-26` this tree is boilerplate: the spec, the
docs, the gem skeleton, the CI, the release plumbing. `0.0.1` is a RubyGems name reservation
([CHANGELOG.md](CHANGELOG.md)).

**What actually exists** — the whole of it, and the only thing you may describe in the present tense:

- **zero runtime dependencies**; the gem loads nothing but the standard library. The gems Magik
  intends to wrap sit in [`magik.gemspec`](magik.gemspec) as comments, added by the phase that needs
  each one.
- `lib/magik.rb` — plain `autoload` over the `Magik::SUBSYSTEMS` map.
- `Magik::Error` — real and tested: a stable `MAGIK_*` code, a cause, a runnable `fix:`, and `to_h`
  for `--json`. The convention working before any catalogue exists.
- `magik version`, `magik help` and `magik docs`, all with `--json`; `help` marks every spec'd command
  `ready` or `planned`. `magik docs` serves the documentation packaged inside the gem — see
  [Where the DSL reference is](#where-the-dsl-reference-is).
- **19 spec-only subsystem stubs**, one per planned subsystem, each exposing `SPEC_PHASE`,
  `DSL_SURFACE`, `STATUS` and a `.define` that raises `NotImplementedError`.
- a Minitest suite that passes **on bare Ruby with no bundle** — `rake test`.

There is no `App.define`, no `model`, no `screen`, no `action`, no router, no server and no database
code.

Your job, in almost every session here, is to **implement a phase of
[`docs/idea/00-build-spec.md`](docs/idea/00-build-spec.md)** — starting from Phase 1.

## Read these first, in this order

| # | File | Why |
|---|---|---|
| 1 | [`docs/idea/00-build-spec.md`](docs/idea/00-build-spec.md) | the source of truth. Everything else elaborates on it and nothing contradicts it. If your change is not traceable to a section of it, stop |
| 2 | [`docs/idea/07-ai-first.md`](docs/idea/07-ai-first.md) | why the guardrails, the uniform grammar and the `fix:` lines exist. Read before arguing with a default |
| 3 | [Guesses this repo will punish](#guesses-this-repo-will-punish) | the short list of things you would otherwise get wrong — below, in this file |
| 4 | [`.claude/README.md`](.claude/README.md) | the agents and slash commands this repo ships — use them instead of improvising a workflow |
| 5 | [`docs/architecture/`](docs/architecture/) | how each subsystem is meant to be built |
| 6 | [`ROADMAP.md`](ROADMAP.md) | the sequencing, and what a phase must demonstrate before it closes |

Then run `bin/setup` and `bin/check` before touching anything, so you know what green looks like on
an untouched tree.

## Status, with one runnable check per row

**Never quote the left column — run the right one.** A status written into a file goes stale on the
next commit; the command does not. `As of 2026-08-26`, every row below answers "not implemented",
and each row's command is how you find out that it no longer does.

| Claim | Read it yourself |
|---|---|
| the version this tree is stamped at | `ruby -Ilib -e 'require "magik/version"; puts Magik::VERSION'` |
| what RubyGems actually serves | `gem list -r magik --all` · `gem info magik -r` |
| the CLI's real surface, and which commands are `planned` | `ruby -Ilib exe/magik help` · `ruby -Ilib exe/magik version --json` |
| what is proven to work | `rake test` — a claim with no test behind it is not a claim |
| every task this repo offers | `rake -T` — `build`, `check`, `docs:coverage`, `rubocop`, `test`, `yard` |
| every public method is documented | `rake yard` · `rake docs:coverage` |
| the tree is lint-clean | `rake rubocop` |
| the whole gate, as CI runs it | `bin/check` · one step: `bin/check --only test` · as data: `bin/check --json` |
| which subsystems are still stubs | `grep -rln NotImplementedError lib/magik` — a file on that list is a placeholder, not a feature |
| what CI does | [`.github/workflows/ci.yml`](.github/workflows/ci.yml) |

**`rake test` runs on bare Ruby; RuboCop and YARD do not.** Both are development dependencies and
are not necessarily installed — the tasks abort with an install hint rather than passing vacuously.
Run `bin/setup` first, and **never report a lint or docs-coverage run you did not actually
complete.**

**Nothing in this repository has been benchmarked, deployed, or run against a real database.** Do
not add a number to any document that no command in this table re-derives.

## Non-negotiables (from the spec — these override any instinct)

1. **TruffleRuby is the production runtime.** Concurrency via Ractors and Fibers, never a thread per
   request. CRuby ≥ 3.2 is supported for tooling and development only; `required_ruby_version` is
   `">= 3.2"`. TruffleRuby is **not installed on the dev machine** — anything TruffleRuby-specific is
   verified in CI, never in a local hook.
2. **Rack + Falcon.** Async, fiber-based. No Puma-shaped assumptions anywhere.
3. **Sequel, never ActiveRecord.** Explicit queries, no lazy-loading magic.
4. **No SPA framework, ever.** Server-rendered HTML + htmx attributes, compiled from the DSL. Never
   introduce React, Vue, Ember, a bundler, or a client build step.
5. **Realtime is opt-in per screen.** Default is plain request/response. Nothing costs anything
   until a `live` or `channel` declaration asks for it.
6. **No offline support.** The server is the single source of truth. Say so in docs; never
   half-build it.
7. **No heavy client-side compute.** Canvas editors, games — out of scope. Refuse and say so.
8. **Multi-tenant by default.** Every model auto-scoped by `tenant_id`; UUIDv7 primary keys from day
   one.
9. **Stateless app servers.** No in-process session or UI state across requests.
10. **Money is integer cents.** A `:money` field type; floats refused **at the type level**, never
    by review. No `Float` anywhere near currency.
11. **Every opinionated default has a swap point** — DB, cache, jobs, search, realtime — switchable
    by config with no app code change, and the swap must be **proven by a test before merge**, never
    promised in prose.
12. **Domain modules enforce boundaries at boot.** Cross-domain direct model access fails the boot,
    not a review.
13. **SOLID, and SRP hardest** — for Magik's own internals *and* for the code Magik generates or
    asks a user's app to write. One class, one reason to change. Small objects with one job; no god
    objects, and no module that grows a new responsibility because it was convenient. New behaviour
    arrives as a **new registered object**, never as another branch in a growing `case`. Depend on
    the narrow role you actually use, not on the neighbouring module.
    → [`docs/architecture/00-conventions.md`](docs/architecture/00-conventions.md) for the full
    treatment.

**The app file tree is part of the product.** Separation of concerns is opinionated on purpose:
generated code goes where [`wiki/Project-Layout.md`](wiki/Project-Layout.md) says it goes, and
[`dummy/`](dummy/) — an invoicing/billing SaaS — is the demonstration. A generator that invents a
path is a bug.

The boot-time guardrails in the spec's "Guardrails to Enforce at Boot" section **are the product**.
When implementing a subsystem, the guardrail ships in the same change as the feature — not after.

## House rules

| Rule | Detail |
|---|---|
| **Minitest, never RSpec** | a spec decision, not a preference. There is no `spec/` directory; tests live in `test/` as `*_test.rb` and run under `rake test` |
| **Sequel, never ActiveRecord** | no `ApplicationRecord`, no `has_many` semantics borrowed from Rails. Wrap Sequel; do not hide it |
| **YARD on every public method** | `@param`, `@return`, `@raise` and at least one `@example` on anything a user calls. `rake yard` must be clean. A public method with no docs is an incomplete change |
| **`MAGIK_*` error codes** | `MAGIK_<SUBSYSTEM>_<CONDITION>`, `SCREAMING_SNAKE`, stable forever once shipped and never reused. Every one carries a concrete cause and a **runnable** `fix:` — a command, never advice |
| **Never claim unimplemented behaviour** | in code comments, docs, commit messages or a README. The vocabulary is `planned`, `not implemented`, `spec only`. Prefer a stub raising `NotImplementedError` with a clear message over a fake implementation |
| **One gem, subsystem modules** | `lib/magik/<subsystem>/`, mirroring the spec phases. Not a multi-gem monorepo. Later extraction stays possible — do not promise it in prose |
| **Date-stamp what can rot** | `As of 2026-08-26`, and pair it with the command that re-derives it |
| **No new dependency without a reason in the PR** | the spec's "libraries to wrap" list is the default answer; anything outside it needs an argument |

The error shape, which is the convention only — **no catalogue is implemented**:

```
MAGIK_LEDGER_UNBALANCED: ledger :Payouts does not balance
  cause: entry :capture debits 1200 and credits 1150
  fix:   magik check --ledger Payouts
```

### Subsystem module names — use these exact names

`core` `cli` `model` `schema` `render` `action` `router` `realtime` `jobs` `ledger` `api` `auth`
`billing` `admin` `i18n` `pwa` `notify` `testing` `domains` `check`

`schema` is migrations. `render` is component/screen/HTML+htmx. Do not invent a synonym for one of
these, and do not add a new subsystem without a spec section to point at.

## Where the DSL reference is

Magik's DSL — `model`, `screen`, `action`, `ledger`, `channel`, `flow` — is in no model's training
data, so **never write it from memory and never web-search for it.** Read it.

- **Working on Magik** (this repo): the reference is in-tree. `docs/` is the design and the spec,
  `wiki/` is the app-author manual. Grep and read them directly; they are always current here.
- **Working on an app built with Magik**: the reference ships inside the installed gem.
  `magik docs path` prints the directory — point your normal grep/glob/read at it. `magik docs list`
  is the catalogue, `magik docs <slug>` prints a page, `magik docs search <term>` finds one.
  An installed gem carries exactly the docs for its own version, so there is no drift between what
  you read and what you run. Design note: [`docs/architecture/09-shipped-docs.md`](docs/architecture/09-shipped-docs.md).

## Guesses this repo will punish

Hand-written, and the highest-value paragraphs in this file: the things you would otherwise get
wrong by reasonable inference. **Nothing is implemented** — `docs/idea/00-build-spec.md` reads
like documentation for a working framework and is a *plan*. Do not describe any of it in the
present tense, in code, in a comment, in a commit message or in a doc.

| You would guess | It is actually |
|---|---|
| `spec/` and RSpec, because it is Ruby | **Minitest** in `test/`, files named `*_test.rb`, run by `rake test`. There is no `spec/` and there never will be — it is a spec decision, not a preference |
| ActiveRecord, or an AR-shaped wrapper | **Sequel**, wrapped but never hidden. No `ApplicationRecord`, no implicit lazy loading, no `includes`-style magic |
| `bin/magik` is the binary | `exe/magik` is the binary. `bin/` holds developer scripts (`setup`, `check`, `dev`, `console`) and ships to nobody |
| a monorepo of gems, like the TypeScript sibling | **one gem**. Subsystems are modules under `lib/magik/<subsystem>/`. Do not add a second `.gemspec`. Extraction stays possible later; never promise it in prose |
| the version lives in the gemspec | `lib/magik/version.rb` is the only place a version is stated. The gemspec reads it |
| you can test TruffleRuby behaviour locally | you cannot — TruffleRuby is the production runtime and is **not installed** on the dev machine. CRuby ≥ 3.2 is what you have. TruffleRuby-only work is verified in CI, never in a local hook |
| a `Float` is fine for money in a test fixture | it is not, anywhere. Integer cents, always, including in fixtures and examples |
| an unimplemented method should return `nil` or an empty result | it should `raise NotImplementedError` with a message naming the phase that will implement it. A plausible-looking empty answer is the failure mode this whole repo is designed against |
| a new generator can pick its own file paths | the app layout is prescribed — [`wiki/Project-Layout.md`](wiki/Project-Layout.md), demonstrated by [`dummy/`](dummy/) |

Error codes are `MAGIK_<SUBSYSTEM>_<CONDITION>`. Every one carries a cause and a `fix:` that is a
command someone can run — advice in a `fix:` line is a defect, not a style difference.

## Commands

Run everything from the repository root.

| Task | Command |
|---|---|
| fresh clone to working | `bin/setup` — idempotent, safe after every pull |
| **the gate** | `bin/check` — what CI runs. Green means the tree is shippable |
| tests | `rake test` |
| one test file | `ruby -Ilib -Itest test/magik/version_test.rb` |
| lint | `rake rubocop` · fix: `bundle exec rubocop -A` |
| docs | `rake yard` · coverage: `rake docs:coverage` · published to <https://developerz-ai.github.io/magik/api/> |
| the default task | `rake` · the task list: `rake -T` |
| the CLI, from source | `ruby -Ilib exe/magik version --json` · `ruby -Ilib exe/magik help` |
| a console with the gem loaded | `bin/console` |
| the CLI against the demo app | `bin/dev` · [`dummy/`](dummy/) |
| services in containers | `docker/compose.yml` · [`.devcontainer/`](.devcontainer/) |
| release pre-flight (prints, never publishes) | `bin/release` · [`PUBLISHING.md`](PUBLISHING.md) |
| git hooks | [`lefthook.yml`](lefthook.yml) |

`bin/check` before you claim a change is done. Nothing else counts as done.

## The loop

1. **Find the spec section.** Every change traces to one section of
   [`docs/idea/00-build-spec.md`](docs/idea/00-build-spec.md). No section, no change — propose a
   spec amendment instead ([CONTRIBUTING.md](CONTRIBUTING.md)).
2. **Write the test first.** Minitest, in `test/` as `<subject>_test.rb`, red before green. Auto-generated and inferred
   tests are a phase-9 feature and are not an excuse to skip writing one now.
3. **Implement the smallest slice**, in the right `lib/magik/<subsystem>/` module.
4. **Ship the guardrail with the feature.** If the spec names a boot-time refusal for what you built,
   it lands in the same change, with its `MAGIK_*` code, cause and `fix:`.
5. **Document it.** YARD on every public method; a wiki or `docs/architecture/` page when the shape
   is new.
6. **Update [`CHANGELOG.md`](CHANGELOG.md)** under `## [Unreleased]`, and correct any status table —
   here, in [`README.md`](README.md), in [`ROADMAP.md`](ROADMAP.md) — that has just become wrong.
   A status row outliving its fact is the defect this file exists to prevent.
7. **`bin/check`.**

## The agents and commands in this repo

[`.claude/`](.claude/README.md) carries the workflow — use it rather than improvising:

| Where | What |
|---|---|
| [`.claude/agents/`](.claude/agents/) | `spec-implementer`, `dsl-designer`, `cli-author`, `guardrail-author`, `swap-point-prover`, `test-writer`, `docs-keeper`, `spec-auditor` |
| [`.claude/commands/`](.claude/commands/) | `/implement-phase`, `/next-task`, `/check`, `/new-dsl`, `/spec-audit`, `/dummy-app`, `/release` |

Read [`.claude/README.md`](.claude/README.md) for what each one is for and when to reach for it.
`/implement-phase` is the entry point for the work this repository exists to do.

## Layout

```
lib/magik/            the gem — one directory per subsystem, mirroring the spec phases
lib/magik/version.rb  the ONLY place a version is stated
exe/magik             the CLI entry point (bin/ is dev scripts, not the binary)
test/                 Minitest suites, run by `rake test`
docs/idea/            what and why — 00-build-spec.md is the source of truth
docs/architecture/    how each subsystem is built
docs/ops/             running an app for real
wiki/                 the reference manual
dummy/                the demo app — an invoicing/billing SaaS, and the layout reference
docker/               compose services for development
.claude/              agents and slash commands for working in this repo
.github/workflows/    ci.yml, release.yml, docs.yml
llms.txt              the machine-readable repo map
```

## Where to read next

| Need | Go |
|---|---|
| what Magik is, authoritatively | [`docs/idea/00-build-spec.md`](docs/idea/00-build-spec.md) |
| why AI-first shapes the design | [`docs/idea/07-ai-first.md`](docs/idea/07-ai-first.md) |
| the DSL surface, phase by phase | [`docs/idea/02-dsl-surface.md`](docs/idea/02-dsl-surface.md) |
| the boot-time guardrails | [`docs/idea/03-guardrails.md`](docs/idea/03-guardrails.md) |
| the swap points, and what proving one means | [`docs/idea/04-swap-points.md`](docs/idea/04-swap-points.md) |
| the limits — no offline, no heavy client compute | [`docs/idea/05-limits.md`](docs/idea/05-limits.md) |
| the phases | [`docs/idea/06-phases.md`](docs/idea/06-phases.md) |
| the rest of the rationale | [`docs/idea/`](docs/idea/) |
| how a subsystem is built | [`docs/architecture/`](docs/architecture/) |
| the coding contract, SOLID in full | [`docs/architecture/00-conventions.md`](docs/architecture/00-conventions.md) |
| where generated code goes in an app | [`wiki/Project-Layout.md`](wiki/Project-Layout.md) · [`dummy/`](dummy/) |
| running an app in production | [`docs/ops/README.md`](docs/ops/README.md) |
| the reference manual | [`wiki/Home.md`](wiki/Home.md) |
| what is planned, in order | [`ROADMAP.md`](ROADMAP.md) |
| conventions an agent cannot infer | [above, in this file](#guesses-this-repo-will-punish) |
| contributing, and changing the spec | [`CONTRIBUTING.md`](CONTRIBUTING.md) |
| cutting a release | [`PUBLISHING.md`](PUBLISHING.md) |
| the whole repo as one link map | [`llms.txt`](llms.txt) |

## Note

Do not use git worktrees — work directly in this checkout. If a task needs subagents, run them as a
team in this same checkout and split the work so no two agents touch the same files. Only the
top-level agent spawns subagents; a subagent that finds its scope too large says so and returns.
