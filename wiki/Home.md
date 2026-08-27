# Magik wiki

**Status:** `Spec only — no framework code exists`. Every page on this wiki documents **intended**
behaviour drawn from [`docs/idea/00-build-spec.md`](../docs/idea/00-build-spec.md). Nothing here
describes something you can run. `As of 2026-08-26`.

Magik is an opinionated, full-stack Ruby framework for TruffleRuby: one DSL for models, screens,
actions, realtime channels, background jobs, ledgers, APIs and admin panels. The server renders HTML
and htmx handles interactivity — there is no second frontend framework, and there never will be.

**Magik is AI-first.** The primary developer is an AI agent, and the design follows from that: one
uniform DSL grammar across every subsystem, boot-time guardrails as the correction mechanism, errors
carrying a runnable `fix:` line, convention over configuration, and a surface small enough to fit in
a context window. The reasoning is [`docs/idea/07-ai-first.md`](../docs/idea/07-ai-first.md); the
agent workbench committed to this repo is [`.claude/README.md`](../.claude/README.md); the agent
entry point is [`llms.txt`](../llms.txt).

## Read this before anything else

`magik 0.0.1` on RubyGems is a **name reservation**. It ships a version constant, the `MAGIK_*` error
convention, a `magik version` / `magik help` shim, and one documented stub per planned subsystem. It
does not render a page, connect to a database, or run a job. `gem install magik` succeeds and gives
you nothing that builds an app.

This wiki exists **first** on purpose: the reference manual is the specification's shape made
concrete, and writing it before the code is what keeps the code honest. Read it as a design document
that happens to be organised like a manual.

Resolve status yourself rather than trusting a sentence on this page:

```bash
gem list magik --remote --all                          # what RubyGems serves
ruby -Ilib -e 'require "magik"; puts Magik::VERSION'   # what a checkout is stamped at
magik help                                             # the commands that actually run
```

## Every page

| Page | What it covers | Read it when |
|---|---|---|
| [Installation](Installation.md) | TruffleRuby as the production target, CRuby 3.2+ for tooling, `gem install magik` and what it actually does today | you want to try it, or find out why you cannot |
| [Getting started](Getting-Started.md) | the intended first run end to end: `magik new` → `bin/setup` → `magik server` | you want to see the target developer experience |
| [Development loop](Development-Loop.md) | hot reload, the console, generators, `--watch`, and the error page. No JS build step | you are working on an app day to day |
| [Project layout](Project-Layout.md) | the directories a generated app has, and separately the layout of this framework repo | you are deciding where a file goes |
| [CLI reference](CLI-Reference.md) | every command, flag, `--json` shape and exit code — with the two that exist today marked | you are driving the CLI, or an agent is |
| [Models](Models.md) | `model`, `migrate`, fields, tenancy, UUIDv7, the Sequel seam | you are modelling data |
| [Screens and components](Screens-And-Components.md) | `component`, `screen`, `policy`, `layout`, the component kit, theming, htmx | you are building UI |
| [Actions](Actions.md) | `action`, params, routing by convention, idempotency, the statelessness rule | you are writing a mutation |
| [Realtime](Realtime.md) | `live`, `channel`, `broadcast`, `presence`, and why it costs nothing undeclared | you want a screen to update itself |
| [Jobs](Jobs.md) | `job`, retries, schedules, the transactional queue, `magik worker` | you are moving work off the request |
| [Money and ledgers](Money-And-Ledgers.md) | the `:money` type, `ledger`, `audited`, `immutable_after:`, `flow` | you are touching currency |
| [API and webhooks](API-And-Webhooks.md) | `api`, `resource`, incoming and outgoing `webhook`, API auth, rate limits | you are exposing or consuming an integration |
| [Auth, billing, admin](Auth-Billing-Admin.md) | `auth`, `billing`, `admin_panel`, `tenant_by`, teams and the abuse defaults | you need the batteries |
| [Testing](Testing.md) | the `test` DSL over Minitest, inferred factories, the helpers, the parallel runner | you are writing a test — which is most of the time |
| [Domains](Domains.md) | `domains/<name>/domain.rb`, `depends_on`, `exposes`, `publishes_events`, boot-time enforcement | your app got big enough to need walls |
| [Error codes](Error-Codes.md) | the `MAGIK_*` catalogue, the code/cause/`fix:` contract | something raised a code at you |
| [Known gaps](Known-Gaps.md) | the honest page. Right now: everything | you are deciding whether to trust it |
| [FAQ](FAQ.md) | why TruffleRuby, why Sequel, why Minitest, why htmx, why no offline, is it production ready | you are arguing with a default |
| [Contributing](Contributing.md) | a pointer to the root contributing guide | you want to help |

## Reading paths

| If you are | Read, in order |
|---|---|
| Evaluating whether this is real | [Known gaps](Known-Gaps.md) → [FAQ](FAQ.md) → [`ROADMAP.md`](../ROADMAP.md) |
| Understanding the design | [`docs/idea/01-thesis.md`](../docs/idea/01-thesis.md) → [Models](Models.md) → [Screens and components](Screens-And-Components.md) → [Actions](Actions.md) |
| An agent building a SaaS with Magik | [`llms.txt`](../llms.txt) → [Models](Models.md) → [Screens and components](Screens-And-Components.md) → [Actions](Actions.md) → [Testing](Testing.md) |
| An agent implementing Magik itself | [`llms.txt`](../llms.txt) → [`docs/idea/00-build-spec.md`](../docs/idea/00-build-spec.md) → [`docs/idea/06-phases.md`](../docs/idea/06-phases.md) → [`.claude/commands/implement-phase.md`](../.claude/commands/implement-phase.md) |
| Hitting an error | [Error codes](Error-Codes.md) → [CLI reference](CLI-Reference.md) |
| Planning to contribute code | [Contributing](Contributing.md) → [`docs/architecture/01-module-map.md`](../docs/architecture/01-module-map.md) → [`docs/architecture/05-adding-a-feature.md`](../docs/architecture/05-adding-a-feature.md) |
| Deciding what to build next | [`ROADMAP.md`](../ROADMAP.md) → [`docs/idea/06-phases.md`](../docs/idea/06-phases.md) |

## The rules everything else follows

Every page on this wiki is downstream of these. They come from the build spec's non-negotiable
architecture decisions, and a page that contradicts one is wrong.

| Rule | Consequence |
|---|---|
| One DSL grammar for everything | a ledger is declared the same way a model is. There is no "fintech mode" to switch into |
| Server renders, htmx interacts | no React, no Vue, no per-screen SPA escape hatch. Ever |
| Realtime is opt-in per screen | a screen with no `live` declaration opens no socket and pays nothing |
| Multi-tenant by default | every model is scoped by `tenant_id` and every primary key is a UUIDv7 |
| Authorization is decided in one place | every surface that reaches a model names a verb in a `policy`. There is no second door to the data, and no per-surface check |
| Money is integer cents | a `Float` in a currency field is refused by the type system, not caught in review |
| Stateless app servers | a screen or action holding instance state across requests fails at boot |
| Every default has a swap | DB, cache, jobs, search and realtime backends are config keys — an opinion with no escape hatch is a future rewrite |
| Guardrails fail at boot | an unbalanced ledger, a cross-domain reach, a `field :card_number` — all boot failures, not runtime surprises |
| Errors are instructions | every failure carries a stable `MAGIK_*` code, a cause, and a runnable `fix:` |

## Limits — permanent, not gaps

| Limit | Detail |
|---|---|
| No offline support | the server is the single source of truth. A PWA ships; an offline cache does not |
| No heavy client-side compute | canvas editors, games, in-browser media editing — out of scope, and the docs refuse rather than fail quietly |
| No SPA framework | see the rules table. This is the one that gets asked most, and the answer does not change |

## Source documents

| Where | What it is |
|---|---|
| [`docs/idea/00-build-spec.md`](../docs/idea/00-build-spec.md) | the source of truth for what Magik is. Everything else elaborates on it and nothing contradicts it |
| [`docs/idea/`](../docs/idea/) | **why** — thesis, DSL surface, guardrails, swap points, limits, phases |
| [`docs/architecture/`](../docs/architecture/) | **how** — conventions, module map, boundaries, error codes, testing strategy |
| [`docs/ops/README.md`](../docs/ops/README.md) | running an app for real. Recommendations only |
| [`.claude/README.md`](../.claude/README.md) | the agent workbench: subagent definitions and slash commands, committed to the tree |
| API docs | <https://developerz-ai.github.io/magik/api/> — YARD, generated from what exists |
| [`ROADMAP.md`](../ROADMAP.md) | the ten phases, the thirteen build steps, and the version milestones |
| [`llms.txt`](../llms.txt) | the machine-readable repo map |
