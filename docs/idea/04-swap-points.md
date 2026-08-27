# Swap points

Every opinionated default in Magik, and the config-level swap that replaces it without touching app code.

**Status:** spec only — no seam is implemented, no default backend exists, and no alternative has been proven. Every row below is `planned`. Reviewed 2026-08-26.

## The rule

> **Swap points required for every "opinionated default."** DB engine, cache backend, job backend, search backend, realtime backend must be config-switchable without app code changes. (Lesson from Meteor's death: magic with no escape hatch = eventual rewrite.) — [`00-build-spec.md`](00-build-spec.md)

This is the load-bearing lesson of the whole design ([`01-thesis.md`](01-thesis.md)). A framework that is opinionated and inescapable is a framework its users eventually rewrite away from, all at once, at the worst possible moment.

**A swap ships proven, not promised.** From the spec's success criteria: *every "opinionated default" has a working, tested config-level swap (proven before merge, not promised)*. Concretely:

| A backend may be listed as available only when | Evidence |
|---|---|
| it passes the seam's conformance suite | the same test file runs against every backend for that seam, green |
| CI runs that suite against it on every push | a job in the workflow, not a manual step |
| an example app boots on it unchanged | zero app-code diff between backends |
| its limits are documented | what it does *not* support, on this page |

Until all four hold, the backend is a **candidate** and this page says so. A candidate never appears in a table without that word.

## How a swap is expressed

One line in `App.define`, and nothing else in the app changes.

```ruby
App.define :Shop do
  database url: ENV.fetch("DATABASE_URL")

  use :cache,    :redis,    url: ENV.fetch("REDIS_URL")
  use :jobs,     :postgres
  use :realtime, :redis,    url: ENV.fetch("REDIS_URL")
  use :search,   :postgres
end
```

| Rule | Detail |
|---|---|
| One namer | `use` is the only place a backend product is named. App code says `cache.fetch`, never `Redis.current`. |
| Boot resolution | seams resolve before declarations load. An unknown or unshipped backend fails with `MAGIK_CONFIG_UNKNOWN_BACKEND` ([`03-guardrails.md`](03-guardrails.md)). |
| No call-site choice | there is no per-call override. Two backends live in one app only when the seam is explicitly multi-instance (caches with different TTL policies), never as a fallback chain. |
| Narrow contracts | a seam's interface is the smallest thing every backend can honour. A capability only one backend has does not enter the interface — it is configuration on that backend. |

## The seams

The five the spec names explicitly, plus seven the same rule catches by implication — each a backend an app cannot avoid needing, and each therefore a seam whether or not the sentence in item 11 lists it.

| Seam | Default | Why this default | Alternatives | Status |
|---|---|---|---|---|
| **Database** | Postgres via Sequel | UUIDv7, `LISTEN`/`NOTIFY`, transactional job queue and full-text search all come from one dependency | MySQL/MariaDB, CockroachDB — candidates | not implemented |
| **Cache** | in-process memory | zero infrastructure for a small app; cost is opt-in | Redis, Memcached — candidates | not implemented |
| **Jobs** | Postgres queue, Que-style | transactional enqueue: a rolled-back transaction enqueues nothing, which no external broker can offer | Kafka (named in the spec), Redis/Sidekiq — candidates | not implemented |
| **Search** | Postgres full-text + `pgvector` | one datastore until scale forces otherwise | Elasticsearch, Meilisearch, Typesense — candidates | not implemented |
| **Realtime** | Postgres `LISTEN`/`NOTIFY` | the database already knows what changed | Redis pub/sub (named in the spec), NATS — candidates | not implemented |
| **Storage** | Shrine, local disk | uploads work before an S3 account exists | S3 and compatibles via Shrine — candidate | not implemented |
| **Billing** | Stripe | the widest coverage of the plan shapes `billing` declares | Paddle (named in the spec) — candidate | not implemented |
| **Mail transport** | SMTP | the one transport every provider speaks | Postmark, SES, Resend — candidates | not implemented |
| **Throttle store** | Postgres | rate limits are counters, and decision 9 forbids a counter living in a process — so this is a seam by construction. [`../../wiki/API-And-Webhooks.md`](../../wiki/API-And-Webhooks.md) already names it; this page did not | Redis — candidate | not implemented |
| **Bot challenge** | none — off by default | a CAPTCHA has a real accessibility and privacy cost, so imposing one on every app is the wrong opinion. The vendor space is volatile on both price and policy, which is exactly what item 11 exists to survive | Turnstile, hCaptcha, reCAPTCHA — candidates | not implemented |
| **JSON codec** | `ruby/json` from the standard library | the fast path is engine-dependent: `ruby/json` selects a pure-Ruby generator under TruffleRuby, and the C-extension alternatives do not name TruffleRuby as a supported platform. A dependency that is a C extension, or that reaches for a runtime primitive, is a seam until a probe says otherwise on the production engine ([`../architecture/10-performance-defaults.md`](../architecture/10-performance-defaults.md)) | `use :json, :oj` — candidate, and only where a probe shows it loads and wins on the production engine | not implemented |
| **Media processing** | a media service | transcoding, packaging and adaptive delivery are a specialist product. A framework that builds one has become a media company ([`10-saas-coverage.md`](10-saas-coverage.md)) | Mux, Cloudflare Stream, Bunny — candidates; `ffmpeg` in a job for teams that want no vendor, at the cost of a dedicated queue, a machine shape and the input-validation burden | not implemented |

## The UI seam

The component kit is an opinionated default too, and item 11's rule does not stop at infrastructure. It is a *declaration-level* swap rather than a `use` line, so it has its own page — the four-rung override ladder, the component contract verified at boot, and the resolution order — [`08-component-overrides.md`](08-component-overrides.md).

| Seam | Default | Swapped by | Status |
|---|---|---|---|
| **Component kit** | the built-in kit (`button`, `form`, `field`, `data_table`, `modal`, `toast`, `card`, `list`, `grid`, `tabs`, `stat`, `chart`, `sidebar`, `topbar`, `nav_item`, `breadcrumbs`, `account_menu`, `dashboard_grid`) | tokens → `extends:` → a shadowing `component` in `app/components/` → `kit :name` for a house library | not implemented |

Auth is deliberately **not** a swap point: Rodauth is a structural dependency of the `auth` DSL, not a backend behind an interface. Saying so is more honest than pretending to a seam nobody could implement against.

Authorization is **not** a swap point either, for a stronger reason: **a second authorization backend is a second authorization system**, which is the failure this whole design is organised against ([`01-thesis.md`](01-thesis.md)). `policy` ([`02-dsl-surface.md`](02-dsl-surface.md#policy)) is one evaluator with no alternative — the same status as tenancy and the primary key strategy, and architecture decision 13 states it as a decision rather than as a preference.

## What a swap does not buy

Escape hatches that promise more than they deliver are the failure mode being avoided, so the limits are part of the design:

| Limit | Detail |
|---|---|
| Semantics are not identical | a Kafka job backend cannot offer transactional enqueue. Choosing it means accepting at-least-once delivery with app-visible consequences, and the seam's docs must say so at the point of choosing. |
| The cheapest rung can be the one that breaks the guarantee | **a second Postgres dedicated to jobs loses transactional enqueue too.** It is the obvious first move when the job table's dead-tuple churn hurts, and it looks like staying on the default — but a cross-database enqueue cannot join the app's transaction any more than a Redis `LPUSH` can. Recovering the guarantee means the outbox pattern, which is machinery rather than configuration ([`../architecture/11-jobs-backend.md`](../architecture/11-jobs-backend.md)). |
| Data does not migrate itself | swapping the cache backend is a restart; swapping the database is a data migration Magik does not perform. |
| The narrow contract is the contract | code written against a backend-specific feature has left the seam and will not survive a swap. That is a supported choice, not a supported *portable* choice. |
| Candidates are not fallbacks | an unshipped backend fails at boot rather than degrading to the default. Silent degradation is the thing guardrails exist to prevent ([`05-limits.md`](05-limits.md)). |

## Adding a seam or a backend

| # | Step |
|---|---|
| 1 | Write the conformance suite first — the behaviour every backend for this seam must exhibit, including failure modes. |
| 2 | Implement the interface under `lib/magik/<subsystem>/backends/<name>.rb` ([`../architecture/01-module-map.md`](../architecture/01-module-map.md)). |
| 3 | Register it so `use :<seam>, :<name>` resolves, and so an unknown name raises with the list of known ones. |
| 4 | Run the suite against **every** backend for the seam in CI, not just the new one. |
| 5 | Boot an example app on it with a zero-line app diff. |
| 6 | Add the row here, move it out of "candidate", and record it in `CHANGELOG.md`. |

The loop, with commands: [`../architecture/05-adding-a-feature.md`](../architecture/05-adding-a-feature.md).
