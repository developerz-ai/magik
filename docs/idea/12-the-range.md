# The range

**One framework from a weekend idea to a large product, and from a non-technical author to an
expert — no lite mode, no second stack to graduate to.** Two axes, one set of primitives, one gate.

**Status:** spec only. Magik is unimplemented, so **every claim on this page is a design intent, not
a measurement.** Ultimate — the sibling that makes this same argument on a different runtime
([`01-thesis.md`](01-thesis.md#magik-and-ultimate)) — pairs each claim with the command that
re-derives it. Magik cannot: it is a spec, and inventing a number here would be the exact dishonesty
the rest of these docs are organised against. So each property below names **the mechanism in the
spec that would deliver it** and **the check that is owed before it may be stated as fact**, and
[What must be measured](#what-must-be-measured) collects every one of those debts in one table.
Reviewed 2026-08-26.

## The two axes

| Axis | From | To | What carries the app across it |
|---|---|---|---|
| **Project size** | one person, one weekend, one Postgres | multi-tenant SaaS, real money, several teams | configuration the small end never types — and nothing the small end did has to be undone |
| **Developer experience** | someone who has never deployed anything | someone who will replace your modal, your job backend and your search engine | guardrails at one end, escape hatches at the other — **different mechanisms, deliberately** |

The two axes are independent. A non-technical author can be at the large end of the size axis; an
expert can be at the small end. Nothing in the design couples them.

## Not two products

There is no `magik new --lite`, no `fintech: true`, no "starter mode" that a growing app migrates
out of. That is forced, not chosen:

| Forced by | Consequence |
|---|---|
| Axiom 1 — the primary developer is an AI agent ([`01-thesis.md`](01-thesis.md)) | a second path is a choice, and a choice is where an agent guesses. A lite mode is a second path by construction |
| Axiom 2 — one DSL grammar for everything | `ledger` reads like `model` reads like `screen`. There is no second dialect for the hard parts, so there is nothing to graduate *into* |
| The spec's mission sentence ([`00-build-spec.md`](00-build-spec.md)) | *"without the user needing to 'graduate' to another stack"* — the whole point of the framework, stated as a requirement |
| The spec's success criteria | *"no separate 'fintech mode'"* — and [`../../ROADMAP.md`](../../ROADMAP.md) makes the absence of one a **gate step**: a grep for such a mode is part of the 1.0 proof |

That last row is the only part of the no-lite-mode claim that is verifiable by a command rather than
by reading, and it is verifiable against the framework's own source rather than against a benchmark.
It is therefore the first thing on this page that could become a fact.

---

# Axis 1 — a weekend idea to a large product

## The load-bearing property

> **The small end pays nothing for the large end. The large end is configuration the small end never
> types. The large end is reachable because nothing the small end did has to be undone.**

Three separate claims, and the third is the one that matters. Frameworks that fail this axis
generally do fine on the first two: they are pleasant when small, and they document a big
deployment. They fail on "nothing has to be undone" — an integer primary key, a table with no
tenant column, a float balance, a session in process memory. Each is cheap on day one and a
migration nobody survives on day one thousand.

Magik's answer is placement, from [`01-thesis.md`](01-thesis.md): **the opinions are concentrated
exactly where reversal is impossible, and absent where reversal is cheap.** That rule is what makes
this axis a design property rather than a marketing claim, and the rest of this section is the
inventory.

## The three shapes

| Size | You run | You decide | Already decided for you |
|---|---|---|---|
| a weekend idea, a first internal tool | `magik server`, one Postgres, nothing else | your models, your screens, your actions | everything in the two tables below |
| a real product with paying users | app processes behind a load balancer, plus `magik worker` — one image, two roles ([`../ops/README.md`](../ops/README.md)) | when a signal says to split a role or move a seam | the same |
| a large product, several teams | the same, plus `domains/`, plus whichever seams have been swapped | which of your infrastructure to plug in ([`04-swap-points.md`](04-swap-points.md)) | the same |

**The app's declarations are identical across those rows.** That is the claim; `magik server`,
`magik worker`, `magik check --domains` and the swap conformance suite are what would prove it, and
none of them exists. There is no scale ladder page here yet, and
[`../ops/README.md`](../ops/README.md) says so plainly: *"What the rungs above it look like will be
written when something has climbed one."*

## What the small end already has, and cannot buy later

Each row is something present in the smallest possible Magik app, at no cost to it, that a large app
cannot retrofit cheaply. This is the "nothing has to be undone" claim, itemised.

| The small app already has | Because | What it is worth at size | Verification owed |
|---|---|---|---|
| **UUIDv7 primary keys** | injected by `model`; `primary_key :id` in the first migration is already a UUIDv7 ([`../../dummy/db/migrations/`](../../dummy/db/migrations/20260826120000_create_customers_and_invoices.rb)) | changing a primary key type across a live, referenced schema is the migration nobody survives. Sortable ids are also what make cursor pagination and a future shard possible at all | a Phase 1 test that every generated table's `id` is UUIDv7, and that the strategy is **not** a swap point ([`../../wiki/Models.md`](../../wiki/Models.md)) |
| **`tenant_id` on every model** | injected, not written — the dummy migration declares no `tenant_id` column and gets one, with its index and foreign key | retrofitting tenancy means auditing every query ever written. This is the single most expensive thing on the page to add late | `MAGIK_MODEL_NO_TENANT` at boot, plus `magik check --scale` reporting unscoped query sites ([`03-guardrails.md`](03-guardrails.md)) |
| **Integer-cent money, floats refused at the type level** | `:money` is a type, not a convention (axiom 10) | a float that reached the database is already wrong; no later fix recovers the precision | `MAGIK_MODEL_FLOAT_MONEY` at boot **and** at runtime |
| **Append-only ledgers, `audited`, `immutable_after:`, `idempotent_by:`** | Phase 5 constructs in the same grammar as `model` — there is no fintech mode to migrate into | history you did not record cannot be reconstructed. In a regulated context that is a compliance failure, not an inconvenience | `MAGIK_LEDGER_UNBALANCED` at boot; the ROADMAP's grep-for-a-mode gate step |
| **Stateless app servers** | a boot guardrail, not a discipline: a screen or action holding state across requests fails to start ([`03-guardrails.md`](03-guardrails.md)) | "add another server" is a config change. This is precisely what LiveView's stateful socket costs and what Magik refuses in exchange | `MAGIK_RENDER_SCREEN_STATEFUL` · `MAGIK_ACTION_STATEFUL`, plus a two-server test that interleaves one `flow`'s steps across both |
| **Append-only migrations and a generated `db/schema.rb`** | `db/migrations/` is hand-written and never edited after it has run ([`../../wiki/Project-Layout.md`](../../wiki/Project-Layout.md)) | the schema is reproducible from the ledger of migrations rather than from someone's laptop | `MAGIK_SCHEMA_IRREVERSIBLE` (a `migrate` with no `down`) and `MAGIK_SCHEMA_DRIFT` |
| **One predictable file per declaration** | the naming rule runs in both directions: a path tells you what it declares before you open it | the flat tree becomes a domained tree by changing a path prefix — see [the move](#the-flat-to-domains-move-exactly) | `MAGIK_FILE_MULTIPLE_DECLARATIONS` · `MAGIK_DECLARATION_MISPLACED` |
| **A rate-limit store that is not in the process** | decision 9 forbids a counter living in a process, so the throttle store is a **seam by construction** ([`04-swap-points.md`](04-swap-points.md)) | the single-server app's throttling is already correct on the second server. Nobody had to notice | the throttle seam's conformance suite, on Postgres and on Redis |
| **The same gate as the largest app** | `magik check` + `magik test`, with `--json`, at every size ([`../architecture/05-adding-a-feature.md`](../architecture/05-adding-a-feature.md)) | no tribal checklist to hand a new team, and no "strict mode" that a mature app turns on late | the checker existing at all — build-order step 13 ([`06-phases.md`](06-phases.md)) |

Two of those rows carry the argument: **the primary key type and the tenant column are the two
things that genuinely cannot be retrofitted, and both are present in the smallest possible app at
zero cost to it.** `magik check --scale` exists to keep
the second one honest as the app grows, as a **warning** rather than a refusal, because an unscoped
query is sometimes correct (a platform-wide admin report) ([`03-guardrails.md`](03-guardrails.md)).

## What the small end never types

The mirror image, and the reason the first table costs nothing. Everything here is off until
declared, so the small app is not paying for the large app's shape.

| Capability | The small app's cost | What turns it on | Anchor |
|---|---|---|---|
| **Realtime** | none. A screen with no `live` opens no socket and issues no realtime query | one line: `live :orders, on: "orders:{tenant}"` — *"this line is the entire cost of realtime"* | [`02-dsl-surface.md`](02-dsl-surface.md), axiom 5 |
| **Domains and boundary enforcement** | none. `magik new` emits no `domains/` directory, and **an app that declares no domains has exactly one implicit domain, so none of the rules bites** | a `domain.rb`, when the app has earned one | [`../architecture/02-boundaries.md`](../architecture/02-boundaries.md) |
| **A worker process** | none. No queue to run until there is a `job` | `magik worker`, the second role of the same image | [`../ops/README.md`](../ops/README.md) |
| **Redis, Kafka, Elasticsearch, NATS, S3** | none. The defaults are Postgres, the in-process cache and local disk — **the small end runs one Postgres and nothing else** | a `use` line ([the seams](#where-the-range-ends-the-seams-and-their-signals)) | [`04-swap-points.md`](04-swap-points.md) |
| **A ledger, an audit trail, an admin panel, an API** | none until declared, and each is the same grammar when it is | a declaration | [`02-dsl-surface.md`](02-dsl-surface.md) |
| **A bot challenge** | none — off by default, because a CAPTCHA has a real accessibility and privacy cost | a seam, chosen deliberately | [`04-swap-points.md`](04-swap-points.md) |

## The flat-to-domains move, exactly

The claim in [`../../wiki/Project-Layout.md`](../../wiki/Project-Layout.md) and
[`../../wiki/Domains.md`](../../wiki/Domains.md) is that a domain contains **the same `app/` tree a
flat app has, one level in** — so growing into domains is a path-prefix change, not a rewrite. That
claim was checked against the sources rather than assumed:

| Source | Says | Agrees? |
|---|---|---|
| [`../../wiki/Project-Layout.md`](../../wiki/Project-Layout.md) | `domains/billing/app/{models,screens,actions,jobs}/` plus `domains/billing/test/` | yes |
| [`../../wiki/Domains.md`](../../wiki/Domains.md) | the same tree, with `components/` visible only inside the domain | yes |
| [`../../dummy/`](../../dummy/README.md) — the reference app | `domains/billing/app/models/subscription.rb` on disk beside a flat `app/` | yes — this is the only place the shape exists as files rather than prose |
| [`../architecture/02-boundaries.md`](../architecture/02-boundaries.md) | **fixed.** It sketched `domains/billing/models/`, without the `app/` level, and disagreed with three sources and with the reference app's own files | **no longer.** Kept as a row because it is the cheapest example of the failure this table exists to catch: one prose sketch, drifting quietly from the layout it illustrates |

**The canonical shape is `domains/<name>/app/<kind>/`.** The disagreement above is a documentation
defect to fix in the boundaries page, not a design ambiguity — and it is worth naming here because
the whole "mechanical move" claim is a claim about paths.

So the move is:

```bash
mkdir -p domains/billing/app/{models,screens,actions,jobs} domains/billing/test
git mv app/models/invoice.rb    domains/billing/app/models/
git mv app/actions/mark_paid.rb domains/billing/app/actions/
# …one git mv per file. The path inside app/ is the path inside domains/<name>/app/.
```

plus one new file:

```ruby
# domains/billing/domain.rb
domain :Billing do
  depends_on :Identity
  exposes :Invoice, :charge
  publishes_events :invoice_paid, :invoice_voided
end
```

**No declaration inside a moved file changes.** `model :Invoice` is `model :Invoice` at either path.
That is the property that makes the move mechanical, and it is a constraint on the implementation
rather than a description of one.

### Where that claim stops, honestly

`git mv` plus a `domain.rb` is the *file* move. It is not the whole job, and saying otherwise would
be the kind of claim this page exists to avoid:

| Also true | Why |
|---|---|
| **The boundary violations you did not know you had become boot failures** | each one is `MAGIK_DOMAIN_BOUNDARY` naming both domains and the exact constant. Fixing them means adding an `exposes`, or converting a direct read into an event subscription — real design work, in an unknown quantity, discovered at the moment of the move |
| **The amount of that work is proportional to entanglement, not to app size** | which is why [`../../dummy/README.md`](../../dummy/README.md) says *"Do not move a slice because the app got big. Size is not the trigger; entanglement is."* A 200-model app with one team and one vocabulary is fine flat |
| **Shared things stay put** | app-wide components and cross-domain screens remain in the top-level `app/`. The move is per-slice, not a re-parenting of the tree |
| **A boundary is not free once drawn** | *"every boundary is a place where a change now needs two edits"* ([`../../wiki/Domains.md`](../../wiki/Domains.md)). That cost is the reason not to draw one early, and it is permanent |
| **Nothing here promises a later service extraction** | a domain is *"a compile-time wall, not a network hop"*, and a **plausible** seam for a future service — no page may imply the extraction is easy |

The signals for making the move are in [`../../wiki/Project-Layout.md`](../../wiki/Project-Layout.md#when-to-move)
and [`../../dummy/README.md`](../../dummy/README.md). The framework's contribution is that the move
is available at any time and costs nothing until taken — not that it is trivial when taken.

## Where the range ends: the seams and their signals

Every framework has a ceiling, and a document claiming none is not credible. Magik's ceiling is
mostly Postgres, on purpose: one datastore until scale forces otherwise, and when it forces
otherwise, the seams are the swap points rather than a rewrite ([`../ops/README.md`](../ops/README.md)).

Each row names the signal that you have outgrown a default and what you move to. **No row carries a
threshold number, because none has been measured** — the signal is a shape in your own telemetry,
and the number that would make it a rule is a debt in [the last table](#what-must-be-measured).

| Default | The signal you have outgrown it | You move to | What the move costs |
|---|---|---|---|
| **In-process memory cache** | a second app server, plus a measured cross-server miss. *"A cache that silently goes wrong across two servers is worse than no cache"* ([`../../dummy/config/backends.rb`](../../dummy/config/backends.rb)) | Redis or Memcached, by `use` | a restart, and a piece of infrastructure to run. Cached data does not migrate |
| **Postgres job queue (Que-style)** | **not the `SELECT`, which is where people look.** Dead-tuple ratio on the job table that aggressive autovacuum cannot hold down, job-table WAL as a material fraction of total WAL, or `LWLock:MultiXact*` waits appearing ([`../architecture/11-jobs-backend.md`](../architecture/11-jobs-backend.md)) | **first a second Postgres dedicated to jobs**, not a broker. Kafka only when the queue is the wrong primitive — independent consumers with independent progress, replay, other services ([`../../wiki/Jobs.md`](../../wiki/Jobs.md)) | **the transactional enqueue, at the very first step.** A second Postgres is a different database, so a cross-database enqueue cannot join the app's transaction any more than a Redis `LPUSH` can. The cheapest rung is the one that silently breaks the guarantee the default was chosen for; recovering it means the outbox pattern, which is machinery, not config |
| **Postgres `LISTEN`/`NOTIFY` realtime** | `LISTEN` connection count against Postgres, and open sockets per app process ([`../ops/README.md`](../ops/README.md)) | Redis pub/sub or NATS, by `use` | infrastructure, plus a fanout path whose failure modes differ from the database's |
| **Postgres full-text search + `pgvector`** | index maintenance cost, or ranking and analysis the database cannot express | Elasticsearch, Meilisearch, Typesense | a second datastore to keep in sync, and an index that can be stale |
| **Local-disk storage (Shrine)** | more than one app server, or a filesystem that does not survive a restart | S3 or a compatible, by configuration | nothing structural — this is the cheapest seam to cross, which is why it is the default |
| **One app process** | request concurrency, p95 latency, socket count | more app **containers** behind the load balancer. TruffleRuby has no `fork`, so Puma runs in single mode and a second process means a second container rather than a clustered worker on the same box ([`../ops/README.md`](../ops/README.md)) | nothing. This is the seam statelessness bought, and the only one that is a pure win |
| **One Postgres** | write throughput, connection count, slow queries | vertical first, then read replicas | real operational work, and the first ceiling that is **not** a `use` line |
| **One Postgres, still** | you have genuinely outgrown vertical plus replicas | **nothing Magik models.** See below | — |

### The hard stop

| Stop | Statement |
|---|---|
| **No sharding, no multi-region, no data residency** | *"One Postgres, one region, tenancy by column."* Sharding, regional pinning and cross-region replication are a deployment topology Magik does not model — it changes the connection story, the migration story, the job story and the realtime story at once ([`05-limits.md`](05-limits.md)) |
| **`magik check --scale` keeps the option open; it is not a shard** | UUIDv7 keys and tenant-scoped queries mean a future shard is *possible*. The spec's own words are *"pre-empts sharding pain"* — pre-empting is not solving, and the check warns rather than refuses ([`00-build-spec.md`](00-build-spec.md)) |
| **Domains are not microservices** | one process, one database, one deploy. The large-app story is a compile-time wall inside one codebase, and that is the largest organisational shape on offer |
| **The product-shape limits bound the *kind* of app, not its size** | no offline, no heavy client-side compute, no native shell, no CMS, no BI, no BPM engine. A product whose core value is any of those is outside the range at *every* size, and [`05-limits.md`](05-limits.md) says so with the mechanism — refused with a code, or documented plainly where no mechanism can detect it |
| **A swap is not a portability guarantee** | *"the narrow contract is the contract."* Code written against a backend-specific feature has left the seam and will not survive a swap. That is a supported choice, not a supported *portable* one ([`04-swap-points.md`](04-swap-points.md)) |
| **A candidate backend is not a fallback** | an unshipped backend fails at boot rather than degrading to the default — `MAGIK_CONFIG_UNKNOWN_BACKEND`. Silent degradation is what guardrails exist to prevent |

---

# Axis 2 — non-technical to expert

**The mechanism is different at each end, and naming the difference is what makes this credible
rather than marketing.** "Good for beginners and experts alike" is a slogan; the two sections
below are two distinct architectural bets, and each can be argued with separately.

| End | The mechanism | The failure it prevents | If it fails |
|---|---|---|---|
| **Non-technical** | the guardrails substitute for expertise | shipping a correctness bug you did not know was possible | the app boots and the mistake reaches a customer |
| **Expert** | the escape hatches prevent the ceiling | hitting the place the opinion is wrong for you and rewriting away | the framework is abandoned at exactly the moment it was working |

## The non-technical end — guardrails substitute for expertise

Someone who does not know that floats destroy money, that a double-entry ledger must balance, that
every query needs `tenant_id`, or that a primary key type cannot be changed once rows reference it,
**gets all of it anyway — because the framework refuses to boot otherwise.**

That is a stronger claim than "it is easy to use". It is that the boot-time guardrails encode
expertise the author does not have and cannot reasonably be expected to acquire. A non-expert
building an invoicing app gets double-entry correctness they could not have specified themselves.
[`03-guardrails.md`](03-guardrails.md) calls the guardrails the product; this is who they are the
product *for*.

There is a quieter half of the same mechanism: **defaults its users would not know to choose.** A
refusal catches the mistake you made; a default prevents the one you would never have known to
consider — cursor pagination instead of `OFFSET`, an index the framework knows the query needs,
bounded queries, a connection pool sized for the server's thread count
([`../architecture/10-performance-defaults.md`](../architecture/10-performance-defaults.md)). Neither
end of this axis types any of it, and only one end would have known to.

The entry point matches. The scaffold's three stages ([`09-app-scaffold.md`](09-app-scaffold.md))
make the first act **describing the product**, not configuring a stack:

| Stage | Command | What the author supplies |
|---|---|---|
| static boilerplate | `magik new myapp` | a name. Every choice is a flag with a default; no prompts, no network, no model |
| AI boilerplate | `/setup-project` | answers about their product, in an interview. *"It asks; it does not guess"* |
| real work | `/feature`, `/screen`, `/check`, `/next` | one feature at a time, gated by `magik check` and `magik test` |

Two properties of that design matter more at this end of the axis than anywhere else. A generated
app carries a `<!-- magik:stage2-pending -->` sentinel so an agent opening a never-bootstrapped app
**routes the user to the interview instead of inventing a domain model** — the failure that costs
most when the author is not equipped to spot an invention. And every rule in the generated
`CLAUDE.md` is meant to have a `MAGIK_*` code behind it, because *"a rule that lives only in prose
is decoration"*.

### Where this end's claim stops

**"Non-technical" does not mean "no technical judgement required."** Somebody still owns production,
decides the trade-offs, reviews the diff, and is accountable when it breaks at 3am. The guardrails
catch the mistakes they can catch, and a mis-specified product is not one of them.

> **Magik lowers the expertise floor for correctness. It does not lower the responsibility floor for
> operating a business.**

Concretely, the things this framework will never do for its author: choose what to build, notice
that the requirement was wrong, decide whether an unscoped admin query is the legitimate kind, size
a database, hold a pager, or accept liability for someone else's money. The seams have to be
operated by someone; [`../ops/README.md`](../ops/README.md) is honest that it currently has *"no
sizing guidance, because nothing has ever been run and a made-up number is worse than none"*.

## The expert end — escape hatches prevent the ceiling

Experts abandon opinionated frameworks at the first place the opinion is wrong for them. That is not
impatience; it is a correct read of the risk, and it is what killed Meteor-shaped frameworks —
*magic with no escape hatch = eventual rewrite* ([`00-build-spec.md`](00-build-spec.md)).

So every default is reachable and replaceable, at a cost proportional to how far you are reaching:

| Reach | Ladder | Rungs |
|---|---|---|
| infrastructure | [`04-swap-points.md`](04-swap-points.md) | twelve seams, each a `use` line, each with its trade-offs documented at the point of choosing |
| UI | [`08-component-overrides.md`](08-component-overrides.md) | tokens → `extends:` → a shadowing `component` in `app/components/` → `raw` HTML. **You never have to jump to the top**, and each rung costs strictly more than the one below |
| behaviour on the page | [`05-limits.md`](05-limits.md) | your own JavaScript on server-rendered markup — a Stimulus controller, a date picker, a chart library — with no toolchain and no bundler |
| the data layer | [`05-limits.md`](05-limits.md) | explicit Sequel. There is no lazy loading to fight and no callback chain to trace |

**The expert stays because they never hit a wall, not because they never disagree.** Two design
choices make that more than a slogan: `raw` is deliberately unpleasant to reach for *and*
`magik check` reports every `raw` site, so the escape hatch is visible rather than quiet; and a
replacement component is accepted because it `satisfies` a contract verified at boot, not because
its author intended it to.

### Where this end's claim stops

An escape hatch that promises more than it delivers is the failure being avoided, so the exclusions
are part of the design rather than an oversight:

| Not escapable | Why that is the right answer |
|---|---|
| **Authorization** | a second authorization backend is a second authorization system — the exact failure this design is organised against. `policy` is one evaluator with no alternative, and architecture decision 13 says so |
| **Auth** | Rodauth is a structural dependency of the `auth` DSL, not a backend behind an interface. *"Saying so is more honest than pretending to a seam nobody could implement against"* ([`04-swap-points.md`](04-swap-points.md)) |
| **Tenancy, the UUIDv7 key strategy, integer-cent money** | these are the reversal-impossible layer. Making them optional would delete the entire Axis 1 argument |
| **The boot guardrails, even on a replaced component** | *"The escape hatch is from Magik's aesthetics, never from its invariants"* — a replacement still holds no state across requests and still renders no timestamp without a zone ([`08-component-overrides.md`](08-component-overrides.md)) |
| **The static type chain** | Ruby cannot make a renamed field a compile error across six artifacts the way the TypeScript sibling can. Magik's answer is boot-time enforcement — the same class of mistake, one stage later. *"Whether that trade holds is the single biggest open question in this design"* ([`01-thesis.md`](01-thesis.md)) |

## What both ends share

**Neither spends the afternoon on glue.** The non-expert did not have the expertise to write it
correctly; the expert has better uses for the time. Glue, defined precisely — routes and param
parsing, serializers, form plumbing, pagination arithmetic, N+1 fixes, job wiring, webhook signature
verification, migration boilerplate, cache invalidation, tenant scoping on every query, the
application shell — is the same list at both ends of the axis
([`01-thesis.md`](01-thesis.md#glue-code-defined)).

They also share the definition of done: `magik check` then `magik test`, with `--json`, the same
list of rules in every app at every size. That is the same property the size axis needs — one gate,
not a checklist that grows with the team.

---

## What must be measured

Ultimate's range document shows a measurement in every row and a command beside it. **Magik's honest
equivalent is this table: the debts.** Nothing above may be restated as fact until the corresponding
row here is green, and each row names what would make it so.

| Claim on this page | What would measure it | Blocked on |
|---|---|---|
| the small end needs one Postgres and nothing else | boot a generated app with only `DATABASE_URL` set; assert no other service is contacted | `magik new`, Phase 1 |
| the small end asks no questions and supplies no env values before the first boot | `magik new --dry-run` flag inventory; a count of required `.env` keys at first boot | `magik new`, Phase 1 |
| a CRUD slice is under 30 lines with zero HTML/JS/CSS | a committed example whose line count is asserted by a test, not counted by hand ([`../../ROADMAP.md`](../../ROADMAP.md)) | Phase 2 |
| there is no lite mode and no fintech mode | a grep for such a mode, as a gate step ([`../../ROADMAP.md`](../../ROADMAP.md)) | the gate step existing |
| realtime costs nothing until declared | a screen with no `live` opens **no socket and issues no realtime query** — a test, not a paragraph ([`06-phases.md`](06-phases.md)) | Phase 3 |
| a swap changes config and zero app code | the seam's conformance suite green on **every** backend, plus an example app booting on each with a zero-line diff ([`04-swap-points.md`](04-swap-points.md)) | one seam with two shipped backends |
| stateless means "add a server" | two app processes behind a load balancer, serving interleaved steps of one `flow` | Phase 2 + Phase 5 |
| flat → domains is a path-prefix move | script the move over [`../../dummy/`](../../dummy/README.md), assert **zero diff inside the moved files**, then boot and count the boundary failures | Phase 12 (`domain` DSL) |
| domains cost nothing until declared | boot an app with no `domains/` and assert the boundary rules are inert | Phase 12 |
| **the Postgres job queue's ceiling** | a benchmark against real Magik code. [`../architecture/11-jobs-backend.md`](../architecture/11-jobs-backend.md) already carries third-party numbers with full attribution and states plainly that **no number on it is one Magik produced** — that page's debt is the same as this one's | Phase 4, plus a benchmark harness that commits its results |
| **the `LISTEN`/`NOTIFY` realtime ceiling** | subscribers per app process, and `LISTEN` connections per database, before latency degrades | Phase 3 |
| the guardrails actually fire | one failing fixture per `MAGIK_*` code in the catalogue ([`03-guardrails.md`](03-guardrails.md)) | each phase, as its guardrails land |
| `magik check --scale` is useful rather than noisy | its true-positive and false-positive rate on the reference app | Phase 12 |
| 1,000 tests, all cores, under 10s | `magik test --workers=auto --report=timing` ([`../architecture/04-testing-strategy.md`](../architecture/04-testing-strategy.md)) | Phase 9, built fifth |
| a generated app is safe on its first run | a cross-tenant actor denied by **every** generated surface; the shell rendering at 375px; the signup form throttling and not revealing whether an account exists ([`../../ROADMAP.md`](../../ROADMAP.md)) | Phase 7 |
| TruffleRuby closes the throughput gap | a server-rendering benchmark on TruffleRuby against the CRuby baseline, in CI | a running framework |
| the harness makes an author faster | **unmeasurable today, and possibly for a long time.** No app has ever been built with Magik by anyone ([`09-app-scaffold.md`](09-app-scaffold.md)) | adoption |

The bottom row is the one to keep in view. Both axes of this document are, ultimately, claims about
outcomes for people, and the mechanisms above are the *reason to expect* the outcome rather than
evidence of it.

## What the range does not claim

| Not claimed | State `As of 2026-08-26` |
|---|---|
| that anyone has shipped anything on Magik | no adoption, no deployments, no testimonials. [`../../README.md`](../../README.md) says so and will until they exist |
| that the small end works | there is no `magik new`, no `App.define`, no server. [`../../dummy/`](../../dummy/README.md) parses and does not run; that is its only claim |
| that a single swap has been proven | zero seams implemented, zero backends shipped. Every row of [`04-swap-points.md`](04-swap-points.md) is `planned`, and a candidate is labelled a candidate |
| that the flat-to-domains move has been performed | the `domain` DSL is build-order step 13 — the last thing built |
| that any ceiling above has a number | no benchmark has been run. The signals are shapes, not thresholds, and they say so |
| that the guardrails catch every mistake | they catch what is derivable from the frozen registry or from source. A wrong requirement, a bad trade-off and a mis-sized database are not in that set |
| that a domain becomes a service | *"a plausible seam for a future service. Nothing here promises the extraction will be easy"* ([`../../wiki/Domains.md`](../../wiki/Domains.md)) |
| that Magik fits every product | see [`05-limits.md`](05-limits.md), and [`10-saas-coverage.md`](10-saas-coverage.md) for the measured distance between the grammar and its 99% target — under a fifth of 68 surveyed surfaces, `As of 2026-08-26` |

## Next

- [`01-thesis.md`](01-thesis.md) — the axioms, and the placement rule this whole page rests on.
- [`04-swap-points.md`](04-swap-points.md) — the seams, their defaults and what a swap does not buy.
- [`05-limits.md`](05-limits.md) — where the range ends by design rather than by capacity.
- [`08-component-overrides.md`](08-component-overrides.md) — the expert end's ladder, rung by rung.
- [`09-app-scaffold.md`](09-app-scaffold.md) — the non-technical end's entry point.
- [`../../wiki/Project-Layout.md`](../../wiki/Project-Layout.md) — the two tree shapes and the move between them.
- [`../ops/README.md`](../ops/README.md) — the deployment shape, and the scale ladder that is not written yet.
