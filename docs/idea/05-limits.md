# Limits

What Magik will never do, why, and how each refusal is made loud rather than silent.

**Status:** spec only — these are permanent design decisions, not a backlog. None of the refusal mechanisms described here is implemented. Reviewed 2026-08-26.

## The rule about limits

From [`00-build-spec.md`](00-build-spec.md)'s success criteria:

> Explicit documented limits: no offline, no heavy client-side compute — **do not silently fail on these, refuse/clarify in docs**.

A limit that degrades quietly is worse than no limit: the app appears to work, ships, and fails on a customer's laptop. So every limit on this page gets one of two treatments, and the doc says which:

| Treatment | Meaning |
|---|---|
| **Refused** | there is a boot or check failure with a `MAGIK_*` code. The app does not start. |
| **Documented** | no mechanism can detect it, so the docs say no plainly and the framework ships nothing that would help. |

Nothing gets a third treatment. There is no "works but is discouraged".

## The list

Two kinds, and the distinction matters: an **architectural** limit is a property of how Magik is built and cannot change without building a different framework. A **product-scope** limit is a thing Magik could technically do and deliberately will not, because doing it well is a second product.

### Architectural

| Limit | Treatment | Code |
|---|---|---|
| [No offline](#no-offline) | Refused | `MAGIK_PWA_OFFLINE_UNSUPPORTED` |
| [No heavy client-side compute](#no-heavy-client-side-compute) | Documented | — |
| [No SPA framework](#no-spa-framework) | Documented, with one refused mechanism | `MAGIK_RENDER_CLIENT_STATE` |
| [No ActiveRecord](#no-activerecord) | Documented | — |
| [No RSpec](#no-rspec) | Documented | — |

### Product scope

Found by the coverage audit ([`10-saas-coverage.md`](10-saas-coverage.md)), which asked what a SaaS needs across its whole life and then asked which answers Magik should refuse to be. All six are **Documented** — no mechanism can detect them, so the docs say no plainly and the framework ships nothing that would help.

| Limit | Why it is a second product |
|---|---|
| [No email marketing or campaigns](#no-email-marketing-or-campaigns) | a different deliverability model, and mixing it with transactional mail damages both |
| [No native mobile application](#no-native-mobile-application) | `pwa` makes an app installable; there is no native shell and `channel :push` means web push |
| [No CMS or marketing-site authoring](#no-cms-or-marketing-site-authoring) | an editorial workflow and a page builder are not an application framework |
| [No ad-hoc BI or report builder](#no-ad-hoc-bi-or-report-builder) | `stat` and `chart` render declared queries; a semantic layer is an analytics product |
| [No workflow or BPM engine](#no-workflow-or-bpm-engine) | `flow` is a linear wizard, and stretching it produces a second, worse execution model beside `job` |
| [No multi-region or data residency](#no-multi-region-or-data-residency) | one Postgres, one region, tenancy by column |

---

## No offline

**The server is the single source of truth for every byte of state, always.** There is no client-side data store, no service-worker cache of application data, no queue of pending mutations, and no reconciliation on reconnect.

| Why | |
|---|---|
| Offline is a distributed systems problem, not a caching feature | it needs conflict resolution, causal ordering and a client-side authorization story. Each is a product. |
| Two sources of truth is two authorization systems | which is the failure that killed Meteor-shaped frameworks ([`01-thesis.md`](01-thesis.md)). |
| The 99% of SaaS the spec targets is online | dashboards, CRUD, fintech, ecommerce, marketplaces — all of them require the server to be reachable to be correct. |

The `pwa` construct exists and makes an app **installable** — an icon, a name, a standalone window. It does not make it work offline. Declaring an offline strategy fails at boot with `MAGIK_PWA_OFFLINE_UNSUPPORTED` rather than emitting a service worker that pretends ([`02-dsl-surface.md`](02-dsl-surface.md)).

What a Magik app does when the network drops: htmx requests fail, and the framework shows a connection-lost state. That is the honest behaviour, and it is the designed one.

## No heavy client-side compute

**Canvas editors, games, video processing, 3D, real-time drawing and anything else whose work must happen at 60fps in the browser are out of scope.** The client story is ~14kb of htmx swapping server-rendered fragments; that is the whole budget.

| Why | |
|---|---|
| The rendering model is server-authored HTML | a framework that compiles declarations to markup cannot also be a client runtime, and pretending otherwise produces two frameworks in one repo. |
| It is not the target | the spec's target is SaaS: CRUD apps, dashboards, fintech, ecommerce, marketplaces. |
| No mechanism can detect it | an app can always load its own JavaScript. Magik does not stop it and does not help it. |

### Where the line actually is

An ambiguous permanent limit is worse than a stricter one clearly stated, and this one has been read too broadly. **The test is whether client-side computation is the product's core value, not whether any JavaScript runs.**

| Out of scope — the compute *is* the product | Fine, and sometimes necessary — a small bounded widget |
|---|---|
| a canvas or vector editor, a game, an in-browser video or audio editor, a spreadsheet engine, a 3D viewer, a live-collaborative rich text surface | an avatar crop-and-scale before upload, a date picker, a colour picker, a masked input, a drag-to-reorder handle, upload progress on a direct-to-storage PUT |
| the app is unusable without it, it holds its own state model, and it owns a rendering path | it operates on one input, it hands its result to the server, it holds nothing across requests, and the page works without it |

The second column is not an exception to the rule — it is the rule read correctly. [`08-component-overrides.md`](08-component-overrides.md) already permits attaching your own JavaScript behaviour to server-rendered markup, and the framework itself ships one such asset: a small, versioned, non-bundled upload script on the same terms as htmx. **No toolchain, no bundler, no `node_modules`, and the app author still writes no JavaScript.**

**Documented, not refused.** If an app needs a canvas editor, the honest answer is that the editor is a separate front-end asset the app serves and Magik knows nothing about — and that Magik is the wrong framework if the editor *is* the product.

## No SPA framework

**No React, no Vue, no Ember, no client router, no hydration step, ever.** UI is server-rendered HTML plus `hx-*` attributes compiled from `component` and `screen` declarations.

| Why | |
|---|---|
| One rendering path | two means every feature is built twice and every authorization check has two homes. |
| No build step | no bundler, no `node_modules`, no toolchain between an edit and a reload — a first-order property for the audience and for the agent writing the code ([`07-ai-first.md`](07-ai-first.md)). |
| htmx is sufficient for the target | a swap of a server-rendered fragment covers the interactivity a SaaS screen needs. |

One piece of it **is** refused: a screen holding client-owned state that the server does not know about — the DSL provides no way to declare it, and a screen attempting to hold state across requests fails the stateless guardrail ([`03-guardrails.md`](03-guardrails.md)). Loading your own JavaScript for a date picker is fine and unpoliced; building your application's state model in the browser is not something the grammar can express.

## No ActiveRecord

**Sequel, explicit queries, no lazy loading.** The `model` DSL wraps Sequel and nothing else.

| Why | |
|---|---|
| Implicit lazy loading is an N+1 factory | the query an app runs should be visible in the code that runs it. |
| Callback chains are untraceable | a framework whose product is boot-time guardrails cannot have a mutation path nobody can statically follow. |
| Two ORMs is two migration stories | and two sets of generated SQL for an agent to learn. |

**Documented, not refused.** Nothing stops an app from adding the `activerecord` gem to its own `Gemfile`. Doing so means the tenant scoping, the `:money` type, the audit trail, the ledger guardrails and every generated test stop applying to those models — the framework's guarantees are properties of the `model` DSL, not of the database.

## No RSpec

**Minitest and Rake, in the framework and in generated apps.** The `test` DSL compiles to Minitest ([`../architecture/04-testing-strategy.md`](../architecture/04-testing-strategy.md)).

| Why | |
|---|---|
| Boot cost is a feature of the test loop | the target is 1,000 tests under 10 seconds; a heavier runner spends the budget before the first assertion. |
| A simple object model | a Minitest test is a method on a class. Running those in parallel worker threads with transactional rollback per test is tractable; against a DSL-heavy runner with its own lifecycle it is not. |
| One test grammar | `test :Name do it "…" end` compiles down to Minitest, so `assert_*` is always available underneath. There is no second way to write a test. |

**Documented, not refused.** An app that adds `rspec` to its own `Gemfile` can run it. What it will not get is `magik test`'s parallel runner, the transactional rollback, the inferred factories or the generated invariant tests — those are built on the Minitest layer.

---

## No email marketing or campaigns

**`notification` is transactional email.** Bulk campaigns, list management, drip sequences, segmentation and engagement tracking are not in scope and no construct will be added for them.

| Why | |
|---|---|
| Sharing a sending reputation is how a password reset lands in spam | transactional and marketing mail want different domains, different IPs and different warm-up. A framework that made them one construct would be making that mistake for every app that used it |
| The compliance surface is different | consent records, preference centres, jurisdiction-specific opt-in rules. Each is a product |
| The workflow is a product | a campaign editor, a schedule, an audience builder and a report are a marketing tool, not a framework feature |

The app's job is to keep the list in sync with a campaign provider. Suppression, unsubscribe tokens and bounce handling **are** in scope, because transactional mail needs them too.

## No native mobile application

**`pwa` makes an app installable — an icon, a name, a standalone window.** There is no native shell, no App Store artifact, no React Native or Flutter bridge, and `notification channel :push` means **web push**, not APNs or FCM through a native SDK.

| Why | |
|---|---|
| A native shell is a second rendering target | with its own store review, its own release cadence, its own crash reporting and its own version skew against the server |
| Web push is the honest subset | it works where the platform supports it and says so where it does not, rather than implying a native delivery path the framework does not have |

If the product needs a native app, the API in [`02-dsl-surface.md`](02-dsl-surface.md) is what it talks to, and the native client is somebody else's codebase.

## No CMS or marketing-site authoring

**Magik renders application screens for known actors.** There is no page builder, no editorial workflow, no content model for marketing pages, and no blog engine.

| Why | |
|---|---|
| The audiences are different | an application screen is authored by a developer in a declaration; a marketing page is authored by a marketer in a browser. Serving both means an admin UI for content, a preview pipeline and a publishing state machine |
| A static site is better at it | and it can sit in front of the app at the same domain |

Per-screen SEO metadata — title, description, canonical, Open Graph — is **not** covered by this limit and should exist: server-rendered HTML is indexable, so it costs a declaration.

## No ad-hoc BI or report builder

**`stat` and `chart` render queries the app declared.** There is no pivot table, no drill-down, no saved-query builder, no semantic layer and no end-user report designer.

| Why | |
|---|---|
| It is an analytics product | a query builder safe enough to expose to a customer needs its own permission model, its own cost controls and its own query planner |
| The escape is an export | (a) export to a warehouse or a spreadsheet, and let a tool built for it do the analysis |

## No workflow or BPM engine

**`flow` is a linear, resumable wizard** — onboarding, KYC, checkout. It is not a workflow engine: no parallel branches, no human task assignment, no compensating transactions, no visual designer, no long-running process state beyond the step token.

| Why | |
|---|---|
| It would be a second execution model | Magik already has `job` for durable work. A BPM engine beside it means two answers to "where does this run", which is exactly the ambiguity axiom 1 forbids ([`07-ai-first.md`](07-ai-first.md)) |
| Stretching `flow` is worse than refusing | a wizard that grew branches and compensations is a state machine nobody declared |

## No multi-region or data residency

**One Postgres, one region, tenancy by column.** Sharding, regional pinning, cross-region replication and per-tenant data residency are a deployment topology Magik does not model.

| Why | |
|---|---|
| It is a topology, not a feature | it changes the connection story, the migration story, the job story and the realtime story at once |
| The option is kept open, not delivered | UUIDv7 keys and `magik check --scale` exist so a future shard is possible. They are not a shard ([`../ops/README.md`](../ops/README.md)) |

---

## Saying no

The bar for adding to this page, so it stays a design document and not a wish list:

| Test | Question |
|---|---|
| Permanent | is this a "no", or a "not in phase 1"? A phase belongs in [`06-phases.md`](06-phases.md), not here. |
| Structural | does supporting it require a second rendering path, a second source of truth, or a second authorization system? |
| Loud | can it be refused with a code? If not, does the doc say no in a place the reader will actually hit? |
| Honest about the alternative | does the page name what the user should do instead, including "use a different framework"? |
