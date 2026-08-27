# Runtime verification

Two spec decisions named a concurrency mechanism the production runtime does not have. This page is the measurement that established that, the method that makes it credible, what it kills, what survives, and the trigger that would reverse it.

**Status:** the probe is written and re-runnable; **the framework is still unimplemented**. The numbers below are the only measured facts in this repository, and their scope is narrow on purpose: they are *capability* results — does the runtime parallelise at all, does `async` boot at all — not throughput results. Nothing here licenses a performance claim anywhere else. Reviewed 2026-08-26.

## Why this page exists

[`../idea/00-build-spec.md`](../idea/00-build-spec.md) item 1 said concurrency comes from Ractors and Fibers, not threads-per-request. Item 2 said the server is Rack + Falcon, async and fiber-based. Both were written before anyone ran TruffleRuby.

[`10-performance-defaults.md`](10-performance-defaults.md) had already flagged the conflict from upstream documentation and called for "an experiment, not an argument". This is that experiment. It changed the answer: the *mechanisms* in items 1 and 2 are not available on the production runtime, the *goal* behind item 1 is met by a different mechanism, and item 2 has no path at all.

A document that only cited upstream prose would be arguing. This one measures, and hands you the command.

## Method — read this before the numbers

The thread-parallelism question is easy to get wrong, and the first attempt at it here **did** get it wrong: it measured **0.32×** on TruffleRuby and would have concluded that TruffleRuby is worse than CRuby at threading. That number was pure noise. Three things have to be right, and a rebuttal to this page has to engage with all three.

| Requirement | Why | What goes wrong without it |
|---|---|---|
| **The work must be work the compiler cannot delete** | a numeric loop with an unused result is dead code to an optimising compiler, and Graal is an optimising compiler | the loop folds away and you time thread creation. Thread creation is *more* expensive than the phantom work, so the "parallel" run loses and the engine looks slow |
| **The JIT must be warmed before timing** | TruffleRuby is a JIT that starts in an interpreter. A cold native image loses to its own warmed self by a wide margin, and the deployment guide says so ([`deploying.md`](https://github.com/oracle/truffleruby/blob/master/doc/user/deploying.md): peak performance requires "running the application under load for a period of time") | you measure warmup, attribute it to the concurrency model, and conclude the opposite of the truth |
| **Each round must depend on the last** | otherwise the rounds are independent and hoistable, and you are back to problem one | the compiler computes one round and reuses it |

`scripts/probes/runtime.rb` satisfies all three by hashing a rolling buffer: `digest = Digest::SHA256.hexdigest(digest)`, N times, where round *n* cannot start until round *n−1* has produced its input. It runs a tenth-scale pass first, purely to warm the JIT, and discards it. Only then does it time a serial pass and a parallel pass of identical total work.

**What the probe deliberately does not do.** It does not compare engines against each other for speed, it does not measure request throughput, and it does not measure memory. It answers three yes/no questions and reports one ratio as evidence for the third:

1. Does `Ractor` exist and work?
2. Is `Fiber.set_scheduler` present — the API `async` and Falcon are built on?
3. Do threads actually run in parallel, or are they serialised by a global lock?

## The probe

```bash
ruby scripts/probes/runtime.rb                                             # whichever engine is on PATH
ruby scripts/probes/runtime.rb --json                                      # machine-readable
MAGIK_PROBE_ROUNDS=500000 MAGIK_PROBE_THREADS=8 ruby scripts/probes/runtime.rb
```

The exact commands that produced the table below, on this machine:

```bash
ruby scripts/probes/runtime.rb                                             # CRuby 3.2.3
mise exec ruby@truffleruby-24.2.1        -- ruby scripts/probes/runtime.rb # TruffleRuby 24.2.1
mise exec ruby@truffleruby+graalvm-34.0.1 -- ruby scripts/probes/runtime.rb # TruffleRuby 34.0.1
```

`MAGIK_PROBE_ROUNDS` (default 200,000) and `MAGIK_PROBE_THREADS` (default 4) tune it. The speedup is called "parallel" above 1.5× — a deliberately loose threshold, because the question is *parallel or not*, not *how parallel*.

## Results — `As of 2026-08-26`

Three engines, including the **newest** TruffleRuby release. Testing an outdated build is the first and most reasonable objection to a finding like this one, so the newest was tested and is reported alongside.

| | CRuby 3.2.3 | TruffleRuby 24.2.1 | TruffleRuby 34.0.1 |
|---|---|---|---|
| `RUBY_DESCRIPTION` | `ruby 3.2.3 (2024-01-18) [x86_64-linux-gnu]` | `truffleruby 24.2.1, like ruby 3.3.7, Oracle GraalVM Native` | `truffleruby 34.0.1 (2026-04-26), like ruby 3.4.9, Oracle GraalVM JVM` |
| Build mode | — | **Native image** | **JVM** |
| `Ractor` | works | **`NameError: uninitialized constant Ractor`** | **`NameError: uninitialized constant Ractor`** |
| `Fiber.set_scheduler` | present | **absent** | **absent** |
| `Fiber.scheduler` | present | **absent** | **absent** |
| `async` 2.45.0 | runs | installs, then **`NoMethodError: undefined method 'scheduler' for class Fiber`** | same failure, identically |
| 4-thread speedup (SHA256, warmed) | **0.80–0.89×** | **2.55–3.54×** | **1.90–2.42×** |
| Threads genuinely parallel | **no** | **yes** | **yes** |
| `Process.respond_to?(:fork)` | `true` | **`false`** | **`false`** |

Version numbering: TruffleRuby moved from its own scheme (`24.2.1`) to GraalVM's (`34.0.1`). 34.0.1 is dated 2026-04-26 and is the newer release by a wide margin, not a lower one.

### The `async` failure, verbatim

```
$ mise exec ruby@truffleruby-24.2.1 -- ruby -e 'require "async"; Async { puts "booted" }'
.../async-2.45.0/lib/kernel/async.rb:28:in `Async': undefined method `scheduler' for class Fiber (NoMethodError)
```

The gem installs cleanly. It fails on the **first `Async{}` block**, at the point where it asks `Fiber` for a scheduler. This is the distinction that matters: `async` does not fail to be fast on TruffleRuby, it fails to boot.

### The version confound, stated as a confound

24.2.1 measured faster than 34.0.1 here. **Do not read that as "the newer TruffleRuby is slower."** The two runs differ in build mode as well as version — 24.2.1 is the Native image, 34.0.1 is the JVM build — and the probe's workload is short. JVM mode is documented to reach a higher peak and to need far more warmup to get there ([README](https://github.com/oracle/truffleruby/blob/master/README.md): Native starts "about as fast as MRI startup" with "good" peak; JVM starts "slower", warms "slower", "best" peak). A short workload is exactly the shape that flatters Native and penalises JVM.

Two different build modes, one short workload: that is a **confound, not a result**. The Native-versus-JVM trade-off is on the owed list below.

## What each result kills, and what survives

| Spec item | Verdict |
|---|---|
| **Item 1 — "concurrency via Ractors/Fibers, not threads-per-request"** | the **mechanism is dead**; the **goal survives intact** |
| **Item 2 — "Rack + Falcon (async, fiber-based)"** | **no path on TruffleRuby.** Not slow — absent |

**Item 1's goal was never Ractors.** It was *do not be GVL-bound* — do not spend a request-handling model working around a lock that serialises Ruby execution. That goal is met, and the probe is what shows it: 0.8× on CRuby is the GVL; 2.4–3.5× on TruffleRuby is its absence. Threads on TruffleRuby *are* the non-GVL-bound concurrency the item asked for. What dies is the sentence naming Ractors, not the reasoning behind it.

**Item 2 has no fallback position.** Falcon is built on the fiber scheduler; the fiber scheduler is not there; `async` raises on its first block. There is no configuration, no shim, and no degraded mode. Falcon on TruffleRuby is not a slower option — it is not an option.

**And to be fair to it, because a record that reads as a verdict on quality is a record nobody trusts: Falcon is not a bad server. It is an excellent one**, and on CRuby it would be the right choice — the fiber-per-connection model is genuinely better than a thread pool for the many-idle-connections workload Magik's realtime feature is. What disqualifies it here is an engine incompatibility and nothing else: it needs an API TruffleRuby has not implemented. If TruffleRuby ships that API, the argument for Falcon comes back intact, which is exactly why [the revisit condition](#the-one-condition-that-would-reopen-the-server-decision) below is stated precisely rather than as a general caveat.

**The decision recorded here: keep TruffleRuby, change the mechanism.**

| | |
|---|---|
| Runtime | **TruffleRuby.** CRuby ≥ 3.2 is supported for development tooling — `magik check`, `magik generate`, the local test loop — and is **not a production target**. The concurrency model does not work there: 0.8× is the GVL, and a CRuby production deploy would be a different framework wearing the same name |
| Concurrency | **real parallel OS threads.** One mechanism |
| Server | **Puma.** Falcon does not run on the production runtime, so it is not an option |

There is no second path, no per-engine branch and no fallback mode. Nothing is implemented yet, so there is no installed base to be compatible with and no reason to design two systems. The [re-verification trigger](#re-verification-trigger) records what would change this decision; it does not pre-build the alternative.

### `ractor-shim` — a workaround, not an answer

TruffleRuby's own compatibility document points at [`ractor-shim`](https://github.com/eregon/ractor-shim): "to run a program relying on Ractor on TruffleRuby you can use the ractor-shim gem and it will run those Ractors in parallel."

It is the right tool for **porting existing Ractor code you did not write**. It is the wrong tool for a framework choosing its own concurrency model from scratch: it would have Magik implement a Ractor-shaped API — with Ractor's isolation constraints and its shareability rules — on top of threads that already run in parallel and have none of those constraints, in order to satisfy a spec sentence rather than a requirement. That is cost with no purchase. Threads directly, not Ractors emulated by threads.

## Upstream documentation — corroboration, not proof

The probe is the proof. These quotes are corroboration: they say the same thing, from the implementers, and they explain *why*.

From [`truffleruby/doc/user/compatibility.md`](https://github.com/oracle/truffleruby/blob/master/doc/user/compatibility.md):

> "`Ractor` is currently not implemented on TruffleRuby."
>
> "Threads are run in parallel on TruffleRuby and Threads are far more compatible with gems than `Ractor`, so `Ractor` is not so useful on TruffleRuby."
>
> "In MRI, threads are scheduled concurrently but not in parallel. In TruffleRuby threads are scheduled in parallel."
>
> "In TruffleRuby, fibers are currently implemented using operating system threads, so they have the same performance characteristics as Ruby threads. This [will be addressed](https://medium.com/graalvm/bringing-fibers-to-truffleruby-1b5d2e258953) once the Loom project becomes stable and available in JVM releases."

The same document also states that `fork` is unavailable — "You cannot `fork` the TruffleRuby interpreter" — which the probe confirms directly and which has consequences of its own ([below](#consequences-that-follow-immediately)).

On the scheduler specifically, TruffleRuby's Ruby-3.x support tracking ([#3039](https://github.com/oracle/truffleruby/issues/3039), repeated in [#2453](https://github.com/oracle/truffleruby/issues/2453) and [#2733](https://github.com/oracle/truffleruby/issues/2733)):

> "Fiber scheduler changes are not implemented because it seems not worth it until Truffle supports VirtualThread on both Native Image and HotSpot."

### The changelog, read as negative evidence

[`truffleruby/CHANGELOG.md`](https://github.com/oracle/truffleruby/blob/master/CHANGELOG.md) runs to **40.0.0** and contains **no entry** for `Fiber::Scheduler`, `Fiber.set_scheduler`, non-blocking fibers, a `Ractor` implementation, or `async` support. The nearest entries are not the scheduler:

| Entry | Version | Why it is not the scheduler |
|---|---|---|
| "Relax `Fiber#transfer` limitations" | 22.0.0 | `Fiber#transfer` is explicit hand-off, not scheduled non-blocking IO |
| "Implement `Fiber#blocking?` like CRuby 3" | 22.0.0 | the *query* from the scheduler API, not the scheduler |
| "Fibers no longer trigger Truffle multi-threading" | 21.1.0 | an internal threading-mode change |
| "Implement `Fiber.[]`, `Fiber.[]=`, `Fiber#storage`" | 34.0.0 | fiber-local storage |
| "Run C extensions marked as `rb_ext_ractor_safe()` … in parallel" | 25.0.0 | honours a *marker* CRuby extensions carry; not a `Ractor` implementation |

Absence from a changelog is weaker evidence than a probe — a feature can land unannounced, and a changelog can be incomplete. It is offered as agreement with the measurement, and the measurement is what settles it.

Reproduce both fetches:

```bash
curl -sL https://raw.githubusercontent.com/oracle/truffleruby/master/doc/user/compatibility.md | grep -n -A3 -iE 'ractor|scheduled in parallel|performance characteristics'
curl -sL https://raw.githubusercontent.com/oracle/truffleruby/master/CHANGELOG.md | grep -niE 'fiber.?scheduler|set_scheduler|non-blocking fiber'   # expect: no output
```

## Consequences that follow immediately

Three things fall out of the table that are not restatements of it. All three are measured, not inferred.

### `fork` is unavailable on TruffleRuby

```
$ mise exec ruby@truffleruby-24.2.1 -- ruby -e 'p Process.respond_to?(:fork); fork { }'
false
NotImplementedError: fork is not available
```

Same on 34.0.1. This matters more than it looks, because "fork a worker per core" is the standard Ruby answer to everything the GVL forbids, and a great deal of Ruby deployment advice assumes it is available. Here it is not:

| Wants to fork | Consequence on TruffleRuby |
|---|---|
| Puma clustered mode (`workers N`) | unavailable. Puma runs **single mode** — one process, one thread pool. That is the deployment shape, and the parallelism result is what makes it viable: the reason clustered mode exists is the GVL, and there is no GVL here |
| A forked test-worker pool | unavailable. The test runner is thread-based ([`04-testing-strategy.md`](04-testing-strategy.md)) |
| `wurk`'s fork-based swarm | already documented as unavailable here in [`11-jobs-backend.md`](11-jobs-backend.md), from wurk's own README. The probe independently confirms the reason |

More capacity comes from more containers, not more processes on one box — which is the stateless topology [`../ops/README.md`](../ops/README.md) already specifies.

### Puma boots and serves on TruffleRuby

Puma 8.0.2 was installed under both TruffleRuby builds — it compiles its C extension there — booted in single mode with a 4–8 thread pool, and served an HTTP request successfully. That establishes only that the server runs. It is **not** a throughput measurement, a concurrency measurement, or a production endorsement, and the load test that would earn any of those is on the owed list.

### CRuby's role, now with a number attached

CRuby is the fast-boot engine for development tooling — `magik check`, `magik generate`, the local test loop — and it is **not a production target**. The 0.8× column is why: the concurrency model this framework is built on does not exist there. The split was already the stated policy ([`10-performance-defaults.md`](10-performance-defaults.md) §7.1); the probe turns it from a preference into a measurement.

## The open question, owed and unanswered

**This probe measured CPU-bound parallelism. Realtime is not CPU-bound.**

Fibers are cheap per idle connection; OS threads are not. `live` and `channel` over Postgres `LISTEN`/`NOTIFY` is a workload of *many mostly-idle connections* — which is precisely the workload fibers were chosen for and precisely the case a digest loop says nothing about. And on TruffleRuby a fiber **is** an OS thread ("the same performance characteristics as Ruby threads"), so there is no cheap-connection primitive available at all.

So the parallelism result does not rescue realtime. It answers a different question. The honest position is that Magik does not yet know what one Puma process on TruffleRuby can hold.

**The measurement owed:** how many concurrent **idle** SSE or WebSocket connections one Puma process sustains on TruffleRuby, and at what resident memory.

**How to measure it:**

| Step | |
|---|---|
| Under test | one Puma process on TruffleRuby, single mode, serving a trivial endpoint that opens a stream, writes a heartbeat every N seconds, and holds |
| Load | a connection generator that opens connections in steps — 100, 500, 1,000, 5,000 — and holds them idle. It must not be Ruby on the same box; the client's own limits must not be the thing measured |
| Measured at each step | RSS of the Puma process, thread count, open file descriptors, heartbeat delivery latency (p50/p99), and connection failures |
| The answer | the step at which heartbeat latency degrades or connections start failing, and the RSS per connection up to that point |
| Also record | `ulimit -n`, thread-stack size, and Puma's `max_threads`, because each of them can be the ceiling instead of the runtime |
| Compare against | the same test on CRuby with Falcon, where fibers *are* cheap. If the gap is an order of magnitude, the realtime backend is a topology decision rather than a tuning one |

Until that runs, the realtime connection ceiling on TruffleRuby is **unknown**, and no page in this repo may imply otherwise.

## Owed measurements, in one list

| Owed | Why it is not answered here | Blocks |
|---|---|---|
| Idle connection density per Puma process on TruffleRuby | above; a CPU probe cannot answer an idle-connection question | the realtime deployment story, `ops/README.md` sizing |
| **Native vs JVM build mode**: boot time versus peak throughput, and which suits `magik server`, `magik worker`, and a one-second CLI command | the two probe runs differ in mode *and* version — a confound. Needs one version, both modes, a long workload | a genuine deployment decision `ops/README.md` will have to make |
| Whether `pg` drops TruffleRuby's global C-extension lock | untested. A global lock around every query would erase the parallelism the runtime was chosen for | the entire threading argument for database work — [`10-performance-defaults.md`](10-performance-defaults.md) §7.2 |
| Puma throughput and concurrency on TruffleRuby under real load | the boot test proves it starts, nothing more | pool arithmetic in [`10-performance-defaults.md`](10-performance-defaults.md) §2.1 |
| Thread-parallel test-runner speedup on a real suite | there is no suite | [`04-testing-strategy.md`](04-testing-strategy.md)'s runner-backend choice |

## Re-verification trigger

This finding is about what upstream has **not yet implemented**, and that class of finding goes stale silently — the day it stops being true, nothing announces it here.

**Reverse this page if any of these lands:**

| Upstream change | What it reverses |
|---|---|
| **TruffleRuby implements `Fiber::Scheduler` / `Fiber.set_scheduler`** | the server decision — see [below](#the-one-condition-that-would-reopen-the-server-decision) |
| TruffleRuby's fibers stop being OS threads (the Loom work its docs point at) | the idle-connection ceiling changes shape even without a scheduler |
| `Ractor` lands on TruffleRuby | the original mechanism becomes available. It does **not** automatically win — threads already parallelise and are more compatible with gems, by TruffleRuby's own assessment — but the comparison is worth re-running |
| `fork` becomes available in the native configuration | Puma clustered mode and process-based workers become possible. Re-open the sizing question, not the concurrency model |

### The one condition that would reopen the server decision

Stated precisely, because "this may change someday" is not a trigger and nobody acts on it.

| | |
|---|---|
| **The trigger** | TruffleRuby implements `Fiber::Scheduler` / `Fiber.set_scheduler`. That single upstream change, and nothing else. Not a TruffleRuby release in general, not a Falcon release, not a benchmark someone publishes |
| **How we notice** | the probe runs in CI against the newest TruffleRuby. `fiber_scheduler.available` flips from `false` to `true` and the step goes red. **That is the mechanism** — a changed probe result, not somebody happening to read a changelog |
| **What we do then** | re-run `scripts/probes/runtime.rb` on every engine, confirm `async` boots, and then re-evaluate Falcon against Puma **on the workload that actually motivates it**: many concurrent idle realtime connections |
| **Why that is the same question** | it is [the measurement already owed](#the-open-question-owed-and-unanswered). The reason to want Falcon back *is* the reason thread-per-connection is a concern. Answer one and you have the evidence for the other |
| **What it would cost to move** | a configuration and deployment change, not an app-code change. The server sits behind Rack; a Magik app's screens, actions and jobs do not name it ([`../idea/04-swap-points.md`](../idea/04-swap-points.md)). The realtime transport is the one place that would need real work |

**That last row is why Puma can be committed to without hedging.** The design has one server, one concurrency model, and no Falcon-compatible abstraction held in reserve — because the cost of revisiting is a deployment change, not a rewrite. Building the alternative now to save a cost that low would be paying for insurance more expensive than the risk.

**How it gets noticed rather than discovered.** `bin/check` does not run this probe — it is not a correctness check and it takes seconds of CPU. CI should:

1. Run `scripts/probes/runtime.rb --json` on **every engine in the matrix**, as an advisory step, and print the JSON.
2. Run it against the **newest** TruffleRuby, not a pinned one. `.github/workflows/ci.yml` already uses `truffleruby-head` for exactly this reason, and that is the right choice — keep it.
3. Fail the step, loudly, if `fiber_scheduler.available` or `ractor.works` flips to `true` on a TruffleRuby leg. **A green-to-red on good news is the point**: the reversal must arrive as a build failure with this page's name on it, not as something a maintainer stumbles into two years later.

**The specific mistake worth naming.** The first version of this measurement probed only TruffleRuby 24.2.1, because `.devcontainer/Dockerfile` pins `TRUFFLERUBY_VERSION=24.2.1` — and a pin is where a stale version comes from. That nearly produced a finding open to the strongest available objection: *you tested an old build*. It was caught by testing 34.0.1 as well. **That pin should move**, and the general rule is the one above: probe the newest, not the pinned.

## How honest these numbers are

State this every time the table is cited.

| Limit | |
|---|---|
| **One machine** | 12 cores, x86_64 Linux, and under other load while running (load average 3.5–7.0). That is why the speedup is a range, not a point |
| **One workload** | a CPU-bound SHA256 loop. It says nothing about IO, memory pressure, GC behaviour, or connection handling |
| **One run each, small N** | two or three runs per engine. Enough to separate 0.8× from 2.5×; **not** enough to separate 2.4× from 3.5× |
| **Capability, not throughput** | the results establish *does it parallelise at all* and *does `async` boot at all*. Both are yes/no questions with unambiguous answers here. Neither is a performance number |
| **4 threads on 12 cores** | the ceiling is 4×, and the probe was not run at higher thread counts. Scaling behaviour beyond 4 is unmeasured |
| **Not a production signal** | no request path, no database, no realtime connection was exercised |

The one thing the table establishes without qualification: **on TruffleRuby, `Ractor` does not exist, `Fiber.set_scheduler` does not exist, `async` does not boot, and threads run in parallel.** Those are binary facts, they reproduce, and the speedup range is only evidence for the last of them.

## Related

- [`10-performance-defaults.md`](10-performance-defaults.md) — pool arithmetic and the runtime section, corrected against this page
- [`11-jobs-backend.md`](11-jobs-backend.md) — the worker concurrency model, corrected against this page
- [`04-testing-strategy.md`](04-testing-strategy.md) — the parallel test runner, corrected against this page
- [`../ops/README.md`](../ops/README.md) — the deployment shape, corrected against this page
- `scripts/probes/runtime.rb` — the probe itself
