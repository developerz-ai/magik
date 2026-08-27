# Testing strategy

Spec Phase 9 as an architecture document: the Minitest wrapper, the `test` DSL, generated tests and factories, the parallel runner, isolation, and the speed budget that shapes all of it.

**Status:** planned. No test DSL, no runner, no factory inference, no `magik test` command. The framework's own suite is empty. Every number on this page is a target with the command that will measure it, never a result. Reviewed 2026-08-26.

## Why this is built fifth

Build-order step 5 in [`../idea/00-build-spec.md`](../idea/00-build-spec.md): *Test DSL + Minitest wrapper + parallel runner (build this early — TDD the rest)*. Everything from realtime onward is written test-first against this, which makes the runner a load-bearing piece of the framework rather than tooling around it.

## Minitest, not RSpec

The spec's decision, and the reasons are structural rather than aesthetic ([`../idea/05-limits.md`](../idea/05-limits.md)):

| Reason | Detail |
|---|---|
| Boot cost | the target is 1,000 tests in under 10 seconds. A runner that spends a second before the first assertion has spent 10% of the budget on itself. |
| A simple object model | a Minitest test is a method on a class. Scheduling one onto a worker thread, transactional rollback and per-test timing are tractable against that; against a runner with its own lifecycle and metaprogramming layer they are guesswork. |
| One grammar | `test :Name do it "…" end` compiles **down** to Minitest, so `assert_*` is always available underneath. There is no second way to write a test. |

`parallel_tests` / `parallel_rspec` appear on this page as **prior art for runner mechanics**, not as a framework option. Their design is worth mining; their runner is not being adopted.

## The `test` DSL

```ruby
test :Orders do
  it "captures a payment and posts a balanced entry" do
    order = create :Order, status: :placed, total: money(1000, :usd)

    perform_action :capture_payment, order_id: order.id, payment_intent_id: "pi_1"

    expect(order.reload.status).to_eq(:captured)
    expect(Payments.balance(:cash)).to_eq(money(1000, :usd))
    assert_enqueued :SettleBatch
  end
end
```

| Element | Compiles to |
|---|---|
| `test :Orders do … end` | a `Magik::TestCase` subclass named `OrdersTest` |
| `it "…" do … end` | `def test_captures_a_payment_and_posts_a_balanced_entry` |
| `expect(x).to_eq(y)` | `assert_equal y, x` — a small matcher set over plain assertions |
| `create :Order, …` | an inferred factory ([below](#inferred-factories)) |

Helpers, all planned: `perform_action`, `render_screen`, `concurrently(n)`, `travel_to`, `assert_enqueued`, `assert_broadcast`, `assert_notified`.

### Four helpers that exist because a claim elsewhere in the spec has to be testable

Each is a phase-9 item the spec names, and each is the executable half of a promise made in another phase. A promise with no assertion behind it is prose.

| Helper | The claim it makes testable |
|---|---|
| `assert_queries(n) { … }` | a way to assert the **absence** of an N+1. Nothing else in the design catches one: an N+1 is correct, fast on a fixture and ruinous in production, so it has to be asserted at the count rather than found at the p99 |
| Email content assertions beyond `assert_notified` | subject, recipient, body text, links, and **that a plain-text part exists**. `assert_notified` proves a notification fired; it says nothing about what landed in the inbox — and an agent has no inbox to check ([`../idea/00-build-spec.md`](../idea/00-build-spec.md) phase 8) |
| **A generated authorization test per policy verb, including a cross-tenant denial** | decision 13 — every surface names a verb and the framework evaluates it. The test is generated from the `policy` declaration, so a verb that ships without one is not possible; the cross-tenant case is generated too, because that is the denial an app author is least likely to write |
| `render_screen … at: :mobile` | phase 2's *every kit component is responsive by construction*. That is a claim to be tested, not asserted, and this is what tests it — alongside the phase-2 exit criterion that the generated app renders correctly at 375px |

```ruby
test :Invoices do
  it "lists without an N+1" do
    3.times { create :Invoice }
    assert_queries(2) { render_screen :Invoices }
  end

  it "renders on a phone" do
    render_screen :Invoices, at: :mobile
  end
end
```

## Prior art, honestly assessed

### Rails

`parallelize(workers: :number_of_processors)` forks N worker **processes** and gives each its own database — `app_test-0`, `app_test-1`, … — with `parallelize_setup` / `parallelize_teardown` hooks to prepare and clean each one.

| Gets right | Pays for |
|---|---|
| true isolation: separate process, separate connection, separate database. A test cannot see another worker's rows | N database copies to create, migrate or load a schema into, on every cold run |
| crash containment: a segfaulting worker does not take the suite down | fork cost per worker, and N × the memory of a booted app |
| no shared-state discipline required of the framework or of user code | cross-process aggregation of results and coverage, which is fiddly and where flakiness hides |

### `parallel_tests` / `parallel_rspec`

Splits the file list across processes, by one of three strategies:

| Split by | Behaviour |
|---|---|
| file count | trivial, and badly unbalanced — one file with 200 slow tests lands beside twenty trivial ones |
| line count | a better proxy, still a proxy. Line count does not predict database round trips |
| **recorded runtime** | the only strategy that actually balances: keep a log of per-file durations, sort descending, greedily assign to the least-loaded worker |

The lesson Magik takes: **balance on recorded runtime, and record it by default** so the first run is the only unbalanced one. The cost it pays — a runtime log that must be maintained and can go stale — is real, and the mitigation is that a missing or stale entry falls back to line count rather than failing.

## What Magik does differently

**One worker *thread* per test file group, `workers: :auto` (all CPUs)** — parallelism inside one process rather than N forked processes.

That works because threads on TruffleRuby are genuinely parallel — measured, not assumed: `ruby scripts/probes/runtime.rb`, results recorded in [`12-runtime-verification.md`](12-runtime-verification.md) `As of 2026-08-26`. **Cite the probe, never the ratio:** the speedup moves run to run with machine load, and a number copied into prose here is a number a re-run contradicts. TruffleRuby has no GVL, so the usual Ruby reason for reaching past threads does not exist.

| Property | Separate processes (Rails-shaped) | Threads (Magik's design) |
|---|---|---|
| Startup | boot per worker | one boot, N threads |
| Memory | N × app | one app image, per-thread locals |
| Databases | N copies | one database, one connection per worker thread, transactional isolation |
| Demands | none on the framework | genuinely shared-nothing tests, and a thread-safe framework: frozen registries, no mutable globals |
| Crash blast radius | one worker | potentially the process |
| Actually parallel? | yes, on any engine | **yes on TruffleRuby**, which is the production runtime and the engine that matters — `ruby scripts/probes/runtime.rb` |

This is why [`00-conventions.md`](00-conventions.md) freezes the declaration registry at the end of boot and forbids mutable globals: the test runner's design depends on it, and a subsystem that stashes mutable state breaks parallelism rather than just being untidy.

### Thread-parallel tests demand shared-nothing tests

Under threads, one test's mutation of process-global state is visible to every test running beside it, and the failure is a flake in a *different* file. Two rules on this page already forbid exactly that:

| Rule | Stated reason | The reason it turns out to have |
|---|---|---|
| Transactional rollback per test, never truncation | speed — no truncate, no reseed | each worker's connection sees only its own uncommitted rows, so database state is not shared even though the process is |
| Frozen clock, sealed network — no wall-clock waits, no unmocked sockets | determinism and speed | a `sleep` or a real socket is shared, contended state. `travel_to` on a *global* clock is itself a shared-state hazard and has to be per-worker |

**The discipline was right for a different reason than the one given.** That is worth saying plainly rather than quietly reclassifying it: these rules were written as a speed budget and they turn out to be the isolation model. What they do not cover, and what the runner must therefore add, is process-global Ruby state — memoised class variables, mutable constants, `ENV` writes, a stubbed global. Those are now a correctness rule for tests, not a style preference, and `magik check` should say so.

### One worker model, not a matrix

The runner has **one** parallel backend: worker threads. There is no forked-worker mode, no per-engine strategy selection, and no `--workers=processes`. Two reasons, and the second is decisive:

| | |
|---|---|
| Threads are genuinely parallel on the production runtime | measured by `ruby scripts/probes/runtime.rb`. The reason forked workers exist in Ruby is the GVL, and TruffleRuby does not have one |
| **`fork` is not available on TruffleRuby anyway** | `Process.respond_to?(:fork)` is `false`; calling it raises `NotImplementedError: fork is not available`. Measured on both builds tested, [`12-runtime-verification.md`](12-runtime-verification.md). A forked fallback is not a thing that could be built here |

`magik test --workers=N` sets how many worker threads, and `auto` is all CPUs. It does not select a mechanism, because there is only one.

**What this costs on CRuby, stated plainly.** The local development loop runs on CRuby, where threads do not parallelise CPU-bound Ruby at all — the same probe reports no speedup there, which is the global lock. The suite still runs, correctly, on worker threads; it just does not get the speedup. The 10-second target is a **TruffleRuby target**, and whoever first measures it must say which engine it was measured on. That is a cost of the decision, not a reason for a second mechanism: two runner backends would mean the suite that gates a change is not the suite that runs in CI.

Nothing here is settled by measurement, because there is no suite to measure. Pretending otherwise would be the dishonest version of this document.

## Isolation

**Transactional rollback per test. Never truncation.**

| | |
|---|---|
| How | each test runs inside a transaction (or a savepoint under a wrapping one) that is rolled back when it ends |
| Buys | no truncation cost per test, no reseeding, no cross-test residue, and cheap parallelism — each connection sees only its own uncommitted work |
| Costs | anything that needs data to be actually *committed* does not work inside it |

Where it breaks down, and the escape hatch:

| Case | Why rollback fails | Escape hatch |
|---|---|---|
| Realtime tests (`LISTEN`/`NOTIFY`) | notifications fire at commit; an uncommitted transaction notifies nobody | `it "…", isolation: :committed` — runs against a truncated database, in a serialized group |
| Jobs executed by a worker on another connection | the worker cannot see uncommitted rows | same flag; or assert on the *enqueue* with `assert_enqueued`, which is the default and the faster test |
| Tests asserting on a real second connection | by definition outside the transaction | `isolation: :committed` |
| Code under test managing its own transactions | nested transaction semantics differ from the real thing | savepoint-aware helper, or `isolation: :committed` where the semantics are the point |

The rule: `isolation: :committed` is opt-in, per test, visible in the diff, and reported in the summary with its cost — because a suite that quietly drifts to truncation has lost the speed budget without anyone deciding to.

## Speed as a designed property

Where the time actually goes in a Ruby suite, and what the design does about each:

| Cost | Typical cause | Magik's answer |
|---|---|---|
| Boot | loading the framework and the app once per worker | boot **once**. Worker threads share the image, so this cost is paid a single time no matter how many workers run |
| Schema setup | running every migration per worker database | load the schema **once** into a template database, clone per worker (`CREATE DATABASE … TEMPLATE`), never migrate in the test path |
| Factory work | fixtures and factories that build object graphs nobody asserts on | factories inferred from field types build the **minimum** valid row; associations are built only when declared |
| DB round trips | per-test setup and teardown chatter | transactional rollback replaces truncate + reseed |
| Wall-clock waits | `sleep`, retries, real HTTP | frozen clock (`travel_to`), sealed network — an unmocked socket **fails** the test rather than hanging it |
| Fixtures | loading and maintaining fixture files | there are none; the factory is derived from the model declaration |

### The target

> Full test suite of 1,000 tests: parallel, all cores, **<10s target** — [`../idea/00-build-spec.md`](../idea/00-build-spec.md)

It is a target. It has never been measured, because there is no runner and no suite. The command that will measure it, when both exist:

```bash
magik test --workers=auto --report=timing --json
```

`--report=timing` prints total wall clock, per-worker load, and the slowest N tests. Any claim of a number on any page in this repo must cite that command and a date.

## The developer loop

| Command | Does | Status |
|---|---|---|
| `magik test` | the whole suite, parallel, failure-first output | planned |
| `magik test path/to/file.rb` | one file, serial, no parallel overhead | planned |
| `magik test --watch` | re-runs on save — the affected tests only, then the rest when idle | planned |
| `magik test --changed` | only the tests the current diff can affect | planned |
| `magik test --workers=N` | pin worker count; `auto` is all CPUs | planned |
| `magik test --report=timing` | where the time went | planned |
| `magik test --json` | machine-readable results for an agent or CI | planned |

**How `--changed` is computed.** Not file mtime — a **dependency graph**. Every declaration is registered with its source file, so the framework knows that `app/models/order.rb` defines `:Order`, that `app/actions/capture_payment.rb` references it, and that `test/orders_test.rb` exercises both. The changed set is: files in the diff, plus everything transitively depending on them, mapped to the tests that touch any of it. Mtime alone would miss a test that breaks because a model it never names changed underneath an action it does.

That graph has two consumers — `magik test --changed/--watch` and the dev-server reloader — and it is **one implementation** shared between them ([`08-dev-loop.md`](08-dev-loop.md)).

**Failure-first reporting**: failures print first, in full, with the `MAGIK_*` code where one applies; the summary and per-test timings follow. The slow tests surface without being hunted, so nobody has to go looking for the reason the suite got slower.

## The auto-generated layer

The spec generates tests from declarations. What is generated:

| Source declaration | Generated test |
|---|---|
| `field …, required: true` | the record is invalid without it, valid with it |
| `validate :x, format: /…/` | a passing case and a failing case per rule |
| `field :total, :money` | a float is refused; minor units round-trip through the database |
| `ledger` `entry` | the entry balances; posting twice with one idempotency key posts once |
| `immutable_after:` | a write past the point raises `MAGIK_MODEL_IMMUTABLE_VIOLATION` |
| `belongs_to` / `has_many` | the association resolves and is tenant-scoped |
| `api resource` | each declared verb answers, paginates, and rejects a cross-tenant read |
| **`policy` `can :verb`** | **one test per verb**: the rule grants what it should, denies by default, denies on a `nil` record, and **denies an actor from another tenant**. Generated from the declaration, so no surface can ship a verb with no test behind it |
| `attachment` (phase 4b) | an unbounded declaration fails the boot; a private file's URL is issued only after the record's policy verb passes |

| Rule | Detail |
|---|---|
| Generated tests never replace hand-written ones | they live in a separate, regenerable location and are additive. A generator that overwrites an author's test is a defect. |
| Regenerable at any time | `magik generate tests --for <Name>`; the output is deterministic. |
| They count toward the suite | they run in the same pass, under the same isolation, in the same timing report. |
| They are not a substitute for a behaviour test | they prove the declaration holds, never that the feature is right. |

### Inferred factories

```ruby
order = create :Order, status: :placed          # everything else inferred and minimal
```

Derived from field types: a `:string` gets a short unique value, an `:enum` its default, a `:money` a small non-zero amount in the declared currency, a `belongs_to` a created parent only when the association is required. No factory files, no fixtures, no trait DSL — the model declaration is already the schema of the thing.

## Test types and where they run

Six kinds, in cost order. The gate runs them in this order so the cheapest failure surfaces first.

| # | Type | Proves | Touches | Where |
|---|---|---|---|---|
| 1 | `unit` | one object's behaviour | nothing | `magik test`, `bin/check` |
| 2 | `declaration` | the generated invariants above | database, in a transaction | `magik test`, `bin/check` |
| 3 | `action` | a mutation end to end, via `perform_action` | database, jobs (asserted, not run) | `magik test`, `bin/check` |
| 4 | `render` | a screen's HTML and its `hx-*` wiring, via `render_screen` | database | `magik test`, `bin/check` |
| 5 | `integration` | realtime, worker execution, committed-data paths | database with `isolation: :committed`, a worker, `LISTEN`/`NOTIFY` | `magik test`, CI |
| 6 | `conformance` | a swap point's backends all satisfy one contract ([`../idea/04-swap-points.md`](../idea/04-swap-points.md)) | each backend, real | CI only |

App-facing usage, helper reference and worked examples live in [`../../wiki/Testing.md`](../../wiki/Testing.md).
