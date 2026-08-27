# Magik roadmap

**Status today: nothing is built.** `magik 0.0.1` on RubyGems is a **name reservation** — it claims
the gem name, ships a version constant, an error-code convention, the three commands that run
(`magik version`, `magik help`, `magik docs`), and one documented stub per planned subsystem. It
renders no page, opens no database connection, and runs no job. Every phase below is **planned**.
`As of 2026-08-26`.

Resolve the status rather than trusting this sentence:

```bash
gem list magik --remote --all                              # what RubyGems serves
ruby -Ilib -e 'require "magik"; puts Magik::VERSION'       # what this checkout is stamped at
magik help                                                 # the commands that actually run
```

The product specification is [`docs/idea/00-build-spec.md`](docs/idea/00-build-spec.md). This file
does not restate it — it orders it, and says what "done" means for each piece.

## How it gets built

**The delivery model is agent-driven, and that is a design decision rather than a convenience.**
Magik is an AI-first repo: the primary developer is an AI agent, and the framework's shape — one
uniform DSL grammar, boot-time guardrails, errors carrying a runnable `fix:` — exists partly because
those are the properties that make a codebase an agent can work on correctly. The reasoning is
[`docs/idea/07-ai-first.md`](docs/idea/07-ai-first.md).

Concretely: a phase is landed by an agent running `/implement-phase` against
[`docs/idea/06-phases.md`](docs/idea/06-phases.md), and it is gated by `bin/check`. The agent
workbench — subagent definitions and slash commands — is committed to the tree at
[`.claude/`](.claude/README.md) rather than living in someone's local config, so a fresh session
opening this repository finds it in one hop.

```bash
bin/check        # the gate a phase has to pass. Lint, tests, doc checks
rake -T          # every task this checkout defines
```

## Two orderings, and which one wins

The spec carries **ten phases** — `1, 2, 3, 4, 4b, 5, 6, 7, 8, 9` — and a **thirteen-step build
order**, and they are deliberately not the same sequence. A phase is an *identity*: which capability
a construct belongs to. A build step is a *position*: when it actually gets written.

**Where the two disagree, build order wins** — the spec says so
([`docs/idea/00-build-spec.md`](docs/idea/00-build-spec.md) § "Build Order"), and the full mapping is
[`docs/idea/06-phases.md`](docs/idea/06-phases.md).

They disagree in three places, each for a stated reason:

| Disagreement | Why |
|---|---|
| **Phase 9 (testing) is built fifth** | every later step is meant to be test-driven. Building the harness after the features it was supposed to drive is how a framework ends up with a suite that documents its bugs |
| **Phase 7 (auth, billing, admin) is built before phase 6 (API)** | `admin_panel` is the first real consumer of the `resource` field-subset vocabulary, so the API DSL lands against a working consumer rather than against a guess |
| **Phase 4b (media) sits between jobs and money** | media spans four phases — the `:file` type is phase 1, the upload component phase 2, derivatives and transcoding are phase 4 jobs, and signed delivery is blocked on `policy`. A capability whose value arrives only when all four have landed is a phase of its own |

**This page is ordered by delivery. Every heading keeps its spec phase number**, so a heading here
and a heading in [`docs/idea/06-phases.md`](docs/idea/06-phases.md) name the same thing; where the
sequence differs, the heading says which build step it is. Nothing on this page renumbers a phase.

## Version milestones

**Intent, not a schedule.** No dates are given, because a date on unstarted work is a guess dressed
up as a commitment. The mapping below is the contract: a minor version means the phases named in its
row are complete under their own "done" definition, and the ones below it are not.

| Version | Carries | Done when |
|---|---|---|
| `0.0.1` | **shipped** — name reservation only | the gem name resolves and `magik version` prints it |
| `0.1.0` | Phase 1 — foundation | build steps 1–2 |
| `0.2.0` | Phase 2 — rendering, actions, `policy`, `layout` | build steps 3–4 |
| `0.3.0` | Phase 9 — testing, pulled forward | build step 5 |
| `0.4.0` | Phase 3 — realtime | build step 6 |
| `0.5.0` | Phase 4 — jobs | build step 7 |
| `0.6.0` | Phase 4b — media | build step 8 |
| `0.7.0` | Phase 5 — money and compliance | build step 9 |
| `0.8.0` | Phase 7 — auth, billing, admin | build step 10 |
| `0.9.0` | Phase 6 — API and webhooks | build step 11 |
| `0.10.0` | Phase 8 — i18n, PWA, notifications | build step 12 |
| `0.11.0` | Spec item 12 — domains and `magik check` | build step 13 |
| `1.0.0` | all ten phases and the domain system, plus every swap point proven by a passing test | see [what 1.0 means](#what-10-means) |

While the major version is `0`, **minor bumps may break the public API**. That is the point of a `0.x`
line: the DSL is being discovered, and freezing it early would be the worse mistake.

## Phases

Ordered by delivery, numbered by phase identity. Each phase is done when **every** row of its exit
criteria is true, and each criterion is a thing a test can assert. "Documented" is never an exit
criterion on its own; an enforced convention is.

### Phase 1 — Foundation *(build steps 1–2)* → `0.1.0`

`App.define :Name`, `model :Name` over Sequel, `migrate :Name`, the `:money`, `:file` and
`:duration` field types, `computed(:name, :type) { … }`, UUIDv7 primary keys, `tenant_id`
auto-injection, **the option tables**, and the `new` / `generate` / `console` / `server` /
`describe` commands.

**Done when:** `magik new myapp && cd myapp && bin/setup && magik console` opens a REPL with a
generated model loaded; a `model` declaration produces a Sequel dataset scoped by `tenant_id` without
the app writing the predicate; a migration round-trips `up` and `down`; a `:money` field refuses a
`Float` at assignment, not at save; a `:file` field with no `max_size` and no `content_types` fails
the boot; and `magik describe model --json` lists every option the coercer accepts, in an empty
directory, with no app and no database.

**Two spellings that are load-bearing, not stylistic:** `computed(:name, :type) { … }` keeps its
parentheses, because a brace block binds to the last call and `computed :name, :type { … }` would
bind to the symbol. And the option tables ship in step 2 rather than later — `magik describe` is
**derived** from the tables the DSL validates against, never hand-maintained, because two tables
drift and one cannot.

### Phase 2 — Rendering, actions, authorization and the shell *(build steps 3–4)* → `0.2.0`

`component`, `screen`, `action`, **`policy`**, **`layout`**, the component kit (`button, form,
field, data_table, modal, toast, card, list, grid, tabs, stat, chart, sidebar, topbar, nav_item,
breadcrumbs, account_menu, dashboard_grid`), the theme system, the router, the dev server and reload.

**`policy` and `layout` land here, and neither is negotiable to a later phase:**

| Declaration | Why phase 2 |
|---|---|
| **`policy`** | a screen and an action are the first two surfaces that reach a model. Adding a `policy:` argument to six constructs after all six exist is the retrofit the spec calls "a migration nobody survives". Its evaluator sits at **tier 1**, below `model`, `render` and `realtime`, because tier 2 must evaluate it and imports go strictly down; it takes the actor as an opaque value, and `auth` at tier 3 supplies that value later without changing anything in the policy layer ([`docs/architecture/01-module-map.md`](docs/architecture/01-module-map.md)) |
| **`layout`** | it is the application shell, and `magik new` generates a working `:App` layout — so **a generated app has a sidebar on its first run**. It is a new declaration, not a second override system: its pieces are kit components with contracts, so the four rungs of [`docs/idea/08-component-overrides.md`](docs/idea/08-component-overrides.md) apply unchanged |

**Done when:** a screen plus an action plus a model is a working CRUD page in **under 30 lines with
no HTML, CSS or JavaScript written by the app** — navigation included, which is what `layout` is for;
the emitted markup carries the htmx attributes that wire the form to the action with no route
declared by hand; a surface with no `policy:` and no explicit `policy: :public` / `policy: :system`
**fails the boot** with `MAGIK_POLICY_UNDECLARED`; a cross-tenant actor is denied by both the screen
and the action; the generated app renders correctly at **375px**; the dev server reloads a changed
screen without a restart; light and dark both render from one token set.

### Phase 9 — Testing, delivered third *(build step 5)* → `0.3.0`

The spec's last phase, built fifth. The `test :Name` DSL over Minitest, inferred factories, the
helpers (`perform_action`, `render_screen`, `concurrently`, `travel_to`, `assert_enqueued`,
`assert_broadcast`, `assert_notified`), and the parallel runner.

**Why here:** every later step is meant to be test-driven. Building the harness after the features
it is supposed to have driven is how a framework ends up with a test suite that documents its bugs.

**Done when:** `magik test` runs the framework's own suite through the DSL; `--watch` and `--changed`
both work; a test rolls back in a transaction rather than truncating; `workers: :auto` uses every
core; `render_screen … at: :mobile` exists, because it is what makes the responsiveness claim
testable rather than asserted. **A worker is a thread** and there is exactly one worker model —
TruffleRuby's threads are genuinely parallel and TruffleRuby has no `fork`, so a thread is both the
right mechanism and the only one ([`docs/architecture/12-runtime-verification.md`](docs/architecture/12-runtime-verification.md)).
The spec's *target* is 1,000 tests in under 10s — a target, and it stays a target until a committed
benchmark result says otherwise.

### Phase 3 — Realtime *(build step 6)* → `0.4.0`

`live`, `channel`, `broadcast`, `presence`. Postgres `LISTEN`/`NOTIFY` by default, Redis pub/sub by
config.

**Done when:** a screen with no `live` declaration opens **no socket and costs nothing** — that is
the opt-in claim and it needs a test, not a paragraph; a `broadcast` reaches a subscribed screen; a
channel evaluates the **same `policy` verb as the request path**, because there is no second door to
the data; flipping the backend to Redis changes one config key and zero lines of app code.

**One question this phase owes a number:** how many concurrent idle SSE or WebSocket connections one
Puma process sustains on TruffleRuby, and at what memory cost per connection. Thread-per-request is
worst at many mostly-idle connections and there is no `fork` to spread them over a second process.
The spec records it as open; nothing here should be read as claiming it is answered.

### Phase 4 — Jobs and async *(build step 7)* → `0.5.0`

`job :Name`, `retries times: 5, backoff: :exponential`, `schedule cron:` / `every:`, `idempotent_by`,
the Postgres-backed transactional queue, the `magik worker` process, and CSV/spreadsheet import and
export as job factories with a progress surface.

**The spelling is `retries`, not `retry`** — `retry` is a Ruby keyword and a declaration named after
it does not parse. That was found by running a parser over the drafted DSL, which is why the spec
requires it: *a drafted DSL spelling is not designed until it has been parsed.* Re-derive by
extracting every ` ```ruby ` block from
[`docs/idea/02-dsl-surface.md`](docs/idea/02-dsl-surface.md) and running `ruby -c` over the
concatenation. `schedule every:` takes a `:duration` — `every: "10m"`, never `every: 15.minutes`.

**Done when:** enqueue and the row that caused it commit or roll back **together**; a worker killed
mid-job retries it with backoff; a `cron:` schedule fires once across N workers; two workers never
claim one job; the queue backend is swappable and both sides pass one conformance suite.

### Phase 4b — Media *(build step 8)* → `0.6.0`

`attachment :name, :image|:document|:video, max_size:, content_types:, visibility:, direct:` on a
model, with a block declaring `derivative`, `responsive` and `exif`. Direct-to-storage presigned
upload, magic-byte content sniffing, image derivatives and `srcset`, EXIF stripping, signed expiring
URLs, a media-processing seam for video and audio, and blob lifecycle.

**Why it is a phase and not a line item:** it spans four others — the field type is phase 1, the
upload component is phase 2, derivative generation and transcoding are phase 4 jobs, and signed
delivery is blocked on `policy`. Ship it as a quarter per phase and the app still cannot store a
photo. **It is not optional:** the spec's mission sentence names ecommerce and marketplaces, and both
are blocked on media ([`docs/idea/10-saas-coverage.md`](docs/idea/10-saas-coverage.md)).

**Done when:** an upload **never passes through a request server** — a server proxying a 2GB file
occupies a connection for minutes and makes the stateless-servers decision a lie about memory; a
`.png` that is really an `.svg` is rejected on **magic bytes**, never the extension and never the
client's header; an `attachment` with no `max_size` and no `content_types` fails the boot with
`MAGIK_MODEL_UNCONSTRAINED_UPLOAD`; EXIF is stripped on ingest; a `:private` file's URL is issued
only after that record's `policy` verb passes; deleting a record enqueues deletion of its blobs; and
the video path is a **wrapped** service (`use :media, :mux`), not a transcoder Magik wrote — with the
`:ffmpeg` backend documented with its real costs.

### Phase 5 — Money and compliance *(build step 9)* → `0.7.0`

`ledger :Name`, `audited`, `immutable_after:`, `idempotent_by`, `flow :Name`, and basis-point rate
arithmetic as `:money`'s sibling for tax and fees.

**Done when:** a ledger whose debits and credits disagree **fails at boot**, with a
`MAGIK_LEDGER_UNBALANCED` naming the account; a ledger entry cannot be updated or deleted through the
DSL; a replayed action with the same `idempotent_by` key performs its effect once; a `flow` resumes
across two different app servers; `field :card_number` is refused at boot.

### Phase 7 — Auth, billing, admin *(build step 10)* → `0.8.0`

`auth do … end` over Rodauth, `billing provider: :stripe`, `admin_panel :Model, policy: %i[Model
administer]`, `tenant_by :subdomain`, and teams / memberships / seats / invitations generated the way
`auth` generates accounts.

**Done when:** a generated app has working registration, login, OAuth and 2FA without writing a
controller; a subscription lifecycle survives Stripe's webhooks arriving out of order; the admin
panel is generated from the model declarations rather than scaffolded into editable files, carries
all four view types (`list`, `show`, `form`, and bulk actions), and **cannot boot without a
`policy:`** — the admin is by construction the broadest data access in the app; an admin action that
writes directly instead of naming a real action fails with `MAGIK_ADMIN_INLINE_MUTATION`; and login
throttling, lockout and enumeration-resistant login and reset responses are **on by default**, not
documented.

### Phase 6 — API and webhooks *(build step 11)* → `0.9.0`

`api :V1 do resource … end`, incoming and outgoing `webhook`, `:bearer` / `:api_key` / `:jwt`,
plan-based rate limits, deprecation and sunset headers, and a webhook delivery log with replay.

**Done when:** a `resource` paginates, filters and sorts with no hand-written query, declaring its
field subsets in the **one vocabulary** `admin_panel`, `data_table` and `screen` use — `fields`,
`filterable`, `sortable`, `searchable`, `writable`; an incoming webhook with a bad signature is
rejected before the handler runs; an outgoing webhook retries through the job queue and its
deliveries are inspectable.

### Phase 8 — i18n, PWA, notifications *(build step 12)* → `0.10.0`

`locales`, `translatable: true`, the timezone-safe `:timestamp`, `pwa do … end`, `notification
:name`, and email production — `magik mail preview`, CSS inlining, a plain-text alternative, a
framework-owned suppression list, unsubscribe tokens and inbound bounce events.

**Done when:** rendering a `:timestamp` without an explicit zone is a **build error**, not a warning;
a missing translation is loud in development; one `notification` reaches email, in-app and push
through the job queue; `magik mail preview` renders an email **to a file** — an agent has no inbox,
so that is its only way to see one; and the PWA is installable and ships **no offline cache** — that
is a deliberate limit, see [Limits](#limits-that-do-not-move).

### Spec item 12 — Domains and `magik check` *(build step 13)* → `0.11.0`

Not a numbered phase: this is architecture decision 12 of the spec, delivered last because it
enforces boundaries across everything that exists by then.

`domains/<name>/domain.rb` with `depends_on` / `exposes` / `publishes_events`, boot-time enforcement,
and the `magik check` linter including `--scale`.

**Done when:** a cross-domain direct model access **fails at boot** naming both domains and the
offending constant; an undeclared dependency and a `depends_on` cycle both fail; `magik check
--scale` reports a query missing `tenant_id` in its `WHERE` clause; `magik check --json` is stable
enough for CI to gate on.

## What 1.0 means

`1.0.0` is not "all the phases are green". It is all the phases green **plus** four claims the spec
makes about itself, each backed by something executable:

| Claim | The proof it needs |
|---|---|
| Every opinionated default has a working swap | a passing test per seam — DB engine, cache, jobs, search, realtime — run against both sides. Proven before merge, never promised in a doc. Authorization is **not** on this list: a second authorization backend is a second authorization system |
| A CRUD screen is under 30 lines with no HTML/JS/CSS | a committed example whose line count is asserted by a test, not counted by hand |
| Fintech-grade money is the same grammar as everything else | no `fintech: true` mode exists anywhere in the codebase, and a grep for one is part of the gate |
| **A generated app is safe and usable on its first run** | three tests, not a document: a cross-tenant actor is denied by **every** generated surface — screen, action, API resource, channel and admin panel; the generated application shell renders correctly at 375px; the generated signup form throttles and does not reveal whether an account exists |

The fourth exists because the three above it can all be true of an application that is insecure and
unusable. It arrived with the coverage audit
([`docs/idea/10-saas-coverage.md`](docs/idea/10-saas-coverage.md)) and is now in the spec's success
criteria.

Until all four are true, the version stays below `1.0.0` however complete the feature list looks.

## Limits that do not move

These are not gaps and no version closes them. They are in the spec as permanent exclusions, and the
docs are required to refuse rather than fail quietly:

- **No offline support.** The server is the single source of truth. A PWA ships; an offline cache
  does not.
- **No heavy client-side compute.** Canvas editors, games, in-browser video editing — out of scope.
- **No SPA framework, ever.** Server-rendered HTML plus htmx. Not React, not Vue, not a "just for
  this one screen" escape hatch.

## Where to read more

| Want | Read |
|---|---|
| The spec itself | [`docs/idea/00-build-spec.md`](docs/idea/00-build-spec.md) |
| Why each decision | [`docs/idea/01-thesis.md`](docs/idea/01-thesis.md) |
| The DSL surface | [`docs/idea/02-dsl-surface.md`](docs/idea/02-dsl-surface.md) |
| What is enforced at boot | [`docs/idea/03-guardrails.md`](docs/idea/03-guardrails.md) |
| The swap points | [`docs/idea/04-swap-points.md`](docs/idea/04-swap-points.md) |
| The limits, in full | [`docs/idea/05-limits.md`](docs/idea/05-limits.md) |
| Whether the 99% claim holds | [`docs/idea/10-saas-coverage.md`](docs/idea/10-saas-coverage.md) — the honest answer is "not as stated" |
| The phase detail, and the build-order mapping | [`docs/idea/06-phases.md`](docs/idea/06-phases.md) |
| Why the grammar is shaped the way it is, and why `magik describe` exists | [`docs/idea/11-dsl-as-tool-surface.md`](docs/idea/11-dsl-as-tool-surface.md) |
| The AI-first thesis | [`docs/idea/07-ai-first.md`](docs/idea/07-ai-first.md) |
| The runtime measurements the concurrency decisions rest on | [`docs/architecture/12-runtime-verification.md`](docs/architecture/12-runtime-verification.md) |
| The agent workbench | [`.claude/README.md`](.claude/README.md) |
| The reference manual | [`wiki/Home.md`](wiki/Home.md) |
| What is broken right now | [`wiki/Known-Gaps.md`](wiki/Known-Gaps.md) — the answer is "all of it", stated properly |
