# Thesis

Rails' bet — one blessed path, batteries included — re-run on TruffleRuby with a single DSL grammar covering models, screens, actions, realtime, jobs, ledgers, APIs and admin, written primarily by an AI agent, where the framework's product is the set of things it refuses to boot.

**Status:** spec only. These are the axioms behind [`00-build-spec.md`](00-build-spec.md), not a description of shipped behaviour. Reviewed 2026-08-26.

## The claim

A SaaS team writes the same forty percent of every app — CRUD screens, a form, a table, an audit trail, a webhook, a money column that must not be a float — and writes it in four languages across three repos. Magik's bet is that all of it is expressible in **one Ruby DSL grammar**, server-rendered, and that the framework earns its keep by failing the boot when the app violates something that would otherwise be found in production.

The second bet is who is typing. **Magik is AI-first: the primary developer is an AI agent, and the secondary is an engineer driving one.** That is a design constraint, not positioning — it is the reason the grammar is uniform, the reason a wrong app fails at boot instead of in review, and the reason every error carries a command rather than advice. The full argument is [`07-ai-first.md`](07-ai-first.md).

Two lines of the spec are load-bearing for everything below:

> **Swap points required for every "opinionated default."** … (Lesson from Meteor's death: magic with no escape hatch = eventual rewrite.)

> **Guardrails to Enforce at Boot (this IS the product)**


## The vision

> **Humans with ideas and vision, AIs with the work.** The human gives direction; the agent does the typing; `magik check` decides whether it passed.
>
> **Focus on delivering. Don't worry about glue code.**

Two sentences, one argument. Everything in the axiom table below is downstream of them.

### The division of labour

**Direction is the scarce input; typing is not.** So the framework's job is to make a direction executable with as little intervening ceremony as possible. What is left for the human is all judgement and no production: deciding what to build, reviewing what came back, and saying when it is wrong.

| Consequence | Where it already shows up |
|---|---|
| Review-time legibility is a first-order property; authoring convenience is not | the recall-versus-comprehension argument in [`11-dsl-as-tool-surface.md`](11-dsl-as-tool-surface.md). A declaration is read far more often than it is written, and by the person who has to approve it |
| The loop is "describe the product once, then direct one feature at a time" | `/setup-project` and `/feature` are that split made literal ([`09-app-scaffold.md`](09-app-scaffold.md)) |
| **Delegation is only safe if something other than your attention catches the mistakes** | which is the whole argument for boot-time enforcement being *the product* ([`03-guardrails.md`](03-guardrails.md)). Guardrails are not a quality feature; they are what makes handing the work over rational |

### Glue code, defined

**Glue code** is everything a developer writes that is not their product: route definitions and param parsing, serializers, form handling and validation plumbing, pagination arithmetic, N+1 fixes, background-job wiring, webhook signature verification, migration boilerplate, cache invalidation, tenant scoping on every query, the application shell and its responsive behaviour, linter and CI configuration, and the twelve small decisions between a model and a working screen. None of it is the reason the product exists. All of it has to be right.

Magik's claim is that **the glue is derived from the declaration** rather than typed — one `model`, one `screen`, one `action`, and the wiring between them falls out. That is the "define once, project everywhere" idea credited to Ultimate below, stated from the user's side instead of the architecture's. Its corollary is the actual value proposition, and it is sharper than "batteries included": **fewer decisions for the author is more time for the product.** Every choice Magik makes is one nobody has to research, defend in review, or revisit in eighteen months.

Three ways the framework spends those decisions, and they are the same trade three times over:

| | |
|---|---|
| **Opinions where reversal is impossible** | the glue you cannot afford to get wrong is not yours to write |
| **Ship the shape, not the parts** (axiom 13) | the glue you were going to write anyway is already written |
| **Defaults its users would not know to choose** | the glue you would have written badly is written well ([`../architecture/10-performance-defaults.md`](../architecture/10-performance-defaults.md)) |

### Where the opinions are concentrated

The defence of an opinionated framework is not "we know better". It is a rule about *placement*:

> **Magik's opinions are concentrated exactly where reversal is impossible.**

Every decision the framework makes for its user is one that is cheap on day one and catastrophic on day one thousand:

| Decision | What reversing it later costs |
|---|---|
| **UUIDv7 primary keys** | changing a primary key type across a live, referenced schema is a migration nobody survives — and sortable ids are what make cursor pagination and future sharding possible at all |
| **`tenant_id` on every model** | retrofitting tenancy means auditing every query ever written. `magik check --scale` exists because this one is unforgiving |
| **Integer cents, floats refused at the type level** | a float that reached the database is already wrong. No later fix recovers the lost precision |
| **Stateless app servers** | this is what makes "add another server" a config change instead of a rewrite — and it is what LiveView's stateful socket costs, as noted below |
| **No lazy loading** | an N+1 that ships is a cliff found in production. `MAGIK_LAZY_ASSOCIATION` makes it an error at the access site instead |
| **Append-only ledgers, `audited`, `immutable_after:`** | history you did not record cannot be reconstructed. In a fintech context that is a compliance failure, not an inconvenience |

The symmetry is the other half of the rule: **where reversal is cheap, Magik does not decide for you.** Cache backend, job backend, realtime backend, search, mail transport — all switchable by one config line, because switching them later costs a config line rather than a schema migration ([`04-swap-points.md`](04-swap-points.md)).

So the framework is maximally opinionated where change is impossible, and maximally flexible where change is easy. That is the direct answer to the Meteor failure named below: **Meteor's magic was concentrated in the reversible layer**, where an escape hatch was both possible and absent.

### Who it works for, and where the claim stops

Magik is useful at both ends of the experience range, and it is worth naming *why*, because **the mechanism is different at each end**. "Good for beginners and experts alike" is marketing; this is not the same claim.

**For the non-expert, the guardrails substitute for expertise.** Someone who does not know that floats destroy money, that a double-entry ledger must balance, that every query needs `tenant_id`, or that a primary key type cannot be changed once rows reference it — gets all of it anyway, because the framework refuses to boot otherwise. That is a stronger claim than "it is easy to use": **the boot-time guardrails encode expertise the author does not have and cannot reasonably be expected to acquire.** [`03-guardrails.md`](03-guardrails.md) calls the guardrails the product; this is who they are the product *for*. A non-expert building an invoicing app on Magik gets double-entry correctness they could not have specified themselves.

**For the expert, the escape hatches prevent the ceiling.** Experts bounce off opinionated frameworks at the first place the opinion is wrong for them. The answer is [`04-swap-points.md`](04-swap-points.md) and the override ladder in [`08-component-overrides.md`](08-component-overrides.md): every default is reachable and replaceable, and nothing is hidden behind magic with no seam. That is the Meteor lesson told as an audience argument — the expert stays because they never hit a wall, not because they never disagree.

What both ends share is the same reason: neither spends the afternoon on glue. The junior did not have the expertise to write it correctly; the expert has better uses for the time.

**The ceiling, stated plainly**, because a claim with no limit is not credible: *non-technical* does not mean *no technical judgement required*. Somebody still owns production, decides the trade-offs, reviews the diff, and is accountable when it breaks at 3am. The guardrails catch the mistakes they can catch, and a mis-specified product is not one of them. **Magik lowers the expertise floor for correctness. It does not lower the responsibility floor for operating a business.**

### The counterweight

Stated in the same breath, because a vision statement without one is marketing: **a decision made for someone is only a gift if they can undo it when their case is genuinely different.** Glue that is generated is glue you no longer control directly. That is what the swap points ([`04-swap-points.md`](04-swap-points.md)), the component override ladder ([`08-component-overrides.md`](08-component-overrides.md)) and the raw-HTML hatch exist for.

Removing decisions *and* the ability to reach underneath them is not a service — it is the Meteor failure named below, one layer up. Axiom 13 sits squarely in the reversible layer: a shipped application shell is an aesthetic opinion, not a schema, which is exactly why it must arrive with the ladder rather than without one.

## Design axioms

| # | Axiom | Consequence |
|---|---|---|
| 1 | **The primary developer is an AI agent.** | Every other axiom is downstream of this one. Agents fail on ambiguity, not on syntax, so a choice menu is a defect: one grammar, one blessed answer, one feedback loop. See [`07-ai-first.md`](07-ai-first.md). |
| 2 | **One DSL grammar for everything.** | `ledger` reads like `model` reads like `screen`. An agent that has learned `model` has already learned `job`. There is no "fintech mode" and no second dialect for the hard parts. A feature that cannot be said in the grammar does not ship. |
| 3 | **Server-authoritative.** | The server is the single source of truth for every byte of state. No client store, no offline reconciliation, no optimistic twin to keep honest. |
| 4 | **No SPA.** | UI is server-rendered HTML plus htmx attributes, compiled from the DSL. React/Vue/Ember are a permanent no, not a "later" ([`05-limits.md`](05-limits.md)). |
| 5 | **Cost is opt-in.** | Realtime, presence, audit trails and jobs cost nothing until declared. `live`/`channel` on a screen is what buys a socket; the default is request/response. |
| 6 | **Every default has a proven swap.** | DB, cache, jobs, search and realtime are config-switchable without app code changes, and a swap ships proven, not promised ([`04-swap-points.md`](04-swap-points.md)). |
| 7 | **Guardrails are the product.** | An unbalanced ledger, a `card_number` column, a cross-domain reach, a screen holding request state, a timestamp with no zone — each fails the boot with a code and a runnable fix ([`03-guardrails.md`](03-guardrails.md)). The boot is where an agent's mistake is caught, because production is where it is otherwise found. |
| 8 | **Errors are instructions.** | Stable `MAGIK_*` code + the specific cause + an executable `fix:` line, renderable as `--json`. An agent that can read the fix does not need to ask a human what to do next ([`../architecture/03-error-codes.md`](../architecture/03-error-codes.md)). |
| 9 | **Multi-tenant and sortable from day one.** | `tenant_id` auto-injected on every model, UUIDv7 primary keys. Retrofitting either is a migration nobody survives. |
| 10 | **Money is a type, not a convention.** | `:money` is integer cents with a currency. Floats for currency are refused at the type system, not in review. |
| 11 | **Stateless app servers.** | No in-process session or UI state. Scaling is "add a server", and the guardrail that keeps it true is a boot check, not a code review. |
| 12 | **Limits are stated loudly.** | No offline, no heavy client-side compute. Both are documented refusals *and* failure modes — never a silent degradation. |
| 13 | **Ship the shape, not the parts.** | Nobody's SaaS is a novel interface — a sidebar, a topbar, a stat row, a filterable table, an empty state before the first record exists. The framework knows that, so it hands over the shape rather than twelve components and an afternoon of reassembly. Every piece of shipped shape carries its documented override ([`08-component-overrides.md`](08-component-overrides.md)), or it is the Meteor failure wearing a design system ([`10-saas-coverage.md`](10-saas-coverage.md)). |

Axiom 7 is the one to argue with first. It is the reason the framework is worth building: everything else in the list is a design preference, but a framework that refuses to start an app whose double-entry ledger does not balance is doing something a linter and a code review demonstrably do not.


### What axiom 1 forces

Each row is a constraint an agent-written codebase imposes, and the design decision it produces.

| Because an agent… | Magik must… | Where it lands |
|---|---|---|
| learns one construct and generalises it | keep the grammar uniform across every subsystem — same block shape, same option style | [`02-dsl-surface.md`](02-dsl-surface.md) |
| guesses when there are two right answers | ship one convention, not a configuration menu — the swap points are seams for the *operator*, not choices at the call site | [`04-swap-points.md`](04-swap-points.md) |
| ships a plausible-looking mistake | fail at boot, loudly, on the specific rule that was broken | [`03-guardrails.md`](03-guardrails.md) |
| cannot act on prose advice | attach a runnable `fix:` command and a `--json` rendering to every error | [`../architecture/03-error-codes.md`](../architecture/03-error-codes.md) |
| has a finite context window | keep the total surface small enough that a whole app — models, screens, actions, jobs — fits in one | [`07-ai-first.md`](07-ai-first.md) |
| needs a loop it can run unattended | make `magik check` and `magik test` the whole gate, with machine-readable output | [`../architecture/05-adding-a-feature.md`](../architecture/05-adding-a-feature.md) |

## Inspired explicitly by / and what we refuse from

Nothing here is novel alone. The bet is the assembly: one grammar, one runtime, one enforcement pass.

| Source | What Magik takes | What Magik refuses |
|---|---|---|
| **Rails** | convention over configuration, generators, batteries in-box, one blessed path — the only proven cure for decision fatigue at framework scale | ActiveRecord: implicit lazy loading and callback soup are exactly the magic the guardrails exist to prevent. Sequel, explicit queries ([`05-limits.md`](05-limits.md)). Also refused: the asset-pipeline lineage and its endless frontend re-platforming |
| **Meteor** | realtime as a first-class declaration rather than a bolted-on gateway; the DDP insight that the server should push what changed | **the load-bearing lesson of the whole spec**: Meteor died of magic with no escape hatch. Every default here carries a config-level swap, and a swap that is not proven is not listed as one. Also refused: realtime-by-default — it is opt-in per screen, because a global sync engine prices every page like the one page that needed it |
| **Phoenix LiveView** | server-authoritative UI, channels, presence, the diff-over-the-wire model | LiveView's stateful socket per connected view. Magik screens hold no in-process state across requests — that is a boot guardrail — because stateful sockets are what make "add another server" a rewrite |
| **Django** | admin-grade introspection: `admin_panel` from a model declaration, migrations that describe themselves, a framework that can answer questions about itself | the second query language and the template layer as a separate skill. There is one grammar; the admin is a projection of it, not a parallel app |
| **Hanami** | explicit boot, app-level module boundaries, dependency direction you can see — the direct ancestor of the `domains/` system in spec item 12 | the container/DI layer. A Magik domain declares `depends_on`/`exposes`/`publishes_events` and the boot refuses a violation; there is no injection graph to reason about at runtime |
| **Ultimate** (`developerz-ai/ultimate`) | the sibling that reached the same conclusions on a different runtime: primitives as declarations, one authz path, boundaries the build enforces, errors that carry a fix, an agent as the primary developer. Where its design is right, Magik copies the shape rather than re-deriving it — see [Magik and Ultimate](#magik-and-ultimate) | its runtime and its client. Bun, TypeScript, SolidJS and a bundler are the parts Magik's audience is trying to leave behind. Also refused: the local-first/optimistic-mutator ladder — Magik is server-authoritative at every rung, with no offline story to keep honest ([`05-limits.md`](05-limits.md)) |
| **htmx** | the whole client story: ~14kb, attributes on server-rendered HTML, no build step, no client router, no state duplication | hand-written `hx-*` soup in templates. The attributes are *compiled* from `component`/`screen`/`action` declarations, so the endpoint an attribute points at cannot drift from the action that answers it |

## Magik and Ultimate

[`developerz-ai/ultimate`](https://github.com/developerz-ai/ultimate) is the closest thing Magik has to a sibling: the same thesis — one uniform declaration grammar, server-authoritative, AI-first, batteries included, guardrails enforced by the build rather than by review — reached independently on Bun and TypeScript. **Ultimate is implemented and running; Magik is a spec.** That asymmetry is worth stating first, because it means Ultimate's design decisions come with evidence and Magik's come with intent.

The two split on runtime and on audience, and the split is deliberate.

| Layer | Ultimate | Magik |
|---|---|---|
| Runtime | Bun (TypeScript) | TruffleRuby |
| Data | no ORM, hand-written parameterised SQL | Sequel, explicit queries |
| Client | SolidJS islands, five render modes, a bundler | server-rendered HTML + htmx attributes, no build step |
| Realtime | a three-rung ladder ending in local-first sync | one rung: opt-in server push per screen |
| Gate | `x verify` | `magik check` + `magik test` (planned) |
| Primary developer | an AI agent | an AI agent |

### What is convergent, not coincidental

Four things both designs arrived at from opposite ends of the language spectrum, which is the best available evidence that they are properties of the problem rather than of the stack:

| Convergence | Why it keeps being the answer |
|---|---|
| One declaration projects to many artifacts | a mapping layer written by hand is a mapping layer that drifts. Magik's `model` → table + migration + factory + admin panel is the same move as Ultimate's `action` → route + client + tool + tests. |
| One authz path, never two | the failure that killed Meteor-shaped frameworks is two doors to the same data. Both designs refuse the second door as a matter of architecture, not configuration. |
| Boundaries as build failures | a convention that is not a check does not exist. Ultimate enforces package tiers; Magik enforces subsystem tiers and app-level domains at boot ([`../architecture/02-boundaries.md`](../architecture/02-boundaries.md)). |
| Errors that carry an executable fix | the agent-facing half of the contract. Same shape, different prefix: `X_*` there, `MAGIK_*` here. |

### The audience claim

Magik is for developers who want to write Ruby and specifically do not want a TypeScript toolchain in their SaaS. That is a real, large population, and the positive case for serving it stands on its own:

| Ruby's argument | What it buys |
|---|---|
| **Blocks are the natural shape for a declaration DSL** | `ledger :Payments do … end` reads as language. The same declaration in any language without blocks reads as configuration wearing a function call, and the difference shows up in every one of the thousands of declarations an app contains. |
| **Readability is a first-order property of generated code** | when an agent writes most of the lines, the scarce resource is a human's ability to audit a diff at a glance. Ruby optimises for exactly that reading. |
| **No compile step in the edit loop** | edit, reload, see it. There is no bundler, no `tsconfig`, no type-check pass between a change and its result — which also means no build tooling for an agent to get wrong. |
| **A small dependency graph** | one gem, a short list of wrapped libraries ([`00-build-spec.md`](00-build-spec.md)), and no `node_modules`. Fewer moving parts is fewer things that fail on a Tuesday. |
| **TruffleRuby closes the gap** | the historical argument against Ruby for this workload was throughput, and it was two arguments wearing one coat: a slow interpreter, and a global lock that made a thread pool decorative. TruffleRuby answers both — a JIT, and threads that genuinely run in parallel. A server-rendering framework is exactly the workload that pays off: rendering is CPU work, and thread-per-request turns a machine's cores into throughput instead of a queue. Measured rather than assumed, and re-derivable: [`../architecture/12-runtime-verification.md`](../architecture/12-runtime-verification.md). |

What Magik gives up by choosing Ruby is the static type chain — Ultimate can make a renamed field a compile error across six artifacts, and Magik cannot. Magik's answer is boot-time enforcement rather than compile-time: the same class of mistake is caught, one stage later, by a guardrail that names the rule ([`03-guardrails.md`](03-guardrails.md)). Whether that trade holds is the single biggest open question in this design, and it will be answered by the guardrail catalogue actually existing — not by this paragraph.

## Why Ruby, and why TruffleRuby

| Choice | Reason |
|---|---|
| Ruby | the DSL is the product. No other mainstream language lets `ledger :Payments do … end` read as language rather than as configuration. |
| TruffleRuby | **the production target**, for one reason above the JIT: its threads are **real parallel OS threads**, and the parallelism survives the database driver — `pg` releases the runtime lock, so concurrent queries overlap rather than queue. That makes the ordinary, boring, gem-compatible concurrency model — a thread per request — actually deliver a machine's cores, which is what a server-rendering framework spends them on. Verified on 24.2.1 and 34.0.1; the probes and the numbers are in [`../architecture/12-runtime-verification.md`](../architecture/12-runtime-verification.md), and this table deliberately quotes neither. |
| CRuby ≥ 3.2 | supported for **tooling and local development only** — the CLI, the linter, the docs build. It is not a production target: its threads do not parallelise CPU work, so the concurrency model above is not true there. TruffleRuby-specific behaviour is verified in CI, not on a laptop. |
| Puma + Rack | thread-per-request, which is the correct server model precisely when threads are parallel — and the only one available, since TruffleRuby has no `fork` and therefore no clustered workers. Capacity comes from more containers, not more processes on a box. No second concurrency vocabulary for an app author to learn, and every gem in the wrap list is already thread-safe or already wrapped. |
| Sequel | explicit SQL, no lazy-loading magic, a migration story that does not lie. |

## What "done" would look like

From [`00-build-spec.md`](00-build-spec.md)'s success criteria — every one of these is a target with a command that will measure it, not a result:

| Target | Measured by (planned) |
|---|---|
| A new CRUD screen: model + screen + action in under 30 lines, zero HTML/JS/CSS | the line count of the generated slice in `examples/` |
| 1,000 tests, all cores, under 10s | `magik test --workers=auto --report=timing` ([`architecture/04-testing-strategy.md`](../architecture/04-testing-strategy.md)) |
| Fintech-grade money in the same grammar as everything else | the `ledger` example booting under the balance guardrail |
| Every opinionated default has a working, tested swap | the swap conformance suite, green on both backends, before the alternative is listed ([`04-swap-points.md`](04-swap-points.md)) |
| Documented limits that refuse rather than degrade | the boot codes in [`03-guardrails.md`](03-guardrails.md) |

None of these has been measured. When one is, it gets a number and a date on the page that claims it.
