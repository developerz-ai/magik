<h1 align="center">Magik</h1>

<p align="center"><strong>Focus on delivering. Don't worry about glue code.</strong></p>

<p align="center">An AI-first, full-stack Ruby framework. One DSL for models, screens, actions, realtime, jobs,
ledgers, APIs and admin — server-rendered on TruffleRuby, with your agent doing the typing.</p>

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

## Start here

You have an idea for a product. You want it to exist.

Between those two things sits a mountain of work that has nothing to do with your idea: wiring up a
database, building login, making the sidebar work on a phone, adding pagination to a table, chasing
a slow query, setting up a background job, getting the invoice email to render, keeping the admin
panel in step with the app. It all has to be right. None of it is *why you started*.

**Magik is the framework that already did that part.** You describe what your product does; the
framework supplies everything around it. And you do not type it yourself — you work with a coding
agent, in three steps:

```sh
magik new myapp     # 1. a complete, working application skeleton
/setup-project      # 2. your agent asks about your product, once, and shapes the app around it
/feature            # 3. describe a feature. Then another. Then another.
```

Step 3 is the whole job, repeated. **You bring the direction; the agent does the work.** That split
is the point: ideas and judgement are the scarce input, and typing is not.

**You never choose a database, a queue, a CSS framework or a JSON parser.** Magik has already
chosen, and it chose the things that are expensive to change later. Where a choice is cheap to
change, it stays yours.

> **New to this? You are the intended reader.** The framework refuses to start if your app has a
> money bug, an unprotected page or a query that will break at scale — so a whole class of mistakes
> is not available to you, whether or not you would have known to look for them.
>
> **Been doing this twenty years? Also the intended reader.** Skip to
> [the architecture decisions](#the-architecture-decisions), [the guardrails](#guardrails-the-framework-refuses-to-boot),
> and [the swap points](#choosing-a-framework-is-normally-a-one-way-door) — the reasoning is written
> down, and every default has a documented way out.

One sentence serves both: **Magik makes the decisions that are expensive to get wrong, and gets out
of the way where they are not.** One reader hears *I am protected*. The other hears *I am not
trapped*. It is the same mechanism.

> ## Status: pre-alpha, spec only
>
> **Magik is not implemented.** This repository is the ground work — the spec, the documentation, the
> gem skeleton, the CI and the release plumbing. There is no framework behind it yet: no `magik new`,
> no `model`, no `screen`, no `action`, no server. **Every framework feature named on this page is
> `planned`**; the short list of things that genuinely run is
> [what exists today](#what-exists-today).
>
> `0.0.1` is a name reservation on RubyGems and nothing more — see [CHANGELOG.md](CHANGELOG.md).
> Nothing here has been benchmarked, deployed, or run against a database, and this file will say so
> until that changes. `As of 2026-08-26`; re-derive with `ruby -Ilib exe/magik version --json` and
> `gem list -r magik --all`.

> **If you are a coding agent, start with [`llms.txt`](llms.txt)** — the whole repository as one link
> map, and the shortest route to knowing which parts exist. Then read
> [`CLAUDE.md`](CLAUDE.md), the working contract for changes made inside this repo, and
> [`.claude/README.md`](.claude/README.md) for the agents and slash commands this repo ships.

## The glue code, named

"Glue code" is vague praise until you list it, and the list *is* the product claim. Every one of
these is work you would otherwise do by hand, in every project, forever:

routes and parameter parsing · form handling and validation display · serializers · pagination
arithmetic · N+1 fixes · tenant scoping on every single query · background job wiring and retries ·
webhook signature verification · migration boilerplate · cache invalidation · the sidebar, the
topbar, the breadcrumbs and their behaviour on a phone · empty, loading and error states · file
upload plumbing and image derivatives · email layouts and plain-text alternatives · the admin panel ·
CSRF, CSP and cookie flags · linter, formatter and CI configuration.

All of it must be correct. None of it is your product. **Magik generates it from the declaration you
already wrote.** → [the DSL, in one worked example](#the-dsl-in-one-worked-example)

## Everything, included

The claim is not that Magik *can* do these things — it is that **you never choose them**. Auth,
billing, an admin panel at [Avo](https://avohq.io)'s level, realtime, background jobs on Postgres
(not Redis, not a second service), double-entry ledgers, file and image handling, video and audio
behind a wrapped provider, email with a previewer and a suppression list, i18n, notifications, a
REST API, charts, searchable and paginated tables, abuse resistance, staging and dev environments —
one grammar, one gem, one gate. No assembling a stack from twelve gems over a weekend, no
`node_modules`, no build step.

**Ship the shape, not the parts.** Nobody's SaaS is a novel interface. It is a sidebar, a topbar, a
row of stats, a filterable table, a detail view, settings, members, billing, and an empty state for
when there is nothing yet. A component kit that hands you `grid` and `card` and asks you to assemble
a sidebar out of them has done the easy half. Magik ships the shell — `layout`, `sidebar`,
`nav_item`, `breadcrumbs`, `account_menu` — so a generated app has working navigation on its first
run, responsive by construction, with no CSS written.

**Fewer decisions for you is more time for the product.** The decisions Magik makes on your behalf
are the ones you could not afford to get wrong — UUIDv7 keys, `tenant_id` on every model,
integer-cent money, stateless servers, authorization in exactly one place — and the ones most people
would not have known to make: cursor pagination instead of `OFFSET`, an index on every `tenant_id`,
a `statement_timeout`, EXIF stripped from every upload. Where a decision is cheap to reverse, Magik
does not make it for you at all. That is what the [swap points](docs/idea/04-swap-points.md) and the
[component override ladder](docs/idea/08-component-overrides.md) are: **opinions where reversal is
impossible, choices where it is not.**

→ [docs/idea/10-saas-coverage.md](docs/idea/10-saas-coverage.md) counts the grammar against 68
surfaces a SaaS needs across its whole life, and carries the command that re-counts the table. Its
last full count put full coverage at **under a fifth**. That gap is the roadmap; the count is the
honest measure of it.

## Who it is for, and the range

**One framework from a weekend CRUD app to a multi-tenant fintech product** — no lite mode, no
second stack to graduate to. The small end pays nothing for the large end; the large end is
configuration the small end never types.

The mechanism differs at each end, which is the whole reason one framework can serve both:

| | What carries you | Why the other end is still reachable |
|---|---|---|
| **You are not a developer** | **the guardrails substitute for expertise.** The app refuses to boot on an unbalanced ledger, a float used for money, a page with no access rule, or a query missing its tenant filter. You do not need to know why those are dangerous — you cannot ship them | nothing you did on day one has to be undone. UUIDv7 keys and `tenant_id` are in your first migration whether or not you ever needed them |
| **You have done this for twenty years** | **the escape hatches prevent the ceiling.** Every opinionated default is a config-level swap; every component has a four-rung override ladder; the database is plain Postgres and the query builder is Sequel, not a DSL you cannot read | you are never stuck at the first place the opinion is wrong for you, and you did not spend the afternoon on glue either |
| **Small growing to large** | flat `app/` becomes `domains/` as a path-prefix move with boot-time boundary enforcement; Postgres-for-everything is swapped by configuration; realtime stays opt-in; the servers were stateless from day one | there is no rewrite waiting at the point of success. That is the promise, and it is the one this repository has to earn |

**The honest ceiling.** Magik lowers the **expertise floor for correctness**. It does not lower the
**responsibility floor for running a business** — you still own your data, your customers, your
uptime and your decisions. A framework that implied otherwise would be lying to the reader it most
wants to help.

**State `As of 2026-08-26`: none of the above is implemented.** It is a design, written down before
the code so the shape is fixed while changing it is still cheap. Re-derive what is real with
`ruby -Ilib exe/magik help` and `rake test`.

## Choosing a framework is normally a one-way door

It is the most consequential decision in a project and the hardest to reverse. Two years in, the
framework is not a dependency — it *is* the application. That is exactly the kind of irreversible
decision Magik's own thesis is about, so this file is written to be **trusted, not to convert**.

Four things you would actually need in order to walk away, and Magik keeps all four:

- **Standard Ruby underneath.** Sequel, Rack, Postgres. No proprietary runtime, no bespoke query
  language, no data format you cannot read without us.
- **Your data is plain Postgres.** Ordinary tables, ordinary SQL, ordinary `pg_dump`. The thing you
  would need to take with you is already portable, by construction.
- **Every default is reachable.** The [swap points](docs/idea/04-swap-points.md) cover the database,
  cache, jobs, search and realtime backends, and the spec requires each swap to be **proven by a
  passing test before merge** — never promised in prose. The
  [override ladder](docs/idea/08-component-overrides.md) does the same for every component.
- **The limits are stated up front,** not discovered in month six. →
  [the limits](#the-limits-stated-loudly)

This is the [Meteor](https://en.wikipedia.org/wiki/Meteor_(web_framework)) lesson stated for your
benefit rather than the designer's. Meteor was a one-way door because its magic had no seam. Magik's
seams are the product — and the honest status callout above is part of the same commitment: a README
that admits what does not exist can be trusted on what it says does.

## AI-first, and why that shapes every decision

The premise: the person shipping the SaaS describes it, and an agent writes it. That is a design
constraint, not a marketing line — an agent has different failure modes from a human, and the
architecture decisions below are answers to those failure modes rather than to taste.

| An agent's failure mode | Magik's answer | Consequence in the design |
|---|---|---|
| **Limited context.** Reading a framework costs the budget the product needed | one grammar for every subsystem — `model`, `screen`, `action`, `job`, `ledger`, `api` all declare the same way. Learn one primitive and you can guess the rest | no second syntax, no plugin API, no configuration dialect. A feature that does not fit the grammar does not ship |
| **Confident wrongness.** It will write plausible code that is subtly unsafe | guardrails that **refuse to boot** — an unbalanced ledger, a `field :card_number`, a page with no access rule, an unbounded upload, cross-request state, an unconverted timestamp. Enforcement is the product | a convention that is not a boot failure is a suggestion. Review cannot be the mechanism when nobody reads every line |
| **No feedback loop.** A silent wrong default is never noticed | `magik check` — the one command that says whether the app is shippable, and `magik check --scale` for the queries that will hurt later | one command, one verdict. The agent's loop is edit → check → fix, not edit → hope |
| **Cannot recover from a bare stack trace** | every error carries a stable `MAGIK_*` code, the concrete cause, and a `fix:` line that is a **command you run, never advice** | a failure costs one round-trip instead of a search |
| **Has not been trained on this DSL, and web search is slow** | **the gem ships its own documentation.** `magik docs path` prints the directory inside the installed gem, so an agent's ordinary grep and read already reach it — version-matched, so what it reads is what the code does | no retrieval step, no stale blog post, no drift between the docs and the runtime |
| **Boilerplate is where it burns tokens and makes mistakes** | zero HTML, JS or CSS written by hand; tests, factories and admin CRUD inferred from the declarations already made | the [example below](#the-dsl-in-one-worked-example) is the whole of a feature |
| **A wrong guess about the stack is expensive to undo** | convention over configuration, and every opinionated default has a *proven* config-level swap | the agent never has to choose a database, a queue or a cache to start, and is never trapped by not having chosen |

**This is a claim about the design, not about a build.** None of it is implemented — read the status
callout above. The reason it is written down now is that these decisions are cheap today and a
rewrite later. → [docs/idea/07-ai-first.md](docs/idea/07-ai-first.md)

The repository dogfoods the premise: the framework itself is built by agents working from
[the spec](docs/idea/00-build-spec.md), with [`CLAUDE.md`](CLAUDE.md) as the contract and
[`.claude/`](.claude/README.md) carrying the agents and slash commands that drive the phases.

### Why a DSL is the right shape for this

A DSL asks a human to *remember* a vocabulary. That is its real cost — and it is a cost of **recall,
not of comprehension**. `ledger :Payouts do … end` is legible to anyone on first reading; what is
hard is holding twenty constructs and their options in your head while you type.

Recall is precisely what an agent does not have to do. It looks the option up, every time, in
documentation that shipped with the gem. Comprehension survives for the human, because Ruby blocks
read as English — which is what makes the diff auditable at a glance when it is your turn to review.

So Magik is **optimised for machine authorship and still legible under human review.** Kubernetes is
the precedent rather than the warning here: its verbosity was never really the problem —
hand-authoring it was. A declarative surface that is tedious to write by hand and trivial to
generate is a good trade the moment something else is doing the writing.

The honest version of the argument, without the hype: writing a perfect nginx config or a subtle
bash script from memory is something people get wrong constantly, because the failure mode is
*recall under pressure*. An agent is not perfect either — the entire guardrail design assumes it
errs. The accurate claim is narrower and stronger: **on a recall-heavy declarative surface, an agent
with lookup and a boot-time gate beats a human working from memory.** All three parts are load-bearing.

This also explains the DSL's shape: **roughly twenty constructs, heavily parameterized, constant
size.** The same principle as designing tools for an agent — a few well-parameterized ones beat
many narrow ones — which is why the grammar grows by *options on existing constructs* rather than by
new constructs, and why `magik describe --json` can emit the whole surface as data.

## The DSL, in one worked example

The spec's first success criterion is **a new CRUD SaaS screen in under 30 lines, with zero HTML, JS
or CSS written**. This is that shape — **the target, not a working sample.** No part of it runs
today, and the exact names may still move before phase 2 lands.

```ruby
App.define :Shop do
  roles :owner, :staff, :viewer, default: :viewer

  policy :Product do
    default :deny                                       # required. There is no implicit allow
    can(:read)    { |actor, _product| actor.role?(:viewer, :staff, :owner) }
    can(:restock) { |actor, _product| actor.role?(:staff, :owner) }
  end

  model :Product do
    field :name,  :string,  required: true
    field :price, :money,   currency: "USD"             # integer cents; a Float is refused
    field :stock, :integer, default: 0
    scope(:in_stock) { where { stock > 0 } }            # tenant_id is applied for you
  end

  screen :Products, policy: %i[Product read], layout: :App do
    state(:products) { Product.in_stock }

    body do
      card { data_table of: :products, using: :ProductRow, empty: t("products.none") }
    end
  end

  action :restock, policy: %i[Product restock] do |params|
    product = Product.find!(params[:product_id])
    product.update(stock: product.stock + params[:count])

    redraw :products
    toast t("products.restocked"), level: :success
  end
end
```

Twenty-eight lines, plus a four-line `component :ProductRow` whose `button "Restock", action:
:restock` is what posts to the action. What the spec says that should project into: a Sequel-backed
model with a UUIDv7 primary key and an automatic `tenant_id`; a page auto-routed from its name,
rendered into the `:App` shell as server-side HTML with `hx-*` attributes; a POST endpoint the button
is wired to; a partial re-render swapped in by `redraw`; an authorization check on both the page and
the mutation from one rule set; and tests inferred from `required:`, the field types and each policy
verb — including a cross-tenant denial.

Three things that are *not* there, on purpose:

- **No realtime.** A screen stays plain request/response until it declares `live` or `channel`, so
  nothing pays for a websocket it did not ask for.
- **No second place to write an access check.** `policy :Product` is the only one, and every
  generated surface — screen, action, API resource, channel, job, admin panel — evaluates it. A
  surface that names no verb does not boot.
- **No layout markup.** `layout: :App` is the shell, generated working by `magik new`.

→ [the canonical shape of every declaration](docs/idea/02-dsl-surface.md)

## Guardrails: the framework refuses to boot

This is the part that is hardest to add later and easiest to underestimate, so it is stated as its
own section. **A convention that is not a boot failure is a suggestion.** These are failures:

| Your app does this | Magik does this |
|---|---|
| a ledger whose debits and credits do not balance | refuses to boot — `MAGIK_LEDGER_UNBALANCED` |
| a `Float` anywhere near currency | refused **at the type level**, not by code review |
| a `field :card_number` | refused — forces tokenized payment fields |
| a screen, action, API resource, channel, job or admin panel with no declared access rule | refuses to boot — `MAGIK_POLICY_UNDECLARED` |
| a file upload with no size limit and no allowed content types | refuses to boot — an unbounded upload is an unbounded bill and a trivial DoS |
| a screen with no layout, or a nav link to a page that does not exist | refuses to boot |
| a timestamp rendered without an explicit timezone | refuses to boot |
| a screen or action holding state between requests | refuses to boot |
| one domain reaching directly into another domain's models | refuses to boot |
| a query that will hurt once the table is large | `magik check --scale` names it before it hurts |

Every one of those errors carries a stable code, the concrete cause, and a `fix:` line that is a
command you can run:

```
MAGIK_LEDGER_UNBALANCED: ledger :Payouts does not balance
  cause: entry :capture debits 1200 and credits 1150
  fix:   magik check --ledger Payouts
```

→ [the full guardrail catalogue](docs/idea/03-guardrails.md) ·
[the error codes](wiki/Error-Codes.md)

## Phases

The build order from [the spec](docs/idea/00-build-spec.md). One status column, one value in it.

| Phase | Brings | Status |
|---|---|---|
| 1 · Foundation | `App.define`, `model`, `migrate`, money type, UUIDv7, tenant injection, the CLI, `magik describe` | not implemented |
| 2 · Rendering & Actions | `component`, `screen`, `action`, **`policy`**, **`layout`**, the component kit, design tokens and dark mode | not implemented |
| 3 · Realtime (opt-in) | `live`, `channel`, `broadcast`, `presence`; Postgres `LISTEN/NOTIFY` by default | not implemented |
| 4 · Jobs & Async | `job` with retries and schedules, a transactional Postgres queue, `magik worker` | not implemented |
| 4b · Media | `attachment`, direct-to-storage upload, image derivatives, signed delivery, video and audio behind a wrapped provider | not implemented |
| 5 · Money & Compliance | `ledger` (double-entry, append-only), `audited`, `immutable_after:`, `idempotent_by`, `flow` | not implemented |
| 6 · API & Integration | `api` resources, incoming and outgoing `webhook`, bearer/api-key/JWT auth, rate limits | not implemented |
| 7 · Auth, Billing, Admin | `auth` (Rodauth-backed), `billing`, `admin_panel`, teams and seats, `tenant_by :subdomain` | not implemented |
| 8 · i18n, PWA, Notifications | `locales`, `translatable:`, timezone-safe timestamps, `pwa`, `notification`, email production | not implemented |
| 9 · Testing | a Minitest-compiling `test` DSL, inferred factories, thread-parallel runner, `magik test` | not implemented |

Re-derive the status of any subsystem rather than trusting this table: `ruby -Ilib exe/magik help`
for the CLI's real surface, `rake test` for what is proven, and
`grep -rln NotImplementedError lib/magik` for what is still a stub.
→ [docs/idea/06-phases.md](docs/idea/06-phases.md) for what each phase contains ·
[ROADMAP.md](ROADMAP.md) for the sequencing and what a phase must demonstrate before it closes.

## The architecture decisions

Thirteen non-negotiables, decided before the first line of framework code. They are the reason this
repository exists in this order — changing one is a change to
[the spec](docs/idea/00-build-spec.md), not a pull request.

| Decision | The rule | Why it is not negotiable |
|---|---|---|
| **Runtime** | TruffleRuby. Concurrency is real, parallel OS threads — no GVL | the performance ceiling that makes a Ruby framework worth building now, and it is measured rather than assumed ([the evidence](docs/architecture/12-runtime-verification.md), re-derivable from `scripts/probes/`). CRuby ≥ 3.2 is supported for development tooling only, never as a production target |
| **Server** | Rack + Puma, single mode: one process, one thread pool | TruffleRuby runs threads in parallel, so one process uses every core it is given — and it has no `fork`, so there are no clustered workers to reason about. More capacity is more containers |
| **Database** | Sequel, never ActiveRecord. Explicit queries, no lazy-loading magic | an N+1 you cannot see is an N+1 you cannot fix |
| **No SPA framework** | server-rendered HTML plus htmx attributes, compiled from the DSL. No React, Vue or Ember — ever | one language, one render path, no client build step |
| **Realtime is opt-in** | per screen, never global. `live` / `channel` turn it on; nothing costs anything until declared | global realtime is what made the previous generation of these frameworks unaffordable |
| **No offline support** | the server is always the single source of truth | stated as a permanent limit rather than half-built. → [the limits](#the-limits-stated-loudly) |
| **No heavy client-side compute** | canvas editors, games and drawing surfaces are out of scope | refuse and say so, never silently degrade |
| **Multi-tenant by default** | every model auto-scoped by `tenant_id`; UUIDv7 primary keys from day one | sortable, shard-safe, and retrofitting tenancy is a rewrite |
| **Stateless app servers** | no in-process session or UI state across requests | "add another server" has to stay a config change |
| **Money** | an integer-cents `:money` type. Floats are refused **at the type level**, not by review | float currency bugs are silent and permanent |
| **Swap points are mandatory** | DB engine, cache, jobs, search and realtime backends are config-switchable with no app code change, and each swap must be *proven by a test* before merge | magic with no escape hatch is an eventual rewrite. That is the lesson from Meteor |
| **Domain modules** | `domains/<name>/domain.rb` declares `depends_on`, `exposes`, `publishes_events`; cross-domain model access fails **at boot** | a boundary that is not a boot failure is a suggestion |
| **Authorization in exactly one place** | every surface reaching a model — screen, action, API resource, channel, job, admin panel — names a verb in a `policy`, and the framework evaluates it. There is no second door to the data, and authorization is deliberately **not** a swap point | a second authorization backend is a second authorization system, which is the failure this design is organised against |

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
  CRuby's interpreter; a JIT-compiled runtime with genuinely parallel threads is a different
  conversation — and one this repo measures rather than asserts.

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
gem install magik          # installs 0.0.1 — a version constant, `magik help` and `magik docs`
magik new shop && cd shop  # planned
bin/setup                  # planned — dependencies, database, migrations, seeds
magik server               # planned — Puma, hot reload
```

The CLI surface the spec commits to: `magik new`, `magik generate model|screen|action|migration`,
`magik console`, `magik server`, `magik worker`, `magik test`, `magik check`, and `magik describe` —
the grammar itself as data, every construct and option with its type, defaults and the error codes it
can raise, so an agent can look up a spelling without a web search. **`magik help` marks each one
`ready` or `planned`** — "not built yet" and "not a command" are different facts, and the CLI already
says which is which:

```sh
ruby -Ilib exe/magik help    # every command, with its status
```

Your generated project also gets `bin/` and `scripts/` directories of its own, so the agent working
in your app has the same short, discoverable command surface this repository has.

→ [Phase table](#phases) · [the CLI in the DSL surface doc](docs/idea/02-dsl-surface.md) ·
[the spec's build order](docs/idea/00-build-spec.md)

## What exists today

The honest inventory, `As of 2026-08-26`. Everything here is real and runnable; nothing else in this
file is.

| What ships | Detail |
|---|---|
| **Zero runtime dependencies** | the gem loads nothing but the standard library. The gems Magik intends to wrap are listed in [`magik.gemspec`](magik.gemspec) as comments, to be added by the phase that needs each one |
| `lib/magik.rb` | plain `autoload` over a `Magik::SUBSYSTEMS` map, so requiring `magik` reads one file |
| `Magik::Error` | real and tested: a stable `MAGIK_*` code, a cause, and a runnable `fix:` line, with a `to_h` for `--json`. The convention, working, before any catalogue exists |
| `magik version` · `magik help` · `magik docs` | a working CLI, all with `--json`. `help` lists every spec'd command and marks it `ready` or `planned`; `docs` serves the documentation packaged inside the gem |
| 20 subsystem stubs | one per planned subsystem, each exposing `SPEC_PHASE`, `DSL_SURFACE` and `STATUS`, with a `.define` that raises `NotImplementedError` naming the spec |
| the test suite | Minitest, **passing on bare Ruby with no bundle** — `rake test` |

That is the whole of it. There is no `App.define`, no `model`, no `screen`, no `action`, no `policy`,
no `layout`, no router, no server, no database code.

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
| who decides what, and the log of decisions taken | [docs/idea/13-decisions.md](docs/idea/13-decisions.md) |
| the agents and slash commands for working here | [.claude/README.md](.claude/README.md) |
| the TypeScript sibling of this framework | [developerz-ai/ultimate](https://github.com/developerz-ai/ultimate) |
| the thesis, in full | [docs/idea/01-thesis.md](docs/idea/01-thesis.md) |
| the DSL surface, phase by phase | [docs/idea/02-dsl-surface.md](docs/idea/02-dsl-surface.md) |
| the boot-time guardrails | [docs/idea/03-guardrails.md](docs/idea/03-guardrails.md) |
| the swap points | [docs/idea/04-swap-points.md](docs/idea/04-swap-points.md) |
| the limits, argued | [docs/idea/05-limits.md](docs/idea/05-limits.md) |
| how much of a SaaS the grammar actually covers | [docs/idea/10-saas-coverage.md](docs/idea/10-saas-coverage.md) |
| the three-stage scaffold, and who owns each generated file | [docs/idea/09-app-scaffold.md](docs/idea/09-app-scaffold.md) |
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
comparison against another framework on speed. None of those exist yet, and this file will keep
saying so until they do — **a number here that no command re-derives is a bug in the documentation.**

## License

MIT © [developerz.ai](https://developerz.ai) — [LICENSE](LICENSE)
