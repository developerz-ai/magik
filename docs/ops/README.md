# Operations

The deployment shape a Magik app is designed for: stateless app servers behind a load balancer, Falcon, Postgres, and a worker process.

**Status:** spec only — **none of this runs yet.** There is no server, no worker, no Dockerfile, no chart, and no app to deploy. This page describes the intended topology so the framework is built toward it, not a runbook for anything that exists. Reviewed 2026-08-26.

## The shape

```
                    ┌─────────────────┐
   clients ────────▶│  load balancer  │  TLS, health checks
                    └────────┬────────┘
                             │
            ┌────────────────┼────────────────┐
            ▼                ▼                ▼
      ┌──────────┐     ┌──────────┐     ┌──────────┐
      │  app 1   │     │  app 2   │     │  app N   │   Falcon · stateless · identical
      └────┬─────┘     └────┬─────┘     └────┬─────┘
           └────────────────┼────────────────┘
                            ▼
                    ┌───────────────┐          ┌──────────────┐
                    │   Postgres    │◀─────────│  worker 1..M │  magik worker
                    │  data · jobs  │          └──────────────┘
                    │  LISTEN/NOTIFY│
                    └───────────────┘
```

Two process roles, one image, one codebase:

| Role | Command | Serves | Scales on |
|---|---|---|---|
| **app** | `magik server` | HTTP, htmx fragments, realtime subscriptions | request concurrency, socket count |
| **worker** | `magik worker` | the job queue and scheduled jobs | queue depth, job latency |

## Why stateless is the whole design

Spec item 9. App servers hold **no in-process session state and no UI state across requests**, and the boot guardrails refuse code that tries ([`../idea/03-guardrails.md`](../idea/03-guardrails.md)).

| Consequence | |
|---|---|
| Scaling is "add a server" | no sticky sessions, no session replication, no shared-nothing exceptions to reason about |
| Any server can serve any request | including the next request of a multi-step `flow`, whose state lives server-side keyed by a resumable token ([`../idea/02-dsl-surface.md`](../idea/02-dsl-surface.md)) |
| Deploys are boring | drain, replace, done. There is no in-memory state to migrate |
| Reloading is tractable in dev | for the same reason ([`../architecture/08-dev-loop.md`](../architecture/08-dev-loop.md)) |

The guardrail is what keeps the property true after month six. A stateless architecture maintained by code review is a stateless architecture until someone is in a hurry.

## What scales how

| Pressure | Add | Watch |
|---|---|---|
| More requests | app processes | p95 latency, Falcon accept queue |
| More realtime subscribers | app processes | open sockets per process, `LISTEN` connections against Postgres |
| Deeper job queue | worker processes | oldest-queued age, attempts-per-job |
| More data | Postgres first (vertical, then read replicas) | connection count, slow queries, index health |
| More tenants | nothing yet — that is what `magik check --scale` pre-empts by keeping queries tenant-scoped ([`../architecture/06-observability.md`](../architecture/06-observability.md)) | unscoped query warnings |

**Postgres is the thing that does not scale by adding a process.** By default it carries data, the job queue, realtime pub/sub and search — which is deliberate: one datastore until scale forces otherwise. When it does force otherwise, the seams are the swap points, not a rewrite ([`../idea/04-swap-points.md`](../idea/04-swap-points.md)): realtime moves to Redis or NATS, jobs to a broker, search to a search engine — each a `use` line, each with its own trade-offs stated on that page.

## Runtime

| Piece | Intent |
|---|---|
| Ruby | TruffleRuby in production; CRuby ≥ 3.2 supported for tooling and development |
| Server | Falcon — async, fiber-based, no thread pool to size. The same server in dev and production |
| Concurrency | Ractors and Fibers rather than threads-per-request |
| Database | Postgres, via Sequel. UUIDv7 primary keys, `tenant_id` on every table |
| Client | htmx (~14kb), served as a static asset. No bundler, no `node_modules`, no build step |

## Deploy

| Concern | Intent |
|---|---|
| Artifact | one container image, two roles selected by the command. Identical across environments |
| Config | environment variables and encrypted credentials; one key in, nothing secret in the image ([`../architecture/07-configuration-and-secrets.md`](../architecture/07-configuration-and-secrets.md)) |
| Migrations | applied by a one-shot `magik migrate` that gates the app rollout, never by an app process racing its peers at startup |
| Health | a liveness endpoint (the process is up) and a readiness endpoint (config resolved, database reachable, guardrails passed) — the load balancer uses readiness |
| Boot failure | a guardrail failure aborts before the socket opens, so a bad release fails its readiness check and is never given traffic. That is the deploy-time payoff of boot-time guardrails |
| Drain | stop accepting, finish in-flight requests, close realtime subscriptions, exit. Workers finish the current job and stop claiming |
| Zero platform primitives | anything that runs a container runs this. No edge functions, no vendor KV, no proprietary anything |

## Observability in production

| Signal | Source |
|---|---|
| Structured JSON logs, one event per request/action/job/query | [`../architecture/06-observability.md`](../architecture/06-observability.md) |
| Request traces, sampled plus every failure | same |
| Error codes in logs | stable `MAGIK_*` codes, matchable by an alert rule ([`../architecture/03-error-codes.md`](../architecture/03-error-codes.md)) |
| Metrics and spans | OpenTelemetry as the export path, opt-in — the local structured logs are the primary tool |

## What is missing, honestly

| Missing | |
|---|---|
| Everything above | there is no framework. This is a design target, `As of 2026-08-26` |
| A Dockerfile, a compose file, a chart | none is written; the image shape above is intent |
| Resource numbers | no sizing guidance, because nothing has ever been run and a made-up number is worse than none |
| Runbooks | there are no incidents to learn from yet |
| A scale ladder | the shape above is one rung. What the rungs above it look like will be written when something has climbed one |
