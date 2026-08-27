<h1 align="center">Magik</h1>

<p align="center"><strong>The AI-first full-stack Ruby framework: ship a SaaS in record time with an agent doing the typing.</strong></p>

<p align="center">One DSL for models, screens, actions, realtime, jobs, ledgers, APIs and admin — server-rendered on TruffleRuby, no frontend framework.</p>

<div align="center">

[![Gem Version](https://img.shields.io/gem/v/magik.svg)](https://rubygems.org/gems/magik)
[![CI](https://github.com/developerz-ai/magik/actions/workflows/ci.yml/badge.svg)](https://github.com/developerz-ai/magik/actions/workflows/ci.yml)
[![Ruby](https://img.shields.io/badge/ruby-%E2%89%A5%203.2-CC342D.svg)](https://www.ruby-lang.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[The spec — the source of truth](docs/idea/00-build-spec.md) ·
[Why AI-first](docs/idea/07-ai-first.md) ·
[Roadmap](ROADMAP.md) ·
[Docs](docs/idea/) ·
[Wiki](wiki/Home.md) ·
[API reference](https://developerz-ai.github.io/magik/api/) ·
[llms.txt](llms.txt)

</div>

> ## Status: pre-alpha, spec only
>
> **Magik is not implemented.** This repository is the ground work — the spec, the documentation, the
> gem skeleton, the CI and the release plumbing. There is no framework behind it yet: no `magik new`,
> no `model`, no `screen`, no `action`, no server. **Every framework feature named on this page is
> `planned`**; the short list of things that genuinely run is
> [what exists today](#what-exists-today).
>
> `0.0.1` is a name reservation on RubyGems and nothing more — see [CHANGELOG.md](CHANGELOG.md)
> and [what exists today](#what-exists-today) for the exact inventory.
> Nothing here has been benchmarked, deployed, or run against a database, and this file will say so
> until that changes. `As of 2026-08-26`; re-derive with `ruby -Ilib exe/magik version --json` and
> `gem list -r magik --all`.

> **If you are a coding agent, start with [`llms.txt`](llms.txt)** — the whole repository as one link
> map, and the shortest route to knowing which parts exist. Then read
> [`CLAUDE.md`](CLAUDE.md), the working contract for changes made inside this repo, and
> [`.claude/README.md`](.claude/README.md) for the agents and slash commands this repo ships.

## What it is

An opinionated, full-stack Ruby framework on TruffleRuby **whose primary developer is an AI agent**.
One DSL for models, screens (UI), actions (mutations), realtime channels, background jobs, ledgers
(money), APIs and admin panels. No separate frontend framework: the server renders HTML and htmx
handles interactivity.

The target is **99% of SaaS** — CRUD apps, dashboards, fintech, ecommerce, marketplaces — without
the author ever having to "graduate" to another stack. Fintech-grade money handling (double-entry
ledgers, audit trails, idempotent mutations) uses the same DSL grammar as everything else: there is
no separate "fintech mode".

Magik wraps rather than reinvents: Sequel, Que, Rodauth, Shrine, htmx, Puma, Minitest,
the money gem. → [the full library list](docs/idea/00-build-spec.md)

## Everything, included

The claim is not that Magik *can* do these things — it is that you never choose them. Auth,
billing, an admin panel, realtime, jobs, double-entry ledgers, uploads, i18n, notifications, a
REST API, and a themed responsive component kit: one grammar, one gem, one gate. No assembling a
stack from twelve gems over a weekend, no `node_modules`, no build step, no picking a JSON parser.

**Fewer decisions for you is more time for the product.** The decisions Magik makes on your behalf
are the ones you could not afford to get wrong — UUIDv7 keys, `tenant_id` on every model,
integer-cent money, stateless servers — and the ones most people would not have known to make:
Oj, a `statement_timeout`, cursor pagination instead of `OFFSET`, an index on every `tenant_id`.
Where a decision is cheap to reverse, Magik does not make it for you at all. That is what the
[swap points](docs/idea/04-swap-points.md) and the
[component override ladder](docs/idea/08-component-overrides.md) are: opinions where reversal is
impossible, choices where it is not.

And you are not the one driving. The intended loop, once the framework exists:

```sh
magik new myapp     # 1. the static boilerplate — deterministic, no model involved
/setup-project      # 2. your agent turns the generic scaffold into *your* project, once
/feature            # 3. real work — and again, and again
```

`/feature` after `/feature` is the whole job. **Planned — none of this runs yet**; the short list
of what genuinely works is [what exists today](#what-exists-today).
→ [docs/idea/09-app-scaffold.md](docs/idea/09-app-scaffold.md) for what each stage emits, who owns
each generated file, and why the three are kept apart.

## AI-first, and why that shapes every decision

The premise: the person shipping the SaaS describes it, and an agent writes it. That is a design
constraint, not a marketing line — an agent has different failure modes from a human, and the
architecture decisions below are answers to those failure modes rather than to taste.

| An agent's failure mode | Magik's answer | Consequence in the design |
|---|---|---|
| **Limited context.** Reading a framework costs the budget the product needed | one grammar for every subsystem — `model`, `screen`, `action`, `job`, `ledger`, `api` all declare the same way. Learn one primitive and you can guess the rest | no second syntax, no plugin API, no configuration dialect. A feature that does not fit the grammar does not ship |
| **Confident wrongness.** It will write plausible code that is subtly unsafe | guardrails that **refuse to boot**: unbalanced ledgers, `field :card_number`, cross-domain access, cross-request state, an unconverted timestamp. Enforcement is the product | a convention that is not a boot failure is a suggestion. Review cannot be the mechanism when nobody reads every line |
| **No feedback loop.** A silent wrong default is never noticed | `magik check` — the one command that says whether the app is shippable, and `magik check --scale` for the queries that will hurt later | one command, one verdict. The agent's loop is edit → check → fix, not edit → hope |
| **Cannot recover from a bare stack trace** | every error carries a stable `MAGIK_*` code, the concrete cause, and a `fix:` line that is a **command you run, never advice** | a failure costs one round-trip instead of a search |
| **Boilerplate is where it burns tokens and makes mistakes** | zero HTML, JS or CSS written by hand; tests, factories and admin CRUD inferred from the declarations already made | the [example below](#the-dsl-in-one-worked-example) is the whole of a feature |
| **A wrong guess about the stack is expensive to undo** | convention over configuration, and every opinionated default has a *proven* config-level swap | the agent never has to choose a database, a queue or a cache to start, and is never trapped by not having chosen |

**This is a claim about the design, not about a build.** None of it is implemented — read the
status callout above. The reason it is written down now is that these decisions are cheap today and
a rewrite later. → [docs/idea/07-ai-first.md](docs/idea/07-ai-first.md)

The repository dogfoods the premise: the framework itself is built by agents working from
[the spec](docs/idea/00-build-spec.md), with [`CLAUDE.md`](CLAUDE.md) as the contract and
[`.claude/`](.claude/README.md) carrying the agents and slash commands that drive the phases.

## Who it is for, and the range

**One framework from a weekend CRUD app to a multi-tenant fintech product** — no lite mode, no
second stack to graduate to. The small end pays nothing for the large end; the large end is
configuration the small end never types.

| End of the range | The intent | State `As of 2026-08-26` |
|---|---|---|
| **small** — a first internal tool, a dashboard | a model, a screen and an action, and the app runs. Zero HTML, JS or CSS written by hand | **not implemented** — the shape below is the target, not a sample you can run |
| **large** — multi-tenant SaaS, real money | tenant scoping, UUIDv7 keys, double-entry ledgers, audit trails and domain boundaries are in the beginner's app from day one, unused until declared | **not implemented** — [phases 5–9](#phases) |
| **the escape hatch** | every opinionated default has a config-level swap: DB engine, cache, jobs, search, realtime | **not implemented** — and the spec requires each swap to be *proven working before merge*, never promised |

Nothing in the right-hand column is a hedge about quality. It is the literal state of the tree:
this repository contains no framework code.

## Magik or Ultimate?

[**Ultimate**](https://github.com/developerz-ai/ultimate) is this project's sibling, from the same
authors, built on the same thesis: one uniform primitive grammar, server-authoritative, AI-first,
batteries included, guardrails as the product. It runs that thesis on **Bun + TypeScript +
SolidJS**. Magik runs it on **TruffleRuby + Sequel + htmx**.

**If you would rather write TypeScript, use Ultimate.** It is a real, released framework with a
published npm surface and a working gate; Magik is a specification with no implementation behind it.
That is not a close call today, and this file will not pretend otherwise.

Magik exists for the developers on the other side of that preference — people who like Ruby and do
not want a TypeScript toolchain in their life. The positive case, stated as taste and toolchain
rather than as an argument about a language:

- **Blocks are the natural shape of a declaration DSL.** `model :Product do … end` is Ruby doing
  what Ruby has always been good at. The same thing in TypeScript is object literals and generics.
- **No compile step.** No `tsconfig`, no bundler, no `dist/`, no build to keep in sync with source.
  Edit, reload.
- **A small dependency graph.** A handful of mature gems, not an `npm` tree.
- **No client build either.** htmx is one script tag; there is no component framework, no hydration
  model and no per-route JS budget to think about, because there is barely any JS.
- **TruffleRuby makes the performance objection stale.** "Ruby is slow" was an argument about
  CRuby's interpreter; a JIT-compiled runtime with real parallelism is a different conversation.

Accurate on both sides `As of 2026-08-26` — Ultimate's column is read from its own repository, not
guessed:

| | **Magik** | **Ultimate** |
|---|---|---|
| Status | **spec only, nothing implemented** | released and published to npm |
| Runtime | TruffleRuby (CRuby ≥ 3.2 for tooling) | Bun |
| Language | Ruby | TypeScript |
| Data layer | Sequel — explicit queries, no lazy loading | its own `entity` primitive over Postgres, hand-written parameterised SQL |
| UI | server-rendered HTML + htmx, compiled from the DSL | SolidJS, five render modes, islands, per-route JS budgets |
| Client build | none | Bun bundler |
| Realtime | opt-in per screen; Postgres `LISTEN/NOTIFY` by default, Redis swappable | three tiers — channels, live queries, and local-first (deferred) |
| Offline | **out of scope, permanently** | in scope — a generated service worker, per-route offline strategies |
| Tests | Minitest, wrapped by a `test` DSL | `bun:test` with six typed test kinds |
| The gate | `magik check` | `x verify` |
| For | people who want Ruby's ergonomics and no TS toolchain | people who want end-to-end type safety and a modern JS stack |

Neither is a lite version of the other, and neither is planned to converge on the other. Same
thesis, two populations.

## The intended `magik new` experience — planned

**None of this works yet.** It is written down so the shape is fixed before the code is:

```sh
gem install magik          # installs 0.0.1 once it is pushed — a version constant and `magik help`
magik new shop && cd shop  # planned
bin/setup                  # planned — dependencies, database, migrations, seeds
magik server               # planned — Puma, hot reload
```

The CLI surface the spec commits to: `magik new`, `magik generate model|screen|action|migration`,
`magik console`, `magik server`, `magik worker`, `magik test`, `magik check`. **`magik help` marks
each one `ready` or `planned`** — "not built yet" and "not a command" are different facts, and the
CLI already says which is which:

```sh
ruby -Ilib exe/magik help    # every command, with its status
```

→ [Phase table](#phases) · [the CLI in the DSL surface doc](docs/idea/02-dsl-surface.md) ·
[the spec's build order](docs/idea/00-build-spec.md)

## The DSL, in one worked example

The spec's first success criterion is **a new CRUD SaaS screen in under 30 lines, with zero HTML,
JS or CSS written**. This is that shape — **the target, not a working sample**. No part of it runs
today, and the exact names may still move before phase 2 lands.

```ruby
App.define :Shop do
  model :Product do
    field :name,  :string,  required: true
    field :price, :money,   currency: "USD"   # integer cents; a Float is refused by the type
    field :stock, :integer, default: 0
    scope(:in_stock) { where { stock > 0 } }  # tenant_id is applied for you
  end

  screen :Products do
    state :products do
      Product.in_stock
    end

    body do
      card do
        data_table of: :products, using: :ProductRow, empty: t("products.none")
      end
    end
  end

  action :restock do |params|
    product = Product.find!(params[:product_id])
    product.update(stock: product.stock + params[:count])

    redraw :products
    toast t("products.restocked"), level: :success
  end
end
```

Twenty-seven lines, plus a four-line `component :ProductRow` whose `button "Restock", action:
:restock` is what posts to the action. What the spec says that should project into: a Sequel-backed
model with a UUIDv7 primary key and an automatic `tenant_id`, a page auto-routed from its name and
rendered as server-side HTML with `hx-*` attributes, a POST endpoint the button is wired to, a
partial re-render swapped in by `redraw`, and tests inferred from `required:` and the field types.
**Realtime is not in that list** — a screen stays plain request/response until it declares `live` or
`channel`, so nothing pays for a websocket it did not ask for.

→ [the canonical shape of every declaration](docs/idea/02-dsl-surface.md)

## Phases

The build order from [the spec](docs/idea/00-build-spec.md). One status column, one value in it.

| Phase | Brings | Status |
|---|---|---|
| 1 · Foundation | `App.define`, `model`, `migrate`, money type, UUIDv7, tenant injection, the CLI | not implemented |
| 2 · Rendering & Actions | `component`, `screen`, `action`, the component kit, design tokens and dark mode | not implemented |
| 3 · Realtime (opt-in) | `live`, `channel`, `broadcast`, `presence`; Postgres `LISTEN/NOTIFY` by default | not implemented |
| 4 · Jobs & Async | `job` with retries and schedules, a transactional Postgres queue, `magik worker` | not implemented |
| 5 · Money & Compliance | `ledger` (double-entry, append-only), `audited`, `immutable_after:`, `idempotent_by`, `flow` | not implemented |
| 6 · API & Integration | `api` resources, incoming and outgoing `webhook`, bearer/api-key/JWT auth, rate limits | not implemented |
| 7 · Auth, Billing, Admin | `auth` (Rodauth-backed), `billing`, `admin_panel`, `tenant_by :subdomain` | not implemented |
| 8 · i18n, PWA, Notifications | `locales`, `translatable:`, timezone-safe timestamps, `pwa`, `notification` | not implemented |
| 9 · Testing | a Minitest-compiling `test` DSL, inferred factories, thread-parallel runner, `magik test` | not implemented |

Re-derive the status of any subsystem rather than trusting this table: `ruby -Ilib exe/magik help`
for the CLI's real surface, `rake test` for what is proven, and
`grep -rln NotImplementedError lib/magik` for what is still a stub.
→ [docs/idea/06-phases.md](docs/idea/06-phases.md) for what each phase contains ·
[ROADMAP.md](ROADMAP.md) for the sequencing and what a phase must demonstrate before it closes.

## The architecture decisions

Twelve non-negotiables, decided before the first line of framework code. They are the reason this
repository exists in this order — changing one is a change to
[the spec](docs/idea/00-build-spec.md), not a pull request.

| Decision | The rule | Why it is not negotiable |
|---|---|---|
| **Runtime** | TruffleRuby. Concurrency is real, parallel OS threads — no GVL | the performance ceiling that makes a Ruby framework worth building now, and it is measured rather than assumed: `ruby scripts/probes/runtime.rb` ([the evidence](docs/architecture/12-runtime-verification.md)). CRuby ≥ 3.2 is supported for development tooling only, never as a production target |
| **Server** | Rack + Puma, single mode: one process, one thread pool | TruffleRuby runs threads in parallel, so one process uses every core it is given. The same server in dev and production, and more capacity is more containers |
| **Database** | Sequel, never ActiveRecord. Explicit queries, no lazy-loading magic | an N+1 you cannot see is an N+1 you cannot fix |
| **No SPA framework** | server-rendered HTML plus htmx attributes, compiled from the DSL. No React, Vue or Ember — ever | one language, one render path, no client build step |
| **Realtime is opt-in** | per screen, never global. `live` / `channel` turn it on; nothing costs anything until declared | global realtime is what made the previous generation of these frameworks unaffordable |
| **Multi-tenant by default** | every model auto-scoped by `tenant_id`; UUIDv7 primary keys from day one | sortable, shard-safe, and retrofitting tenancy is a rewrite |
| **Stateless app servers** | no in-process session or UI state across requests | "add another server" has to stay a config change |
| **Money** | an integer-cents `:money` type. Floats are refused **at the type level**, not by review | float currency bugs are silent and permanent |
| **Swap points are mandatory** | DB engine, cache, jobs, search and realtime backends are config-switchable with no app code change, and each swap must be *proven* before merge | magic with no escape hatch is an eventual rewrite. That is the lesson from Meteor |
| **Domain modules** | `domains/<name>/domain.rb` declares `depends_on`, `exposes`, `publishes_events`; cross-domain model access fails **at boot** | a boundary that is not a boot failure is a suggestion |
| **Guardrails at boot** | unbalanced ledgers, a `field :card_number`, a domain violation, cross-request state, an unconverted timestamp — each refuses to boot | this enforcement *is* the product |
| **Errors are instructions** | every failure carries a stable `MAGIK_*` code, a concrete cause and a runnable `fix:` line | a failure should cost one command, not a search |

## The limits, stated loudly

Two things Magik will **not** do. They are permanent scope decisions, not gaps waiting on a phase:

- **No offline support.** The server is always the single source of truth. There is no local write
  queue, no reconciliation, no conflict resolution. An app that must work on a plane is the wrong
  app for this framework.
- **No heavy client-side compute.** Canvas editors, games, real-time drawing surfaces, anything
  whose interaction loop cannot survive a server round-trip. The spec's rule is to refuse and say
  so, never to silently degrade.

Neither limit is enforced by code yet, because there is no code.
→ [docs/idea/05-limits.md](docs/idea/05-limits.md) · [the spec](docs/idea/00-build-spec.md)

## What exists today

The honest inventory, `As of 2026-08-26`. Everything here is real and runnable; nothing else in this
file is.

| What ships | Detail |
|---|---|
| **Zero runtime dependencies** | the gem loads nothing but the standard library. The gems Magik intends to wrap are listed in [`magik.gemspec`](magik.gemspec) as comments, to be added by the phase that needs each one |
| `lib/magik.rb` | plain `autoload` over a `Magik::SUBSYSTEMS` map, so requiring `magik` reads one file |
| `Magik::Error` | real and tested: a stable `MAGIK_*` code, a cause, and a runnable `fix:` line, with a `to_h` for `--json`. The convention, working, before any catalogue exists |
| `magik version` · `magik help` | a working CLI, both with `--json`. `help` lists every spec'd command and marks it `ready` or `planned` |
| 19 subsystem stubs | one per planned subsystem, each exposing `SPEC_PHASE`, `DSL_SURFACE` and `STATUS`, with a `.define` that raises `NotImplementedError` naming the spec |
| the test suite | Minitest, **passing on bare Ruby with no bundle** — `rake test` |

That is the whole of it. There is no `App.define`, no `model`, no `screen`, no `action`, no router,
no server, no database code.

## Working on the framework itself

This repository is the framework, not an app built with it.

```sh
bin/setup        # dependencies and the local toolchain, idempotent
bin/check        # THE GATE — the same steps CI runs. Green means the tree is shippable
rake test        # the suite alone; works on bare Ruby, no bundle needed
```

| Task | Command |
|---|---|
| the gate, as CI runs it | `bin/check` · one step: `bin/check --only test` · as data: `bin/check --json` |
| every rake task | `rake -T` — `build`, `check`, `docs:coverage`, `rubocop`, `test`, `yard` |
| tests | `rake test` |
| lint | `rake rubocop` (RuboCop comes from `bundle install`) |
| docs | `rake yard` · coverage: `rake docs:coverage` |
| the CLI, from source | `ruby -Ilib exe/magik version --json` · `ruby -Ilib exe/magik help` |
| a console | `bin/console` |
| the CLI against the demo app | `bin/dev` · [`dummy/`](dummy/) |
| release pre-flight (prints, never publishes) | `bin/release` · [PUBLISHING.md](PUBLISHING.md) |
| Postgres and friends, in containers | `docker/compose.yml` · [`.devcontainer/`](.devcontainer/) |

`rake test` needs nothing but Ruby and Rake. RuboCop and YARD are development dependencies — run
`bin/setup` (or `bundle install`) before `rake rubocop` or `rake yard`, or the task aborts with the
install hint rather than pretending to pass.

TruffleRuby is the production runtime and is **not** assumed to be installed locally; anything
TruffleRuby-specific runs in [CI](.github/workflows/ci.yml). Development on CRuby ≥ 3.2 is expected
and supported.

→ [CONTRIBUTING.md](CONTRIBUTING.md) for the full loop, the commit convention and the rule that
every change must trace to a section of the spec.

## Navigate

One hop per question.

| You want | Go |
|---|---|
| **what Magik is, authoritatively** | [docs/idea/00-build-spec.md](docs/idea/00-build-spec.md) — the source of truth; nothing contradicts it |
| why "AI-first" is a design constraint | [docs/idea/07-ai-first.md](docs/idea/07-ai-first.md) |
| the agents and slash commands for working here | [.claude/README.md](.claude/README.md) |
| the TypeScript sibling of this framework | [developerz-ai/ultimate](https://github.com/developerz-ai/ultimate) |
| the thesis, in full | [docs/idea/01-thesis.md](docs/idea/01-thesis.md) |
| the DSL surface, phase by phase | [docs/idea/02-dsl-surface.md](docs/idea/02-dsl-surface.md) |
| the boot-time guardrails | [docs/idea/03-guardrails.md](docs/idea/03-guardrails.md) |
| the swap points | [docs/idea/04-swap-points.md](docs/idea/04-swap-points.md) |
| the limits, argued | [docs/idea/05-limits.md](docs/idea/05-limits.md) |
| why a decision was made | [docs/idea/](docs/idea/) |
| how a subsystem is meant to work | [docs/architecture/](docs/architecture/) |
| running an app for real | [docs/ops/README.md](docs/ops/README.md) |
| the reference manual | [wiki/Home.md](wiki/Home.md) |
| the generated API docs | [developerz-ai.github.io/magik/api/](https://developerz-ai.github.io/magik/api/) — built by [`docs.yml`](.github/workflows/docs.yml) from `rake yard` |
| where code goes in an app you build | [wiki/Project-Layout.md](wiki/Project-Layout.md) · [dummy/](dummy/) — an invoicing/billing SaaS |
| what is planned, in what order | [ROADMAP.md](ROADMAP.md) |
| the machine-readable repo map | [llms.txt](llms.txt) |
| the contract for changing this repo | [CLAUDE.md](CLAUDE.md) (`AGENTS.md` is a symlink to it) |
| how to contribute | [CONTRIBUTING.md](CONTRIBUTING.md) · [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) |
| reporting a vulnerability | [SECURITY.md](SECURITY.md) |
| what changed | [CHANGELOG.md](CHANGELOG.md) |
| how a release is cut and published | [PUBLISHING.md](PUBLISHING.md) |

## Never claimed

No adoption numbers. No production deployments. No benchmarks. No passing-test counts. No
comparison against another framework. None of those exist yet, and this file will keep saying so
until they do — a number here that no command re-derives is a bug in the documentation.

## License

MIT © [developerz.ai](https://developerz.ai) — [LICENSE](LICENSE)
