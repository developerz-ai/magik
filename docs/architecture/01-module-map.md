# Module map

Twenty-one subsystems under `lib/magik/`, one reason to change each, mapped to the spec phase they serve.

**Status:** not implemented. Every subsystem below is a spec-only stub — a front-door file exposing `SPEC_PHASE`, `DSL_SURFACE` and `STATUS`, whose `.define` raises `NotImplementedError` — in front of a planned directory and a planned public surface. Re-derive the list with `ruby -Ilib -e 'require "magik"; puts Magik::SUBSYSTEMS.keys.join(" ")'` and the stub list with `grep -rln NotImplementedError lib/magik`. Reviewed 2026-08-26.

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
tier 1   schema, router, i18n, policy
tier 2   model, render, realtime, jobs
tier 3   action, ledger, api, auth, notify, pwa
tier 4   billing, admin, domains
tier 5   check, testing
tier 6   cli
```

There is no exceptions column, on purpose. The first sideways exception is a signal that a tier is wrong; argue the tier instead.

The executable copy of this table is [`../../scripts/lib/tiers.rb`](../../scripts/lib/tiers.rb), and [`../../scripts/checks/boundaries.rb`](../../scripts/checks/boundaries.rb) re-parses this page and [`02-boundaries.md`](02-boundaries.md) against it on every run. When prose and code diverge, the code is right and the prose is the bug.

### Why `policy` is tier 1

The tier is load-bearing rather than incidental, and the spec argues it explicitly ([`../idea/00-build-spec.md`](../idea/00-build-spec.md), decision 13 and Phase 2):

| | |
|---|---|
| `render` and `realtime` are tier 2 and both must evaluate policies | imports go strictly down, so an evaluator sitting beside `auth` at tier 3 would be **unreachable from the two surfaces that need it most** |
| `policy` therefore takes the actor as an **opaque value** | exactly as `router` at tier 1 takes a path without knowing what a screen is. It decides; it does not identify |
| `auth` stays at tier 3 and **supplies** the actor | it never decides. That split is what lets `policy` land in phase 2 and `auth` in phase 7 with nothing in the policy layer changing at the handover |

Authorization is deliberately **not** a swap point ([`../idea/04-swap-points.md`](../idea/04-swap-points.md)): a second authorization backend is a second authorization system.

## Every subsystem

| Subsystem | Tier | Phase | Responsibility (one line) | Intended public surface | Must never | Status |
|---|---|---|---|---|---|---|
| `core` | 0 | 1 | errors, config, the declaration registry, the boot pipeline, the value types | `Magik::Error`, `Magik.config`, `Magik::Registry`, `Magik::Money`, `Magik::Uuid7`, `Magik::Timestamp`, the guardrail runner and rule interface | require any other subsystem; know what a screen or a job is | not implemented |
| `schema` | 1 | 1 | the `migrate` DSL over Sequel migrations, column type mapping, drift detection | `migrate`, `Magik::Schema.apply`, `Magik::Schema.drift` | contain business logic; know about models' associations | not implemented |
| `router` | 1 | 2 | the path grammar and the route table — name → path, both directions | `Magik::Router.path_for`, `Magik::Router.resolve`, `Magik::Router.table` | know concretely about `action` or `screen`; render anything | not implemented |
| `i18n` | 1 | 8 | catalogs, locale negotiation, `t()`, loud misses | `t`, `locales`, `Magik::I18n.catalog` | read a request; format money or timestamps itself | not implemented |
| `policy` | 1 | 2 | the `policy` DSL and the one authorization evaluator every surface calls — verbs, `default :deny`, pure predicates, the `roles` / `staff_roles` sets | `policy`, `roles`, `staff_roles`, `Magik::Policy.allows?`, `Magik::Policy::Verb` | identify the actor — it receives one as an **opaque value**; issue a query or any other I/O inside a predicate; be swappable ([above](#why-policy-is-tier-1)) | not implemented |
| `model` | 2 | 1 | the `model` DSL over Sequel — fields, associations, validations, scopes, tenancy, audit annotations, `attachment` (phase 4b) | `model`, `Magik::Model::Definition`, `audited`, `immutable_after`, `attachment` | render; authorize; reach another domain's models | not implemented |
| `render` | 2 | 2 | the `component`/`screen`/`layout` DSL and the HTML + `hx-*` compiler, the component kit, the theme system, the override registry | `component`, `screen`, `layout`, `Magik::Kit::*`, `Magik::Render.compile` | hold state across requests; import `realtime` (it needs a channel *name*, which lives in `core`); write its own authorization check — a screen **names a verb** and `policy` (1) decides | not implemented |
| `realtime` | 2 | 3 | `channel`/`broadcast`/`presence` and the pub-sub transport | `channel`, `broadcast`, `presence`, `backends/postgres.rb`, `backends/redis.rb` | authorize on its own — a channel evaluates **the same `policy` verb as the request path**; open a socket nobody declared | not implemented |
| `jobs` | 2 | 4 | the `job` DSL, the durable queue, retries, the scheduler, the worker loop | `job`, `Magik::Jobs.enqueue`, `Magik::Jobs::Worker`, `backends/postgres.rb` | serve HTTP; assume exactly-once delivery; run without a declared `policy:` verb (`policy: :system` is the usual opt-out) | not implemented |
| `action` | 3 | 2 | the `action` DSL, params coercion, the mutation lifecycle, `redraw`/`toast`/`redirect`, `idempotent_by` | `action`, `Magik::Action.perform`, `redraw`, `toast` | hold instance state; assemble HTML by hand; run slow work inline | not implemented |
| `ledger` | 3 | 5 | the `ledger` DSL, double-entry posting, balance analysis, append-only enforcement | `ledger`, `Magik::Ledger.post`, `Magik::Ledger.balance` | accept a float; update or delete a posted entry | not implemented |
| `api` | 3 | 6 | the `api` DSL, REST resources, pagination/filter/sort, `webhook` in both directions, API auth and rate limiting | `api`, `webhook`, `Magik::Api::Resource` | render screens; bypass model validations | not implemented |
| `auth` | 3 | 7 | the `auth` DSL over Rodauth — accounts, sessions, OAuth, 2FA, and the actor a request resolves to | `auth`, `Magik::Auth.actor`, `Magik::Auth::Account` | decide authorization for a *resource* — it identifies | not implemented |
| `notify` | 3 | 8 | the `notification` DSL and delivery across email, in-app and push | `notification`, `notify`, `Magik::Notify::Channel` | deliver inline — delivery goes through `jobs` | not implemented |
| `pwa` | 3 | 8 | the `pwa` DSL, the manifest, icons, install metadata | `pwa`, `Magik::Pwa.manifest` | emit a service worker that caches application data ([`../idea/05-limits.md`](../idea/05-limits.md)) | not implemented |
| `billing` | 4 | 7 | the `billing` DSL — plans, trials, subscriptions, metered usage, provider webhooks | `billing`, `Magik::Billing.subscribe`, `backends/stripe.rb` | own money arithmetic — that is `core`'s `Money` and `ledger` | not implemented |
| `admin` | 4 | 7 | the `admin_panel` DSL and the generated CRUD admin | `admin_panel`, `Magik::Admin.mount` | be a second app with its own auth or rendering path | not implemented |
| `domains` | 4 | item 12 | the `domain` DSL, the dependency graph, and boot-time boundary enforcement | `domain`, `Magik::Domains.graph`, `Magik::Domains.enforce!` | be optional — an app with no domains has one implicit domain | not implemented |
| `check` | 5 | item 12 | the static rule set behind `magik check`, `--scale` heuristics, finding formatting, `--json` | `Magik::Check.run`, `Magik::Check::Finding` | duplicate a boot guardrail — it runs the same rule objects without a server | not implemented |
| `testing` | 5 | 9 | the `test` DSL over Minitest, factories, helpers, the parallel runner, transactional isolation | `test`, `Magik::TestCase`, `perform_action`, `render_screen`, `assert_enqueued` | be required from `lib/` production code paths | not implemented |
| `cli` | 6 | 1 | `exe/magik` — the command surface, generators, the dev server, `magik worker`, `magik console`, `magik describe` | `Magik::Cli.start`, the command classes | contain framework logic — it composes subsystems and prints; hand-maintain a second copy of the grammar (`magik describe` **serializes the option tables**, [below](#the-option-tables-and-magik-describe)) | not implemented |

The **Phase** column names a spec phase ([`../idea/06-phases.md`](../idea/06-phases.md)). `item 12` is the spec's *Domain module system* architecture decision rather than a numbered phase; it is built at build-order step 13.

## The option tables and `magik describe`

`magik describe` is a phase-1 CLI command and **the grammar, as data** — every construct, declaration and option with its type, default, allowed value set and the `MAGIK_*` codes it can raise. It is built at build-order step 2, with the option tables it serializes.

| Rule | Detail |
|---|---|
| Where the tables live | with the construct — one `Option` value object per option, in the subsystem that owns the construct. There is no central options file |
| Who reads them | the coercer at boot, the guardrail rules, the docs anchors, and `magik describe`. **One artifact serialized four ways** |
| Never hand-maintained | two tables drift; one cannot. A `describe` output written by hand is the defect this design exists to prevent |
| Not `magik registry` | `describe` is *what the grammar allows* and needs no app; `registry` is *what this app declared* and needs a booted one ([`06-observability.md`](06-observability.md)). Neither may grow into the other |

The design and the rules that follow from it: [`../idea/11-dsl-as-tool-surface.md`](../idea/11-dsl-as-tool-surface.md) §2, indexed in [`00-conventions.md`](00-conventions.md#dsl-design-rules-r1r10).

## Media has no subsystem, on purpose

Phase 4b spans four existing ones rather than adding a twenty-second ([`../idea/06-phases.md`](../idea/06-phases.md)):

| Piece of media | Lives in |
|---|---|
| the `:file` field type and `attachment` on a model, plus the storage seam | `model` (2) |
| the upload component and `srcset` / responsive rendering | `render` (2) |
| derivative generation and the transcoding seam (`use :media, :mux`, wrapped never built) | `jobs` (2) |
| signed expiring URLs, issued only after the record's verb passes | `policy` (1) decides; the surface issuing the URL calls it |

Adding a subsystem is an architecture change, and media does not need one — it needs a declaration on `model` and job work behind it.

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
