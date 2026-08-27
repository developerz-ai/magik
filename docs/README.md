# Magik — documentation map

Three doc trees: why the framework is shaped this way, how the repo that will build it is organised, and how a finished app would be run.

**Status:** spec only. Magik is unimplemented — `docs/idea/00-build-spec.md` is the product spec, every other page elaborates on it, and nothing on any page describes running code. Reviewed 2026-08-26.

| Tree | Answers | Read it when |
|---|---|---|
| [`idea/`](idea/) | **what and why** | you want to understand a decision, or argue with it |
| [`architecture/`](architecture/) | **how this repo is built** | you are about to write framework code |
| [`ops/`](ops/README.md) | **how a Magik app would be run** | you are sizing the deployment story |

## `idea/` — the product

| Doc | Read this when… |
|---|---|
| [`idea/00-build-spec.md`](idea/00-build-spec.md) | you need the source of truth — every other doc defers to it, and nothing anywhere contradicts it |
| [`idea/01-thesis.md`](idea/01-thesis.md) | you want the axioms behind the spec, and the table of what Magik takes from Rails, Meteor, LiveView, Django, Hanami and htmx — and refuses |
| [`idea/02-dsl-surface.md`](idea/02-dsl-surface.md) | you are implementing a DSL construct and need its intended Ruby shape |
| [`idea/03-guardrails.md`](idea/03-guardrails.md) | you want to know what fails a boot, and with which error code |
| [`idea/04-swap-points.md`](idea/04-swap-points.md) | you are about to hard-code an opinionated default and need its escape hatch |
| [`idea/05-limits.md`](idea/05-limits.md) | someone asked for offline, a canvas editor, an SPA, ActiveRecord or RSpec |
| [`idea/06-phases.md`](idea/06-phases.md) | you are picking up work and need to know what is next and what it unblocks |
| [`idea/07-ai-first.md`](idea/07-ai-first.md) | you want the AI-first argument in full: what it changes about the design, and what each agent audience needs |
| [`idea/08-component-overrides.md`](idea/08-component-overrides.md) | you want your own modal, table or chart instead of the kit's |
| [`idea/09-app-scaffold.md`](idea/09-app-scaffold.md) | you want the three stages a generated app goes through — `magik new` → `/setup-project` → `/feature` |
| [`idea/10-saas-coverage.md`](idea/10-saas-coverage.md) | you want the adversarial count of the grammar against what a SaaS actually needs, and the command that re-counts it |
| [`idea/11-dsl-as-tool-surface.md`](idea/11-dsl-as-tool-surface.md) | you are adding DSL and need the rules it is designed against — including why `magik describe` exists and why `magik mcp` is deferred |
| [`idea/12-the-range.md`](idea/12-the-range.md) | you want the two axes one framework has to span, from a weekend idea to a large product |

## `architecture/` — the repo

| Doc | Read this when… |
|---|---|
| [`architecture/00-conventions.md`](architecture/00-conventions.md) | you are writing any Ruby file in this repo |
| [`architecture/01-module-map.md`](architecture/01-module-map.md) | you need to decide which `lib/magik/<subsystem>/` a change belongs in |
| [`architecture/02-boundaries.md`](architecture/02-boundaries.md) | your `require` points sideways or upward, or you are wiring app-level domains |
| [`architecture/03-error-codes.md`](architecture/03-error-codes.md) | you are about to raise something |
| [`architecture/04-testing-strategy.md`](architecture/04-testing-strategy.md) | you are writing the test that has to fail before your code exists |
| [`architecture/05-adding-a-feature.md`](architecture/05-adding-a-feature.md) | you are landing a piece of the framework, start to finish |
| [`architecture/06-observability.md`](architecture/06-observability.md) | something went wrong and the output is all you have — logs, traces, `magik check`, `magik doctor` |
| [`architecture/07-configuration-and-secrets.md`](architecture/07-configuration-and-secrets.md) | you need a secret, an env var, or a config key that fails at boot instead of at 3am |
| [`architecture/08-dev-loop.md`](architecture/08-dev-loop.md) | you want to know what hot-reloads, what does not, and why |
| [`architecture/09-shipped-docs.md`](architecture/09-shipped-docs.md) | you want to know why the gem carries its own manual, what `magik docs` serves, and what ships |
| [`architecture/10-performance-defaults.md`](architecture/10-performance-defaults.md) | you are about to pick a default that costs something at runtime |
| [`architecture/11-jobs-backend.md`](architecture/11-jobs-backend.md) | you need which Postgres queue is wrapped, by what locking mechanism, and where it stops being the right answer |
| [`architecture/12-runtime-verification.md`](architecture/12-runtime-verification.md) | you want the runtime measurements the concurrency and server decisions rest on — the method, the numbers, and what would reverse them |

## `ops/` — running it

| Doc | Read this when… |
|---|---|
| [`ops/README.md`](ops/README.md) | you want the intended deployment shape: stateless app servers, Puma, Postgres, workers — and the note that none of it runs yet |

Outside `docs/`: [`../README.md`](../README.md) is the repo entry point, `wiki/` is the reference manual, `CHANGELOG.md` records what actually landed.

## Reading order

| You are | Read |
|---|---|
| Evaluating the idea | `idea/00-build-spec.md` → `idea/01-thesis.md` → `idea/05-limits.md` |
| Implementing a subsystem | `architecture/00-conventions.md` → `architecture/01-module-map.md` → `architecture/02-boundaries.md` → `architecture/05-adding-a-feature.md` |
| Designing a DSL construct | `idea/02-dsl-surface.md` → `idea/03-guardrails.md` → `architecture/03-error-codes.md` |
| An agent, on either side | `idea/07-ai-first.md` → `architecture/06-observability.md` → `architecture/05-adding-a-feature.md` |
| Debugging anything | `architecture/06-observability.md` → `architecture/03-error-codes.md` → `architecture/08-dev-loop.md` |
| Planning the work | `idea/06-phases.md` → `architecture/04-testing-strategy.md` |

## Doc conventions

- Every page opens with a one-line summary and a `Status:` line. No page claims behaviour that exists.
- Status vocabulary: `planned`, `not implemented`, `spec only`. Never a benchmark number, a passing-test count, or "it does X" for framework behaviour. The one page carrying measurements is [`architecture/12-runtime-verification.md`](architecture/12-runtime-verification.md), and they are measurements of the *Ruby engines*, not of Magik — every other page cites it rather than repeating a number.
- Lead with the rule, not the reason. Tables for any list of things.
- Code blocks are *intended* Ruby — they are design targets, not transcripts of a session.
- Cross-link with relative paths. Date any claim that can go stale (`As of 2026-08-26`).
