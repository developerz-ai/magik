# Module map

Twenty subsystems under `lib/magik/`, one reason to change each, mapped to the spec phase they serve.

**Status:** not implemented. `lib/` currently contains `magik/version.rb` only. Every subsystem below is a planned directory with a planned public surface. Reviewed 2026-08-26.

## The shape

**One gem.** `magik` ships every subsystem; they are directories, not gems. Extraction stays possible later and is not promised.

```
lib/magik.rb
lib/magik/<subsystem>.rb            # front door — the only file another subsystem may require
lib/magik/<subsystem>/…             # one responsibility per file
lib/magik/<subsystem>/errors.rb     # this subsystem's MAGIK_* codes
lib/magik/<subsystem>/backends/…    # only where the subsystem owns a swap point
```

If two things in a subsystem change for different reasons, they are two objects inside it — not two subsystems. Adding a subsystem is an architecture change: it needs a tier, a public surface, and a row here.

## Tiers

A subsystem may require **strictly lower** tiers only. Never sideways, never upward. The full rule and its enforcement: [`02-boundaries.md`](02-boundaries.md).

```
tier 0   core
tier 1   schema, router, i18n
tier 2   model, render, realtime, jobs
tier 3   action, ledger, api, auth, notify, pwa
tier 4   billing, admin, domains
tier 5   check, testing
tier 6   cli
```

There is no exceptions column, on purpose. The first sideways exception is a signal that a tier is wrong; argue the tier instead.

## Every subsystem

| Subsystem | Tier | Phase | Responsibility (one line) | Intended public surface | Must never | Status |
|---|---|---|---|---|---|---|
| `core` | 0 | 1 | errors, config, the declaration registry, the boot pipeline, the value types | `Magik::Error`, `Magik.config`, `Magik::Registry`, `Magik::Money`, `Magik::Uuid7`, `Magik::Timestamp`, the guardrail runner and rule interface | require any other subsystem; know what a screen or a job is | not implemented |
| `schema` | 1 | 1 | the `migrate` DSL over Sequel migrations, column type mapping, drift detection | `migrate`, `Magik::Schema.apply`, `Magik::Schema.drift` | contain business logic; know about models' associations | not implemented |
| `router` | 1 | 2 | the path grammar and the route table — name → path, both directions | `Magik::Router.path_for`, `Magik::Router.resolve`, `Magik::Router.table` | know concretely about `action` or `screen`; render anything | not implemented |
| `i18n` | 1 | 8 | catalogs, locale negotiation, `t()`, loud misses | `t`, `locales`, `Magik::I18n.catalog` | read a request; format money or timestamps itself | not implemented |
| `model` | 2 | 1 | the `model` DSL over Sequel — fields, associations, validations, scopes, tenancy, audit annotations | `model`, `Magik::Model::Definition`, `audited`, `immutable_after` | render; authorize; reach another domain's models | not implemented |
| `render` | 2 | 2 | the `component`/`screen` DSL and the HTML + `hx-*` compiler, the component kit, the theme system, the override registry | `component`, `screen`, `Magik::Kit::*`, `Magik::Render.compile` | hold state across requests; import `realtime` (it needs a channel *name*, which lives in `core`) | not implemented |
| `realtime` | 2 | 3 | `channel`/`broadcast`/`presence` and the pub-sub transport | `channel`, `broadcast`, `presence`, `backends/postgres.rb`, `backends/redis.rb` | authorize on its own; open a socket nobody declared | not implemented |
| `jobs` | 2 | 4 | the `job` DSL, the durable queue, retries, the scheduler, the worker loop | `job`, `Magik::Jobs.enqueue`, `Magik::Jobs::Worker`, `backends/postgres.rb` | serve HTTP; assume exactly-once delivery | not implemented |
| `action` | 3 | 2 | the `action` DSL, params coercion, the mutation lifecycle, `redraw`/`toast`/`redirect`, `idempotent_by` | `action`, `Magik::Action.perform`, `redraw`, `toast` | hold instance state; assemble HTML by hand; run slow work inline | not implemented |
| `ledger` | 3 | 5 | the `ledger` DSL, double-entry posting, balance analysis, append-only enforcement | `ledger`, `Magik::Ledger.post`, `Magik::Ledger.balance` | accept a float; update or delete a posted entry | not implemented |
| `api` | 3 | 6 | the `api` DSL, REST resources, pagination/filter/sort, `webhook` in both directions, API auth and rate limiting | `api`, `webhook`, `Magik::Api::Resource` | render screens; bypass model validations | not implemented |
| `auth` | 3 | 7 | the `auth` DSL over Rodauth — accounts, sessions, OAuth, 2FA, and the actor a request resolves to | `auth`, `Magik::Auth.actor`, `Magik::Auth::Account` | decide authorization for a *resource* — it identifies | not implemented |
| `notify` | 3 | 8 | the `notification` DSL and delivery across email, in-app and push | `notification`, `notify`, `Magik::Notify::Channel` | deliver inline — delivery goes through `jobs` | not implemented |
| `pwa` | 3 | 8 | the `pwa` DSL, the manifest, icons, install metadata | `pwa`, `Magik::Pwa.manifest` | emit a service worker that caches application data ([`../idea/05-limits.md`](../idea/05-limits.md)) | not implemented |
| `billing` | 4 | 7 | the `billing` DSL — plans, trials, subscriptions, metered usage, provider webhooks | `billing`, `Magik::Billing.subscribe`, `backends/stripe.rb` | own money arithmetic — that is `core`'s `Money` and `ledger` | not implemented |
| `admin` | 4 | 7 | the `admin_panel` DSL and the generated CRUD admin | `admin_panel`, `Magik::Admin.mount` | be a second app with its own auth or rendering path | not implemented |
| `domains` | 4 | 12 | the `domain` DSL, the dependency graph, and boot-time boundary enforcement | `domain`, `Magik::Domains.graph`, `Magik::Domains.enforce!` | be optional — an app with no domains has one implicit domain | not implemented |
| `check` | 5 | 12 | the static rule set behind `magik check`, `--scale` heuristics, finding formatting, `--json` | `Magik::Check.run`, `Magik::Check::Finding` | duplicate a boot guardrail — it runs the same rule objects without a server | not implemented |
| `testing` | 5 | 9 | the `test` DSL over Minitest, factories, helpers, the parallel runner, transactional isolation | `test`, `Magik::TestCase`, `perform_action`, `render_screen`, `assert_enqueued` | be required from `lib/` production code paths | not implemented |
| `cli` | 6 | 1 | `exe/magik` — the command surface, generators, the dev server, `magik worker`, `magik console` | `Magik::Cli.start`, the command classes | contain framework logic — it composes subsystems and prints | not implemented |

## Where the guardrails live

A deliberate split, because the naive design puts `core` above `check` and inverts the whole tier table:

| Piece | Lives in | Why |
|---|---|---|
| The rule interface and the boot runner | `core` | boot must run rules without knowing which subsystems exist |
| Each boot rule | the subsystem that owns the concept — the balance rule in `ledger`, the PAN-field rule in `model`, the boundary rule in `domains` | one reason to change, and the rule ships with the construct it guards |
| The static rule set, `--scale`, finding formatting, `--json` | `check` | it needs to see everything, so it sits near the top |

This is why `core` never requires `check`, and why "a phase is not done without its guardrails" ([`../idea/06-phases.md`](../idea/06-phases.md)) is a statement about the *subsystem's own* directory.

## Where the swap points live

Each seam is owned by exactly one subsystem, and every backend lives under that subsystem's `backends/`:

| Seam | Owner | Directory |
|---|---|---|
| Database | `core` (connection) + `model`/`schema` (dialect) | `lib/magik/core/backends/` |
| Cache | `core` | `lib/magik/core/backends/` |
| Jobs | `jobs` | `lib/magik/jobs/backends/` |
| Realtime | `realtime` | `lib/magik/realtime/backends/` |
| Search | `model` | `lib/magik/model/backends/` |
| Storage | `model` (uploads via Shrine) | `lib/magik/model/backends/` |
| Billing provider | `billing` | `lib/magik/billing/backends/` |
| Component kit | `render` | `lib/magik/render/kit/` + the override registry ([`../idea/08-component-overrides.md`](../idea/08-component-overrides.md)) |

Rules for adding one: [`../idea/04-swap-points.md`](../idea/04-swap-points.md).
