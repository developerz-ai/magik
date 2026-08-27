# Magik roadmap

**Status today: nothing is built.** `magik 0.0.1` on RubyGems is a **name reservation** — it claims
the gem name, ships a version constant, an error-code convention, a `magik version` / `magik help`
shim, and one documented stub per planned subsystem. It renders no page, opens no database
connection, and runs no job. Every phase below is **planned**. `As of 2026-08-26`.

Resolve the status rather than trusting this sentence:

```bash
gem list magik --remote --all                              # what RubyGems serves
ruby -Ilib -e 'require "magik"; puts Magik::VERSION'       # what this checkout is stamped at
magik help                                                 # the commands that actually run
```

The product specification is [`docs/idea/00-build-spec.md`](docs/idea/00-build-spec.md). This file
does not restate it — it orders it, and says what "done" means for each piece.

## How it gets built

**The delivery model is agent-driven, and that is a design decision rather than a convenience.**
Magik is an AI-first repo: the primary developer is an AI agent, and the framework's shape — one
uniform DSL grammar, boot-time guardrails, errors carrying a runnable `fix:` — exists partly because
those are the properties that make a codebase an agent can work on correctly. The reasoning is
[`docs/idea/07-ai-first.md`](docs/idea/07-ai-first.md).

Concretely: a phase is landed by an agent running `/implement-phase` against
[`docs/idea/06-phases.md`](docs/idea/06-phases.md), and it is gated by `bin/check`. The agent
workbench — subagent definitions and slash commands — is committed to the tree at
[`.claude/`](.claude/README.md) rather than living in someone's local config, so a fresh session
opening this repository finds it in one hop.

```bash
bin/check        # the gate a phase has to pass. Lint, tests, doc checks
rake -T          # every task this checkout defines
```

## The one-line summary

Nine spec phases, delivered in a twelve-step build order that is **not** the same sequence: testing
(spec Phase 9) is built fifth so everything after it is TDD'd, and the API phase (6) lands after the
auth/billing/admin phase (7) because the admin panel is the first real consumer of the resource DSL.

## Version milestones

**Intent, not a schedule.** No dates are given, because a date on unstarted work is a guess dressed
up as a commitment. The mapping below is the contract: a minor version means the phases named in its
row are complete under their own "done" definition, and the ones below it are not.

| Version | Carries | Done when |
|---|---|---|
| `0.0.1` | **shipped** — name reservation only | the gem name resolves and `magik version` prints it |
| `0.1.0` | Phase 1 — foundation | build steps 1–2 |
| `0.2.0` | Phase 2 — rendering and actions | build steps 3–4 |
| `0.3.0` | Phase 9 — testing, pulled forward | build step 5 |
| `0.4.0` | Phase 3 — realtime | build step 6 |
| `0.5.0` | Phase 4 — jobs | build step 7 |
| `0.6.0` | Phase 5 — money and compliance | build step 8 |
| `0.7.0` | Phase 7 — auth, billing, admin | build step 9 |
| `0.8.0` | Phase 6 — API and webhooks | build step 10 |
| `0.9.0` | Phase 8 — i18n, PWA, notifications | build step 11 |
| `0.10.0` | Phase 12 — domains and `magik check` | build step 12 |
| `1.0.0` | all nine phases, plus every swap point proven by a passing test | see [1.0 means](#what-10-means) |

While the major version is `0`, **minor bumps may break the public API**. That is the point of a `0.x`
line: the DSL is being discovered, and freezing it early would be the worse mistake.

## Phases

Each phase is done when **every** row of its exit criteria is true, and each criterion is a thing a
test can assert. "Documented" is never an exit criterion on its own; an enforced convention is.

### Phase 1 — Foundation → `0.1.0`

`App.define :Name`, `model :Name` over Sequel, `migrate :Name`, the `:money` type, UUIDv7 primary
keys, `tenant_id` auto-injection, and the `new` / `generate` / `console` / `server` commands.

**Done when:** `magik new myapp && cd myapp && bin/setup && magik console` opens a REPL with a
generated model loaded; a `model` declaration produces a Sequel dataset scoped by `tenant_id` without
the app writing the predicate; a migration round-trips `up` and `down`; a `:money` field refuses a
`Float` at assignment, not at save.

### Phase 2 — Rendering and actions → `0.2.0`

`component`, `screen`, `action`, the component kit (`button, form, field, data_table, modal, toast,
card, list, grid, tabs, stat, chart`), the theme system, the router, the dev server and reload.

**Done when:** a screen plus an action plus a model is a working CRUD page in **under 30 lines with
no HTML, CSS or JavaScript written by the app**; the emitted markup carries the htmx attributes that
wire the form to the action with no route declared by hand; the dev server reloads a changed screen
without a restart; light and dark both render from one token set.

### Phase 3 — Testing, pulled forward → `0.3.0`

Spec Phase 9, built fifth. The `test :Name` DSL over Minitest, inferred factories, the helpers
(`perform_action`, `render_screen`, `concurrently`, `travel_to`, `assert_enqueued`,
`assert_broadcast`, `assert_notified`), and the parallel runner.

**Why here:** every later phase is meant to be test-driven. Building the harness after the features
it is supposed to have driven is how a framework ends up with a test suite that documents its bugs.

**Done when:** `magik test` runs the framework's own suite through the DSL; `--watch` and `--changed`
both work; a test rolls back in a transaction rather than truncating; `workers: :auto` uses every
core. The spec's *target* is 1,000 tests in under 10s — a target, and it stays a target until a
committed benchmark result says otherwise.

### Phase 4 — Realtime → `0.4.0`

`live`, `channel`, `broadcast`, `presence`. Postgres `LISTEN`/`NOTIFY` by default, Redis pub/sub by
config.

**Done when:** a screen with no `live` declaration opens **no socket and costs nothing** — that is
the opt-in claim and it needs a test, not a paragraph; a `broadcast` reaches a subscribed screen;
flipping the backend to Redis changes one config key and zero lines of app code.

### Phase 5 — Jobs → `0.5.0`

`job :Name`, `retry`, `schedule :cron` / `:every`, the Postgres-backed transactional queue, the
`magik worker` process.

**Done when:** enqueue and the row that caused it commit or roll back **together**; a worker killed
mid-job retries it; two workers never claim one job; the queue backend is swappable.

### Phase 6 — Money and compliance → `0.6.0`

`ledger :Name`, `audited`, `immutable_after:`, `idempotent_by`, `flow :Name`.

**Done when:** a ledger whose debits and credits disagree **fails at boot**, with a
`MAGIK_LEDGER_UNBALANCED` naming the account; a ledger entry cannot be updated or deleted through the
DSL; a replayed action with the same `idempotent_by` key performs its effect once; `field
:card_number` is refused at boot.

### Phase 7 — Auth, billing, admin → `0.7.0`

`auth do … end` over Rodauth, `billing provider: :stripe`, `admin_panel :Model`, `tenant_by
:subdomain`.

**Done when:** a generated app has working registration, login, OAuth and 2FA without writing a
controller; a subscription lifecycle survives Stripe's webhooks arriving out of order; the admin
panel is generated from the model declarations rather than scaffolded into editable files.

### Phase 8 — API and webhooks → `0.8.0`

`api :V1 do resource … end`, incoming and outgoing `webhook`, `:bearer` / `:api_key` / `:jwt`,
plan-based rate limits.

**Done when:** a `resource` paginates, filters and sorts with no hand-written query; an incoming
webhook with a bad signature is rejected before the handler runs; an outgoing webhook retries and its
deliveries are inspectable.

### Phase 9 — i18n, PWA, notifications → `0.9.0`

`locales`, `translatable: true`, the timezone-safe `:timestamp`, `pwa do … end`, `notification :name`.

**Done when:** rendering a `:timestamp` without an explicit zone is a **build error**, not a warning;
a missing translation is loud in development; the PWA is installable and ships **no offline cache**
— that is a deliberate limit, see [Limits](#limits-that-do-not-move).

### Phase 10 — Domains and `magik check` → `0.10.0`

`domains/<name>/domain.rb` with `depends_on` / `exposes` / `publishes_events`, boot-time enforcement,
and the `magik check` linter including `--scale`.

**Done when:** a cross-domain direct model access **fails at boot** naming both domains and the
offending constant; `magik check --scale` reports a query missing `tenant_id` in its `WHERE` clause;
`magik check --json` is stable enough for CI to gate on.

## What 1.0 means

`1.0.0` is not "all the phases are green". It is all the phases green **plus** the three claims the
spec makes about itself, each backed by something executable:

| Claim | The proof it needs |
|---|---|
| Every opinionated default has a working swap | a passing test per seam — DB engine, cache, jobs, search, realtime — run against both sides. Proven before merge, never promised in a doc |
| A CRUD screen is under 30 lines with no HTML/JS/CSS | a committed example whose line count is asserted by a test, not counted by hand |
| Fintech-grade money is the same grammar as everything else | no `fintech: true` mode exists anywhere in the codebase, and a grep for one is part of the gate |
| **A generated app is safe and usable on its first run** | three tests, not a document: a cross-tenant actor is denied by **every** generated surface — screen, action, API resource, channel and admin panel; the generated application shell renders correctly at 375px; the generated signup form throttles and does not reveal whether an account exists. Added by the coverage audit ([`docs/idea/10-saas-coverage.md`](docs/idea/10-saas-coverage.md)), because the three claims above can all be true of an application that is insecure and unusable |

Until all three are true, the version stays below `1.0.0` however complete the feature list looks.

## Limits that do not move

These are not gaps and no version closes them. They are in the spec as permanent exclusions, and the
docs are required to refuse rather than fail quietly:

- **No offline support.** The server is the single source of truth. A PWA ships; an offline cache
  does not.
- **No heavy client-side compute.** Canvas editors, games, in-browser video editing — out of scope.
- **No SPA framework, ever.** Server-rendered HTML plus htmx. Not React, not Vue, not a "just for
  this one screen" escape hatch.

## Where to read more

| Want | Read |
|---|---|
| The spec itself | [`docs/idea/00-build-spec.md`](docs/idea/00-build-spec.md) |
| Why each decision | [`docs/idea/01-thesis.md`](docs/idea/01-thesis.md) |
| The DSL surface | [`docs/idea/02-dsl-surface.md`](docs/idea/02-dsl-surface.md) |
| What is enforced at boot | [`docs/idea/03-guardrails.md`](docs/idea/03-guardrails.md) |
| The swap points | [`docs/idea/04-swap-points.md`](docs/idea/04-swap-points.md) |
| The limits, in full | [`docs/idea/05-limits.md`](docs/idea/05-limits.md) |
| Whether the 99% claim holds | [`docs/idea/10-saas-coverage.md`](docs/idea/10-saas-coverage.md) — the honest answer is "not as stated" |
| The phase detail | [`docs/idea/06-phases.md`](docs/idea/06-phases.md) |
| The AI-first thesis | [`docs/idea/07-ai-first.md`](docs/idea/07-ai-first.md) |
| The agent workbench | [`.claude/README.md`](.claude/README.md) |
| The reference manual | [`wiki/Home.md`](wiki/Home.md) |
| What is broken right now | [`wiki/Known-Gaps.md`](wiki/Known-Gaps.md) — the answer is "all of it", stated properly |
