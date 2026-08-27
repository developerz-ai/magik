# Magik — Build Spec

> The source of truth for what Magik is. Everything else in `docs/` elaborates on this file; nothing
> contradicts it.
>
> **Status:** spec only. Nothing in this document is implemented. `As of 2026-08-26` the repository
> contains a name-reservation gem and documentation; no construct, guardrail or command described
> below exists ([`../../wiki/Known-Gaps.md`](../../wiki/Known-Gaps.md)).

## Mission

Build **Magik**: an opinionated, full-stack Ruby framework on TruffleRuby. One DSL for models,
screens (UI), actions (mutations), realtime channels, background jobs, ledgers (money), APIs and
admin panels. No separate frontend framework — the server renders HTML, htmx handles interactivity.

**The target: express 99% of SaaS use cases — CRUD apps, dashboards, fintech, ecommerce,
marketplaces — in one grammar, so that no app has to "graduate" to another stack.** The named
exclusions are permanent and listed in [`05-limits.md`](05-limits.md).

That target is a bar the phases below are sequenced to reach, and the distance to it is a **measured
question rather than a rhetorical one**. [`10-saas-coverage.md`](10-saas-coverage.md) counts the
grammar against 68 surfaces a SaaS needs across its whole life and carries the command that re-counts
the table. Its last full count, `As of 2026-08-26`, put full coverage at **under a fifth**, and named
three gaps that force a graduation — authorization, the application shell, and media. Those three are
closed by the phases below; the rest is the work, and the count is owed a re-run. **Re-run it rather
than trusting this paragraph.**

## Non-negotiable Architecture Decisions

1. **Runtime**: TruffleRuby. Concurrency via **real parallel OS threads**.
2. **Server**: Rack + Puma, thread-per-request.
3. **DB**: Sequel (not ActiveRecord). Explicit queries, no lazy-loading magic.
4. **No SPA framework.** UI = server-rendered HTML + htmx attributes, compiled from DSL. No
   React/Vue/Ember, ever.
5. **Realtime is opt-in per screen**, not global. Default = plain request/response. `live`/`channel`
   declarations turn a screen/model realtime. No cost unless declared.
6. **No offline support.** Server is always the single source of truth. State this limit explicitly
   in docs.
7. **No heavy client-side compute** (canvas editors, games) — out of scope, say so.
8. **Multi-tenant by default.** Every model auto-scoped by `tenant_id`. UUIDv7 primary keys
   (sortable, shard-safe) from day one.
9. **Stateless app servers.** No in-process session/UI state — enables "add more servers" scaling.
10. **Money type**: integer-cents backed `:money` field type. Floats forbidden for currency at the
    type-system level.
11. **Swap points required for every "opinionated default."** DB engine, cache backend, job backend,
    search backend, realtime backend must be config-switchable without app code changes. (Lesson from
    Meteor's death: magic with no escape hatch = eventual rewrite.)
12. **Domain module system** for large apps: `domains/<name>/domain.rb` declares `depends_on`,
    `exposes`, `publishes_events`. Boot-time enforcement — a domain cannot access another domain's
    models directly, only via published interface or event subscription.
13. **Authorization is evaluated in exactly one place.** Every surface that reaches a model — a
    screen, an action, an API resource, a realtime channel, a job and the admin panel — names a verb
    in a `policy` and the framework evaluates it. There is no second door to the data and no
    per-surface check. Because `render` and `realtime` must evaluate it, **the evaluator sits at
    tier 1** — below `model`, `render` and `realtime` — and takes the actor as an opaque value;
    `auth` at tier 3 supplies that value and never decides
    ([`../architecture/01-module-map.md`](../architecture/01-module-map.md)). Authorization is
    **not** a swap point: a second authorization backend is a second authorization system, which is
    the failure this whole design is organised against ([`04-swap-points.md`](04-swap-points.md)).

### The runtime, and the measurement under it

Decisions 1 and 2 rest on running code rather than on reasoning about the design, so they carry their
provenance rather than a figure. **Cite the probe, never a number:** the ratios move run to run with
machine load, and a number copied into prose is a number a re-run contradicts.

| | |
|---|---|
| Production runtime | **TruffleRuby**, verified on **24.2.1** and on **34.0.1** (2026-04-26, `like ruby 3.4.9`). Its threads are genuinely parallel: N threads over N cores finish CPU-bound work several times faster than one thread does. That is what makes thread-per-request the correct server model, and Puma the correct server |
| Parallelism holds through the IO path | this is the load-bearing half, because a request spends its life in IO rather than in Ruby. **`pg` releases the runtime lock on every engine tested** — eight threads each issuing a one-second query finish in about one second, not eight — so concurrent queries overlap instead of serialising. CPU parallelism behind a serialising driver would be a queue wearing a thread pool. Probe: [`../../scripts/probes/pg_concurrency.rb`](../../scripts/probes/pg_concurrency.rb) |
| Development runtime | **CRuby ≥ 3.2**, for tooling only: the CLI, the linter, the docs build, the test suite of the gem itself. **It is not a production target.** Its threads do not parallelise CPU-bound work at all — the global lock — so decision 1 is not true there, and a CRuby production deploy would be a different framework wearing the same name |
| **There is no `fork`** | TruffleRuby does not implement it: `Process.respond_to?(:fork)` is `false` and calling it raises. Two consequences, both design rather than caveat. **Puma runs in single mode** — no clustered workers — so capacity comes from more containers rather than more processes on a box ([`../ops/README.md`](../ops/README.md)). And **the test runner has exactly one worker model, a thread** (phase 9), because there is no forked worker to fall back to |
| Provenance | method, full results and the CI matrix: [`../architecture/12-runtime-verification.md`](../architecture/12-runtime-verification.md). The probes are [`../../scripts/probes/runtime.rb`](../../scripts/probes/runtime.rb) and [`../../scripts/probes/pg_concurrency.rb`](../../scripts/probes/pg_concurrency.rb); re-derive with `ruby scripts/probes/runtime.rb --json`, once per engine |
| Staleness | every fact above is engine-version specific and dated `As of 2026-08-26`. A runtime release can move any of it, and **the probes are the mechanism for noticing.** A claim about the runtime that is not re-derivable from them does not belong in this file |

**The open cost, named rather than papered over.** An OS thread is not free per idle connection.
Realtime — `live` and `channel` over `LISTEN`/`NOTIFY`, phase 3 — means **many mostly-idle open
connections**, which is the workload thread-per-request is worst at, and with no `fork` there is no
second process on the box to spread them over. This is an **open question with a measurement owed**,
not a solved problem: *how many concurrent idle SSE or WebSocket connections does one Puma process
sustain on TruffleRuby, and at what memory cost per connection?* Until that number exists, decision
5 — realtime is opt-in per screen — is carrying more weight than it was designed to carry. Nothing in
this spec should be read as claiming the question is answered.

## Core DSL Surface (build in this order)

### Phase 1 — Foundation
- `App.define :Name do ... end` — app composition root
- `model :Name do field/computed/belongs_to/has_many/validate/scope end` — wraps Sequel
- `migrate :Name do up/down end` — schema DSL over Sequel migrations
- Money type, UUID v7 id strategy, tenant_id auto-injection
- `magik new`, `magik generate model/screen/action`, `magik console`, `magik server`,
  `magik describe` CLI

The field type set carries three members that are types rather than conventions, for the same reason
`:money` is one — a malformed value fails at boot rather than at first use:

- **`:money`** — integer minor units plus a currency. A float is refused at the type system.
- **`:file`** — an attachment, with `max_size:` and `content_types:` **required**. A field type added
  after release is a migration for every app that worked around its absence. The rest of media is
  phase 4b.
- **`:duration`** — a unit-suffixed string coerced at boot (`"14d"`, `"10m"`, `"90s"`).

`computed(:name, :type) { ... }` declares a derived field.

`magik describe [construct[.declaration]] [--json]` is **the grammar, as data.** Every construct,
every declaration, every option with its type, default, allowed value set and the `MAGIK_*` codes it
can raise. It answers about the grammar, so it needs no app, no boot and no database, and works in an
empty directory. It is **derived from the option tables the DSL validates against**, never
hand-maintained — two tables drift, one cannot. It is not `magik registry`, which reports what an app
declared. It is the command an option-level error's `fix:` line points at
([`../architecture/03-error-codes.md`](../architecture/03-error-codes.md)), and the named consumer
without which the option table gets built as prose
([`11-dsl-as-tool-surface.md`](11-dsl-as-tool-surface.md) §2).

Phase 1 also carries, one line each — the designs are in
[`10-saas-coverage.md`](10-saas-coverage.md), not here:

- `searchable` declarations on `model` and `Model.search`, over the existing search seam
- soft delete / archive / restore as a model annotation, with scopes excluding archived rows
- an `environment` block inside `App.define` selecting seams per environment (`App.define` is already
  the only place a backend is named; a second namer would break the rule that makes the seam
  analysable)
- liveness and readiness endpoints, `magik migrate` as a deploy gate, drain semantics

### Phase 2 — Rendering & Actions
- `component :Name do prop; body do ... end end` — reusable UI DSL, compiles to HTML+htmx attrs
- `screen :Name do state/body end` — page-level component, auto-routed
- `action :name do |params| ... end` — mutation handler, auto-wired to htmx POST
- `policy :Model do default :deny; can :verb do |actor, record| ... end end` — one authorization
  rule set
- `layout :Name do sidebar / topbar / content / responsive end` — the application shell
- Component kit: `button, form, field, data_table, modal, toast, card, list, grid, tabs, stat,
  chart, sidebar, topbar, nav_item, breadcrumbs, account_menu, dashboard_grid`
- Theme system: design tokens, light/dark mode via CSS vars

**`policy` lands here, not with `auth` in phase 7**, and its evaluator sits at tier 1, not beside
`auth` at tier 3. Both are load-bearing and neither is tradeable:

| Property | Why |
|---|---|
| **Phase 2, not phase 7** | a screen and an action are the first two surfaces that need it. Adding a `policy:` argument to six constructs after all six exist is precisely the retrofit this spec calls "a migration nobody survives" when it says it about tenancy (decision 8). Before `auth` ships the actor is whatever the app resolves; after it, `auth` supplies it, and nothing in the policy layer changes at the handover — which is the test that the tier split is right |
| **Evaluator at tier 1** | `render` and `realtime` are tier 2 and must evaluate policies, and imports go strictly down ([`../architecture/01-module-map.md`](../architecture/01-module-map.md)). A tier-3 evaluator is unreachable from the two surfaces that need it most. `policy` at tier 1 takes the actor as an opaque value, exactly as `router` at tier 1 takes a path without knowing what a screen is |

Predicates are pure: no queries, no I/O, because a `live` screen re-evaluates one per subscriber per
change. A `nil` record denies. `roles` and `staff_roles` on `App.define` declare the role set once
beside the actor — staff are a separate axis, because a support engineer is not a member of the
tenant they are helping. Every surface **names a verb** instead of writing a check —
`screen :Invoices, policy: %i[Invoice read]`, `action :issue_invoice, policy: %i[Invoice issue]`,
`channel`, `job`, `api resource`, `admin_panel`. Opting out is a declaration too: `policy: :public`,
`policy: :system`. Drafted Ruby: [`02-dsl-surface.md`](02-dsl-surface.md#policy).

**Three questions `policy` did not answer, found by writing the reference app rather than by reading
the design — and now decided.** Each was a surface that reaches a model but had no actor or no model
to name, so each was a place `MAGIK_POLICY_UNDECLARED` was unsatisfiable: the same shape of defect
`MAGIK_ADMIN_UNPROTECTED` was, and the reason that code no longer exists.

**1. A verified incoming webhook presents a declared service actor, never `:system`.** A signature
authenticates an *origin*, not a person, and `policy: :system` would hand every verb in the
application to anything that can reach the endpoint — which is the broadest possible grant given to
the one surface an attacker can call directly. So an incoming webhook declares the verbs it may
exercise, and only those:

```ruby
webhook :incoming, :stripe do
  verify_signature secret: secret(:stripe_webhook), scheme: :stripe
  acts_as :service, can: %i[Invoice.record_payment]     # least privilege, and it is a declaration
  on "payment_intent.succeeded" do |event| … end
end
```

`can:` is a verb list, not a role: there is no actor to carry a role. Every verb still resolves
through the same `policy`, so this widens nothing — it narrows. An incoming webhook with no
`acts_as`, or one naming `policy: :system`, does not boot (`MAGIK_WEBHOOK_UNSCOPED_ACTOR`). *Rejected:
letting a webhook inherit `:system` like a job. A job is triggered by the application on its own
schedule; a webhook is triggered by a stranger.*

**2. A `policy` subject is any declared construct that owns data, not only a `model`.**
`ledger :Receivables` is not a model, so `api resource :ledger_entries` had no legal verb to name.
`policy :Receivables` is now legal, and the subject must be a name the registry knows —
`MAGIK_POLICY_UNKNOWN_SUBJECT` otherwise. *Rejected: requiring every surface to project onto a model.
That would have forced a fake `LedgerEntry` model into existence purely to satisfy authorization,
which is inventing a data model to satisfy a guard — backwards, and exactly the pressure to write
fake framework code this repository is organised against.*

**3. A `flow` names its own verb and inherits nothing.** `flow` joins the surface list above.
Inheriting the union of every verb its steps post to would make a flow's authorization a function of
code elsewhere, unpredictable at the declaration site and impossible to read off the page — which is
the second door `policy` exists to close. A step's `action` still evaluates its own verb, so a flow
gates *entry* and each action gates its *write*. Two gates, one evaluator, and neither is implicit.

None of the three blocked phase 2 — screens and actions, the two surfaces phase 2 delivers, were
fully specified without them. Each blocked the phase that ships the surface in question, and each was
cheaper to settle here than after that surface existed. The reasoning is logged in
[`13-decisions.md`](13-decisions.md).


**`layout` is the application shell**, and a screen names one
(`screen :Invoices, layout: :App, parent: :Dashboard`); opting out is written down
(`layout: :None`). `magik new` generates a working `:App` layout, so **a generated app has a sidebar
on its first run**. It is a new *declaration*, not a second override system: its pieces are kit
components with contracts, so all four rungs of
[`08-component-overrides.md`](08-component-overrides.md) apply unchanged, and a collapsing sidebar is
a media query plus one htmx target — inside both permanent limits.

**Every kit component is responsive by construction, and no app-authored declaration is required to
make a screen work on a phone.** That is a claim to be tested, not asserted: `render_screen … at:
:mobile` and a phase-2 exit criterion that the generated app renders correctly at 375px. The one
place it costs the author a line is `data_table` on a narrow screen, which becomes a **card list**,
never a horizontal scroll.

Phase 2 also carries, one line each:

- `data_table` fully specified — cursor pagination on `(sort_key, id)`, sorting, filters with URL
  state, bulk selection encoded in the request, column control, export, narrow-screen mode. It is the
  most-used component in any SaaS
- `chart` specified — server-rendered inline SVG, six types, series colours from tokens, data from a
  `state` and never a query in the chart call
- empty, loading and error states as first-class slots on every collection component
- spacing, type, elevation, motion and icon tokens; one finished-looking default theme
- accessibility as a **component-contract element**, so a rung-3 replacement that drops the focus trap
  fails at boot the way a missing slot already does
- screen-level `search` and `filter` declarations feeding `state`; fragment caching as an option on
  `state` and `component`
- CSRF, CSP, HSTS, frame options and cookie flags as **framework defaults** with a documented override
- a honeypot and submission-timing check on every generated `form`, **on by default**
- per-IP / per-actor / per-action throttling as an option on `action`, over a throttle-store seam
- output escaping stated as a **guarantee**, with `raw` as the single named hatch

### Phase 3 — Realtime (opt-in)
- `live :state_var, on: "channel:name"` on screens
- `channel :name do subscribe_to/on_create/on_update end`
- `broadcast "channel", :event, payload`
- Backend: Postgres LISTEN/NOTIFY (default) → Redis pub/sub (swap via config)
- `presence` for online/cursor tracking

A channel evaluates **the same `policy` verb as the request path**. There is no second door to the
data — that is the Meteor lesson stated as a phase requirement rather than as prose.

### Phase 4 — Jobs & Async
- `job :Name do retries times:, backoff:; schedule cron:/every:; idempotent_by; perform do |args| end end`
- Postgres-backed transactional queue (Que-style) by default, swappable to Kafka
- `magik worker` process, horizontally scalable
- CSV and spreadsheet import and export as job factories with a progress surface

`schedule every:` takes a `:duration` — `every: "10m"`, never `every: 15.minutes`.

### Phase 4b — Media

A phase between jobs and money, because media spans four others: the field type is phase 1, the
upload component is phase 2, derivative generation and transcoding are phase 4 jobs, and signed
delivery is blocked on `policy`. **A capability whose value arrives only when all four have landed is
a phase**; otherwise each phase ships its quarter and the app still cannot store a photo.

- `attachment :name, :image|:document|:video, max_size:, content_types:, visibility:, direct:` on a
  model, with a block declaring `derivative`, `responsive` and `exif`
- direct-to-storage presigned upload **by default** — a request server proxying a 2GB file occupies a
  connection for minutes and makes decision 9 a lie about memory
- content type **sniffed from magic bytes**, never the extension, never the client header
- image derivatives pre-generated in a job, `srcset`, WebP/AVIF negotiation, **EXIF stripped on ingest**
- signed expiring URLs for `:private` files, issued only after the record's `policy` verb passes
- video and audio **wrapped, never built** — `use :media, :mux`, with an `:ffmpeg` backend documented
  with its costs (a dedicated queue, a machine shape, an input-validation burden)
- blob lifecycle — deleting a record enqueues blob deletion; retention and erasure cover blobs, not
  only rows

It is not optional: the mission sentence names ecommerce and marketplaces, and both are blocked on
media. Source: [`10-saas-coverage.md`](10-saas-coverage.md) §Media.

### Phase 5 — Money & Compliance (fintech-ready)
- `ledger :Name do account; entry do debit/credit/guard end end` — double-entry, boot-time balance validation, append-only
- `audited` + `immutable_after:` model annotations — automatic audit trail
- `idempotent_by` on actions — dedupes retried mutations
- `flow :Name do step ... end` — multi-step wizards (onboarding, KYC, checkout)

Phase 5 also carries, one line each:

- basis-point rate arithmetic as `:money`'s sibling, for tax and fees — `0.21` against cents
  reintroduces the error `:money` exists to remove
- GDPR subject export and erasure, **including** the interaction with `audited` and append-only
  ledgers — that collision is why it needs designing rather than adding
- retention policies and scheduled purge
- a staff-versus-customer dimension on the audit trail

### Phase 6 — API & Integration
- `api :V1 do resource :name do index/show/create/update/destroy end end` — REST, auto-paginate/filter/sort
- `webhook :incoming, :name do verify_signature; on :event end`
- `webhook :outgoing, :name do fires_on; deliver_to; sign_with end`
- Auth: `:bearer`, `:api_key`, `:jwt` (mobile), rate limiting by plan

A `resource` declares field subsets in the **one vocabulary** used by `admin_panel`, `data_table` and
`screen` — `fields`, `filterable`, `sortable`, `searchable`, `writable` — rather than as per-verb
options.

Phase 6 also carries API deprecation and sunset headers on a version, and a webhook delivery log with
replay and a customer-facing endpoint surface.

### Phase 7 — Auth, Billing, Admin (batteries)
- `auth do strategy; oauth_providers; two_factor; session_ttl end` — generates full auth flow (Rodauth-backed)
- `billing provider: :stripe do plans end` — subscriptions, trials, metered billing
- `admin_panel :Model, policy: %i[Model administer] do list do fields/filterable/searchable end; show; form end` — auto CRUD admin
- `tenant_by :subdomain` — multi-tenancy wiring

`policy:` on `admin_panel` is **required.** Benchmarked against [Avo](https://avohq.io), the admin is
by construction the surface with the broadest data access in the application, and an admin panel
without a policy is a security hole with a nice table on top. `admin_panel` is a projection of
`model`, so its vocabulary is `api`'s, and it carries all four view types: a `list`, a `show` with
panels, tabs and a sidebar, and a `form` with per-view field visibility. An admin who can list orders
and cannot open one is not an admin.

`auth`'s `session_ttl` and `billing`'s trial take a `:duration` — `session_ttl "14d"`,
`plan :starter, …, trial: "14d"`.

**What is kept unchanged, because it is the best property of the design:** admin actions **are** the
app's actions. `MAGIK_ADMIN_INLINE_MUTATION` forbids a second write path, so a Magik admin cannot
have a mutation the product does not have. Everything else is built on that.

Phase 7 also carries, one line each:

- bulk actions with argument forms, typed filters, saved views, global search across resources, admin
  dashboard cards, and impersonation with a mandatory audit record and a visible banner
- **teams, memberships, seats and invitations**, generated the way `auth` generates accounts — every
  B2B SaaS needs it in week one, and it is the data model `policy` needs in order to decide anything
- **abuse defaults, on by default and not documentation** — login throttling and lockout,
  enumeration-resistant login and reset responses with equal timing, constant-time comparison. *An
  agent asked to build a signup flow will not add any of them unless they are defaults*, which is the
  same argument this spec already makes for boot guardrails
- a bot-challenge seam, **off** by default — a CAPTCHA has a real accessibility and privacy cost, and
  the vendor space is exactly what decision 11 exists to survive
- disposable-domain policy on signup, off by default
- support views of a tenant's data; subscription upgrade, downgrade, proration and cancellation as a
  specified state machine
- feature flags as a **factory over `policy`** — a flag is an authorization rule whose subject is a
  cohort rather than a role

### Phase 8 — i18n, PWA, Notifications
- `locales :en, :es, ...`, `translatable: true` fields, timezone-safe `:timestamp` type
- `pwa do name/icon/display end` — installable, no offline caching
- `notification :name do channel :email, :in_app, :push end`

Phase 8 also carries, one line each:

- **email production** — `magik mail preview` rendering to a file, CSS inlining, a generated
  plain-text alternative, mail layouts distinct from screen layouts, a **framework-owned** suppression
  list consulted by `notify` before delivery, unsubscribe tokens and `List-Unsubscribe`, and inbound
  bounce/complaint events over the existing `webhook :incoming` DSL. The preview matters doubly here:
  **an agent has no inbox**, so rendering to a file is its only way to see an email
- an in-app notification centre screen and component reading what `channel :in_app` writes
- currency, number, address and pluralisation formatting; RTL as a theme direction
- per-screen `meta`, canonical URL and Open Graph tags — server-rendered HTML is indexable, so this is
  a declaration rather than a project
- PDF and print rendering as a declared output of a `notification` or a `job`

### Phase 9 — Testing
- Wrap **Minitest** (not RSpec) — fast boot, simple object model
- `test :Name do it "..." do expect(...) end end` DSL compiling to Minitest
- Auto-generated tests from `required:`, `validate`, ledger balance checks
- Auto-inferred factories from model field types
- Helpers: `perform_action`, `render_screen`, `concurrently(n)`, `travel_to`, `assert_enqueued`, `assert_broadcast`, `assert_notified`
- Parallel execution: one **worker** per test file group, `workers: :auto` (all CPUs), transactional rollback per test (no truncation)
- `magik test`, `magik test --watch`, `magik test --changed`

**A worker is a thread**, and there is exactly one worker model. TruffleRuby's threads are genuinely
parallel (decision 1) and TruffleRuby has no `fork`, so a thread is both the right mechanism and the
only one — the runner does not carry a second, and the isolation story is written once. The design is
[`../architecture/04-testing-strategy.md`](../architecture/04-testing-strategy.md). The
1,000-tests-under-10s target is a target that has never been measured.

Phase 9 also carries, one line each:

- `assert_queries(n) { ... }` — a way to assert the *absence* of an N+1
- email content assertions beyond `assert_notified` — subject, recipient, body text, links, and that a
  plain-text part exists
- **an authorization test generated per policy verb**, including a cross-tenant denial
- `render_screen … at: :mobile`, which is what makes the responsiveness claim testable rather than
  asserted

## DSL vocabulary

*One concept, one spelling, everywhere* ([`11-dsl-as-tool-surface.md`](11-dsl-as-tool-surface.md)
R1). Four concepts recur across constructs, and each has exactly one spelling. The rules cited are
R1–R10 on that page.

| # | Concept | The spelling | Why |
|---|---|---|---|
| **D1** | A duration | **a `:duration` type everywhere — a unit-suffixed string, coerced at boot.** `session_ttl "14d"`, `schedule every: "10m"`, `trial: "14d"`, `throttle per: "1h"` | the alternative — `*_days`/`*_ms` integers — puts the **unit in the option name**, so `retention_days:` and `retention_hours:` become two spellings of one concept, which is the per-name explosion R10 exists to prevent, and `"90s"` becomes inexpressible without a new option. R2 permits a free-form string where the space is genuinely open provided it carries a format check and a named error code, which a duration does. Making it a *type* rather than a String means a typo fails at boot, exactly as `:money` refuses a float (decision 10) — and `magik describe` can carry `"type": "duration"` with its grammar, so it stays discoverable (R6) |
| **D2** | A precondition | **`guard "reason" do ... end`, a declaration with a message and a block, on `ledger entry`, `action`, `job` and `flow step`.** A flow step that simply does not apply uses `skip_when do ... end` | R9 puts behaviour in blocks and options in keyword arguments, and a precondition is behaviour — it evaluates per posting, per request, per step. A lambda-in-an-option is also invisible to the schema (R6): `describe` can list a `guard`; it cannot describe what an arbitrary `if:` decides. The message is not decoration — R7 requires an error to name the specific cause, and a guard carrying its own sentence gives every failure one for free. The `skip_when` split is deliberate: *skip* and *abort* are different meanings, and collapsing them into `guard` would trade one R1 violation for a worse one |
| **D3** | A field subset | **five declarations, one vocabulary, on `api`, `admin_panel`, `data_table` and `screen`: `fields`, `filterable`, `sortable`, `searchable`, `writable`** — variadic symbols, inside the construct's block, never per-verb options | there is not one concept here but five — shown, filtered, sorted, searched, written — so "one spelling" means **one word per role, identical across every surface**, not one word for all five. `writable` rather than `read_only` because a whitelist beats a blacklist. Declarations rather than options because they say *what*, which is R9's line, and because it makes `admin_panel` a projection of `model` in `api`'s vocabulary. `per_page:` stays an option — it is a scalar setting, not a field subset |
| **D4** | Uniqueness | **they are two concepts and they stay apart. `unique:` on a `field` means a database uniqueness constraint and nothing else; a job's dedupe key is `idempotent_by`** | a constraint and a dedupe key cannot converge, and R1 says sharing a stem while meaning different things is the worst of both. `unique: true` keeps the name every ORM and SQL itself already uses; renaming it would be novelty at review-time cost (R4). A job's meaning — *a repeated request with the same key produces one effect* — is exactly what `action`'s `idempotent_by` already means, so the catalogue carries one option rather than two (R10), and the `unique` stem keeps a single meaning |

**A drafted DSL spelling is not designed until it has been parsed.** Every Ruby block in
[`02-dsl-surface.md`](02-dsl-surface.md) parses; re-derive by extracting every ` ```ruby ` block from
that file and running `ruby -c` over the concatenation. Reading a block is not a substitute — a
keyword that cannot be a method name, or a brace block that binds to the wrong receiver, is invisible
to a reader and obvious to a parser.

**Enforcement:** these are data, not prose. A `scripts/checks/` step over the option tables asserts
that every option in [`02-dsl-surface.md`](02-dsl-surface.md) appears in `magik describe --json` and
vice versa. A convention that is not a check does not exist.

## Libraries to Wrap (don't reinvent)

Sequel (DB) · Que (jobs) · Rodauth (auth) · Shrine (uploads, S3) · money gem (currency) · htmx
(client interactivity, ~14kb) · Puma (server) · Stripe/Paddle SDKs (billing) · pgvector (vector
search) · Minitest (test core) · JSON behind a seam · Prawn (PDF) · OpenTelemetry Ruby
(observability) · a media service (Mux / Cloudflare Stream / Bunny) behind `use :media` ·
Anthropic/OpenAI SDKs (AI actions)

**JSON is a seam rather than a fixed dependency** (`use :json, :auto | :oj | :stdlib`) because the
fast path is engine-dependent: `ruby/json` selects a pure-Ruby generator when
`RUBY_ENGINE == "truffleruby"`, and the C-extension alternatives do not name TruffleRuby as a
supported platform ([`../architecture/10-performance-defaults.md`](../architecture/10-performance-defaults.md)).
The general rule: *a dependency that is a C extension, or that reaches for a runtime primitive, is a
candidate for a seam until a probe says otherwise on the production engine.*

**Video and audio are wrapped, never built.** Transcoding, HLS/DASH packaging, poster frames,
waveforms and adaptive bitrate ladders are a specialist product; a framework that builds one has
become a media company. The `ffmpeg` path exists as a backend for teams that want no vendor, and is
documented with its real costs — a CPU-bound multi-minute process on the app's own worker fleet, its
own queue, its own machine shape, and a malformed input as a remote-code-execution surface with a
long CVE history.

**Wrapped libraries and swap points are not the same thing.** Rodauth is a structural dependency of
`auth`, not a backend behind an interface, and saying so is more honest than pretending to a seam
nobody could implement against. The seams are in [`04-swap-points.md`](04-swap-points.md).

## Guardrails to Enforce at Boot (this IS the product)
- Ledger entries must balance (debits == credits) or boot fails
- No `field :card_number` type allowed — forces tokenized payment fields
- Domain boundary violations (cross-domain direct model access) fail at boot
- Screens/actions cannot hold in-process instance state across requests
- Timestamps cannot be rendered without explicit timezone conversion
- `magik check --scale` — warns on queries missing tenant_id in WHERE clause (pre-empts sharding pain)

Authorization, layout and uploads are guardrails for the same reason: each is a rule the frozen
registry can decide, each is consequential, and each is fixable by an edit the error can name. The
full catalogue with its `fix:` lines is [`03-guardrails.md`](03-guardrails.md).

| Guardrail | What fails | Code |
|---|---|---|
| **Every surface reaching a model names a policy verb** | a `screen`, `action`, `api resource`, `channel`, `job`, `flow`, `webhook :incoming` or `admin_panel` with no `policy:` and no explicit `policy: :public` / `policy: :system` | `MAGIK_POLICY_UNDECLARED` |
| A policy predicate performs no I/O | a `can` block issuing a query — `live` re-evaluates one per subscriber per change, so a query here is one round trip per row per open socket | `MAGIK_POLICY_IO` |
| A named verb exists | `policy: %i[Invoice publish]` where `policy :Invoice` declares no `:publish` | `MAGIK_POLICY_UNKNOWN_VERB` |
| Denial is the default | a `policy` block with no `default :deny` | `MAGIK_POLICY_NO_DEFAULT` |
| A rule receiving a `nil` record denies | a row-level rule that would pass on an absent record | `MAGIK_POLICY_NULL_PASSES` |
| An incoming webhook names the verbs it may exercise | a `webhook :incoming` with no `acts_as :service, can: [...]`, or one naming `policy: :system` | `MAGIK_WEBHOOK_UNSCOPED_ACTOR` |
| A policy subject is a declared construct | `policy :Receivables` where nothing declares `Receivables` | `MAGIK_POLICY_UNKNOWN_SUBJECT` |
| Every screen has a layout | a `screen` with no layout and no `layout: :None`; a `nav_item` naming a screen that does not exist; and a layout declaration naming an `action` that does not exist — `search action: :global_search` carries exactly the rot `nav_item` is guarded against | `MAGIK_LAYOUT_MISSING` · `MAGIK_LAYOUT_UNKNOWN_SCREEN` · `MAGIK_LAYOUT_UNKNOWN_ACTION` |
| Uploads are bounded | a `:file` field or `attachment` with no `max_size` and no `content_types` — an unbounded upload field is an unbounded storage bill and a trivial DoS | `MAGIK_MODEL_UNCONSTRAINED_UPLOAD` |

`MAGIK_POLICY_UNDECLARED` is the load-bearing one. It makes authorization non-optional the way
`tenant_id` is non-optional, which is the only mechanism that survives an agent in a hurry — and it
is what makes an unprotected admin panel a boot failure rather than a documented risk.

## Success Criteria
- New CRUD SaaS screen: model + screen + action in <30 lines, zero HTML/JS/CSS written — including
  the navigation, which is what `layout` is for
- Full test suite of 1,000 tests: parallel, all cores, <10s target
- Fintech-grade money handling (ledger, audit, idempotency) available with same DSL grammar as everything else — no separate "fintech mode"
- Every "opinionated default" has a working, tested config-level swap (proven before merge, not promised)
- Explicit documented limits: no offline, no heavy client-side compute — do not silently fail on these, refuse/clarify in docs
- **A generated app is safe and usable on its first run**, proven by three tests rather than a
  document: a cross-tenant actor is denied by **every** generated surface — screen, action, API
  resource, channel and admin panel; the generated application shell renders correctly at 375px; the
  generated signup form throttles and does not reveal whether an account exists

The last criterion is the fourth executable proof required for `1.0.0`, beside the three
[`../../ROADMAP.md`](../../ROADMAP.md) names. It exists because the five above it can all be true of
an application that is insecure and unusable.

## Build Order

The ordering principle is that **anything wrapping every surface must land before the surfaces
multiply.** `policy`, `layout` and the option tables are all wrapping concerns, and every one of them
gets exponentially more expensive per step that ships without it.

1. Rack app skeleton + `App.define` boot process + Sequel connection
2. `model` DSL → Sequel mapping, migrations, **the option tables and `magik describe` that serializes
   them** — the tables are what the coercer, the guardrails, the docs anchors and `describe` all read
   (R8), and retrofitting an option-table representation onto constructs already implemented is the
   same shape of migration as retrofitting `policy:`
3. `screen`/`component`/`action` DSL → HTML+htmx compiler, **plus `policy` and `layout`** — a screen
   and an action are the first two surfaces needing authorization and the first thing needing a shell
4. Router (convention: action name → path) + dev server + hot reload
5. Test DSL + Minitest wrapper + parallel runner (build this early — TDD the rest)
6. Realtime (channel/live/broadcast) over Postgres LISTEN/NOTIFY
7. Jobs (Postgres-backed queue)
8. Media — derivatives, the transcoding seam, direct upload, signed delivery, blob lifecycle. After
   jobs because derivative generation is job work, and after `policy` because signed delivery is
   blocked on it
9. Ledger + audited/immutable primitives
10. Auth + billing + admin_panel scaffolds
11. API/webhook DSL
12. i18n/PWA/notifications
13. Domain module system + boot-time enforcement + `magik check` linter

The build order and the phase list disagree in one place on purpose — step 5 builds phase 9 early so
the rest is TDD'd. **Where they disagree, build order wins**; the full mapping is
[`06-phases.md`](06-phases.md).

## Deliberately deferred

`magik mcp` — an MCP server over the framework's read-only introspection — is **deferred, not
rejected.** Three reasons, in order of weight:

1. It is strictly a second front end over `describe`, `docs`, `check --json`, `registry`, `routes`
   and `explain`, five of which do not exist. A wrapper specified before the things it wraps is
   specified against guesses.
2. Its own design page states the honest limit: *where an agent has a shell, the CLI is the better
   path*. Today every agent working on Magik has a shell, so the marginal capability is zero.
3. Decisively, **it is not a retrofit.** `policy` had to land in phase 2 because it adds an argument
   to six constructs; `magik mcp` adds an argument to nothing — it reads `--json` outputs that already
   have an additive-only stability contract. Deferring it costs a later release, not a migration, and
   applying the retrofit argument reflexively here would cheapen it where it is real.

**The condition for revisiting it:** once `magik describe`, `magik check --json`,
`magik registry --json`, `magik routes --json` and `magik explain --json` all ship and their schemas
are stable across one release, the server is a thin, well-specified addition and should be argued for
then, on the evidence of those schemas. It stays **read-only** whenever it arrives — a mutating
server is a different product with different obligations (credentials behind a gateway, end-to-end
identity, synchronous audit) and would be a separate binary with a separate name. The full design is
[`11-dsl-as-tool-surface.md`](11-dsl-as-tool-surface.md) §3.
