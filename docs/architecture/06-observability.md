# Observability

Debugging and logging designed as a feature, because whatever the framework prints when something goes wrong is an agent's entire diagnostic surface.

**Status:** planned. There is no logger, no trace, no dev dashboard and no `magik doctor`. Every output shape below is intended. Reviewed 2026-08-26.

## Why this is a designed subsystem

An agent debugging a Magik app cannot attach a debugger, cannot read a stack trace over a colleague's shoulder, and cannot ask what the framework "usually" does. It has exactly what the framework prints ([`../idea/07-ai-first.md`](../idea/07-ai-first.md)). A 40-frame backtrace through framework internals is not a diagnostic; it is noise with a fact buried in it.

So the design rule: **every failure answers three questions in its first six lines — what was expected, what was found, and what to run next.**

## The error contract, extended

The code, cause, location, `fix:` and `--json` field set are defined once in [`03-error-codes.md`](03-error-codes.md) and are not restated here. What this page adds is what a *failure event* looks like beyond the error object:

| Element | Rule |
|---|---|
| App frames first | the location is the declaration site in app code. Framework frames are **collapsed by default**. |
| Expanding | `--trace` on any command, `MAGIK_TRACE=1` in the environment, or the "show framework frames" control on the dev error page. |
| Frame labelling | expanded frames are tagged with the subsystem they belong to, so the boundary between app and framework is visible rather than inferred. |
| Declaration context | the failure names the declaration that produced the code path — `screen :Orders` → `action :refund_order` → `model :Order` — not just the file. |
| One string everywhere | the same code and the same `fix:` in the terminal, the JSON, the dev page and the log line. A paraphrase is a thing an agent cannot match on. |

## Structured logging

**One event per unit of work**, with a stable field set. A log line without the stable fields is a bug, not a style preference.

| Unit | Emitted when |
|---|---|
| request | a request completes or fails |
| action | an `action` finishes |
| query | a query executes (dev: always; production: over a threshold) |
| job | a job attempt ends |
| broadcast | an event is published to a channel |
| notification | a notification is delivered or fails |

### The stable field set

| Field | Meaning |
|---|---|
| `ts` | ISO-8601 UTC |
| `level` | `debug` `info` `warn` `error` `fatal` |
| `event` | `request` `action` `query` `job` `broadcast` `notification` |
| `correlation_id` | one id for everything descending from a request or job — the join key |
| `tenant_id` | which tenant. Never omitted where one exists |
| `actor` | the resolved actor id, or `anonymous` |
| `declaration` | what produced this — `screen:Orders`, `action:refund_order`, `job:SettleBatch` |
| `duration_ms` | wall clock for this unit |
| `outcome` | `ok` `error` `warn` |
| `code` | the `MAGIK_*` code when the outcome is an error |

| Rule | Detail |
|---|---|
| Dev format | human-readable, aligned, colourised, one line per event with the slow ones marked |
| Production format | JSON, one object per line, the field set above plus event-specific keys |
| `--json` | available on every CLI command, so an agent parses instead of scraping |
| Levels mean something | `info` = a unit of work completed. `warn` = something degraded but served. `error` = a unit failed. `fatal` = the process cannot continue. No debug-as-info |
| Redaction | the redaction list is part of this contract, not an add-on — see [`07-configuration-and-secrets.md`](07-configuration-and-secrets.md). Anything on it never reaches a log line, an error message or a job payload |
| Cost | logging is not free; per-query logging in production is threshold-gated, and the threshold is configuration |

## The request trace

The thing most frameworks cannot produce, and Magik can because every artifact descends from one declaration: **the whole chain of a single request, with timings.**

```
request  GET /orders            correlation=01J8… tenant=acme actor=u_31   42.6ms  ok
├─ screen  :Orders                                                          41.9ms
│  ├─ state :orders → model :Order.recent                                    3.1ms
│  │  └─ query  SELECT … FROM orders WHERE tenant_id = $1 …   50 rows        2.8ms
│  └─ render  data_table of: :orders using: :OrderRow (50×)                 38.2ms   ← slow
└─ 0 jobs enqueued · 0 broadcasts
```

| Property | Detail |
|---|---|
| Chain | screen → action → model → query → job → broadcast, in the order they happened |
| Timings | per node, with the dominant node marked |
| Availability | on demand in dev; in production for a sampled fraction and for every failed request |
| `--json` | the same tree as nested objects, so an agent can walk it instead of parsing box-drawing characters |
| Why it works | the declaration registry knows what produced what. A framework where the same information is spread across a router file, a template and a model callback cannot assemble this |

## The dev-time surface

"What did the framework actually do" must be answerable without reading framework source.

| Surface | Answers | Status |
|---|---|---|
| `magik routes` | every path, the declaration behind it, the verb | planned |
| `magik registry [--json]` | everything registered: models, screens, actions, jobs, channels, ledgers, domains, component overrides and what they shadow | planned |
| `magik explain screen :Orders` | the compiled HTML, the `hx-*` attributes, the state vars and their queries | planned |
| `magik explain query Order.recent` | the SQL that compiles to, with the injected tenant predicate visible | planned |
| `magik jobs status` | queued, running, failed, scheduled — counts and the oldest of each | planned |
| dev dashboard at `/_magik` | the same information in a browser, plus the last N request traces | planned |
| `magik console` | all of the above in IRB, against a booted app with reloading ([`08-dev-loop.md`](08-dev-loop.md)) | planned |

The injected-tenant-predicate case is the point of `magik explain query`: the framework writes part of the SQL, so the framework has to be able to show it.

## Diagnostic commands

| Command | Role | Status |
|---|---|---|
| `magik check` | the static feedback loop — the guardrails without a server ([`../idea/03-guardrails.md`](../idea/03-guardrails.md)) | planned |
| `magik check --scale` | tenant-scoping and sharding hazards, as warnings | planned |
| `magik doctor` | the environment: Ruby version and engine, Postgres reachability and version, required extensions, migration state, config keys present, backends resolvable | planned |
| `magik errors explain <CODE>` | the catalogue as a command | planned |
| `magik test --report=timing` | where test time went ([`04-testing-strategy.md`](04-testing-strategy.md)) | planned |

| Rule | Detail |
|---|---|
| `--json` on all of it | with a documented, additive-only schema. An agent must be able to rely on the shape across versions |
| Exit codes | `0` clean, `1` findings at `:error`, `2` findings at `:warning` only. Scriptable without parsing text |
| No boot required where possible | `check`, `errors explain` and the boundary scan read source; `doctor` needs the environment and says so per probe |

## N+1 and slow queries

Failures that must surface in dev and CI, not in production:

| Detection | Signal | Where |
|---|---|---|
| N+1 | the same query shape executed N times within one request, differing only in a bound parameter | dev: a warning in the trace with both sites. CI: `magik check --scale` reports it |
| Slow query | over a configurable threshold | logged with the SQL, the plan on request, and the declaration that issued it |
| Unscoped query | no `tenant_id` in the `WHERE` clause — the spec's `magik check --scale` rule | `MAGIK_SCALE_UNSCOPED_QUERY`, severity `warning`, because a platform-wide admin report is legitimately unscoped |
| Missing index | a scan over a table above a row threshold on a column the declaration filters by | reported by `--scale` as a warning with the suggested migration |

All four are warnings rather than boot failures, for the reason in [`../idea/03-guardrails.md`](../idea/03-guardrails.md): each has a legitimate counter-example, and a guardrail with legitimate counter-examples is a warning, not a refusal.

## OpenTelemetry

OTel is on the spec's wrap list, and its role here is precise: **the local structured logs and the request trace are the primary tool; OTel is the export path.**

| Property | Detail |
|---|---|
| Mapping | the request trace becomes spans; `correlation_id` becomes the trace id; `declaration` becomes the span name; `tenant_id` and `actor` become attributes |
| Opt-in | no exporter is configured by default. Cost is opt-in, like everything else |
| Not a dependency of the design | if OTel is absent, nothing about the local diagnostics changes. It is an output, not the source |
| Honest limit | an agent debugging a failing test does not have a collector. That is exactly why the local surface has to be complete on its own |
