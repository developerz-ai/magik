# Magik — Build Spec

> **v2, amended 2026-08-26.** The source of truth for what Magik is. Everything else in `docs/`
> elaborates on this file; nothing contradicts it.
>
> **Status:** spec only. Nothing in this document is implemented. `As of 2026-08-26` the repository
> contains a name-reservation gem and documentation; no construct, guardrail or command described
> below exists ([`../../wiki/Known-Gaps.md`](../../wiki/Known-Gaps.md)).

## How to read this file

v1 was the spec as authored and was kept verbatim. It has now been amended, because writing the
reference app and auditing the spec against a real SaaS surface found gaps that are **free to close
today and a breaking change to close after release** — there is no implementation, no user and no
semver obligation `as of 2026-08-26`.

The original text is the owner's and its authority matters, so **nothing here is silently rewritten**:

| Rule | Detail |
|---|---|
| Original text is intact | every sentence of v1 is still present, in its original section and order |
| Every change is marked | an amendment is a `**Amended 2026-08-26 (An):**` block, inline, immediately after the text it touches |
| Every change is attributable | each block carries a one-line reason and a link to the document that found it |
| Every replacement records what it replaced | where an amendment changes existing words, the block ends with **`*was*, verbatim from v1:`** and a fenced block holding the exact original line |
| The original is reconstructible | mechanically: replace each amended line with the contents of its `was` fence, delete every `**Amended …**` block, delete every section marked *(added by amendment)*, and restore the v1 header note to the top. That yields v1. **Nine lines** are replaced, recorded in **eight** `was` fences (one fence covers the two adjacent architecture decisions A18 changes); everything else in this file is additive |

| Amendments are argued, except where they are measured | **A18 and A19 are the only two derived from running code** rather than from reasoning about the spec. They are dated and re-derivable, and a future runtime release could reverse either |

The changelog below is the complete list. If an amendment is not in it, it is not an amendment.

## Amendment changelog — 2026-08-26

| # | Section | What changed | Why | Found by |
|---|---|---|---|---|
| A1 | Mission | the 99% claim is restated as a target the phases are sequenced to reach, with the audit named as the measurement | not defensible as a claim about today: 12 of 68 surfaces covered, 15 partial, 40 absent, 1 contradictory | [`10-saas-coverage.md`](10-saas-coverage.md) |
| A2 | Architecture decisions | new decision 13 — authorization is evaluated in exactly one place | it is an architecture decision, not a battery; its neighbours are all of that weight | [`10-saas-coverage.md`](10-saas-coverage.md) |
| A3 | Phase 1 | `:file` and `:duration` field types; `computed(:name, :type) { }` named with its parsing spelling | Shrine is on the wrap list with nothing calling it; `computed` was used by the reference app and never spelled in the spec | [`10-saas-coverage.md`](10-saas-coverage.md) · [`../../dummy/README.md`](../../dummy/README.md) |
| A4 | Phase 1 | `magik describe` added to the CLI | the error contract already prescribes `fix: magik describe …` for a command the spec does not name | [`11-dsl-as-tool-surface.md`](11-dsl-as-tool-surface.md) |
| A5 | Phase 2 | **`policy` added as a new primitive**, in phase 2, evaluator at tier 1 | the most serious gap: absent, unretrofittable, a security property, and already invented three incompatible ways in the reference app | [`10-saas-coverage.md`](10-saas-coverage.md) |
| A6 | Phase 2 | **`layout` added**, plus layout primitives in the component kit and responsiveness as a stated property | the kit had twelve things that go *inside* a page and nothing that *is* one; it voids the headline success criterion | [`10-saas-coverage.md`](10-saas-coverage.md) |
| A7 | Phases 1–9 | one line per phase for each gap the audit classified (a) — in scope, existing phase | so this file and [`06-phases.md`](06-phases.md) agree; the designs stay in the audit | [`10-saas-coverage.md`](10-saas-coverage.md) |
| A8 | Phase 4 | `retry` → **`retries`**; `unique_by` → `idempotent_by`; `every:` takes a duration string | `retry` is a Ruby keyword and does not parse; the other two are spelling decisions D4 and D1 | [`../../dummy/README.md`](../../dummy/README.md) · [`11-dsl-as-tool-surface.md`](11-dsl-as-tool-surface.md) |
| A9 | Phases | **Phase 4b — Media** added between phases 4 and 5 | ecommerce and marketplaces are two of the four verticals the mission names, and both are blocked | [`10-saas-coverage.md`](10-saas-coverage.md) |
| A10 | Phases 6, 7 | one field-subset vocabulary on `api`, `admin_panel` and the kit; `admin_panel` expanded to a detail view, associations, forms and bulk actions | four spellings of "which fields participate"; and the specced admin is a third of an admin | [`11-dsl-as-tool-surface.md`](11-dsl-as-tool-surface.md) · [`10-saas-coverage.md`](10-saas-coverage.md) |
| A11 | Phase 7 | `session_ttl` and `trial` take durations; `policy:` on `admin_panel`; security defaults named | spelling decision D1, and an unprotected admin was a boot failure no app could avoid | [`11-dsl-as-tool-surface.md`](11-dsl-as-tool-surface.md) · [`10-saas-coverage.md`](10-saas-coverage.md) |
| A12 | Libraries to Wrap | a media service added; the wrapped-vs-seam distinction stated | transcoding is a specialist product; a framework that builds one has become a media company | [`10-saas-coverage.md`](10-saas-coverage.md) |
| A13 | Guardrails | `policy`, `layout` and upload guardrails added; `MAGIK_ADMIN_UNPROTECTED` retired | it named "a declared access rule" the grammar could not express — a guardrail no app could satisfy | [`10-saas-coverage.md`](10-saas-coverage.md) |
| A14 | Success criteria | a sixth criterion, and the fourth executable `1.0` proof — a generated app is safe and usable on its first run | the other three can all be true of an app that is insecure and unusable | [`10-saas-coverage.md`](10-saas-coverage.md) |
| A15 | Build order | `policy` and `layout` at step 3, `magik describe` at step 2, media as step 8 | anything that wraps every surface must land before the surfaces multiply | [`10-saas-coverage.md`](10-saas-coverage.md) |
| A16 | **New section** — DSL spelling decisions | the four R1 inconsistencies decided, and three non-parsing spellings corrected (a third was found while applying this amendment) | a renamed option is a breaking change after release and free before it | [`11-dsl-as-tool-surface.md`](11-dsl-as-tool-surface.md) · [`../../dummy/README.md`](../../dummy/README.md) |
| A18 | Architecture decisions **1 and 2**, and Phase 9's runner | concurrency becomes **real parallel OS threads**, not Ractors/Fibers; the server becomes **Puma**, not Falcon; Phase 9's "one Ractor per test file group" becomes "one worker". TruffleRuby is kept | **measured:** TruffleRuby 24.2.1 has no `Ractor` and no fiber scheduler, so `async` — and therefore Falcon — cannot boot; its threads are genuinely parallel (3.54×) where MRI's are not (0.94×) | [`../../scripts/probes/runtime.rb`](../../scripts/probes/runtime.rb) · [`../architecture/12-runtime-verification.md`](../architecture/12-runtime-verification.md) |
| A19 | Libraries to Wrap | `Falcon/Async (server)` → `Puma (server)`; `Oj` flagged as engine-dependent and therefore a seam | same measurement as A18; and `Oj` is a C extension that does not name TruffleRuby, while `ruby/json` selects a pure-Ruby generator when `RUBY_ENGINE == "truffleruby"` | [`../../scripts/probes/runtime.rb`](../../scripts/probes/runtime.rb) · [`../architecture/10-performance-defaults.md`](../architecture/10-performance-defaults.md) |
| A17 | **New section** — deliberately deferred | `magik mcp` recorded as deferred, with the condition for revisiting | it wraps five commands that do not exist, and unlike `policy` it is not a retrofit | [`11-dsl-as-tool-surface.md`](11-dsl-as-tool-surface.md) |

### The v1 header note, kept

The note below opened v1. It is kept as the record of *why* two spellings were wrong and how that was
found. The spellings themselves are now corrected in the body (A8, A16) rather than only flagged here.

> **Two DSL spellings in this file do not parse as Ruby**, found by writing the reference app
> against them: `retry` is a Ruby keyword (the DSL spells it `retries`), and
> `computed :name, :type { ... }` binds the brace block to the symbol, not the call
> (`computed(:name, :type) { ... }`). The text below is left as authored; the corrections and
> how they were found are in [`dummy/README.md`](../../dummy/README.md). Derived docs use the
> parsing spellings.

## Mission
Build **Magik**: an opinionated, full-stack Ruby framework on TruffleRuby. One DSL for models, screens (UI), actions (mutations), realtime channels, background jobs, ledgers (money), APIs, and admin panels. No separate frontend framework — server renders HTML, htmx handles interactivity. Target: covers 99% of SaaS use cases (CRUD apps, dashboards, fintech, ecommerce, marketplaces) without the user needing to "graduate" to another stack.

**Amended 2026-08-26 (A1):** the last sentence is a **target the phases below are sequenced to
reach**, not a description of where the spec stands. It reads:

> **The target: express 99% of SaaS use cases — CRUD apps, dashboards, fintech, ecommerce,
> marketplaces — in one grammar, so that no app has to "graduate" to another stack.** The named
> exclusions are permanent and listed in [`05-limits.md`](05-limits.md). Where the spec stands
> against that target is a measured question, not a rhetorical one: audited across 68 surfaces a
> SaaS needs across its whole life, the grammar as specified fully covers 12, partially covers 15,
> is silent on 40, and contained 1 surface specified as a guardrail the DSL could not satisfy —
> **under a fifth**, `As of 2026-08-26`. The amendments in this file close the three that force a
> graduation. The rest is the work. The measurement, and the command that re-derives it, is
> [`10-saas-coverage.md`](10-saas-coverage.md); re-run it rather than trusting this paragraph.

Reason: the audit found the claim not defensible as stated, and it is the sentence a user believes
when choosing a framework. The ambition is kept; the tense is corrected.
*was*, verbatim from v1:

```text
Target: covers 99% of SaaS use cases (CRUD apps, dashboards, fintech, ecommerce, marketplaces) without the user needing to "graduate" to another stack.
```

## Non-negotiable Architecture Decisions
1. **Runtime**: TruffleRuby. Concurrency via **real parallel OS threads** — not Ractors, not Fibers. (A18)
2. **Server**: Rack + **Puma**, thread-per-request. (A18)
3. **DB**: Sequel (not ActiveRecord). Explicit queries, no lazy-loading magic.
4. **No SPA framework.** UI = server-rendered HTML + htmx attributes, compiled from DSL. No React/Vue/Ember, ever.
5. **Realtime is opt-in per screen**, not global. Default = plain request/response. `live`/`channel` declarations turn a screen/model realtime. No cost unless declared.
6. **No offline support.** Server is always the single source of truth. State this limit explicitly in docs.
7. **No heavy client-side compute** (canvas editors, games) — out of scope, say so.
8. **Multi-tenant by default.** Every model auto-scoped by `tenant_id`. UUIDv7 primary keys (sortable, shard-safe) from day one.
9. **Stateless app servers.** No in-process session/UI state — enables "add more servers" scaling.
10. **Money type**: integer-cents backed `:money` field type. Floats forbidden for currency at the type-system level.
11. **Swap points required for every "opinionated default."** DB engine, cache backend, job backend, search backend, realtime backend must be config-switchable without app code changes. (Lesson from Meteor's death: magic with no escape hatch = eventual rewrite.)
12. **Domain module system** for large apps: `domains/<name>/domain.rb` declares `depends_on`, `exposes`, `publishes_events`. Boot-time enforcement — a domain cannot access another domain's models directly, only via published interface or event subscription.

**Amended 2026-08-26 (A18):** decisions **1 and 2** are changed. This is the largest amendment in this
file and **the only one backed by a measurement rather than an argument.** The runtime is kept; the
mechanism changes.

> 1. **Runtime**: TruffleRuby. Concurrency via **real parallel OS threads**, not Ractors or Fibers.
> 2. **Server**: Rack + **Puma**, thread-per-request.

**What was measured**, on this machine, `As of 2026-08-26`. Do not trust the table — re-derive it:
`ruby scripts/probes/runtime.rb --json`, once per engine.

| Probe | CRuby 3.2.3 | TruffleRuby 24.2.1 |
|---|---|---|
| `Ractor` | works | **`NameError: uninitialized constant Ractor`** |
| `Fiber.set_scheduler` | present | **absent** |
| `async` 2.45.0 | runs | installs, then **`NoMethodError: undefined method 'scheduler' for class Fiber`** on the first `Async{}` |
| 4-thread SHA256 speedup, 12 cores | **0.94×** — the GVL | **3.54×** — genuinely parallel |

Two facts follow, and both are about v1 being **internally inconsistent** rather than merely unverified:

- **Item 1 named Ractors, which do not exist on the runtime item 1 selects.**
- **Item 2 named Falcon, which is built on `async` and cannot boot on TruffleRuby at all.** `async`
  raises on the first reactor, so this is a failure rather than a gap. A framework whose second
  non-negotiable decision names a server that cannot start on its first non-negotiable decision's
  runtime has a contradiction, not a risk.

**Why the fix keeps the runtime and changes the mechanism.** v1's stated *reason* for rejecting
threads-per-request is that MRI threads do not run in parallel. On TruffleRuby they do — 3.54× on four
threads — so **the goal item 1 was written to reach is met by the mechanism item 1 ruled out.**
TruffleRuby's own compatibility documentation says the same thing: *"Threads are run in parallel on
TruffleRuby and Threads are far more compatible with gems than `Ractor`."* Thread-per-request is the
correct server model precisely when threads are parallel, which is why item 2 becomes Puma. **Falcon
returns as an option the moment TruffleRuby implements the fiber scheduler** — nothing here is a
judgement about Falcon.

**The open cost, named rather than papered over.** A fiber is cheap per idle connection; an OS thread
is not. Realtime — `live` and `channel` over `LISTEN`/`NOTIFY`, phase 3 — means **many mostly-idle open
connections, which is exactly the workload fibers were chosen for.** This is an **open question with a
measurement owed**, not a solved problem: *how many concurrent idle SSE or WebSocket connections does
one Puma process sustain on TruffleRuby, and at what memory cost per connection?* Until that number
exists, decision 5 — realtime is opt-in per screen — is carrying more weight than it was designed to
carry. Nothing in this spec should be read as claiming the question is answered.

**Independent corroboration, from before the probe existed.**
[`../architecture/11-jobs-backend.md`](../architecture/11-jobs-backend.md) already reasoned its way to
half of this: *"On TruffleRuby, threads run genuinely in parallel. **Fibers do neither** … a framework
that says 'concurrency via Fibers, not threads' has quietly made CPU-bound work a different category of
thing, and the framework has to say so."* That page reached the conclusion from the jobs side and kept
the fiber design anyway, because the spec said so. It now needs revising with the rest — its "Fibers
and Falcon" section is the largest single consequence of this amendment outside this file.

**Provenance and staleness.** Method, full results and the CI matrix:
[`../architecture/12-runtime-verification.md`](../architecture/12-runtime-verification.md). Probe:
[`../../scripts/probes/runtime.rb`](../../scripts/probes/runtime.rb). Both facts are engine-version
specific and dated `As of 2026-08-26` — a TruffleRuby release could restore `Ractor`, add the fiber
scheduler, or both, and reverse either half of this amendment. **The probe is the mechanism for
noticing.** A claim about the runtime that is not re-derivable from it does not belong in this file.

*was*, verbatim from v1:

```text
1. **Runtime**: TruffleRuby. Concurrency via Ractors/Fibers, not threads-per-request.
2. **Server**: Rack + Falcon (async, fiber-based).
```

**Amended 2026-08-26 (A2):** decision 13 is added.

> 13. **Authorization is evaluated in exactly one place.** Every surface that reaches a model — a
>     screen, an action, an API resource, a realtime channel, a job and the admin panel — names a
>     verb in a `policy` and the framework evaluates it. There is no second door to the data and no
>     per-surface check. Because `render` and `realtime` must evaluate it, **the evaluator sits at
>     tier 1** — below `model`, `render` and `realtime` — and takes the actor as an opaque value;
>     `auth` at tier 3 supplies that value and never decides
>     ([`../architecture/01-module-map.md`](../architecture/01-module-map.md)). Authorization is
>     **not** a swap point: a second authorization backend is a second authorization system, which
>     is the failure this whole design is organised against ([`04-swap-points.md`](04-swap-points.md)).

Reason: `auth` explicitly disclaims authorization and nothing else owned it, so the reference app
invented it three incompatible ways — `dummy/app/actions/issue_invoice.rb:30`,
`dummy/app/actions/record_payment.rb:31` and `dummy/app/channels/invoices.rb:26`, all different
arities, none of them in the grammar. Two authz systems is how Meteor-shaped frameworks died, and
decision 11's own reasoning is the argument. Source: [`10-saas-coverage.md`](10-saas-coverage.md) §b1.

## Core DSL Surface (build in this order)

### Phase 1 — Foundation
- `App.define :Name do ... end` — app composition root
- `model :Name do field/belongs_to/has_many/validate/scope end` — wraps Sequel
- `migrate :Name do up/down end` — schema DSL over Sequel migrations
- Money type, UUID v7 id strategy, tenant_id auto-injection
- `magik new`, `magik generate model/screen/action`, `magik console`, `magik server` CLI

**Amended 2026-08-26 (A3):** the `model` line reads
`model :Name do field/computed/belongs_to/has_many/validate/scope end`, and the type list gains two
members:

- **`:file`** — an attachment, with `max_size:` and `content_types:` **required**. Shrine was already
  on the wrap list with nothing calling it, and a field type added later is a migration for every app
  that worked around its absence. The rest of media is phase 4b (A9).
- **`:duration`** — a unit-suffixed string coerced at boot (`"14d"`, `"10m"`, `"90s"`). `:money`'s
  sibling: a duration is a type, not a convention, so a malformed one fails at boot rather than at
  first use. This is spelling decision D1 (A16).
- **`computed(:name, :type) { ... }`** — a derived field. Named here with its parsing spelling; the
  v1 header note recorded that `computed :name, :type { ... }` binds the block to the symbol, but the
  body never spelled the declaration at all, so there was nothing to correct. The reference app uses
  it in five files.

Reason: [`10-saas-coverage.md`](10-saas-coverage.md) items 38 and 30; [`../../dummy/README.md`](../../dummy/README.md).
*was*, verbatim from v1:

```text
- `model :Name do field/belongs_to/has_many/validate/scope end` — wraps Sequel
```

**Amended 2026-08-26 (A4):** the CLI line gains `magik describe`.

> `magik describe [construct[.declaration]] [--json]` — **the grammar, as data.** Every construct,
> every declaration, every option with its type, default, allowed value set and the `MAGIK_*` codes
> it can raise. It answers about the grammar, so it needs no app, no boot and no database, and works
> in an empty directory. It is **derived from the option tables the DSL validates against**, never
> hand-maintained — two tables drift, one cannot. It is not `magik registry`, which reports what an
> app declared.

Reason: the error contract in [`../architecture/03-error-codes.md`](../architecture/03-error-codes.md)
already prescribes a runnable `fix:` line on every failure, and the natural fix for an option-level
error is a lookup command this spec did not name — the same shape of unsatisfiable contract as
`MAGIK_ADMIN_UNPROTECTED` (A13). It also gives the option table a named consumer, without which the
table gets built as prose. It adds a command, not a construct, so it costs nothing on the axis
[`07-ai-first.md`](07-ai-first.md) budgets. Full argument and recommendation: A17 and
[`11-dsl-as-tool-surface.md`](11-dsl-as-tool-surface.md) §2.

**Amended 2026-08-26 (A7):** phase 1 also carries, one line each — designs are in
[`10-saas-coverage.md`](10-saas-coverage.md), not here:

- `searchable` declarations on `model` and `Model.search`, over the existing search seam
- soft delete / archive / restore as a model annotation, with scopes excluding archived rows
- an `environment` block inside `App.define` selecting seams per environment (`App.define` is already
  the only place a backend is named; a second namer would break the rule that makes the seam analysable)
- liveness and readiness endpoints, `magik migrate` as a deploy gate, drain semantics

### Phase 2 — Rendering & Actions
- `component :Name do prop; body do ... end end` — reusable UI DSL, compiles to HTML+htmx attrs
- `screen :Name do state/body end` — page-level component, auto-routed
- `action :name do |params| ... end` — mutation handler, auto-wired to htmx POST
- Component kit: `button, form, field, data_table, modal, toast, card, list, grid, tabs, stat, chart`
- Theme system: design tokens, light/dark mode via CSS vars

**Amended 2026-08-26 (A5):** **`policy` is a new primitive and it lands here, not with `auth` in
phase 7.**

> - `policy :Model do default :deny; can :verb do |actor, record| ... end end` — one authorization
>   rule set. Predicates are pure: no queries, no I/O, because a `live` screen re-evaluates one per
>   subscriber per change. A `nil` record denies.
> - `roles` and `staff_roles` on `App.define` — the role set, declared once beside the actor. Staff
>   are a separate axis: a support engineer is not a member of the tenant they are helping.
> - Every surface **names a verb** instead of writing a check — `screen :Invoices, policy: %i[Invoice read]`,
>   `action :issue_invoice, policy: %i[Invoice issue]`, `channel`, `job`, `api resource`,
>   `admin_panel`. Opting out is a declaration too: `policy: :public`, `policy: :system`.

Two properties of this amendment are load-bearing and must not be traded away:

| Property | Why |
|---|---|
| **Phase 2, not phase 7** | a screen and an action are the first two surfaces that need it. Adding a `policy:` argument to six constructs after all six exist is precisely the retrofit this spec calls "a migration nobody survives" when it says it about tenancy (decision 8). Before `auth` ships the actor is whatever the app resolves; after it, `auth` supplies it, and nothing in the policy layer changes at the handover — which is the test that the tier split is right |
| **Evaluator at tier 1, not beside `auth` at tier 3** | `render` and `realtime` are tier 2 and must evaluate policies, and imports go strictly down ([`../architecture/01-module-map.md`](../architecture/01-module-map.md)). A tier-3 evaluator is unreachable from the two surfaces that need it most. `policy` at tier 1 takes the actor as an opaque value, exactly as `router` at tier 1 takes a path without knowing what a screen is |

Cost, stated honestly: one construct, one subsystem, one tier, five error codes, and a `policy:`
argument on six existing constructs. The alternative is not zero — it is every app inventing
`authorize`, which is more surface to learn and none of it checkable. Guardrails: A13. Drafted Ruby:
[`02-dsl-surface.md`](02-dsl-surface.md#policy). Argument: [`10-saas-coverage.md`](10-saas-coverage.md) §b1.

**Amended 2026-08-26 (A6):** **`layout` is a new primitive, and the component kit gains layout
primitives and responsiveness as a stated property.**

> - `layout :Name do sidebar / topbar / content / responsive end` — the application shell. A screen
>   names one (`screen :Invoices, layout: :App, parent: :Dashboard`); opting out is written down
>   (`layout: :None`). `magik new` generates a working `:App` layout, so **a generated app has a
>   sidebar on its first run**.
> - The component kit line reads: `button, form, field, data_table, modal, toast, card, list, grid,
>   tabs, stat, chart, sidebar, topbar, nav_item, breadcrumbs, account_menu, dashboard_grid`.
> - **Every kit component is responsive by construction, and no app-authored declaration is required
>   to make a screen work on a phone.** That is a claim to be tested, not asserted: `render_screen … at: :mobile`
>   and a phase-2 exit criterion that the generated app renders correctly at 375px. The one place it
>   costs the author a line is `data_table` on a narrow screen, which becomes a **card list**, never a
>   horizontal scroll.

Reason: `sidebar`, `app shell`, `breakpoint` and `breadcrumb` occurred zero times in the repository,
and `dummy/`'s two screens have no way to link to each other because the grammar has no nav. This
does not block capability — it **voids the headline success criterion below**, since "zero
HTML/JS/CSS written" is false the first afternoon somebody needs a sidebar, and the audience
[`01-thesis.md`](01-thesis.md) names leaves quietly over exactly that. `layout` is a new
*declaration*, not a second override system: its pieces are kit components with contracts, so all
four rungs of [`08-component-overrides.md`](08-component-overrides.md) apply unchanged. It respects
both permanent limits — a collapsing sidebar is a media query plus one htmx target. Argument:
[`10-saas-coverage.md`](10-saas-coverage.md) §b2.
*was*, verbatim from v1:

```text
- Component kit: `button, form, field, data_table, modal, toast, card, list, grid, tabs, stat, chart`
```

**Amended 2026-08-26 (A7):** phase 2 also carries, one line each:

- `data_table` fully specified — cursor pagination on `(sort_key, id)`, sorting, filters with URL
  state, bulk selection encoded in the request, column control, export, narrow-screen mode. It is the
  most-used component in any SaaS and was specified in less detail than `pwa`
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

**Amended 2026-08-26 (A7):** a channel evaluates **the same `policy` verb as the request path**.
There is no second door to the data — that is the Meteor lesson stated as a phase requirement rather
than as prose. Source: [`10-saas-coverage.md`](10-saas-coverage.md).

### Phase 4 — Jobs & Async
- `job :Name do retries times:, backoff:; schedule cron:/every:; idempotent_by; perform do |args| end end`
- Postgres-backed transactional queue (Que-style) by default, swappable to Kafka
- `magik worker` process, horizontally scalable

**Amended 2026-08-26 (A8):** three corrections to the `job` line.

| Change | Reason |
|---|---|
| `retry` → **`retries times: 5, backoff: :exponential`** | `retry` is a Ruby keyword; `retry times: 5` is a `SyntaxError`, not a method call. Verified by `ruby -c` on the reference app ([`../../dummy/README.md`](../../dummy/README.md)). The v1 header note flagged it; this corrects it in the body |
| `unique_by` → **`idempotent_by`** | spelling decision D4 (A16) |
| `schedule every:` takes a `:duration` | spelling decision D1 (A16) — `every: "10m"`, never `every: 15.minutes` |

*was*, verbatim from v1:

```text
- `job :Name do retry; schedule :cron/:every; perform do |args| end end`
```

**Amended 2026-08-26 (A7):** phase 4 also carries CSV and spreadsheet import and export as job
factories with a progress surface.

### Phase 4b — Media *(added by amendment)*

**Amended 2026-08-26 (A9):** a new phase, between jobs and money.

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

**Why it is a phase and not a line item:** it spans four others — the field type is phase 1 (A3), the
upload component is phase 2, derivative generation and transcoding are phase 4 jobs, and signed
delivery is blocked on `policy` (A5). A capability whose value arrives only when all four have landed
is a phase; otherwise each phase ships its quarter and the app still cannot store a photo.

**Why it is not optional:** the mission sentence names ecommerce and marketplaces. There was no
`:file` type, no attachment declaration, no derivative pipeline and no transcoding answer, so two of
the four named verticals were blocked on constructs that did not exist. Source:
[`10-saas-coverage.md`](10-saas-coverage.md) §Media.

### Phase 5 — Money & Compliance (fintech-ready)
- `ledger :Name do account; entry do debit/credit/guard end end` — double-entry, boot-time balance validation, append-only
- `audited` + `immutable_after:` model annotations — automatic audit trail
- `idempotent_by` on actions — dedupes retried mutations
- `flow :Name do step ... end` — multi-step wizards (onboarding, KYC, checkout)

**Amended 2026-08-26 (A7):** phase 5 also carries, one line each:

- basis-point rate arithmetic as `:money`'s sibling, for tax and fees — the reference app already had
  to invent `tax_rate_bp` because `0.21` against cents reintroduces the error `:money` exists to remove
- GDPR subject export and erasure, **including** the interaction with `audited` and append-only
  ledgers — that collision is why it needs designing rather than adding
- retention policies and scheduled purge
- a staff-versus-customer dimension on the audit trail

### Phase 6 — API & Integration
- `api :V1 do resource :name do index/show/create/update/destroy end end` — REST, auto-paginate/filter/sort
- `webhook :incoming, :name do verify_signature; on :event end`
- `webhook :outgoing, :name do fires_on; deliver_to; sign_with end`
- Auth: `:bearer`, `:api_key`, `:jwt` (mobile), rate limiting by plan

**Amended 2026-08-26 (A10):** a `resource` declares field subsets in the **one vocabulary** used by
`admin_panel`, `data_table` and `screen` — `fields`, `filterable`, `sortable`, `searchable`,
`writable` — rather than `filter:`/`sort:`/`only:` as per-verb options. Spelling decision D3 (A16).

**Amended 2026-08-26 (A7):** phase 6 also carries API deprecation and sunset headers on a version,
and a webhook delivery log with replay and a customer-facing endpoint surface.

### Phase 7 — Auth, Billing, Admin (batteries)
- `auth do strategy; oauth_providers; two_factor end` — generates full auth flow (Rodauth-backed)
- `billing provider: :stripe do plans end` — subscriptions, trials, metered billing
- `admin_panel :Model, policy: %i[Model administer] do list do fields/filterable/searchable end; show; form end` — auto CRUD admin
- `tenant_by :subdomain` — multi-tenancy wiring

**Amended 2026-08-26 (A10 + A11):** the `admin_panel` line is replaced. Three changes:

| Change | Reason |
|---|---|
| `policy:` is required | benchmarked against [Avo](https://avohq.io), the admin is by construction the surface with the broadest data access in the application. An admin panel without a policy is a security hole with a nice table on top |
| `list_display`/`read_only` → `fields`/`writable`, inside a `list` block | spelling decision D3 (A16). `admin_panel` is a projection of `model`; its vocabulary is `api`'s |
| a `show` and a `form` block exist | `list_display` produced **a list**, and only one of Avo's four view types existed. An admin who can list orders and cannot open one is not an admin. `show` carries panels, tabs and a sidebar; `form` carries per-view field visibility |

Phase 7 also gains bulk actions with argument forms, typed filters, saved views, global search across
resources, admin dashboard cards, and impersonation with a mandatory audit record and a visible banner.
**What is kept unchanged, because it is the best property of the specced design:** admin actions
**are** the app's actions. `MAGIK_ADMIN_INLINE_MUTATION` forbids a second write path, so a Magik admin
cannot have a mutation the product does not have. Everything above is built on that.
*was*, verbatim from v1:

```text
- `admin_panel :Model do list_display; filterable; searchable end` — auto CRUD admin
```

**Amended 2026-08-26 (A11):** `auth`'s `session_ttl` and `billing`'s trial take a `:duration` —
`session_ttl "14d"`, `plan :starter, …, trial: "14d"`. Spelling decision D1 (A16). No `was:` line: the
spec's phase-7 bullets named neither option, so this amendment adds a spelling rather than replacing
one. The spellings it supersedes — `session_ttl "14d"` and `trial_days: 14` — are in
[`02-dsl-surface.md`](02-dsl-surface.md), which is updated to match.

**Amended 2026-08-26 (A7):** phase 7 also carries, one line each:

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
- feature flags as a **factory over `policy`**, once `policy` exists — a flag is an authorization rule
  whose subject is a cohort rather than a role

### Phase 8 — i18n, PWA, Notifications
- `locales :en, :es, ...`, `translatable: true` fields, timezone-safe `:timestamp` type
- `pwa do name/icon/display end` — installable, no offline caching
- `notification :name do channel :email, :in_app, :push end`

**Amended 2026-08-26 (A7):** phase 8 also carries, one line each:

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

**Amended 2026-08-26 (A18, consequence):** "one Ractor per test file group" becomes "one **worker**
per test file group", because **`Ractor` does not exist on TruffleRuby 24.2.1** — the same measurement
that forced decisions 1 and 2. Leaving the line as written would have the spec's testing phase
contradict its own first architecture decision.

What a worker *is* is deliberately not decided here, because it differs by engine and this file is not
where that gets designed:

| Engine | The mechanism available | Note |
|---|---|---|
| TruffleRuby (production) | a **thread** — threads are genuinely parallel, 3.54× on four | this is the same reason decision 1 changed |
| CRuby ≥ 3.2 (tooling, dev) | a thread does **not** parallelise CPU-bound work (0.94×), so the runner needs a **forked process** here | which means the runner has two mechanisms, and the isolation story has to hold under both |

**That two-mechanism problem is an open design question, not a decision**, and it is owed to
[`../architecture/04-testing-strategy.md`](../architecture/04-testing-strategy.md), which currently
specifies the Ractor design and needs revising. What this spec fixes is the false claim; what it does
not do is invent the replacement in a changelog entry. The 1,000-tests-under-10s target is unchanged
and remains a target that has never been measured.

*was*, verbatim from v1:

```text
- Parallel execution: one Ractor per test file group, `workers: :auto` (all CPUs), transactional rollback per test (no truncation)
```

**Amended 2026-08-26 (A7):** phase 9 also carries, one line each:

- `assert_queries(n) { ... }` — there is no specified way to assert the *absence* of an N+1
- email content assertions beyond `assert_notified` — subject, recipient, body text, links, and that a
  plain-text part exists
- **an authorization test generated per policy verb**, including a cross-tenant denial
- `render_screen … at: :mobile`, which is what makes A6's responsiveness claim testable rather than asserted

## DSL spelling decisions *(added by amendment)*

**Amended 2026-08-26 (A16).** [`11-dsl-as-tool-surface.md`](11-dsl-as-tool-surface.md) rule R1 —
*one concept, one spelling, everywhere* — found four concepts carrying more than one spelling, and
noted that each is free to settle now and a semver break to settle after release. They are settled
here. The rules cited are R1–R10 on that page.

### The three that do not parse

| Spelling | Correction | Evidence |
|---|---|---|
| `job :Name do retry ... end` | **`retries times: 5, backoff: :exponential`** | `retry` is a Ruby keyword; the call is a `SyntaxError`. Verified by `ruby -c` on `dummy/app/jobs/send_invoice_email.rb` |
| `computed :name, :type { ... }` | **`computed(:name, :type) { ... }`** | a brace block binds to the last method call, and `:money` is a symbol literal, so the block never reaches `computed` |
| an `attachment` block opened by a bare `do` on its own line, after a multi-line argument list | **the last argument and `do` share a line** — `… content_types: %w[…] do` | found the same way as the other two, by parsing the drafted DSL rather than reading it. This one was in the *proposed* `attachment` draft in [`02-dsl-surface.md`](02-dsl-surface.md), which A9 accepts into the spec, so it is corrected there `As of 2026-08-26`. Re-derive with: extract every ` ```ruby ` block from that file and run `ruby -c` over the concatenation |

The first two were flagged in the v1 header note and are now corrected in the body (A3, A8). The
header note is kept as the record of how they were found. **The general lesson holds and is worth
stating as a rule: a drafted DSL spelling is not designed until it has been parsed.** Three of three
non-parsing spellings were found by running a parser, and none by reading.

### The four R1 decisions

| # | Concept | Spellings before | **Decided** | Why |
|---|---|---|---|---|
| **D1** | A duration | `session_ttl "14d"` · `every: "10m"` · `trial_days: 14` (and `every: 15.minutes` in the wiki) | **a `:duration` type everywhere — a unit-suffixed string, coerced at boot.** `session_ttl "14d"`, `schedule every: "10m"`, `trial: "14d"`, `throttle per: "1h"` | the alternative — `*_days`/`*_ms` integers — puts the **unit in the option name**, so `retention_days:` and `retention_hours:` become two spellings of one concept, which is the per-name explosion R10 exists to prevent, and `"90s"` becomes inexpressible without a new option. R2 permits a free-form string where the space is genuinely open provided it carries a format check and a named error code, which a duration does. Making it a *type* rather than a String means a typo fails at boot, exactly as `:money` refuses a float (decision 10) — and `magik describe` can carry `"type": "duration"` with its grammar, so it stays discoverable (R6) |
| **D2** | A precondition | `guard { ... }` on a `ledger` entry · `if: ->(ctx) { ... }` on a `flow` step (and `guard: ->` in the reference app) | **`guard "reason" do ... end`, a declaration with a message and a block, on `ledger entry`, `action`, `job` and `flow step`.** A flow step that simply does not apply uses `skip_when do ... end` | R9 puts behaviour in blocks and options in keyword arguments, and a precondition is behaviour — it evaluates per posting, per request, per step. A lambda-in-an-option is also invisible to the schema (R6): `describe` can list a `guard`; it cannot describe what an arbitrary `if:` decides. The message is not decoration — R7 requires an error to name the specific cause, and a guard carrying its own sentence gives every failure one for free. The `skip_when` split is deliberate: `flow`'s `if:` meant *skip*, not *abort*, and collapsing two meanings into `guard` would trade one R1 violation for a worse one |
| **D3** | A field subset | `only: %i[…]` on `api create` · `filter:`/`sort:` on `api index` · `list_display`/`filterable`/`searchable`/`read_only` on `admin_panel` | **five declarations, one vocabulary, on `api`, `admin_panel`, `data_table` and `screen`: `fields`, `filterable`, `sortable`, `searchable`, `writable`** — variadic symbols, inside the construct's block, never per-verb options | there is not one concept here but five — shown, filtered, sorted, searched, written — so "one spelling" means **one word per role, identical across every surface**, not one word for all five. `writable` rather than `read_only` because a whitelist beats a blacklist and it is already what `only:` was. Declarations rather than options because they say *what*, which is R9's line, and because it makes `admin_panel` a projection of `model` in `api`'s vocabulary, which is what the audit asked for. `per_page:` stays an option — it is a scalar setting, not a field subset |
| **D4** | Uniqueness | `unique: true` on `field` · `unique_by :tenant_id` on `job` | **they diverge. `unique:` means a database uniqueness constraint and nothing else; the job option is renamed `idempotent_by`** | the two meanings cannot converge — a constraint and a dedupe key are different things — and R1 says sharing a stem while meaning different things is the worst of both. `unique: true` keeps its name because it is the spelling every ORM and SQL itself already uses; renaming it would be novelty at review-time cost (R4). The job's meaning — *a repeated request with the same key produces one effect* — is exactly what `action`'s `idempotent_by` already means, so this **removes** an option from the catalogue rather than adding one (R10), and leaves the `unique` stem with a single meaning |

**Flagged for the owner to overrule.** D4 is the one to argue with: `idempotent_by` on a job reads
slightly differently from `idempotent_by` on an action (do not enqueue a duplicate, versus return the
first result). The alternative is a third name such as `dedupe_by` used on both, which is more
accurate and costs a rename of `idempotent_by`, a term already in three phases of this spec. D2's
`skip_when` is the second: it adds one declaration to `flow` in order to keep `guard` unambiguous, and
a reader who thinks `flow` should simply not have a skip case should say so.

**Enforcement:** these are data, not prose. A `scripts/checks/` step over the option tables asserts
that every option in [`02-dsl-surface.md`](02-dsl-surface.md) appears in `magik describe --json` and
vice versa (A4). A convention that is not a check does not exist.

## Libraries to Wrap (don't reinvent)
Sequel (DB) · Que (jobs) · Rodauth (auth) · Shrine (uploads, S3) · money gem (currency) · htmx (client interactivity, ~14kb) · **Puma (server)** · Stripe/Paddle SDKs (billing) · pgvector (vector search) · Minitest (test core) · **JSON behind a seam** · Prawn (PDF) · OpenTelemetry Ruby (observability) · Anthropic/OpenAI SDKs (AI actions)

**Amended 2026-08-26 (A19):** two entries change, for the measured reason in A18.

| Was | Now | Why |
|---|---|---|
| `Falcon/Async (server)` | **`Puma (server)`** | Falcon is built on `async`, and `async` cannot start a reactor on TruffleRuby — verified, not assumed ([`../../scripts/probes/runtime.rb`](../../scripts/probes/runtime.rb)). Falcon is re-listed the day the fiber scheduler lands |
| `Oj (fast JSON)` | **`JSON behind a seam`** | `Oj` is a **C extension whose supported-platform list does not name TruffleRuby**, and `ruby/json` selects a pure-Ruby generator when `RUBY_ENGINE == "truffleruby"`. So "fast JSON" is not a fixed dependency on the production runtime; it is a swap point — `use :json, :auto \| :oj \| :stdlib`, as proposed in [`../architecture/10-performance-defaults.md`](../architecture/10-performance-defaults.md) |

Both are the same mistake in two sizes: **naming an engine-specific dependency as though the engine
choice did not constrain it.** Item 2 was the fatal version; `Oj` is the survivable one. The general
rule this amendment adds to the list: *a dependency that is a C extension, or that reaches for a
runtime primitive, is a candidate for a seam until a probe says otherwise on the production engine.*

*was*, verbatim from v1:

```text
Sequel (DB) · Que (jobs) · Rodauth (auth) · Shrine (uploads, S3) · money gem (currency) · htmx (client interactivity, ~14kb) · Falcon/Async (server) · Stripe/Paddle SDKs (billing) · pgvector (vector search) · Minitest (test core) · Oj (fast JSON) · Prawn (PDF) · OpenTelemetry Ruby (observability) · Anthropic/OpenAI SDKs (AI actions)
```

**Amended 2026-08-26 (A12):** add **a media service (Mux / Cloudflare Stream / Bunny) behind a
`use :media` seam** for video and audio, with `ffmpeg` in a job as the no-vendor backend.

Transcoding, HLS/DASH packaging, poster frames, waveforms and adaptive bitrate ladders are a
specialist product; a framework that builds one has become a media company. The `ffmpeg` path is
documented with its real costs — a CPU-bound multi-minute process on the app's own worker fleet, its
own queue, its own machine shape, and a malformed input as a remote-code-execution surface with a long
CVE history. Source: [`10-saas-coverage.md`](10-saas-coverage.md) §Media.

Note on the distinction this list does not draw: **wrapped libraries and swap points are not the same
thing.** Rodauth is a structural dependency of `auth`, not a backend behind an interface, and saying so
is more honest than pretending to a seam nobody could implement against. The seams are in
[`04-swap-points.md`](04-swap-points.md), which the audit added three rows to — a throttle store, a bot
challenge and media processing.

## Guardrails to Enforce at Boot (this IS the product)
- Ledger entries must balance (debits == credits) or boot fails
- No `field :card_number` type allowed — forces tokenized payment fields
- Domain boundary violations (cross-domain direct model access) fail at boot
- Screens/actions cannot hold in-process instance state across requests
- Timestamps cannot be rendered without explicit timezone conversion
- `magik check --scale` — warns on queries missing tenant_id in WHERE clause (pre-empts sharding pain)

**Amended 2026-08-26 (A13):** seven guardrail rows are added — eight `MAGIK_*` codes — and one code is retired. The full catalogue, with
its `fix:` lines, is [`03-guardrails.md`](03-guardrails.md); the additions each pass that page's four
bars — derivable from the frozen registry, consequential, unambiguous, fixable.

| Added guardrail | What fails | Code |
|---|---|---|
| **Every surface reaching a model names a policy verb** | a `screen`, `action`, `api resource`, `channel`, `job` or `admin_panel` with no `policy:` and no explicit `policy: :public` / `policy: :system` | `MAGIK_POLICY_UNDECLARED` |
| A policy predicate performs no I/O | a `can` block issuing a query — `live` re-evaluates one per subscriber per change, so a query here is one round trip per row per open socket | `MAGIK_POLICY_IO` |
| A named verb exists | `policy: %i[Invoice publish]` where `policy :Invoice` declares no `:publish` | `MAGIK_POLICY_UNKNOWN_VERB` |
| Denial is the default | a `policy` block with no `default :deny` | `MAGIK_POLICY_NO_DEFAULT` |
| A rule receiving a `nil` record denies | a row-level rule that would pass on an absent record | `MAGIK_POLICY_NULL_PASSES` |
| Every screen has a layout | a `screen` with no layout and no `layout: :None`; and a `nav_item` naming a screen that does not exist | `MAGIK_LAYOUT_MISSING` · `MAGIK_LAYOUT_UNKNOWN_SCREEN` |
| Uploads are bounded | a `:file` field or `attachment` with no `max_size` and no `content_types` — an unbounded upload field is an unbounded storage bill and a trivial DoS | `MAGIK_MODEL_UNCONSTRAINED_UPLOAD` |

`MAGIK_POLICY_UNDECLARED` is the load-bearing one. It makes authorization non-optional the way
`tenant_id` is non-optional, which is the only mechanism that survives an agent in a hurry.

| Retired | Why |
|---|---|
| **`MAGIK_ADMIN_UNPROTECTED`** | it required "a declared access rule" that the grammar had no way to express, so it could only ever fail or be quietly dropped — meaning `admin_panel` **as specified could not legally boot**. It becomes a special case of `MAGIK_POLICY_UNDECLARED`. A guardrail catalogue containing a rule no app can satisfy was the strongest available internal evidence that a primitive was missing |

## Success Criteria
- New CRUD SaaS screen: model + screen + action in <30 lines, zero HTML/JS/CSS written
- Full test suite of 1,000 tests: parallel, all cores, <10s target
- Fintech-grade money handling (ledger, audit, idempotency) available with same DSL grammar as everything else — no separate "fintech mode"
- Every "opinionated default" has a working, tested config-level swap (proven before merge, not promised)
- Explicit documented limits: no offline, no heavy client-side compute — do not silently fail on these, refuse/clarify in docs

**Amended 2026-08-26 (A14):** a sixth bullet is added — the **fourth executable proof** required
for `1.0.0`, beside the three [`../../ROADMAP.md`](../../ROADMAP.md) already names — and the first
bullet is noted as depending on A6.

> - **A generated app is safe and usable on its first run**, proven by three tests rather than a
>   document: a cross-tenant actor is denied by **every** generated surface — screen, action, API
>   resource, channel and admin panel; the generated application shell renders correctly at 375px;
>   the generated signup form throttles and does not reveal whether an account exists.

Reason: the five criteria above can all be true of an application that is insecure and unusable. Each
clause here is a test rather than a document, which is the standard the others already meet.

Note on the first criterion: **"zero HTML/JS/CSS written" was false as specified** the moment an app
needed navigation, because the grammar had no way to declare any. A6 is what makes it true for a
product rather than for one form. Source: [`10-saas-coverage.md`](10-saas-coverage.md) and
[`../../ROADMAP.md`](../../ROADMAP.md).

## Build Order
1. Rack app skeleton + `App.define` boot process + Sequel connection
2. `model` DSL → Sequel mapping, migrations
3. `screen`/`component`/`action` DSL → HTML+htmx compiler
4. Router (convention: action name → path) + dev server + hot reload
5. Test DSL + Minitest wrapper + parallel runner (build this early — TDD the rest)
6. Realtime (channel/live/broadcast) over Postgres LISTEN/NOTIFY
7. Jobs (Postgres-backed queue)
8. Ledger + audited/immutable primitives
9. Auth + billing + admin_panel scaffolds
10. API/webhook DSL
11. i18n/PWA/notifications
12. Domain module system + boot-time enforcement + `magik check` linter

**Amended 2026-08-26 (A15):** three insertions. The ordering principle is that **anything wrapping
every surface must land before the surfaces multiply** — both new primitives are wrapping concerns and
both get exponentially more expensive per step that ships without them.

| Insert | Where | Why not later |
|---|---|---|
| `magik describe` and the option tables it serializes | with step 2, as the first construct's tables are written | the tables are what the coercer, the guardrails, the docs anchors and `describe` all read (R8). Retrofitting an option-table representation onto constructs already implemented is the same shape of migration as retrofitting `policy:` |
| **`policy` and `layout`** | **step 3**, alongside `screen`/`component`/`action` | a screen and an action are the first two surfaces needing authorization and the first thing needing a shell. Every screen written before `layout` exists has no home for its navigation, and adding a `policy:` argument to six constructs after six constructs exist is the retrofit this spec calls unsurvivable |
| **Media** | a new step **8**, after jobs and after `policy` (renumbering 8–12 to 9–13) | derivative generation is job work and signed delivery is blocked on `policy`. Landing media before either produces an upload feature with no processing and no access control |

The build order and the phase list disagree in one place on purpose — step 5 builds phase 9 early so
the rest is TDD'd. **Where they disagree, build order wins**; the full mapping is
[`06-phases.md`](06-phases.md).

## Deliberately deferred *(added by amendment)*

**Amended 2026-08-26 (A17).** [`11-dsl-as-tool-surface.md`](11-dsl-as-tool-surface.md) proposes two
commands and correctly notes that neither can reach `lib/` until this file names them. One is added
(A4); the other is deferred, and recording the difference is more useful than adding both.

| Proposal | Decision | Reasoning |
|---|---|---|
| **`magik describe`** | **added — phase 1, A4** | it is not a nicety. The error contract already prescribes a runnable `fix:` for every failure and had no command to point an option-level error at; the option table has no named consumer without it; and it costs a *command*, not a construct, so it is free on the axis the AI-first thesis actually budgets. It is also the mechanism the whole design leans on: a DSL's cost to an author is **recall**, and recall is the one cost automation removes — but only if the surface is lookupable |
| **`magik mcp`** | **deferred, not rejected** | three reasons, in order of weight. **(i)** It is strictly a second front end over `describe`, `docs`, `check --json`, `registry`, `routes` and `explain` — five of which do not exist. A wrapper specified before the things it wraps is specified against guesses. **(ii)** Its own design page states the honest limit: *where an agent has a shell, the CLI is the better path*. Today every agent working on Magik has a shell, so the marginal capability is zero. **(iii)** Decisively, **it is not a retrofit.** `policy` had to land in phase 2 because it adds an argument to six constructs; `magik mcp` adds an argument to nothing — it reads `--json` outputs that already have an additive-only stability contract. Deferring it costs a later release, not a migration, and applying the retrofit argument reflexively here would cheapen it where it is real |

**The condition for revisiting `magik mcp`:** once `magik describe`, `magik check --json`,
`magik registry --json`, `magik routes --json` and `magik explain --json` all ship and their schemas
are stable across one release, the server is a thin, well-specified addition and should be argued for
then, on the evidence of those schemas. It stays **read-only** whenever it arrives — a mutating server
is a different product with different obligations (credentials behind a gateway, end-to-end identity,
synchronous audit) and would be a separate binary with a separate name.
