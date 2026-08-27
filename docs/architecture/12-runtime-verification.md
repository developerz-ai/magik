# Runtime verification

The spec's first two decisions — TruffleRuby, and Rack + Puma thread-per-request — rest on running code rather than on reasoning about the design. This page is that measurement: the method that makes it credible, the results, what follows from them immediately, what is still unknown, and the one upstream change that would reopen the server question.

**Status:** the probes are written and re-runnable; **the framework is still unimplemented**. The results below are the only measured facts in this repository, and their scope is narrow on purpose: they are *capability* results — does the runtime parallelise at all, does the database driver overlap queries at all — not throughput results. Nothing here licenses a performance claim anywhere else. Reviewed 2026-08-26.

**Cite the probe, never a number.** Outside the results tables on this page, no document — including this one — states a ratio. Ratios move run to run with machine load, and a number copied into prose is a number a re-run contradicts. A results table saying what was measured, on what engine, on what date is the honest form; a sentence carrying the same figure a year later is not.

## Why this page exists

[`10-performance-defaults.md`](10-performance-defaults.md) flagged, from upstream documentation alone, that Ruby's usual concurrency folklore does not transfer to this stack, and called for "an experiment, not an argument". This is that experiment.

Two questions had to be settled before a server model could be chosen, and neither is answerable from a README:

1. **Do threads on TruffleRuby actually run in parallel**, or does something serialise them?
2. **Does that parallelism survive the IO path** — specifically, does the `pg` driver hold a runtime lock for the duration of a query?

The second is the load-bearing one. A request spends its life in IO rather than in Ruby, so CPU parallelism behind a serialising driver would be a queue wearing a thread pool. Both are now measured.

A document that only cited upstream prose would be arguing. This one measures, and hands you the commands.

## Method — read this before the numbers

The thread-parallelism question is easy to get wrong, and the first attempt at it here **did** get it wrong: it reported TruffleRuby's parallel run as *slower* than its serial one, and would have concluded that TruffleRuby is worse than CRuby at threading. That result was pure noise. Three things have to be right, and a rebuttal to this page has to engage with all three.

| Requirement | Why | What goes wrong without it |
|---|---|---|
| **The work must be work the compiler cannot delete** | a numeric loop with an unused result is dead code to an optimising compiler, and Graal is an optimising compiler | the loop folds away and you time thread creation. Thread creation is *more* expensive than the phantom work, so the "parallel" run loses and the engine looks slow |
| **The JIT must be warmed before timing** | TruffleRuby is a JIT that starts in an interpreter. A cold native image loses to its own warmed self by a wide margin, and the deployment guide says so ([`deploying.md`](https://github.com/oracle/truffleruby/blob/master/doc/user/deploying.md): peak performance requires "running the application under load for a period of time") | you measure warmup, attribute it to the concurrency model, and conclude the opposite of the truth |
| **Each round must depend on the last** | otherwise the rounds are independent and hoistable, and you are back to problem one | the compiler computes one round and reuses it |

`scripts/probes/runtime.rb` satisfies all three by hashing a rolling buffer: `digest = Digest::SHA256.hexdigest(digest)`, N times, where round *n* cannot start until round *n−1* has produced its input. It runs a tenth-scale pass first, purely to warm the JIT, and discards it. Only then does it time a serial pass and a parallel pass of identical total work.

**What the probe deliberately does not do.** It does not compare engines against each other for speed, it does not measure request throughput, and it does not measure memory. It answers three yes/no questions and reports one ratio as evidence for the first:

1. Do threads actually run in parallel, or are they serialised by a global lock?
2. Is `Fiber.set_scheduler` present?
3. Does `Ractor` exist and work?

Questions 2 and 3 are **capability probes on the runtime**, not proposals. Neither a fiber scheduler nor a Ractor is Magik's concurrency model; they are recorded because their availability is what the [re-verification trigger](#re-verification-trigger) watches, and because a runtime record that only reports what was chosen is a record nobody can audit.

## The probes

```bash
ruby scripts/probes/runtime.rb                                             # whichever engine is on PATH
ruby scripts/probes/runtime.rb --json                                      # machine-readable
MAGIK_PROBE_ROUNDS=500000 MAGIK_PROBE_THREADS=8 ruby scripts/probes/runtime.rb
```

And the IO half, which needs a database:

```bash
DATABASE_URL=postgres://localhost/postgres ruby scripts/probes/pg_concurrency.rb
DATABASE_URL=postgres://localhost/postgres ruby scripts/probes/pg_concurrency.rb --json
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

### `pg` releases the runtime lock — `As of 2026-08-26`

This is the load-bearing half, and it was the largest open question in the design until it was run. TruffleRuby treats native extensions as thread-unsafe by default and serialises them behind a global lock unless they mark themselves safe; a global lock around every query would have erased the parallelism the runtime was chosen for, while leaving the CPU result above true and irrelevant.

The method answers directly rather than by inference: **N threads, one connection each, each issuing `SELECT pg_sleep(S)`.** The database does the waiting, so the wall clock is the answer — about `S` means the queries overlapped, about `N × S` means they did not. Sharing one connection would serialise for a reason that has nothing to do with the runtime lock, so each thread gets its own.

| | Result |
|---|---|
| Probe | [`../../scripts/probes/pg_concurrency.rb`](../../scripts/probes/pg_concurrency.rb) |
| Setup | eight threads, eight connections, `pg_sleep(1.0)` each — serial would be eight seconds |
| Every engine tested | the queries **overlap**: the eight finish in about one second, not eight |
| Verdict | **`pg` releases the runtime lock while a query is in flight.** Concurrent queries overlap instead of serialising |

Two limits on the claim, stated with it: it was run on the engines and `pg` version recorded by `--json`, and a `pg` or TruffleRuby release can change it — which is why the probe is the artifact and this table is dated. A driver that serialised would not be a tuning problem; it would be a different framework.

### The `async` failure, verbatim

```
$ mise exec ruby@truffleruby-24.2.1 -- ruby -e 'require "async"; Async { puts "booted" }'
.../async-2.45.0/lib/kernel/async.rb:28:in `Async': undefined method `scheduler' for class Fiber (NoMethodError)
```

The gem installs cleanly. It fails on the **first `Async{}` block**, at the point where it asks `Fiber` for a scheduler. This is the distinction that matters: `async` does not fail to be fast on TruffleRuby, it fails to boot.

### The version confound, stated as a confound

24.2.1 measured faster than 34.0.1 here. **Do not read that as "the newer TruffleRuby is slower."** The two runs differ in build mode as well as version — 24.2.1 is the Native image, 34.0.1 is the JVM build — and the probe's workload is short. JVM mode is documented to reach a higher peak and to need far more warmup to get there ([README](https://github.com/oracle/truffleruby/blob/master/README.md): Native starts "about as fast as MRI startup" with "good" peak; JVM starts "slower", warms "slower", "best" peak). A short workload is exactly the shape that flatters Native and penalises JVM.

Two different build modes, one short workload: that is a **confound, not a result**. The Native-versus-JVM trade-off is on the owed list below.

## What the results settle

**The decision recorded here, in three rows.**

| | |
|---|---|
| Runtime | **TruffleRuby**, verified on 24.2.1 and on 34.0.1. CRuby ≥ 3.2 is supported for development tooling — `magik check`, `magik generate`, the local test loop — and is **not a production target**: the probe shows no thread parallelism there at all, which is the global lock, and a CRuby production deploy would be a different framework wearing the same name |
| Concurrency | **real parallel OS threads.** One mechanism, everywhere — one request, one thread; one job, one worker thread; one test file group, one worker thread. There is no second concurrency model in this framework, and neither the fiber scheduler nor `Ractor` is one |
| Server | **Puma + Rack, thread-per-request**, in **single mode** — there is no `fork` ([below](#fork-is-unavailable-on-truffleruby)) |

The two probe results are what make that coherent rather than merely chosen. Genuine thread parallelism is what makes thread-per-request the correct server model; `pg` releasing the runtime lock is what makes it survive contact with a request that spends its life in IO. Either result reversed would take the server model with it.

There is no second path, no per-engine branch and no fallback mode. Nothing is implemented yet, so there is no installed base to be compatible with and no reason to design two systems. The [re-verification trigger](#re-verification-trigger) records what would change this decision; it does not pre-build the alternative.

### What the capability probes do *not* propose

Two rows of the results table report absent runtime features. Recording them is not the same as wanting them, and neither is a mechanism Magik uses or plans to use:

| Absent | What follows |
|---|---|
| `Fiber.set_scheduler` / `Fiber.scheduler`, so `async` raises on its first block | a fiber-scheduler server cannot boot on the production runtime. That is a fact about the engine, not a preference; the one condition that would reopen the question is stated [below](#the-one-condition-that-would-reopen-the-server-decision) and nowhere else |
| `Ractor` | **Ractors are not Magik's concurrency model, here or anywhere.** Threads already run in parallel on this runtime and are, by TruffleRuby's own assessment, far more compatible with gems. The row exists so the trigger has something to watch |

TruffleRuby's compatibility document points at [`ractor-shim`](https://github.com/eregon/ractor-shim) for code that already depends on `Ractor`. It is the right tool for porting code you did not write, and the wrong one for a framework choosing its concurrency model from scratch: it would have Magik implement a Ractor-shaped API — with Ractor's isolation and shareability constraints — on top of threads that already run in parallel and have none of them. Threads directly, not Ractors emulated by threads.

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

CRuby is the fast-boot engine for development tooling — `magik check`, `magik generate`, the local test loop — and it is **not a production target**. Its column in the results table is why: threads there show no CPU parallelism at all, so the concurrency model this framework is built on does not exist. The split was already the stated policy ([`10-performance-defaults.md`](10-performance-defaults.md) §7.1); the probe turns it from a preference into a measurement.

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

**And with no `fork`, there is no second process on the box to spread them over** — the usual Ruby answer to "one process holds too few connections" is unavailable here, so whatever one process holds is what one container holds.

Until that runs, the realtime connection ceiling on TruffleRuby is **unknown**, and no page in this repo may imply otherwise. Decision 5 — realtime is opt-in per screen — is carrying more weight than it was designed to carry until it does.

## Owed measurements, in one list

| Owed | Why it is not answered here | Blocks |
|---|---|---|
| Idle connection density per Puma process on TruffleRuby | above; a CPU probe cannot answer an idle-connection question | the realtime deployment story, `ops/README.md` sizing |
| **Native vs JVM build mode**: boot time versus peak throughput, and which suits `magik server`, `magik worker`, and a one-second CLI command | the two probe runs differ in mode *and* version — a confound. Needs one version, both modes, a long workload | a genuine deployment decision `ops/README.md` will have to make |
| Puma throughput and concurrency on TruffleRuby under real load | the boot test proves it starts, nothing more | pool arithmetic in [`10-performance-defaults.md`](10-performance-defaults.md) §2.1 |
| Thread-parallel test-runner speedup on a real suite | there is no suite | [`04-testing-strategy.md`](04-testing-strategy.md)'s runner-backend choice |

## Re-verification trigger

This finding is about what upstream has **not yet implemented**, and that class of finding goes stale silently — the day it stops being true, nothing announces it here.

**Reverse this page if any of these lands:**

| Upstream change | What it reverses |
|---|---|
| **TruffleRuby implements `Fiber::Scheduler` / `Fiber.set_scheduler`** | the server decision — see [below](#the-one-condition-that-would-reopen-the-server-decision) |
| TruffleRuby's fibers stop being OS threads (the Loom work its docs point at) | the idle-connection ceiling changes shape even without a scheduler |
| `Ractor` lands on TruffleRuby | nothing automatically. Threads already parallelise here and are more compatible with gems, by TruffleRuby's own assessment, so a Ractor implementation changes what is *available* and not what Magik uses. Worth one comparison run, not a redesign |
| `fork` becomes available in the native configuration | Puma clustered mode and process-based workers become possible. Re-open the sizing question, not the concurrency model |
| `pg` stops releasing the runtime lock, on any supported engine | the threading argument for database work, and with it the server model. Re-run [`../../scripts/probes/pg_concurrency.rb`](../../scripts/probes/pg_concurrency.rb) after a `pg` or TruffleRuby major |

### The one condition that would reopen the server decision

Stated precisely, because "this may change someday" is not a trigger and nobody acts on it. **This is the only place in the repository that names an alternative server, and it names one deliberately:**

| | |
|---|---|
| **The trigger** | TruffleRuby implements `Fiber::Scheduler` / `Fiber.set_scheduler`. That single upstream change, and nothing else. Not a TruffleRuby release in general, not a benchmark someone publishes |
| **Why it is the trigger** | a fiber-per-connection server — Falcon is the mature one — is genuinely better than a thread pool for many mostly-idle connections, which is exactly Magik's realtime workload. It cannot boot here today: the scheduler is absent and `async` raises on its first block. The disqualification is an engine incompatibility and nothing else |
| **How we notice** | the probe runs in CI against the newest TruffleRuby. `fiber_scheduler.available` flips from `false` to `true` and the step goes red. **That is the mechanism** — a changed probe result, not somebody happening to read a changelog |
| **What we do then** | re-run `scripts/probes/runtime.rb` on every engine, confirm `async` boots, and then re-evaluate the alternative against Puma **on the workload that actually motivates it**: many concurrent idle realtime connections |
| **Why that is the same question** | it is [the measurement already owed](#the-open-question-owed-and-unanswered). The reason to want a fiber server *is* the reason thread-per-connection is a concern. Answer one and you have the evidence for the other |
| **What it would cost to move** | a configuration and deployment change, not an app-code change. The server sits behind Rack; a Magik app's screens, actions and jobs do not name it ([`../idea/04-swap-points.md`](../idea/04-swap-points.md)). The realtime transport is the one place that would need real work |

**That last row is why Puma can be committed to without hedging.** The design has one server, one concurrency model, and no alternative-server abstraction held in reserve — because the cost of revisiting is a deployment change, not a rewrite. Building the alternative now to save a cost that low would be paying for insurance more expensive than the risk.

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
| **Two workloads, both narrow** | a CPU-bound SHA256 loop, and eight sleeping queries. Together they say *Ruby parallelises* and *queries overlap*; they say nothing about memory pressure, GC behaviour, or connection handling |
| **One run each, small N** | two or three runs per engine. Enough to separate "no parallelism" from "several times faster"; **not** enough to separate one TruffleRuby build's ratio from another's |
| **Capability, not throughput** | the results establish *does it parallelise at all*, *does the driver overlap at all*, *does `async` boot at all*. All are yes/no questions with unambiguous answers here. None is a performance number |
| **4 threads on 12 cores** | the CPU probe was not run at higher thread counts. Scaling behaviour beyond 4 is unmeasured |
| **`pg_sleep`, not real queries** | the database does the waiting, which is what isolates the runtime lock — and which means no planner, no result-set marshalling and no row transfer was exercised |
| **Not a production signal** | no request path, no realtime connection and no application query was exercised |

The one thing the tables establish without qualification: **on TruffleRuby, `Fiber.set_scheduler` does not exist, `async` does not boot, `Ractor` does not exist, `fork` does not exist, threads run in parallel, and `pg` lets concurrent queries overlap.** Those are binary facts and they reproduce; the speedup range is only evidence for the fifth of them, and it is the only figure on this page that is a range rather than an answer.

## Related

- [`10-performance-defaults.md`](10-performance-defaults.md) — pool arithmetic and the runtime section, corrected against this page
- [`11-jobs-backend.md`](11-jobs-backend.md) — the worker concurrency model, corrected against this page
- [`04-testing-strategy.md`](04-testing-strategy.md) — the parallel test runner, corrected against this page
- [`../ops/README.md`](../ops/README.md) — the deployment shape, corrected against this page
- [`../../scripts/probes/runtime.rb`](../../scripts/probes/runtime.rb) — the CPU-parallelism and capability probe
- [`../../scripts/probes/pg_concurrency.rb`](../../scripts/probes/pg_concurrency.rb) — the IO-path probe, and the load-bearing half
