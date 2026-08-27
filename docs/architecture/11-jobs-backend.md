# The jobs backend

Which Postgres queue Magik wraps, by what locking mechanism, and where that mechanism stops being the right answer.

**Status:** planned. Nothing here is implemented — `lib/magik/jobs/` does not exist, no backend is written, no benchmark has been run on Magik code, and every number on this page is quoted from an upstream source with attribution. Reviewed 2026-08-26.

## What is already decided

The queue is Postgres-backed, transactional, Que-style. That is the spec ([`../idea/00-build-spec.md`](../idea/00-build-spec.md), Phase 4) and the seam table ([`../idea/04-swap-points.md`](../idea/04-swap-points.md)), and the argument for it — *an external queue cannot join your transaction* — is made in full in [`../../wiki/Jobs.md`](../../wiki/Jobs.md). It is not re-argued here.

This page answers the three questions that decision leaves open:

| Question | Section |
|---|---|
| Which gem, given Sequel and no Rails? | [Wrap what](#wrap-what) |
| Advisory locks or `SKIP LOCKED`, and what does each cost? | [The mechanism](#the-mechanism) |
| Where does a Postgres queue stop working, and what replaces it? | [The ceiling](#the-ceiling) |

## The constraints that do the eliminating

Four facts about Magik decide most of the comparison before quality enters it.

| Constraint | Source | Consequence |
|---|---|---|
| **Sequel, not ActiveRecord** | spec item 3 | a backend whose storage layer *is* ActiveRecord is not adaptable; it is a second ORM in the process |
| **Not a Rails app** | the whole spec | a gem with a runtime dependency on `railties` drags a framework in to run a queue |
| **TruffleRuby in production** | spec item 1 | anything with a threading or forking model tuned to MRI needs verifying, not assuming |
| **Threads, genuinely parallel** | measured — [`12-runtime-verification.md`](12-runtime-verification.md) | the worker runs a bounded thread pool. Concurrency is a declared thread count, and the OS preempts a CPU-bound job rather than letting it stall its peers |
| **`fork` is unavailable on TruffleRuby** | measured — same page | any backend whose scaling story is "fork a worker per core" has no scaling story here. More workers means more containers |

The first two are not preferences. `activerecord` and `railties` are declared runtime dependencies or they are not, and that is checkable rather than arguable.

## Wrap what

### The four candidates, as of 2026-08-26

Re-derive any row with:

```bash
curl -s https://rubygems.org/api/v1/gems/good_job.json |
  ruby -rjson -e 'd=JSON.parse($stdin.read)
    puts "#{d["version"]}  #{d["version_created_at"]}"
    puts d["dependencies"]["runtime"].map { |x| "#{x["name"]} #{x["requirements"]}" }'
```

| Gem | Latest | Released | Runtime dependencies | Rails-bound? |
|---|---|---|---|---|
| **que** | 2.4.1 | 2024-10-28 | **none** | no — "Rails 6.0+ (optional)" |
| **good_job** | 4.19.2 | 2026-07-20 | `activejob`, `activerecord`, `railties`, `concurrent-ruby`, `fugit`, `thor` | **yes** |
| **solid_queue** | 1.7.0 | 2026-08-21 | `activejob`, `activerecord`, `railties`, `concurrent-ruby`, `fugit`, `thor` | **yes** |
| **wurk** | 1.7.3 | 2026-08-18 | `redis-client`, `connection_pool`, `rack`, … | no — but Redis, not Postgres |

Sources: rubygems.org API, queried 2026-08-26.

### GoodJob — disqualified, and not on quality

GoodJob is the strongest Postgres queue in the Ruby ecosystem by feature depth: cron, batches, a mounted dashboard, concurrency controls, and three selectable locking modes (advisory by default, `SELECT FOR UPDATE SKIP LOCKED`, or both). Its README states it targets "applications that enqueue 1-million jobs/day and more" and that it uses "`LISTEN`/`NOTIFY` to reduce queuing latency."

It is also, in its own first sentence, "a multithreaded, Postgres-based, **Active Job** backend for **Ruby on Rails**." `activerecord` and `railties` are hard runtime dependencies. Its storage layer is `ActiveRecord::Base` subclasses; its dashboard is a `Rails::Engine`; its execution modes (`:async`, `:async_all`) are defined relative to a Rails web process.

Using it would mean loading ActiveRecord into a Sequel application to run the queue — two connection pools, two transaction abstractions, and a job row that cannot participate in a `Sequel` transaction without a shared-connection hack. **The transactional guarantee is exactly what would break.** Disqualified.

### Solid Queue — disqualified, same reason

`activejob`, `activerecord`, `railties` >= 7.1. Its own README: "The minimum supported version of Rails is 7.1." Same analysis, same outcome.

Two of its design choices are worth stealing regardless, and are picked up below: claiming via `FOR UPDATE SKIP LOCKED` into a separate `ready_executions` table rather than a status column on the job row, and a worker whose concurrency is a declared number rather than an implicit one.

### Que — the only candidate that fits, with real problems

**What is right about it.** Zero runtime gem dependencies. First-class Sequel support that is not an afterthought — the docs have a dedicated section:

> If you're using Sequel, with or without Rails, you'll need to give Que a specific database instance to use:
> ```ruby
> DB = Sequel.connect(ENV['DATABASE_URL'])
> Que.connection = DB
> ```
> — [Que docs](https://github.com/que-rb/que/blob/master/docs/README.md)

It also ships `Que::Sequel::Model` for inspecting the queue, supports raw `PG` connections through `connection_pool` or `pond`, and exposes `Que.connection_proc` for any pool at all. It already does the two things this design wants: advisory-lock claiming, and `LISTEN`/`NOTIFY` wakeup rather than pure polling.

**What is wrong about it.**

| Problem | Detail |
|---|---|
| **No release in ~22 months** | v2.4.1 shipped 2024-10-28. The most recent commit on `master` is 2026-01-01, and it is a CI fix. The repo is not archived (2,322 stars, 59 open issues, checked 2026-08-26) — it is *quiescent*, which is a different risk from abandoned but is not zero |
| **MRI is the stated platform** | the README's compatibility list is "MRI Ruby 2.7+". TruffleRuby is neither supported nor refused; it is untested. Mitigated by Que being pure Ruby with no dependencies — the only native code beneath it is `pg`, which Magik carries anyway |
| **The ecosystem is a version behind** | Que's README lists `que-scheduler` (cron), `que-locks` and `que-unique` (uniqueness) and `que-web` (dashboard) under "These projects are tested to be compatible with Que **1.x**". Magik's `job` DSL promises `schedule cron:`, `unique_while_running` and `magik jobs status` — every one of which is a satellite gem pinned to the previous major |
| **The worker is not the worker Magik needs** | Que runs a thread pool plus a dedicated locking thread — which is now the *right* shape and the wrong implementation, since it is tuned around MRI's GVL. Magik needs `magik worker` with its own thread-pool concurrency, Magik's own retry/backoff DSL, Magik's stable log field set ([`06-observability.md`](06-observability.md)) and Magik's error codes. None of that is Que's |

Add those up and the honest size of the wrap becomes visible: **Que supplies the table, the migrations, and the claim query. Magik writes everything above them anyway.**

### Rolling our own — taken seriously

The case for is real and the spec half-makes it: Sequel and Postgres are already committed, `SELECT … FOR UPDATE SKIP LOCKED` has been in Postgres since 9.5, and the claim loop is genuinely short.

The case against is not "it is hard." It is that the short part is not the whole part:

| Looks like a few hundred lines | Is not |
|---|---|
| the claim query | Que's poller is a recursive CTE over `(priority, run_at, id)` with a `pg_temp` helper function, written that way because the naive `SELECT … LIMIT 5` **locks jobs it then discards**. That subtlety is a bug you find in production, not in review |
| shutdown | see [Long-running jobs](#long-running-jobs): the safe shutdown for a queue worker is counter-intuitive, and getting it wrong risks partially-committed transactions |
| schema versioning | `Que.migrate!(version: 7)` — seven schema revisions of accumulated learning, each one a migration someone had to write and test against live queues |
| expiry, retries, dead-lettering, bulk enqueue, notify suppression | each is a paragraph in Que's docs and a week of nobody's time |

Against that, the spec's own rule: *wrap something good rather than reinvent it.* But the rule and the reality pull in opposite directions here, because Que does not cover the surface Magik promises. So the answer is not either default.

### Recommendation

> **Wrap Que for storage and claiming. Own the scheduler, uniqueness, retries, the worker loop and observability. Draw the line explicitly and put it in the code.**

Concretely, in `lib/magik/jobs/backends/postgres.rb` ([`01-module-map.md`](01-module-map.md)):

| Layer | Owner | Why |
|---|---|---|
| job table + migrations | **Que** | seven revisions of hard-won schema; no reason to re-derive |
| enqueue on the caller's Sequel connection | **Que** (`Que.connection = DB`) | this is the transactional guarantee, and Que already does it correctly |
| claim / lock / unlock query | **Que** | the recursive CTE is the subtle part |
| `LISTEN`/`NOTIFY` wakeup | **Que** for jobs, Magik's `realtime` transport for everything else — see [One mechanism, two subsystems](#one-mechanism-two-subsystems) | already built, already correct |
| worker loop, thread-pool concurrency, drain, signals | **Magik** | Que's thread pool is close in shape but is sized and reasoned about for MRI's GVL; the drain, signal and shutdown-timeout behaviour is Magik's anyway |
| `retries`, `backoff:`, `discard_on`, `timeout:`, `on_failure` | **Magik** | this is DSL surface; it cannot be delegated |
| `schedule cron:` / `every:` | **Magik** | Que has none; the satellite gem is pinned to 1.x |
| `unique_while_running`, enqueue-time dedup | **Magik** | same |
| logs, traces, `magik jobs status` | **Magik** | the field set in [`06-observability.md`](06-observability.md) is non-negotiable |

This is a **thin wrap of the part that is genuinely hard, and a full implementation of the part that is genuinely ours.** It is not a compromise between the two options; it is what an honest reading of both produces.

### What would change it

Each of these is checkable before Phase 4 starts, and each has a defined consequence. This is the pre-condition list for the phase, not a set of vague worries.

| If the spike finds… | Then |
|---|---|
| Que's `Que::Job` contract cannot be driven from Magik's `job` DSL without monkey-patching internals | **own it.** A monkey-patched dependency is worse than a written one — it breaks silently on upgrade and cannot be reasoned about from the source |
| Que does not run on TruffleRuby | **own it**, reusing Que's schema and claim SQL under Magik's copyright and attribution. The mechanism is public knowledge; the gem is the optional part |
| a Postgres 18+ incompatibility appears in Que and no release follows within one phase | **own it.** Quiescent is survivable; unmaintained-and-broken is not |
| Que ships a 3.x with a maintained scheduler and uniqueness in-gem | **widen the wrap.** Delete Magik's scheduler and use theirs |
| GoodJob or Solid Queue extracts a Rails-free storage core | **re-open the comparison entirely.** Both are better-maintained than Que and the only thing keeping them out is the dependency edge |

The last row is worth watching. Nothing about GoodJob's *design* is wrong for Magik. The whole disqualification is a `gemspec` line.

## The mechanism

### Advisory locks vs `FOR UPDATE SKIP LOCKED`

Both solve "two workers must not claim the same job." They fail differently, and the failure is the decision.

| | Advisory lock (`pg_try_advisory_lock`) | `SELECT … FOR UPDATE SKIP LOCKED` |
|---|---|---|
| **What claiming writes** | nothing. Postgres's lock table only | an `UPDATE` on the job row (`locked_at`, `locked_by`) |
| **Cost per claim** | one shared-memory lock entry | one dead tuple + WAL, on every claim *and* every release |
| **Contention** | readers do not block readers. Que: "Workers don't block each other when trying to lock jobs, as often occurs with 'SELECT FOR UPDATE'-style locking" | non-blocking by construction (that is what `SKIP LOCKED` means), but the claim `UPDATE` serialises on the row and multiplies row versions |
| **Ceiling** | the shared lock table. Postgres docs: sized by `max_locks_per_transaction` and `max_connections`, and "This imposes an upper limit on the number of advisory locks grantable by the server, typically in the tens to hundreds of thousands" | no lock-table ceiling. The ceiling is vacuum |
| **Works behind PgBouncer transaction pooling** | **no.** A session lock and a transaction-pooled connection are incompatible by definition | **yes** |
| **Visible to `magik jobs status`** | only via `pg_locks` — a join, not a column | directly, as a column on the row |
| **Worker dies** | see below | see below |

### What happens to a locked job when a worker dies

This is the whole argument.

**Advisory lock.** The lock is session-scoped. Postgres: *"Once acquired at session level, an advisory lock is held until explicitly released or the session ends."* The worker's session ending *is* the release. Que's README states the operational consequence:

> If a Ruby process dies, the jobs it's working won't be lost, or left in a locked or ambiguous state — they immediately become available for any other worker to pick up.

Recovery is free, requires no reaper, no lease, no heartbeat, and no configuration. The honest caveat: **"immediately" means "when Postgres notices the session is gone."** A `SIGKILL`, a segfault or a container stop closes the socket and the backend exits at once. A network partition or a frozen host leaves the backend alive until TCP keepalives expire, so the true bound is `tcp_keepalives_idle + tcp_keepalives_interval × tcp_keepalives_count`, not zero. That must be tuned deliberately on the worker's connection, and `magik doctor` should report it rather than leave it at the OS default.

**`SKIP LOCKED`.** The row lock lives for the claiming transaction only, which is milliseconds — far shorter than the job. So the claim has to be *materialised* into a column, and now the column is the source of truth and nothing releases it. A dead worker leaves `locked_at = <forever ago>` and the job never runs again. The fix is a lease plus a reaper:

```sql
UPDATE magik_jobs SET locked_at = NULL, locked_by = NULL
 WHERE locked_at < now() - $lease;
```

And the lease has to exceed the longest job, or the reaper hands a still-running job to a second worker. So the lease is bounded below by your slowest job, and **crash recovery latency equals that lease.** A 40-minute job means a 40-minute lease means a crashed worker's job is stuck for 40 minutes. Adding heartbeats shortens it, at the cost of a write per worker per interval on the same high-churn table.

### The choice

> **Advisory locks for claiming.** Free crash recovery, no write to claim, and no lease to tune wrong.

The two costs are accepted explicitly:

1. **No transaction pooling for worker connections.** Workers connect directly, or through a session-pooling proxy. Que already anticipates this — its `connection-url` option exists "if your application connections can't use advisory locks — for example, if they're passed through an external connection pool like PgBouncer." Que's poller also installs `pg_temp` helper functions per connection, which transaction pooling breaks independently. This becomes a boot check, not a runbook footnote: a worker that cannot take an advisory lock must fail loudly at boot ([`../idea/03-guardrails.md`](../idea/03-guardrails.md)).
2. **A lock-table budget.** One entry per in-flight job. At Postgres's default `max_locks_per_transaction = 64` the pool is large but finite, and Magik's total in-flight job count across all workers is bounded by it. Worth surfacing in `magik doctor` next to the connection count.

A `locked_at`-style column may still be written **as an observability breadcrumb** so `magik jobs status` does not have to join `pg_locks` — but it is never the source of truth, and no reaper reads it. Two sources of truth for "is this job claimed" is the bug that mode is designed to avoid.

This is not an exclusive choice in principle: GoodJob ships all three modes (advisory, `:skiplocked`, and a hybrid that does both), which is evidence a hybrid works. It is one seam too many for a first implementation.

### One mechanism, two subsystems

Polling costs latency or costs queries, and there is no setting that avoids both. `LISTEN`/`NOTIFY` avoids both: the enqueue emits a notification and an idle worker wakes on it.

Que already does this — from its docs on `poll-interval`:

> Jobs that are ready to be worked immediately will be broadcast via the `LISTEN`/`NOTIFY` system, so polling is unnecessary for them — polling is only necessary for jobs that are scheduled in the future or which are being delayed due to errors. The default is 5 seconds.

Polling does not go away. It is the backstop for `run_at` in the future, for retries, and for a notification lost while a worker was restarting. It goes from being the primary path to being the safety net, which is the correct role for it.

**The architectural saving.** The spec's default realtime backend is Postgres `LISTEN`/`NOTIFY` ([`../idea/04-swap-points.md`](../idea/04-swap-points.md), and [`../../wiki/Realtime.md`](../../wiki/Realtime.md)). The job queue's wakeup is the same mechanism. So:

| | |
|---|---|
| **One mechanism** | `LISTEN`/`NOTIFY` serves both `broadcast "channel", :event, payload` and "a job is ready" |
| **One dependency** | Postgres. No Redis for realtime, no Redis for the queue, no second failure mode to learn |
| **One set of limits** | the 8000-byte payload cap, the "delivered only to currently-connected listeners" semantics, and the connection-per-listener cost are learned once and apply to both |
| **One operational signal** | `LISTEN` connection count against Postgres is already on the watch list in [`../ops/README.md`](../ops/README.md); the queue adds to the same number rather than a new one |

The subsystems stay separate — `realtime` is tier 2 and owns its transport, `jobs` is tier 2 and does not require it ([`01-module-map.md`](01-module-map.md)). They share a Postgres feature, not code. That is the correct amount of sharing: a `jobs` that required `realtime` would be a sideways dependency, and a `realtime` that the queue depended on would make an opt-in subsystem mandatory.

Two costs, stated:

| Cost | Detail |
|---|---|
| A dedicated connection per listening process | a `LISTEN` connection is in a session state and cannot be handed back to a pool. Every worker and every app process listening for realtime holds one. This is the thing that scales with process count and hits Postgres's `max_connections` first |
| Bulk enqueue defeats it | Que's docs: enqueueing many jobs individually "and running the notify trigger for each ... can become a performance bottleneck." `Que.bulk_enqueue` inserts in one query and by default **does not fire the trigger**, so those jobs wait for the next poll. A bulk enqueue is a latency decision, and Magik's DSL must make that visible rather than surprising |

## Threads in the worker

`magik worker` runs a bounded **thread pool**: one job, one worker thread. On TruffleRuby those threads are genuinely parallel — 2.55–3.54× on 4 threads, measured ([`12-runtime-verification.md`](12-runtime-verification.md)) — so a worker process uses the cores it is given. Three consequences, in ascending order of how much trouble they cause.

### The connection pool is thread-keyed — which is Sequel's default

Sequel's concurrency primitive is `Thread.current`. One job, one worker thread, one `Thread.current` — so the default keying is the correct keying and each in-flight job gets its own connection. That is what satisfies the `pg` constraint: *"it is not safe to access any PG object simultaneously from more than one thread or fiber unless the object is frozen."* Nothing has to be configured to make it true.

**What must not happen is `Sequel.current` being changed underneath the worker.** Sequel ships extensions that re-key checkout on a different primitive; loading one turns a correct pool into two jobs sharing a connection, and the failure mode is corrupted results rather than an exception. So the boot check is an assertion, not a configuration: **`Sequel.current` resolves to a `Thread`**, verified at worker boot, failing loudly if it does not ([`../idea/03-guardrails.md`](../idea/03-guardrails.md)).

**Pool size and concurrency are one number, not two.** `magik worker --concurrency 20` needs a pool of 20; anything smaller means threads blocking on checkout and then raising `Sequel::PoolTimeout`, anything larger is connections charged against the server's `max_connections` that no thread can use. `magik doctor` reports the pair and says so when they disagree, because the misconfiguration is silent — it looks like slowness, not like an error.

One detail worth copying from Que: the advisory locks for **all** in-flight jobs are held on a single dedicated locking connection, while the jobs themselves run on pool connections. That is what stops advisory-lock claiming from pinning one connection per in-flight job. It also means the locking connection dying releases every lock at once — which is the desired behaviour, and is why it must be the *worker's* connection and not one borrowed from the app pool.

### A job that blocks on IO — the common case

Most background work is IO-bound: an HTTP call, an S3 upload, a slow query. A worker thread waiting on a socket costs a thread and nothing else — **no GVL, so it blocks nobody**, and the other in-flight jobs keep running in parallel.

The number that governs this is `--concurrency`, and it is a real ceiling rather than a limit nobody hits: each in-flight job is an OS thread with an OS thread's stack. A worker holding a hundred slow HTTP calls is holding a hundred threads. **How many one process actually sustains is unmeasured**, is on the owed list in [What is not decided](#what-is-not-decided), and no number appears here.

What the model does *not* require is the property that would have been hardest to guarantee: **a blocking call inside a C extension blocks its own thread and nobody else's.** There is no reactor to stall, so there is no per-gem audit of whether every dependency yields correctly. That is one fewer ongoing obligation on the framework and on every gem it touches.

`pg` is the right driver for the usual reason and one specific one: "Add support for TruffleRuby. It is regularly tested as part of our CI" ([`ruby-pg` README](https://github.com/ged/ruby-pg)).

One open question sits upstream of all of it and is in [What is not decided](#what-is-not-decided): TruffleRuby treats native extensions as thread-unsafe by default and serialises them behind a global lock unless they mark themselves safe. **If `pg` does not get that lock lifted, the worker's threads serialise on every query.** It is unmeasured, and it belongs in [`../idea/05-limits.md`](../idea/05-limits.md) until it is not.

### A job that blocks on CPU — the expensive case

Worker threads are OS threads and the OS scheduler preempts them. A job spinning in Ruby — a large PDF render, an image transform, a report aggregating a million rows in memory — **does not stall the process.** The other in-flight jobs, the `LISTEN` loop and the shutdown handler keep running, and on TruffleRuby they keep running *in parallel* rather than merely taking turns.

| | A CPU-bound job does this to its peers |
|---|---|
| Threads on MRI | starves them. The GVL forces a switch, so they progress slowly |
| Threads on TruffleRuby (**the model**) | costs them **one core**. No GVL, genuine parallelism — the remaining threads run at full speed on the remaining cores |

So the cost of a CPU-bound job is capacity, not availability: it occupies a core for its duration, and a queue of them occupies the box.

**`timeout:` is honourable here.** `Timeout` raises into the target from a timer thread; the timer thread runs, and it interrupts a spinning Ruby loop. `retries timeout: 30.seconds` on a CPU-bound job is a promise the runtime can keep.

Two limits survive, and they are narrow:

| Limit | |
|---|---|
| A blocking call inside a C extension is still not interruptible | the exception is raised at the next Ruby-level check point, and a native call that never returns has none. This is the ordinary Ruby `Timeout` caveat, true on every engine, and it is a documentation obligation rather than a DSL refusal |
| `Timeout` interrupts at an arbitrary point | the job is left wherever it was. This is an argument for `idempotent_by` and for doing writes in a short final transaction ([Long-running jobs](#long-running-jobs)), not an argument against the flag |

Two design outputs follow, and each is a rule rather than advice:

| Consequence | |
|---|---|
| **CPU-bound work gets its own queue and its own workers** | `queue :heavy`, served by workers at low concurrency on their own machine shape. This is why `queue` exists in the DSL and is not decoration |
| **`magik check --scale` flags the shape** | a `perform` block with no IO call and an unbounded loop over a collection is a heuristic, not a proof — so a warning, per the rule in [`../idea/03-guardrails.md`](../idea/03-guardrails.md) that a guardrail with legitimate counter-examples warns rather than refuses |

The honest summary for [`10-performance-defaults.md`](10-performance-defaults.md): **a job costs a thread for its duration, whatever it is doing.** IO-bound jobs are cheap in CPU and not free in threads; CPU-bound jobs cost a core. The per-process ceiling that follows is unmeasured and must not be sold as anything else.

## Job table design

### Indexing and the claim path

The claim query is the only query that matters, and it is run constantly. Que's index is `(priority, run_at, id)` and its predicate is `queue = $1 AND run_at <= now() AND finished_at IS NULL AND expired_at IS NULL`.

| Rule | Reason |
|---|---|
| **Partial index** on `WHERE finished_at IS NULL AND expired_at IS NULL` | the hot index stays proportional to *pending* jobs, not to the table. If finished rows linger for retention, they must not be in the index the claim walks |
| **Index order is the claim order** | `(priority, run_at, id)` lets the poller walk the table in a stable order and stop as soon as it has enough. Any other index is a sort |
| **`fillfactor` below 100** on the job table | leaves room on the page for heap-only-tuple updates, so a claim-marking `UPDATE` does not have to touch every index. Relevant even with advisory locking, because state transitions still write |
| **One index per query shape, no more** | Richard Yen, [*Potential Consequences of Using Postgres as a Job Queue*](https://richyen.com/postgres/2026/05/04/postgres_job_queue.html), 2026-05-04: *"Every index on the table also accumulates dead entries. The partial index on `status = 'pending'` gets thrashed especially hard."* On a high-churn table an index is a recurring cost, not a one-time one |

### There is no ordering guarantee

`(priority, run_at, id)` is the order jobs are *claimed in*, best-effort. It is not the order they finish in, and with N workers it cannot be. Two jobs enqueued in the same transaction may complete in either order, and a retry reorders a job arbitrarily far into the future.

**Stated as a rule:** *Magik guarantees no ordering between two jobs.* If B must follow A, that is one job that does both, or A enqueues B on completion. This is the same shape of honesty as the at-least-once statement already in [`../../wiki/Jobs.md`](../../wiki/Jobs.md), and the two failures compound: an at-least-once queue with no ordering guarantee means a handler must be correct when run twice *and* when run out of order.

### Priorities and queues

| | |
|---|---|
| **Priority** | an integer, lower is more urgent, on the leading edge of the claim index. Que uses the Linux scale and defaults to 100, leaving room in both directions |
| **Queue** | a text column in the claim predicate. Queues exist for **isolation**, not for priority — a slow queue must not starve a fast one, and CPU-bound work needs its own workers ([above](#a-job-that-blocks-on-cpu--the-trap)) |
| **The cost of many queues** | Que's README, on working several at once: *"less efficient because it requires polling all of them."* A queue per job class is an anti-pattern that turns one indexed poll into N |

### Scheduled and cron jobs

Two different things, and only the second is hard.

| | Mechanism |
|---|---|
| **Deferred** (`run_at` in the future, retry backoff) | a column. Already handled by the claim predicate. Not fired by `NOTIFY`, so it costs one poll interval of latency — Que documents this exactly, warning against setting `run_at` from `Time.now` for a job meant to run immediately |
| **Recurring** (`schedule cron:`, `schedule every:`) | must fire **once per tick across M workers**, which is a distributed-agreement problem hiding in a decorator |

For recurring, the recommendation is an atomic row claim rather than leader election:

```sql
UPDATE magik_job_schedules
   SET next_run_at = $next, last_run_at = now()
 WHERE name = $1 AND next_run_at <= now()
RETURNING id;
```

Every worker runs this on a timer; exactly one gets a row back and enqueues the job; the rest get nothing and move on. No leader, no lease, no election to go wrong on a restart, and the enqueue can join the same transaction as the claim so a crash between them is impossible. A missed tick — because every worker was down — is visible as a stale `last_run_at`, which is the right thing for `magik jobs status` to show.

`zone:` is required on a `cron:` schedule and its absence fails at boot ([`../../wiki/Jobs.md`](../../wiki/Jobs.md)). The `next_run_at` computation is the reason: a cron expression evaluated without a zone silently produces a different UTC instant twice a year.

### Uniqueness, deduplication, and idempotency

Three distinct guarantees. Conflating them is the bug, because they cover three non-overlapping windows.

| Guarantee | Window it covers | Mechanism | Fails to cover |
|---|---|---|---|
| **`unique_while_running`** — one instance at a time | from claim to completion | an advisory lock on `hash(job_class, args)`, taken alongside the job's own claim lock. Free crash recovery for the same reason | two enqueues where the first has already finished |
| **Enqueue-time dedup** — do not queue a duplicate | from enqueue to completion | a partial unique index on `(job_class, args_digest) WHERE finished_at IS NULL`. The duplicate `INSERT` conflicts **inside the caller's transaction**, which is the only dedup that composes with transactional enqueue | a job that ran, succeeded, and is redelivered because the acknowledgement was lost |
| **`idempotent_by` on the action** ([`../idea/00-build-spec.md`](../idea/00-build-spec.md) Phase 5, [`../../wiki/Money-And-Ledgers.md`](../../wiki/Money-And-Ledgers.md)) | forever, on the **effect** | a persisted idempotency key on the mutation itself, so a second execution is a no-op | nothing — this is the only one that is a guarantee rather than a window |

**The rule that follows:** the first two are optimisations. Only `idempotent_by` is a guarantee, because only it survives the case an at-least-once queue actually produces — the job ran, the side effect landed, the process died before the row was marked finished, another worker picked it up. That is why [`../../wiki/Jobs.md`](../../wiki/Jobs.md) makes `idempotent_by` mandatory for money movement at boot and not merely recommended, and why `unique_while_running` must never be documented as if it prevented double execution. It prevents double *concurrency*.

## The ceiling

A Postgres queue is the right default. It is not infinite, and the limit is not where people expect — it is almost never the `SELECT`.

### Throughput, with attribution

Every number below is someone else's measurement of someone else's software. **Magik has no benchmark, because Magik has no code.**

| Source | Setup | Claim |
|---|---|---|
| Chris Hanks (Que's author), [*Turning PostgreSQL into a queue serving 10,000 jobs per second*](https://gist.github.com/chanks/7585810) | AWS c3.4xlarge, PostgreSQL 9.3, vanilla config, **`synchronous_commit` off** | ~9,806 jobs/s |
| [hardbyte/postgresql-job-queue-benchmarking](https://github.com/hardbyte/postgresql-job-queue-benchmarking), sweep dated 2026-05-09 | `postgres:18.3-alpine`, **capped at 4 CPUs** for reproducibility | pgque 39,898/s (single-consumer), awa 14,158/s, pgmq 11,277/s, pg-boss 2,387/s, river 501/s, oban 284/s |
| GoodJob README | none stated | targets "applications that enqueue 1-million jobs/day and more" — ~12/s averaged |

Read those carefully, because the headline numbers mislead in three separate directions:

1. **The Que number was bought by giving up durability.** `synchronous_commit = off` means a crash loses recently committed transactions — including enqueued jobs. That is precisely the guarantee the Postgres queue exists to provide. The honest reading is: *the claim mechanism can go this fast; the durable enqueue cannot.*
2. **It is from 2013, on PostgreSQL 9.3.** Predates `SKIP LOCKED` entirely.
3. **The 2026 spread is adapter design, not Postgres.** A 78× gap between pgque and oban on the same 4-CPU container is a statement about batching, polling intervals and claim strategy in each library. No Ruby adapter appears in the sweep at all.

**A defensible planning figure, stated as such:** a well-indexed Postgres queue with durable commits, on ordinary hardware, is comfortable in the **hundreds to low thousands of jobs per second**, and needs deliberate operational attention above that. That is a range inferred from the sources above, not a measurement, and it should be replaced by a Magik benchmark the moment one exists.

**And it is the wrong question.** Almost no SaaS application is anywhere near it. Brandur's post — the one Que's own docs link to for this — describes a production system at *"roughly 50 jobs a second"* falling over. Not from volume.

### Vacuum and bloat — the cost nobody mentions

This is the failure mode, and it is worth quoting Que's README warning in full because it is on the front page and still gets missed:

> **Please note** — Que's job table undergoes a lot of churn when it is under high load, and like any heavily-written table, is susceptible to bloat and slowness if Postgres isn't able to clean it up. The most common cause of this is long-running transactions, so it's recommended to try to keep all transactions against the database housing Que's job table as short as possible.

**The mechanism.** Every enqueue is an `INSERT`, every state change an `UPDATE`, every completion a `DELETE`. Under MVCC none of those remove anything immediately — they leave dead tuples that autovacuum must collect. And autovacuum cannot collect a tuple that any open snapshot might still see. So **one long transaction anywhere in the database freezes cleanup of the job table**, and the workers' claim query starts walking an index full of invisible rows.

Brandur Leach, [*Postgres Job Queues & Failure By MVCC*](https://brandur.org/postgres-queues), measured it:

| Observation | |
|---|---|
| Dead rows accumulated | *"by the end of our experiment, we're approaching an incredible 100,000 dead rows"* |
| Lock acquisition time | from `< 0.01 s` to `0.1 s and above` — a ~15× degradation |
| What `VACUUM` reported | *"247311 dead row versions cannot be removed yet"* |
| Result | a 60k-job backlog accumulated in an hour, at a ~50 jobs/second production rate |

The critical detail: **the long transaction did not have to touch the queue.** Any long transaction in the same database does it. A reporting query, a migration, an idle-in-transaction connection from an unrelated service, a `psql` someone left open.

Yen (2026-05-04) documents where it ends up:

> Dead tuples accumulate faster than autovacuum can clean them. By the time autovacuum finishes one pass, tens of thousands of new dead tuples have appeared. … Job queue tables can grow to tens of gigabytes when the actual "live" data was only a few megabytes.

And two failure modes beyond bloat, at higher worker counts with `SKIP LOCKED`:

> You'll see dozens or hundreds of backends piled up on these waits [`LWLock:MultiXactMemberSLRU`, `LWLock:MultiXactOffsetSLRU`] … CPU gets pegged, throughput collapses, and latency spikes.

> Every lock/unlock is a full WAL-logged transaction … On a system processing thousands of jobs per second, the WAL volume from the job queue alone can saturate your `wal_writer` and checkpoint processes.

The MultiXact point is a second, independent argument for advisory locks: it is a consequence of many backends taking row locks on the same rows, and advisory locking does not take row locks.

### Mitigations, in the order to apply them

| # | Mitigation | Detail |
|---|---|---|
| 1 | **Delete on success, by default** | the cheapest row is the one that is not there. Que's `destroy` in the same transaction as the job's own writes. Keep failures and dead-lettered jobs; do not keep successes as a default |
| 2 | **A short, bounded retention if history is wanted** | Que's documented deletion, with the notify trigger suppressed so the deletion does not wake every worker: `BEGIN; SET LOCAL que.skip_notify TO true; DELETE FROM que_jobs WHERE finished_at < (select now() - interval '7 days'); COMMIT;` |
| 3 | **Per-table autovacuum settings on the job table** | Yen: *"running vacuum more aggressively (lower `autovacuum_vacuum_scale_factor`, higher `autovacuum_vacuum_cost_limit`)"*. This is a `ALTER TABLE … SET (…)` in the migration that creates the table, not a cluster-wide change |
| 4 | **A scheduled manual `VACUUM`** | Que's docs ship one, at a 300-second interval and the highest priority, with the caveat that a manual vacuum *"does not back-off and sleep, so you will want to make sure your server has enough disk I/O available to handle the vacuum + any autovacuums + your workload + some overhead"* |
| 5 | **Kill long transactions** | Brandur's recommendation: *"putting together a Postgres supervisor … and executes a `pg_terminate_backend` on anything that's been alive for too long"*, plus a `statement_timeout`. Cheaper first step: set `idle_in_transaction_session_timeout` |
| 6 | **Partition the job table and drop partitions** | Yen: *"partitioning the table and dropping old partitions."* `DROP TABLE` reclaims space instantly; `DELETE` creates more dead tuples to vacuum. The right answer once retention is measured in millions of rows |
| 7 | **Move finished rows to a history table** | keeps the hot table proportional to pending work regardless of how much history is retained. Costs a write per completion, so it is a trade, not a free win |

**The design outputs.** Two, both concrete, both connecting to [`06-observability.md`](06-observability.md):

- `magik doctor` probes the job table's dead-tuple ratio (`pg_stat_user_tables.n_dead_tup / n_live_tup`) and **the age of the oldest open transaction in the database** — the second is the leading indicator and nothing else in the stack watches it.
- `magik jobs status` reports oldest-queued age alongside the counts, because a rising oldest-queued age with a flat queue depth is exactly the bloat signature and is invisible in a depth graph.

### Long-running jobs

A 40-minute job in a transactional queue is a different animal, in four ways.

**1. It can bloat the queue that scheduled it.** The Que pattern — do your writes and `destroy` the job in one transaction — is correct for a fast job and catastrophic for a slow one, because that transaction is open for 40 minutes and is the exact thing that stops autovacuum cleaning the job table. **A long job must not hold a transaction for its duration.** Do the slow work outside a transaction; open a short one at the end to write the result and finish the job. The price is that the crash window between "effect landed" and "job marked finished" is now real — which is at-least-once, which [`../../wiki/Jobs.md`](../../wiki/Jobs.md) already commits to, and which is what `idempotent_by` is for.

**2. The lock cost is genuinely small — with advisory locks.** Que's docs:

> Long-running jobs aren't necessarily a problem for the database, since the overhead of an individual job is very small (just an advisory lock held in memory).

One lock-table entry for 40 minutes is nothing. Under `SKIP LOCKED` plus a lease, the same job forces a ≥40-minute lease on the whole queue and therefore a ≥40-minute crash-recovery latency. **The mechanism choice and the long-job story are the same decision.**

**3. Deploys become the problem.** [`../ops/README.md`](../ops/README.md) specifies drain as "workers finish the current job and stop claiming." With a 40-minute job that is a 40-minute drain. Que's docs describe the same corner and the resolution is counter-intuitive:

> Que will block the worker process from exiting until all jobs it is working have completed normally. Unfortunately, if you have long-running jobs, this may take a very long time … The solution in this case is SIGKILL — luckily, Ruby processes that are killed via SIGKILL will end without using `Thread#kill` on its running threads. This is safer than exiting normally — when PostgreSQL loses the connection it will simply roll back the open transaction, if any, and unlock the job so it can be retried later by another worker.

**`SIGKILL` is the safe shutdown**, because a graceful exit risks partially-committed transactions and a hard kill does not. That only holds because the lock is a session advisory lock — a third convergence of the same choice. Magik therefore needs an explicit `--shutdown-timeout` on `magik worker` with a documented default, after which it kills rather than waits, and the deploy story has to say so.

**4. So a long job is a topology decision, not a job attribute.** Its own `queue`, its own workers, and those workers excluded from the rolling restart or given a long shutdown timeout. Better still, made resumable — a 40-minute job split into checkpointed chunks that each re-enqueue the next is a job that survives a deploy, and that is a pattern the framework should make easy rather than a rule it should impose.

### The signal that you have outgrown it

Stated here because [`../idea/04-swap-points.md`](../idea/04-swap-points.md) requires a swap's trade to be stated *at the point of choosing*. Two groups, and they mean different things.

**Group A — Postgres is straining. The queue shape is still right.**

| Signal | Measure it with |
|---|---|
| Dead-tuple ratio on the job table cannot be held below ~20% by aggressive autovacuum | `pg_stat_user_tables` |
| Job-table WAL is a material fraction of total WAL | `pg_stat_statements` on the enqueue and finish statements |
| Job-table maintenance competes with application queries for the same I/O budget | I/O wait, checkpoint frequency, and application p95 moving with queue depth |
| `LWLock:MultiXact*` waits appear | `pg_stat_activity.wait_event` |

The first move is **not** a broker. It is a second Postgres instance dedicated to jobs — cheapest, most familiar, and it removes the shared-vacuum coupling entirely.

**And it costs exactly what Redis costs: the enqueue is no longer in your transaction.** A second Postgres is a different database; a cross-database enqueue cannot join the application's transaction any more than a Redis `LPUSH` can. This is worth being loud about, because the cheapest rung on the scaling ladder is also the one that silently breaks the guarantee the default was chosen for. Anyone taking it needs the outbox pattern — write an intent row locally in the transaction, relay it to the job database — which is a real amount of machinery and should be a deliberate decision, not a config change.

**Group B — the queue is the wrong primitive. A bigger queue does not help.**

| Signal | What you actually need |
|---|---|
| One event must be consumed by N independent consumers with independent progress | a log with offsets — Kafka |
| The job stream itself is data: replay, audit, analytics over what happened | retention and replay — Kafka |
| Consumers are other services, other languages, other datacentres | a broker, not a table in your database |
| You need sub-millisecond enqueue-to-start latency at very high rates | an in-memory broker — Redis, and the family below |

Group B is a change of primitive. Nothing about tuning Postgres addresses it, and a team that hits it should stop tuning.

## The swap targets

Named backends for `use :jobs, :<name>`. All are **candidates** — none is implemented, none has a conformance suite, and per [`../idea/04-swap-points.md`](../idea/04-swap-points.md) a candidate is not a backend.

**The rule that governs all three:** transactional enqueue is a property of the Postgres backend, **not of the jobs seam.** The swap-point page's narrow-contracts rule — *"a capability only one backend has does not enter the interface"* — means the seam's interface cannot promise it. So it is documented at the point of choosing, on every alternative, every time:

> Any non-Postgres jobs backend loses transactional enqueue. The enqueue crosses a process boundary before your transaction commits. A rollback leaves the job queued, and a commit that fails after the enqueue leaves a job referencing a row that does not exist. Every guarantee in [`../../wiki/Jobs.md`](../../wiki/Jobs.md)'s transactional section comes off the table, and the app must adopt the outbox pattern to get it back.

| Target | Buys | Costs |
|---|---|---|
| **Kafka** (named in the spec) | fanout to independent consumers, retention, replay, cross-service and cross-language delivery | transactional enqueue. Also per-job retry, per-job priority and dead-lettering — Kafka has offsets and partitions, not jobs, so Magik's `retries`/`priority`/`discard_on` surface would need reimplementing above it. It is a log, not a queue |
| **Redis / Sidekiq family** (named in the spec) | latency and raw throughput; the most familiar operational story in Ruby | transactional enqueue. Plus a second datastore with its own persistence, failover and memory-limit semantics to learn |
| **[`wurk`](https://github.com/developerz-ai/wurk)** | the Redis option, named concretely — see below | the same, plus the caveats below |

### `wurk`

`developerz-ai/wurk` is a shipped MIT gem from the same organisation as Magik. Facts, from its README and `wurk.gemspec`, `As of 2026-08-26`:

| | |
|---|---|
| Version | 1.7.3, released 2026-08-18 (rubygems.org) |
| Requires | Ruby >= 3.2, Redis >= 7.0 |
| Runtime dependencies | `redis-client`, `connection_pool`, `concurrent-ruby`, `rack`, `logger`, `base64`, `fiddle` — no Rails |
| What it is | *"wire-compatible with Sidekiq — same Redis keys, same job JSON, same Ruby DSL"*, replacing `sidekiq` + `sidekiq-pro` + `sidekiq-ent` with one Gemfile line |
| Parity | the Pro and Enterprise feature sets in the free gem: reliable fetch, batches, reliable scheduler and client, queue pause/resume, job expiration, StatsD export, rate limiting, periodic (cron) jobs, unique jobs, AES-256-GCM argument encryption, metrics history, and the fork-based `swarm` with rolling restarts |
| Beyond Sidekiq | OpenTelemetry tracing, Kubernetes `/live` + `/ready` probes, an HTTP producer/observe API, flows (a DAG over batches), cluster-wide per-queue concurrency caps, per-job timeouts and deadlines |
| On speed, from its own README | *"Wurk is not currently faster than stock Sidekiq — it runs at roughly 0.87×–1.02× depending on workload shape"*, and *"The swarm buys copy-on-write memory and one supervisor, not raw speed"* |

It is the right thing to name because "Redis/Sidekiq — candidates" points at a licence question (Sidekiq OSS is LGPL-3.0; Pro and Enterprise are commercial) where `wurk` points at a single MIT gem carrying the whole feature set. It is also a sibling project, so the seam has a maintainer who can be asked.

Three honest caveats, because a sibling project gets more scrutiny, not less:

1. **It loses transactional enqueue.** Redis is a different process. This is not a wurk deficiency — it is inherent to any external broker, and it is the entire reason the Postgres backend is the default. Note specifically that wurk's *reliable client* (Redis-outage buffering) does not help here: it addresses *Redis being unavailable*, not *your transaction rolling back*. Different failures; only the first is addressable at the broker.
2. **Its headline differentiator is unavailable on Magik's production runtime.** wurk's README: *"JRuby, TruffleRuby, and Windows fall back to threads-only mode (no fork) — behaviorally equivalent to stock Sidekiq."* Magik targets TruffleRuby in production. So on Magik's actual deployment target, the fork-based swarm is off and what remains is Sidekiq-equivalent threading. That is still a good trade — the free Pro/Enterprise feature set is the real value, not the fork — but a swap page that sold the swarm to a TruffleRuby app would be selling something that does not happen.
3. **The drop-in value does not transfer.** wurk's compatibility is with the *Sidekiq* API — `Sidekiq::Worker`, `perform_async`, `sidekiq_options`. A Magik app writes `job :Name do … end`. The backend would sit under Magik's DSL, so the wire compatibility and the one-line-Gemfile-swap — the things wurk leads with — are worth nothing to a Magik app. What is worth something is the feature set, the dashboard, the OTel integration and the operational tooling.

## What is not decided

Written down so nobody reads the recommendation above as settled fact.

| Open | Resolved by |
|---|---|
| Does Que run on TruffleRuby? | a spike, before Phase 4 starts. Its answer picks between "wrap Que" and "own it" |
| Does `pg` run without TruffleRuby's global C-extension lock? | the same spike. TruffleRuby treats native extensions as thread-unsafe by default and serialises them unless they mark themselves safe; a global lock around every query would erase the parallelism the worker's thread pool depends on. **This now gates the thread worker model, not just the gem choice** |
| How many concurrent jobs one worker process actually holds | a load test. Each in-flight job is an OS thread; the per-process ceiling and its memory cost are unmeasured ([`12-runtime-verification.md`](12-runtime-verification.md)) |
| What Magik's own throughput is | a benchmark against real code. There is none, and no number appears on this page that Magik produced |
| Whether advisory-lock claiming survives contact with a real deployment's connection topology | first real deployment. The PgBouncer incompatibility is known; whether it is a blocker is not |
| Whether the recurring-job row claim is enough, or a scheduler process is needed | implementation. The row claim is simpler and should be tried first |

## Next

- [`../../wiki/Jobs.md`](../../wiki/Jobs.md) — the `job` DSL, the transactional argument, and the guardrails
- [`../idea/04-swap-points.md`](../idea/04-swap-points.md) — the jobs seam and the rules a backend must satisfy to stop being a candidate
- [`01-module-map.md`](01-module-map.md) — where `lib/magik/jobs/backends/` sits and what it may require
- [`06-observability.md`](06-observability.md) — the `job` log event and `magik jobs status`
- [`../ops/README.md`](../ops/README.md) — the worker process, drain, and what scales how
- [`10-performance-defaults.md`](10-performance-defaults.md) — the cost-is-opt-in rule this page's concurrency trade-offs feed into
