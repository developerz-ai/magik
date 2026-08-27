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

This page previously said *Ractor* rather than *thread*, on the strength of spec item 1. That was measured and falsified: `Ractor` does not exist on TruffleRuby, and threads there run genuinely in parallel — [`12-runtime-verification.md`](12-runtime-verification.md), `As of 2026-08-26`. The *shape* of the design is unchanged (one process, N workers, one database, transactional isolation); the primitive underneath it is a thread.

| Property | Separate processes (Rails-shaped) | Threads (Magik's design) |
|---|---|---|
| Startup | boot per worker | one boot, N threads |
| Memory | N × app | one app image, per-thread locals |
| Databases | N copies | one database, one connection per worker thread, transactional isolation |
| Demands | none on the framework | genuinely shared-nothing tests, and a thread-safe framework: frozen registries, no mutable globals |
| Crash blast radius | one worker | potentially the process |
| Actually parallel? | yes, on any engine | **on TruffleRuby yes; on CRuby no** — the GVL serialises CPU-bound work, measured at 0.8× on 4 threads |

This is why [`00-conventions.md`](00-conventions.md) freezes the declaration registry at the end of boot and forbids mutable globals: the test runner's design depends on it, and a subsystem that stashes mutable state breaks parallelism rather than just being untidy.

### Thread-parallel tests demand shared-nothing tests

Under threads, one test's mutation of process-global state is visible to every test running beside it, and the failure is a flake in a *different* file. Two rules on this page already forbid exactly that:

| Rule | Stated reason | The reason it turns out to have |
|---|---|---|
| Transactional rollback per test, never truncation | speed — no truncate, no reseed | each worker's connection sees only its own uncommitted rows, so database state is not shared even though the process is |
| Frozen clock, sealed network — no wall-clock waits, no unmocked sockets | determinism and speed | a `sleep` or a real socket is shared, contended state. `travel_to` on a *global* clock is itself a shared-state hazard and has to be per-worker |

**The discipline was right for a different reason than the one given.** That is worth saying plainly rather than quietly reclassifying it: these rules were written as a speed budget and they turn out to be the isolation model. What they do not cover, and what the runner must therefore add, is process-global Ruby state — memoised class variables, mutable constants, `ENV` writes, a stubbed global. Those are now a correctness rule for tests, not a style preference, and `magik check` should say so.

### The parallel backend is still a seam

| Mitigation | Detail |
|---|---|
| The runner's parallel backend is a seam | `workers: :auto` selects a strategy; the strategy is not baked into the test DSL |
| Selection is explicit and reported | `magik test --workers=auto` prints which strategy it chose and why, so nobody debugs a mystery |
| The strategy is engine-dependent, and that is not a wart | on TruffleRuby, threads. On CRuby, where threads do not parallelise CPU-bound work, **forked workers** with one database per worker — the Rails-shaped model above, slower to start, known to work |
| The decision is measurable | whichever backend hits the target on the framework's own suite wins, and the page says which one that was |

### The constraint that removes the obvious fallback

**`fork` is not available on TruffleRuby.** `Process.respond_to?(:fork)` is `false` and calling it raises `NotImplementedError: fork is not available` — measured on both builds tested, [`12-runtime-verification.md`](12-runtime-verification.md).

So "fall back to forked workers" is a CRuby answer, not a universal one. On the production runtime the options are:

| Option | Cost |
|---|---|
| Worker threads | the design above. Requires the shared-nothing discipline to actually hold |
| `Process.spawn`-ed workers | verified to work. A **full boot per worker** and no copy-on-write page sharing, so it is strictly more expensive than fork would have been. The escape hatch, not the plan |

Neither is settled by measurement, because there is no suite to measure. Pretending otherwise would be the dishonest version of this document.

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
| Boot | loading the framework and the app once per worker | boot once; worker threads share the image. Under the CRuby forked fallback, boot before forking; under spawned workers this cost is paid per worker and is the reason spawn is the escape hatch |
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

App-facing usage, helper reference and worked examples live in `wiki/Testing.md`.
