# CLAUDE.md

Read this contract before editing. Trace every change to the spec; write the failing test first;
ship the guardrail with the feature; run `bin/check` before claiming done. Never invent DSL or claim planned behaviour works.

## What this repo is, today

**Magik** — an AI-first, full-stack Ruby framework planned for TruffleRuby: one DSL for models,
screens, actions, realtime, jobs, ledgers, APIs and admin; server-rendered HTML + htmx, no frontend framework.
Sibling: [Ultimate](https://github.com/developerz-ai/ultimate), the TypeScript-on-Bun counterpart.
Gem `magik` · module `Magik` · binary `magik` · GitHub `developerz-ai/magik` · MIT.

**The framework is not implemented.** `As of 2026-08-26`: spec, docs, gem skeleton, CI and release plumbing;
`0.0.1` reserves the RubyGems name ([CHANGELOG.md](CHANGELOG.md)). Only this plumbing may be described as implemented:
- Zero runtime dependencies; standard library only. Planned libraries remain comments in [`magik.gemspec`](magik.gemspec) until their phase needs them.
- `lib/magik.rb`: plain `autoload` over `Magik::SUBSYSTEMS`.
- `Magik::Error`: tested stable `MAGIK_*` code, cause, runnable `fix:` and `to_h` for `--json`; no error catalogue yet.
- `magik version`, `magik help`, `magik docs`, all with `--json`; help labels commands `ready` or `planned`; docs serves packaged documentation.
- 20 spec-only subsystem stubs: `SPEC_PHASE`, `DSL_SURFACE`, `STATUS`, and `.define` raising `NotImplementedError`.
- Minitest suite runnable on bare Ruby without a bundle: `rake test`.

No `App.define`, `model`, `screen`, `action`, `policy`, `layout`, router, server or database code exists.
The usual work is implementing a phase of [`docs/idea/00-build-spec.md`](docs/idea/00-build-spec.md), starting with Phase 1.

## Read these first, in this order

| Order | Read | Rule |
|---|---|---|
| 1 | [`docs/idea/00-build-spec.md`](docs/idea/00-build-spec.md) | Source of truth; no traceable section, no change. |
| 2 | [`docs/idea/07-ai-first.md`](docs/idea/07-ai-first.md) | Rationale for guardrails, uniform grammar and `fix:` lines. |
| 3 | [Guesses this repo will punish](#guesses-this-repo-will-punish) | Avoid plausible but wrong inferences. |
| 4 | [`.claude/README.md`](.claude/README.md) | Use the shipped agents and workflows. |
| 5 | [`docs/architecture/`](docs/architecture/) | Subsystem implementation designs. |
| 6 | [`ROADMAP.md`](ROADMAP.md) | Delivery order and phase exit criteria. |

Then run `bin/setup` and `bin/check` before editing to establish the baseline.

## Status, with one runnable check per row

**Run checks; do not quote stale status.** Date claims (`As of 2026-08-26`) and pair them with a re-deriving command.
The framework remains spec only; the commands below inspect plumbing, not proof of planned features.

| Inspect | Check |
|---|---|
| Stamped version | `ruby -Ilib -e 'require "magik/version"; puts Magik::VERSION'` |
| RubyGems release | `gem list -r magik --all` · `gem info magik -r` |
| CLI / tests / tasks / docs / lint / gate | Exact commands in [Commands](#commands); never claim a check you did not complete. |
| Remaining stubs | `grep -rln NotImplementedError lib/magik` — placeholders, not features. |
| CI | [`.github/workflows/ci.yml`](.github/workflows/ci.yml) |

`rake test` needs no bundle; RuboCop and YARD are development dependencies. Run `bin/setup` first;
missing tools abort with an install hint, not a vacuous pass. Nothing here has been benchmarked,
deployed or run against a real database. Add no number without a command that re-derives it.

## Non-negotiables (from the spec — these override any instinct)

| Area | Required rule |
|---|---|
| Runtime | **TruffleRuby production; CRuby ≥ 3.2 for development tooling only**, never production; `required_ruby_version` is `">= 3.2"`. Real parallel OS threads, no GVL, one concurrency model, no fallback or per-engine branch. No `fork` or forked workers. Evidence: `ruby scripts/probes/runtime.rb`; [runtime verification](docs/architecture/12-runtime-verification.md). |
| Server | **Rack + Puma, single mode**: one process, one thread pool; scale with containers. No async/fiber-scheduler server: TruffleRuby has no fiber scheduler and `async` raises on its first block. Reopening condition: [runtime verification](docs/architecture/12-runtime-verification.md). |
| Database | **Sequel, never ActiveRecord**. Explicit queries, no implicit lazy loading; wrap Sequel, never hide it. No `ApplicationRecord`, Rails `has_many` semantics or `includes`-style magic. |
| UI | Server-rendered HTML + htmx attributes compiled from DSL. **No SPA**, React, Vue, Ember, bundler or client build step. |
| Realtime | **Opt-in per screen** via `live` or `channel`; default plain request/response, no cost until declared. |
| Permanent limits | **No offline support**: server is the single source of truth; state this in docs, never half-build it. **No heavy client compute** (canvas editors, games): refuse and say out of scope. |
| Data | Every model auto-scoped by `tenant_id`; **UUIDv7** primary keys from day one. Stateless app servers: no in-process session/UI state across requests. |
| Money | Integer cents via `:money`; refuse floats **at the type level**, including fixtures and examples. No `Float` near currency. |
| Swap points | Every opinionated default — DB, cache, jobs, search, realtime — config-switchable without app code changes; **prove each swap by test before merge**, not prose. |
| Domains | Cross-domain direct model access **fails boot**, not review. |
| Authorization | Exactly one evaluator. Every model-reaching `screen`, `action`, `api resource`, `channel`, `job`, `admin_panel` names a verb in a `policy`; no second door or per-surface check. Evaluator at **tier 1**, below `render`/`realtime` (tier 2), which must call it; imports strictly down. Opaque actor supplied by `auth` at tier 3, which never decides. **Not a swap point**; pure predicates, no queries or I/O. `policy` lands in phase 2, not phase 7. |
| SOLID / SRP | Applies to internals, generated code and app code we ask users to write. One class, one reason to change; small single-job objects, no god objects or convenience responsibilities. New behaviour is a **new registered object**, not another branch in a growing `case`; depend on the narrow role used. [Full conventions](docs/architecture/00-conventions.md). |
| App layout | Generated paths follow [`wiki/Project-Layout.md`](wiki/Project-Layout.md), demonstrated by [`dummy/`](dummy/), the invoicing/billing SaaS. Inventing a path is a generator bug. |
| Guardrails | The spec's “Guardrails to Enforce at Boot” **are the product**; ship each boot-time refusal in the same change as its feature. |

## Who decides

**Decide and record spec-framed, reversible design questions; do not queue them for a human.**
Owner supplies direction; agent exercises judgement only while the spec frames it, `bin/check` catches
mistakes (seven steps, four engines in CI), and nothing shipped makes reversal costly.
*If being wrong costs an edit, decide it. If being wrong costs a release, bring it back.*

**Always reserved to the owner:** publishing gems, tags or other outward-facing immutable actions;
spending money or committing in the owner's name; changing mission, permanent limits or audiences;
unframed invention outside the spec; destructive operations on anything not reconstructible from this repository.
Record each non-obvious decision in [`docs/idea/13-decisions.md`](docs/idea/13-decisions.md):
**decision, alternative, reason grounded in an existing constraint, and what would reopen it**.

## House rules

| Rule | Requirement |
|---|---|
| Tests | **Minitest, never RSpec**; `test/*_test.rb`, no `spec/` now or later. Red before green. |
| Public API | YARD: `@param`, `@return`, `@raise`, at least one `@example`; `rake yard` clean. Undocumented public methods are incomplete. |
| Errors | `MAGIK_<SUBSYSTEM>_<CONDITION>`, `SCREAMING_SNAKE`; stable forever once shipped, never reused. Concrete cause and runnable `fix:` command, never advice. |
| Honest status | Comments, docs, README and commit messages must say `planned`, `not implemented` or `spec only` for unbuilt behaviour. Stubs raise `NotImplementedError`, naming the implementing phase; never plausible `nil`/empty results. |
| Packaging | One gem, `lib/magik/<subsystem>/` mirroring phases; no second `.gemspec` or multi-gem monorepo. Keep extraction possible, never promise it. |
| Dependencies | Explain each new dependency in the PR; spec's “libraries to wrap” list is the default, deviations need an argument. |

Error shape is convention only, **not an implemented catalogue**:
```
MAGIK_LEDGER_UNBALANCED: ledger :Payouts does not balance
  cause: entry :capture debits 1200 and credits 1150
  fix:   magik check --ledger Payouts
```

### Subsystem module names — use these exact names

`core` `cli` `model` `schema` `render` `action` `router` `policy` `realtime` `jobs` `ledger` `api`
`auth` `billing` `admin` `i18n` `pwa` `notify` `testing` `domains` `check`
`schema` means migrations; `render` means component/screen/HTML+htmx. No synonyms or new subsystem without a spec section.

## Where the DSL reference is

**Read DSL, never recall it from training data or web-search for it** (`model`, `screen`, `action`, `policy`, `layout`, `ledger`, `channel`, `flow`).
In this repo, grep/read `docs/` (design/spec) and `wiki/` (app-author manual).
In an app, use the installed gem's version-matched docs: `magik docs path` gives the directory,
`magik docs list` the catalogue, `magik docs <slug>` a page, `magik docs search <term>` a search.
Design: [`docs/architecture/09-shipped-docs.md`](docs/architecture/09-shipped-docs.md).

## Guesses this repo will punish

**The build spec is a plan, not working-framework documentation.** Apply the stack and house rules above; also:

| Plausible guess | Required correction |
|---|---|
| `bin/magik` is the binary | `exe/magik`; `bin/` contains developer scripts (`setup`, `check`, `dev`, `console`) and does not ship. |
| Version lives in gemspec | Only `lib/magik/version.rb` states it; gemspec reads it. |
| Local CRuby proves TruffleRuby | No. Dev-machine contract is CRuby ≥ 3.2, not an installed TruffleRuby; verify TruffleRuby-only work in CI, never a local hook. |
| Readable DSL is designed DSL | Parse extracted ` ```ruby ` blocks with `ruby -c`. `retry` is a keyword: use `retries times: 5, backoff: :exponential`. Brace binding requires `computed(:name, :type) { … }`, not `computed :name, :type { … }`. |
| Authorization can wait for `auth` | Phase-2 `policy`, tier-1 evaluator; see [Non-negotiables](#non-negotiables-from-the-spec--these-override-any-instinct). Do not retrofit `policy:` after six surfaces exist. |
| A screen is a whole page | Planned phase-2 `layout` is the shell. `magik new` must generate working `:App` with sidebar on first run; screen without layout or explicit `layout: :None` must fail boot. |
| Generators choose paths | Follow [`wiki/Project-Layout.md`](wiki/Project-Layout.md) and [`dummy/`](dummy/). |

## Commands

Run from the repository root. `bin/check` is the gate before claiming done; never claim unrun lint/docs coverage.

| Task | Exact command / reference |
|---|---|
| Setup | `bin/setup` — idempotent, safe after every pull. |
| Full gate / one step / data | `bin/check` · `bin/check --only test` · `bin/check --json` |
| Tests / one test file | `rake test` · `ruby -Ilib -Itest test/magik/version_test.rb` |
| Lint / autofix | `rake rubocop` · `bundle exec rubocop -A` |
| Documentation / coverage | `rake yard` · `rake docs:coverage` · <https://developerz-ai.github.io/magik/api/> |
| Default / task list | `rake` · `rake -T` (`build`, `check`, `docs:coverage`, `rubocop`, `test`, `yard`). |
| CLI from source | `ruby -Ilib exe/magik version --json` · `ruby -Ilib exe/magik help` |
| Console / demo CLI | `bin/console` · `bin/dev` · [`dummy/`](dummy/) |
| Container services | `docker/compose.yml` · [`.devcontainer/`](.devcontainer/) |
| Release pre-flight (prints, never publishes) | `bin/release` · [`PUBLISHING.md`](PUBLISHING.md) |
| Hooks | [`lefthook.yml`](lefthook.yml) |

## The loop

1. Find the spec section in [`docs/idea/00-build-spec.md`](docs/idea/00-build-spec.md); otherwise propose an amendment ([CONTRIBUTING.md](CONTRIBUTING.md)).
2. Write failing Minitest in `test/` as `<subject>_test.rb`. Phase-9 generated/inferred tests are no excuse to skip today's test.
3. Implement the smallest slice in `lib/magik/<subsystem>/`; ship its boot guardrail, `MAGIK_*` code, cause and runnable `fix:` together.
4. Document public API with YARD; add wiki or `docs/architecture/` documentation for a new shape.
5. Update [`CHANGELOG.md`](CHANGELOG.md) under `## [Unreleased]`; correct newly stale status here, in [`README.md`](README.md) and [`ROADMAP.md`](ROADMAP.md).
6. Run `bin/check`.

## The agents and commands in this repo

Use [`.claude/README.md`](.claude/README.md), not an improvised workflow; `/implement-phase` is the entry point.
[Agents](.claude/agents/): `spec-implementer`, `dsl-designer`, `cli-author`, `guardrail-author`, `swap-point-prover`, `test-writer`, `docs-keeper`, `spec-auditor`.
[Commands](.claude/commands/): `/implement-phase`, `/next-task`, `/check`, `/new-dsl`, `/spec-audit`, `/dummy-app`, `/release`.

## Layout

| Path | Purpose |
|---|---|
| `lib/magik/` · `lib/magik/version.rb` · `exe/magik` · `test/` | Subsystem gem code · sole version · CLI entry point · Minitest. |
| `docs/idea/` · `docs/architecture/` · `docs/ops/` · `wiki/` | What/why (build spec authoritative) · how · running apps · reference manual. |
| `dummy/` · `docker/` · `.claude/` | Invoicing/billing SaaS and app-layout reference · dev compose services · agents/commands. |
| `.github/workflows/` · `llms.txt` | `ci.yml`, `release.yml`, `docs.yml` · machine-readable repo map. |

## Where to read next

Rationale: [`docs/idea/`](docs/idea/), especially [DSL surface](docs/idea/02-dsl-surface.md),
[boot guardrails](docs/idea/03-guardrails.md), [swap points](docs/idea/04-swap-points.md),
[permanent limits](docs/idea/05-limits.md), [phases](docs/idea/06-phases.md).
Implementation: [SOLID/conventions](docs/architecture/00-conventions.md), [production ops](docs/ops/README.md).
Navigation: [manual](wiki/Home.md), [roadmap](ROADMAP.md), [contributing](CONTRIBUTING.md),
[release](PUBLISHING.md), [repo link map](llms.txt); decisions and ordered reading are linked above.

## Note

No git worktrees: work in this checkout. Teams share it with disjoint file ownership; only the top-level
agent spawns subagents. A subagent whose scope is too large reports that and returns, never delegates.
