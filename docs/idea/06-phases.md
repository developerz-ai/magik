# Phases

The nine spec phases and the twelve-step build order, as a delivery plan: what each phase contains, what "done" means for it, and what it unblocks.

**Status:** spec only — nothing is in progress and no phase has started. Every phase below is `not implemented`. Reviewed 2026-08-26.

## Two orderings, and which one wins

[`00-build-spec.md`](00-build-spec.md) contains both a **phase list** (the DSL surface, grouped by capability) and a **build order** (twelve steps, the order to construct them in). They disagree in one place, on purpose:

> 5. Test DSL + Minitest wrapper + parallel runner (**build this early — TDD the rest**)

Phase 9 is the testing surface; build-order step 5 is where it actually gets built. **Where the two disagree, build order wins.** Phases describe what a construct belongs to; build order describes when it is written.

| Build step | Phase it delivers | Why here |
|---|---|---|
| 1. Rack skeleton + `App.define` boot + Sequel connection | 1 | nothing can be declared before there is a boot to declare into |
| 2. `model` DSL → Sequel, migrations | 1 | every later construct references a model |
| 3. `screen`/`component`/`action` → HTML+htmx compiler | 2 | the first thing a user can see |
| 4. Router + dev server + hot reload | 2 | closes the edit loop |
| 5. **Test DSL + Minitest wrapper + parallel runner** | 9 | early, so steps 6–12 are test-driven |
| 6. Realtime over `LISTEN`/`NOTIFY` | 3 | first opt-in cost; needs screens to attach to |
| 7. Jobs (Postgres-backed queue) | 4 | needed by notifications, webhooks and billing |
| 8. Ledger + `audited`/`immutable_after` | 5 | the fintech claim, and the flagship guardrail |
| 9. Auth + billing + `admin_panel` scaffolds | 7 | batteries; all three sit on models, screens, actions and jobs |
| 10. API/webhook DSL | 6 | independent of the UI path, so it can land after it |
| 11. i18n/PWA/notifications | 8 | cross-cutting polish over a working app |
| 12. Domain module system + boot enforcement + `magik check` | 12 | enforces boundaries across everything that exists by now |

## The phases

Each row's "Done when" is the gate for calling the phase finished. Every one of them is a statement about tests and guardrails, never about a demo working once.

### Phase 1 — Foundation

| | |
|---|---|
| Contains | `App.define`, `model`, `migrate`, `:money`, UUIDv7 ids, `tenant_id` injection, `magik new/generate/console/server` |
| Done when | a generated app boots, a model round-trips through Postgres, a migration applies and reverses, `:money` refuses a float, and every model carries `tenant_id` and a UUIDv7 id — each covered by a test |
| Unblocks | everything. No other phase can start. |
| Guardrails landed | `MAGIK_MODEL_FLOAT_MONEY`, `MAGIK_MODEL_NO_TENANT`, `MAGIK_SCHEMA_IRREVERSIBLE`, `MAGIK_BOOT_REDEFINED` |
| Audit additions ([`10-saas-coverage.md`](10-saas-coverage.md)) | a `:file` field type and the `attachment` declaration; `searchable` declarations and `Model.search` over the existing search seam; soft delete / archive / restore as a model annotation; an `environment` block in `App.define` selecting seams per environment, with `magik doctor --env`; liveness and readiness endpoints and `magik migrate` as a deploy gate |

### Phase 2 — Rendering & actions

| | |
|---|---|
| Contains | `component`, `screen`, `action`, the component kit, the theme system, the router, hot reload |
| Done when | the spec's headline is true — a model + screen + action under 30 lines renders a working CRUD page with zero HTML, JS or CSS written by hand — and the generated htmx endpoint provably matches the action that answers it |
| Unblocks | realtime (something to attach `live` to), auth screens, admin, flows |
| Guardrails landed | `MAGIK_ROUTER_PATH_CONFLICT`, `MAGIK_RENDER_SCREEN_STATEFUL`, `MAGIK_ACTION_STATEFUL`, `MAGIK_RENDER_TIMESTAMP_NO_ZONE` |
| Audit additions ([`10-saas-coverage.md`](10-saas-coverage.md)) | **proposed `policy` and `layout` primitives land here, not later** ([`02-dsl-surface.md`](02-dsl-surface.md)); `data_table` fully specified — cursor pagination, sorting, filters with URL state, bulk selection, column control, export, narrow-screen mode; `chart` specified as server-rendered SVG themed from tokens; responsiveness as a kit property with a 375px render test; empty, loading and error states on every collection component; spacing, type, elevation, motion and icon tokens; accessibility as a component-contract element; screen-level search and filter; fragment caching on `state`; CSRF, CSP, HSTS, frame options and cookie flags as defaults; a form honeypot and timing check on by default; per-IP/per-actor/per-action throttling on `action`; output escaping stated as a guarantee with `raw` as the single hatch |

### Phase 9 — Testing *(built fifth)*

| | |
|---|---|
| Contains | the `test` DSL over Minitest, inferred factories, generated invariant tests, the parallel runner, `magik test --watch/--changed` |
| Done when | the framework's own suite runs on the runner, isolation holds under parallelism, and `--report=timing` exists to measure the 1,000-under-10s target ([`../architecture/04-testing-strategy.md`](../architecture/04-testing-strategy.md)) |
| Unblocks | every phase after it, honestly. Steps 6–12 are written test-first against this. |
| Guardrails landed | none — this phase is how the others prove theirs |
| Audit additions ([`10-saas-coverage.md`](10-saas-coverage.md)) | `assert_queries(n)` for N+1 absence; email content assertions beyond `assert_notified`; a generated authorization test per policy verb including a cross-tenant denial; `render_screen … at: :mobile` |

### Phase 3 — Realtime (opt-in)

| | |
|---|---|
| Contains | `live`, `channel`, `broadcast`, `presence`, Postgres `LISTEN`/`NOTIFY` |
| Done when | a screen with one `live` line updates from a write in another process, a screen without one opens no socket and issues no realtime query, and the Redis backend passes the same conformance suite ([`04-swap-points.md`](04-swap-points.md)) |
| Unblocks | live dashboards, presence, the realtime half of notifications |
| Proves | axiom 5 — cost is opt-in — measurably, not rhetorically |
| Audit additions ([`10-saas-coverage.md`](10-saas-coverage.md)) | a channel evaluates the same `policy` verb as the request path — there is no second door to the data |

### Phase 4 — Jobs & async

| | |
|---|---|
| Contains | `job`, retries, `schedule`, the Postgres transactional queue, `magik worker` |
| Done when | enqueue inside a rolled-back transaction enqueues nothing, retries back off, cron fires once across N workers, and `assert_enqueued` works in the test DSL |
| Unblocks | notifications, outbound webhooks, billing dunning, anything slow |
| Audit additions ([`10-saas-coverage.md`](10-saas-coverage.md)) | CSV and spreadsheet import and export as job factories with a progress surface |

### Phase 4b — Media *(proposed)*

| | |
|---|---|
| Contains | `attachment` on a model, direct-to-storage presigned upload, magic-byte content sniffing, size and dimension limits, image derivatives and `srcset`, format conversion, EXIF stripping, signed expiring URLs for private files, a media-processing seam for video and audio, blob lifecycle and orphan cleanup |
| Why its own phase | it spans four others — the field type is phase 1, the upload component is phase 2, derivative generation and transcoding are phase 4 jobs, and signed delivery is blocked on the proposed `policy`. A capability whose value arrives only when all four have landed is a phase, not a line item; otherwise each phase ships a quarter of it and the app still cannot store a photo ([`10-saas-coverage.md`](10-saas-coverage.md)) |
| Done when | an upload never passes through a request server; a `.png` that is really an `.svg` is rejected on magic bytes; an `attachment` with no size and content-type bounds fails the boot; a private file's URL is issued only after its record's policy verb passes; deleting a record deletes its blobs; and the video path is a **wrapped** service, not a transcoder Magik wrote |
| Unblocks | ecommerce and marketplaces — two of the four verticals the spec's mission sentence names |
| Guardrails landed | `MAGIK_MODEL_UNCONSTRAINED_UPLOAD` |
| Status | **proposed.** Not in [`00-build-spec.md`](00-build-spec.md); argued in [`10-saas-coverage.md`](10-saas-coverage.md) |

### Phase 5 — Money & compliance

| | |
|---|---|
| Contains | `ledger`, `audited`, `immutable_after:`, `idempotent_by:`, `flow` |
| Done when | an unbalanced `entry` fails the boot with `MAGIK_LEDGER_UNBALANCED` and a file:line, posted entries refuse mutation, a retried idempotent action posts once, and a `flow` resumes across two different app servers |
| Unblocks | billing, and the fintech claim in the spec's success criteria |
| Guardrails landed | `MAGIK_LEDGER_UNBALANCED`, `MAGIK_LEDGER_ENTRY_MUTATED`, `MAGIK_MODEL_IMMUTABLE_VIOLATION`, `MAGIK_ACTION_IDEMPOTENCY_REQUIRED`, `MAGIK_MODEL_FORBIDDEN_FIELD` |
| Audit additions ([`10-saas-coverage.md`](10-saas-coverage.md)) | basis-point rate arithmetic as `:money`'s sibling, for tax and fees — the reference app already needed it; GDPR subject export and erasure, including the interaction with `audited` and append-only ledgers; retention policies and scheduled purge; a staff-versus-customer dimension on the audit trail |

### Phase 6 — API & integration

| | |
|---|---|
| Contains | `api` resources, pagination/filter/sort, `webhook :incoming`/`:outgoing`, bearer/API-key/JWT auth, plan-based rate limiting |
| Done when | a `resource` declaration serves all five verbs with pagination and filtering, an unsigned inbound webhook fails the boot, and an outbound webhook retries through the job queue |
| Unblocks | mobile clients, third-party integrations, Stripe's inbound events for billing |
| Guardrails landed | `MAGIK_WEBHOOK_UNVERIFIED` |
| Audit additions ([`10-saas-coverage.md`](10-saas-coverage.md)) | API deprecation and sunset headers on a version; a webhook delivery log with replay and a customer-facing endpoint surface |

### Phase 7 — Auth, billing, admin

| | |
|---|---|
| Contains | `auth` (Rodauth-backed), `billing provider:`, `admin_panel`, `tenant_by` |
| Done when | a generated app has working signup/login/reset/2FA, a subscription lifecycle drives plan state through the ledger, and `admin_panel :Model` produces CRUD with filters and search |
| Unblocks | an app that can take money and be operated — the practical definition of shippable |
| Audit additions ([`10-saas-coverage.md`](10-saas-coverage.md)) | teams, memberships, seats and invitations, generated the way `auth` generates accounts; support impersonation with a mandatory audit record and a visible banner; `admin_panel` depth benchmarked against Avo — detail views, association browsing, forms, bulk actions with arguments, typed filters, saved views, global search, admin dashboard cards; a bot-challenge seam, off by default; enumeration-resistant login and reset **by default**; disposable-domain policy on signup; login throttling and lockout; feature flags as a `policy` factory |

### Phase 8 — i18n, PWA, notifications

| | |
|---|---|
| Contains | `locales`, `translatable:` fields, timezone-safe `:timestamp`, `pwa`, `notification` |
| Done when | a missing locale key fails `magik check`, an app installs as a PWA with no offline caching, and one `notification` reaches email, in-app and push through the job queue |
| Unblocks | non-English products and mobile-shaped installs |
| Guardrails landed | `MAGIK_I18N_MISSING_KEY`, `MAGIK_PWA_OFFLINE_UNSUPPORTED` |
| Audit additions ([`10-saas-coverage.md`](10-saas-coverage.md)) | email production — `magik mail preview` rendering to a file, CSS inlining, a generated plain-text alternative, mail layouts distinct from screen layouts, a framework-owned suppression list consulted before delivery, unsubscribe tokens, and inbound bounce/complaint events over the webhook DSL; an in-app notification centre; currency, number, address and pluralisation formatting and RTL; per-screen `meta`, canonical and Open Graph tags; PDF and print rendering |

### Spec item 12 — Domains & `magik check`

| | |
|---|---|
| Contains | `domain` declarations, `depends_on`/`exposes`/`publishes_events`, boot-time boundary enforcement, the `magik check` linter and `--scale` |
| Done when | a cross-domain model reference fails the boot naming both domains and the reference site, an undeclared dependency fails, cycles fail, and `magik check --scale` reports unscoped query sites as warnings with `--json` |
| Unblocks | large apps — the point at which multiple teams can work in one codebase without a review culture holding the boundary |
| Guardrails landed | `MAGIK_DOMAIN_BOUNDARY`, `MAGIK_SCALE_UNSCOPED_QUERY` |

## Cross-phase rules

| Rule | Detail |
|---|---|
| A phase is not done without its guardrails | the guardrail is the product; shipping the construct without its boot check ships the half that does not differentiate ([`03-guardrails.md`](03-guardrails.md)). |
| A phase is not done without its swap conformance | any phase introducing a backend ships the seam's conformance suite green on every listed backend ([`04-swap-points.md`](04-swap-points.md)). |
| Every phase ships YARD | public methods are documented as they land, never in a later pass ([`../architecture/00-conventions.md`](../architecture/00-conventions.md)). |
| Version means nothing yet | `0.0.1` is a name reservation. No phase completion implies a release number until the release policy says so. |
| The plan is a plan | this page is re-derived from the spec, not from progress. When work starts, status moves here and in `CHANGELOG.md` — never into prose claiming behaviour. |
