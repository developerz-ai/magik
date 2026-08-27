# Performance defaults

The performance decisions Magik makes on its users' behalf: what it does without being asked, why, what each one costs, and how to turn it off.

**Status:** planned. Nothing on this page is implemented — there is no serializer, no connection pool, no index generator, no cache and no paginator. **No page in this repo may carry a benchmark number**, and this one carries none: every quantity below is either a target with the command that will measure it, or an upstream project's own published claim, attributed. Reviewed 2026-08-26.

## Why a framework decides this

Ruby has a long, well-known list of performance techniques. `statement_timeout`. An index on the foreign key. Keyset pagination. Bound parameters. Bulk insert. Experienced people apply them; everyone else never hears about them, and finds out on the day a query that was fine at 10,000 rows is not fine at 10,000,000.

Magik's premise is that **the framework makes the decisions its users would not know to make**. That premise is sharper here than in most frameworks for the reason in [`../idea/07-ai-first.md`](../idea/07-ai-first.md): the primary developer is an agent, and **an agent writes whatever the framework makes easiest, not what a performance-minded human would have chosen.** A framework that leaves `SELECT *` as the path of least resistance will get `SELECT *`, several thousand times, in code nobody reads line by line.

So the default is the design. This page is the list.

## The rule that sorts this page

From [`../idea/01-thesis.md`](../idea/01-thesis.md): **Magik's opinions are concentrated exactly where reversal is impossible, and where reversal is cheap the swap points decide instead.** Applied to a performance default, that is a three-way test:

| Tier | The test | What it looks like |
|---|---|---|
| **Baked in** | reversing it later is a data migration, a correctness bug, or a security incident — **or** there is no legitimate reason to want the slow version | not configurable. No flag, no option, no call-site override |
| **Default on, switchable** | the default is right for almost every app, and the minority that needs the other answer needs it for a whole deployment | one `use`/config line in `App.define` ([`../idea/04-swap-points.md`](../idea/04-swap-points.md)), resolved at boot |
| **Opt-in** | it costs something real — writes, memory, staleness, or an invalidation story — so the spec's *cost is opt-in* axiom applies | a declaration in app code. Zero cost until written |

The complete classification is the [summary table](#the-classification-in-one-table). Where a default did **not** fit its tier cleanly, or contradicts something the spec already decided, it is in [Conflicts and open questions](#conflicts-and-open-questions) rather than quietly smoothed over.

## The stack these defaults are specific to

**TruffleRuby · Falcon · Sequel · Postgres · htmx.** Half the published Ruby performance advice is about a different stack, and applying it here would be worse than applying nothing.

### What does not apply here

CRuby-specific techniques, named so nobody wastes an afternoon:

| Technique | Why it does not apply |
|---|---|
| **YJIT / ZJIT** | Ruby's own documentation describes YJIT as "a lightweight, minimalistic Ruby JIT built inside CRuby" ([doc/jit/yjit.md](https://github.com/ruby/ruby/blob/master/doc/jit/yjit.md)). It is a CRuby component, not a portable gem. TruffleRuby has the Graal compiler; there is no `--yjit` to pass |
| **jemalloc, `MALLOC_ARENA_MAX`** | glibc-malloc tuning aimed at CRuby's heap behaviour. TruffleRuby Native uses Native Image's garbage collector, and TruffleRuby on the JVM uses the JVM heap; neither routes Ruby object allocation through libc malloc. *No upstream TruffleRuby sentence says this — it is an inference from how the runtime is built, not a quote* |
| **`RUBY_GC_*` environment variables** | CRuby's GC tuning surface. TruffleRuby's memory guidance is `--jvm` vs native and the JVM/Native Image heap settings ([deploying.md](https://github.com/oracle/truffleruby/blob/master/doc/user/deploying.md)) |
| **Bootsnap** | caches CRuby bytecode via `RubyVM::InstructionSequence`, which is CRuby-specific |
| **GVL-shaped thread-pool arithmetic** | TruffleRuby's README states it "does not have a global interpreter lock and runs both Ruby code and thread-safe native extensions in parallel" ([README](https://github.com/oracle/truffleruby/blob/master/README.md)). The reasoning that produces "5 threads per Puma worker" does not transfer |

`As of 2026-08-26`. TruffleRuby-specific behaviour is verified in CI, never on a laptop — the local development machine runs CRuby ([`../idea/01-thesis.md`](../idea/01-thesis.md)).

---

## 1. Serialization

JSON is not a corner of the framework. It is the API response body, the job payload, the production log line, the `--json` rendering of every CLI command and every error, and the `--json` request trace ([`06-observability.md`](06-observability.md)). It is on a hot path in four subsystems at once, which is why the spec puts Oj on the wrap list ([`../idea/00-build-spec.md`](../idea/00-build-spec.md)).

### One front door — baked in

Framework and app code call `Magik::Core::Json.dump` / `.parse`. Nothing anywhere calls `JSON.generate`, `Oj.dump`, `#to_json` or `MultiJson` directly. This is the same *one namer* rule the swap points use: a codec named at four hundred call sites is a codec that cannot be changed.

**Not switchable**, because the alternative is not a slower version — it is no seam at all.

### The mode is pinned — baked in

Oj's own documentation states that `:object` "is the default mode unless changed in the Oj default options", and describes it as generating "JSON that follows conventions which allow Class and other information … to be encoded in a JSON document" ([Oj Modes](https://github.com/ohler55/oj/blob/develop/pages/Modes.md)).

That is a footgun with Magik's name on it. An agent that writes `Oj.dump(payload)` and reads the README emits a document with Ruby class markers in it — not interchange JSON — and a parser in `:object` mode reconstructs Ruby objects from whatever the document claims. For an inbound webhook body or a job payload that is not a performance question at all.

So the mode is pinned at the seam (`:strict` for anything leaving the process, `:compat` where json-gem semantics are expected) and is not an option. `Oj.mimic_JSON` — which Oj documents as making Oj "take over" the `JSON` constant's methods ([JsonGem.md](https://github.com/ohler55/oj/blob/develop/pages/JsonGem.md)) — is **not** used: a global monkey-patch of `JSON` is exactly the kind of action-at-a-distance the boundary rules exist to prevent ([`02-boundaries.md`](02-boundaries.md)).

### Which codec — a swap point, and the default is engine-dependent

This is the part that would have been embarrassing to assert instead of check.

| Fact | Source |
|---|---|
| Oj is a C extension with no pure-Ruby fallback | [Oj README](https://github.com/ohler55/oj/blob/develop/README.md) |
| Oj's stated compatibility is "Ruby 2.7+ and RBX" — **TruffleRuby is not listed** | [Oj Compatibility.md](https://github.com/ohler55/oj/blob/develop/pages/Compatibility.md) |
| Oj has nonetheless tracked TruffleRuby: "3.7.1 — Updated to support TruffleRuby", "3.13.19 — TruffleRuby issues resolved" | [Oj CHANGELOG](https://github.com/ohler55/oj/blob/develop/CHANGELOG.md) |
| TruffleRuby has had to fix its own side: "Investigate failures in oj test suite" — "Some missing C API functions (like `rb_ivar_foreach`), some differences and some segfaults" | [oracle/truffleruby#2701](https://github.com/oracle/truffleruby/issues/2701) |
| **The `json` gem ships a TruffleRuby-specific pure-Ruby generator**, selected by engine: `if RUBY_ENGINE == 'truffleruby' … JSON.generator = JSON::TruffleRuby::Generator` | [ruby/json `lib/json/ext.rb`](https://github.com/ruby/json/blob/master/lib/json/ext.rb), [CHANGES.md](https://github.com/ruby/json/blob/master/CHANGES.md) |

The last row is the load-bearing one. The reference JSON library for the whole Ruby ecosystem decided that on TruffleRuby, a **pure-Ruby generator compiled by Graal beats its own C extension** — and TruffleRuby vendors that gem. "Use the C extension because C is fast" is a CRuby intuition, and it does not obviously survive the move to a JIT that compiles Ruby and interprets C through Sulong.

Oj's own published claims, quoted and attributed as required: Oj's `Advanced.md` states it "is about 2 times faster than any other Ruby JSON parser, and 3 or more times faster at serializing JSON" ([Oj Advanced.md](https://github.com/ohler55/oj/blob/develop/pages/Advanced.md)). **These are undated, unbenchmarked claims from the project's own documentation, made about CRuby.** Magik cites them as Oj's position, not as a measurement, and not as a claim about TruffleRuby.

Therefore JSON is **a seam, not a hard-coded gem**:

```ruby
App.define :Shop do
  use :json, :auto          # the default: :oj on CRuby, :stdlib on TruffleRuby
end
```

| Tier | Decision |
|---|---|
| **Baked in** | one front door; a pinned mode; no `mimic_JSON` |
| **Default on, switchable** | the codec — `use :json, :auto \| :oj \| :stdlib`, or `MAGIK_JSON_BACKEND` |
| **Opt-in** | nothing |

`:auto` is a default that reads the engine, not a fallback chain — an explicitly named backend that does not load fails at boot with `MAGIK_CONFIG_UNKNOWN_BACKEND`, per the swap-point rule that candidates never silently degrade. The conformance suite for this seam is a round-trip corpus (unicode, deep nesting, large integers, `:money` minor units, `nil`) run against every codec on both engines, and it is what would settle which default is right — see [Measurement](#11-measurement).

### Where JSON is *not* used

| Path | Instead |
|---|---|
| `:money` on the wire | integer minor units plus a currency string. Never a JSON float, on any codec ([`../idea/02-dsl-surface.md`](../idea/02-dsl-surface.md)) |
| Redacted fields | redaction runs **before** serialization, never after. A secret that reaches the serializer has already left the building ([`07-configuration-and-secrets.md`](07-configuration-and-secrets.md)) |
| htmx responses | HTML fragments. There is no client-side store to send JSON to ([`../idea/05-limits.md`](../idea/05-limits.md)) |

---

## 2. The database layer

Almost all real SaaS slowness is here. The sections below are ordered by how often they are the answer.

### 2.1 Connection pooling under a fiber server — baked in

Falcon's arithmetic is not Puma's arithmetic, and getting this wrong is a correctness bug rather than a slow page.

**The mechanism.** Sequel's connection pool keys checked-out connections on `Sequel.current`, whose definition in `lib/sequel/core.rb` is:

```ruby
# The current concurrency primitive, Thread.current by default.
def current
  Thread.current
end
```

and whose pool comments describe `@allocated` as "a hash with thread/fiber keys and connection values for currently allocated connections" ([threaded.rb](https://github.com/jeremyevans/sequel/blob/master/lib/sequel/connection_pool/threaded.rb)). `hold` short-circuits on `owned_connection(Sequel.current)` — re-entrant checkout is keyed on the concurrency primitive.

Falcon runs **one fiber per request**: it self-describes as "a multi-process, multi-fiber rack-compatible HTTP server" where "each request is executed within a lightweight fiber and can block on up-stream requests without stalling the entire server process" ([Falcon README](https://github.com/socketry/falcon)). Many fibers share one thread.

Put those together with the default `Sequel.current`: fiber A checks out connection C, yields on I/O, and fiber B on the same thread asks for a connection — and `owned_connection(Thread.current)` hands it C. Two requests, one connection, interleaved. *(The step-by-step failure is read off Sequel's source rather than quoted from an upstream issue; the conclusion that it must be fixed is not in doubt.)*

**The fix is one line, and Magik applies it before `Sequel.connect`:**

```ruby
Sequel.extension :fiber_concurrency
```

Sequel documents it as changing "the default concurrency primitive in Sequel to be `Fiber.current` instead of `Thread.current` … (thread-safe concurrency by default, fiber-safe concurrency with this extension)" ([fiber_concurrency.rb](https://github.com/jeremyevans/sequel/blob/master/lib/sequel/extensions/fiber_concurrency.rb); added in Sequel 5.32.0, [CHANGELOG](https://github.com/jeremyevans/sequel/blob/master/CHANGELOG)).

**Not switchable.** There is no legitimate reason to want thread-keyed checkout under a fiber-per-request server.

**The arithmetic changes with it.**

| | Threads-per-request (Puma) | Fibers-per-request (Falcon) |
|---|---|---|
| Concurrency ceiling | threads × processes — a number you chose | unbounded fibers. Falcon's documented backpressure lever is the file-descriptor limit, not a fiber cap ([performance tuning](https://socketry.github.io/falcon/guides/performance-tuning/index.html)) |
| Pool size rule | `pool = threads`. It *derives* from the server | `pool` derives from nothing. **It is the concurrency limit you are choosing for database work**, and there is no other one |
| Overload looks like | requests queue on the thread pool | requests queue on the connection pool, then raise `Sequel::PoolTimeout` after `:pool_timeout` (Sequel default 5s) |
| Connections the DB sees | threads × processes × hosts | `max_connections` × processes × hosts |

Sequel's defaults are `:max_connections` 4 and `:pool_timeout` 5 seconds ([opening databases](https://sequel.jeremyevans.net/rdoc/files/doc/opening_databases_rdoc.html)); on Ruby ≥ 3.2 the default pool class is `:timed_queue`. Falcon's `serve` command defaults to the `:forked` container with `--count` equal to `Etc.nprocessors` ([serve.rb](https://github.com/socketry/falcon/blob/main/lib/falcon/command/serve.rb)) — so the process multiplier is the machine's core count unless someone sets it, which on a shared host is usually wrong (Falcon's own deployment guide flags this and reads `WEB_CONCURRENCY` instead).

**Magik's default: the pool is a declared ceiling, and the total is checked, not assumed.**

```ruby
App.define :Shop do
  database url: ENV.fetch("DATABASE_URL"),
           pool: 8,                     # in-flight queries per process
           pool_timeout: 5              # seconds a fiber waits for a connection
end
```

`magik doctor` reads `max_connections` and `superuser_reserved_connections` from the server and reports the arithmetic:

```
pool 8 × web 4 + pool 4 × workers 2 + 4 realtime LISTEN = 44 of 100 max_connections
```

Realtime is in that sum on purpose: Postgres `LISTEN` occupies a connection for as long as it listens, which is why [`../ops/README.md`](../ops/README.md) already lists "`LISTEN` connections against Postgres" as a thing to watch.

Proposed, **not in the catalogue**: `MAGIK_SCALE_POOL_OVERSUBSCRIBED`, severity `warning`, raised by `magik doctor` when the arithmetic exceeds what the server will grant.

**Beyond that, PgBouncer** — and it is not free. PgBouncer's transaction pooling mode marks `SET`/`RESET`, `LISTEN`, `WITH HOLD` cursors, `PREPARE`/`DEALLOCATE`, session-level advisory locks and `LOAD` as never working, with the docs' own framing that "transaction pooling breaks client expectations of the server *by design*" ([PgBouncer features](https://www.pgbouncer.org/features.html)). Two of those are Magik defaults: `SET`-based connection setup (§2.3) and `LISTEN` (the realtime backend). Since PgBouncer 1.21, *protocol-level* prepared statements do work in transaction mode via `max_prepared_statements` ([PgBouncer config](https://www.pgbouncer.org/config.html)) — but SQL-level `PREPARE` still does not. A pooler is therefore a deployment topology Magik documents, not a default it ships.

For sizing the *database* side rather than the app side, the widely used formula is HikariCP's `connections = (core_count * 2) + effective_spindle_count` ([About Pool Sizing](https://github.com/brettwooldridge/HikariCP/wiki/About-Pool-Sizing)) — community-authoritative, not a Postgres document, and cited as such.

### 2.2 Bound parameters and prepared statements

**Bound parameters — baked in.** Every value the `model` DSL puts in a query is a bound parameter. Sequel's `pg_auto_parameterize` extension "changes Sequel's postgres adapter to automatically parameterize queries by default" ([pg_auto_parameterize](https://sequel.jeremyevans.net/rdoc-plugins/files/lib/sequel/extensions/pg_auto_parameterize_rb.html)), and Magik enables it. There is no legitimate reason to want literalised SQL: it is an injection surface, and it defeats plan reuse by producing a different query text per value.

The extension's documented caveats are real and belong here rather than in a surprise: a wrong type guess raises `DatabaseError` unless you write `Sequel.cast(value, type)`; Postgres allows a maximum of 65,535 parameters per query; and it is pg-driver-only. `Sequel.skip_pg_auto_param` and `no_auto_parameterize` exist as narrow escape hatches for a single expression.

**Prepared statements — default on, switchable.** Sequel spells them `ds.prepare(:select, :name)` and `ps.call(n: "Jim")`, with `:$name` placeholders ([prepared statements](https://sequel.jeremyevans.net/rdoc/files/doc/prepared_statements_rdoc.html)). Magik prepares the statements a declaration implies — a `scope`, an `api resource`'s index/show, the model's primary-key lookup — **at boot**, because Sequel's own documentation warns: "Creating a prepared statement uses `Object#extend`, which can hurt performance. For high performance applications, it's recommended to create all of your prepared statements upon application initialization, and not to create prepared statements dynamically at runtime."

The switch exists for exactly one reason: a deployment behind a connection pooler in transaction mode. `database prepared_statements: false`.

### 2.3 Timeouts — baked in that they exist, configurable in what they are

Almost nobody sets these, and an unbounded query is how one request takes down a database for everyone. All four are milliseconds when no unit is given and all default to `0`, meaning disabled ([runtime-config-client](https://www.postgresql.org/docs/current/runtime-config-client.html)):

| Setting | Postgres' own wording | Since |
|---|---|---|
| `statement_timeout` | "Abort any statement that takes more than the specified amount of time." | — |
| `lock_timeout` | "Abort any statement that waits longer than the specified amount of time while attempting to acquire a lock…" | — |
| `idle_in_transaction_session_timeout` | "Terminate any session that has been idle … within an open transaction for longer than the specified amount of time." | 9.6 |
| `idle_session_timeout` | "Terminate any session that has been idle … but not within an open transaction, for longer than the specified amount of time." | 14 |

`idle_in_transaction_session_timeout` is the one people miss. A session idle inside a transaction holds its locks and pins the oldest visible snapshot, so `VACUUM` cannot reclaim anything newer — one wedged request bloats the table it touched and every table behind it.

**Three profiles, because one number is wrong for three process roles.** This is the part that is genuinely non-obvious:

| Role | `statement_timeout` | `lock_timeout` | `idle_in_transaction_session_timeout` | Why |
|---|---|---|---|---|
| **web** (`magik server`) | short — a request that cannot answer in seconds should fail, not queue | short | short | the user is waiting; a timeout is a better answer than a held connection |
| **worker** (`magik worker`) | long, or per-job | short | short | a batch job legitimately runs for minutes. The web number would kill it |
| **migration** (`magik migrate`) | long — an index build takes as long as it takes | **very** short, with retry | short | a DDL statement waiting on a lock queues every later query behind it. That is the classic migration outage, and a low `lock_timeout` plus retry is the cure |

`lock_timeout` below `statement_timeout` is deliberate: it makes "I waited for a lock" and "I ran too long" distinguishable in the logs instead of both arriving as one code.

**How they are set.** Sequel offers `:connect_sqls` ("an array of sql strings to execute on each new connection") and `:after_connect`. Magik uses `:connect_sqls` by default. Behind a pooler in transaction mode `SET` is in PgBouncer's *never* column, so the alternative is libpq's startup-parameter route — `?options=-c%20statement_timeout%3D5000` on the connection URL ([libpq-connect](https://www.postgresql.org/docs/current/libpq-connect.html)) — which Magik emits instead when a pooler is declared.

**Switchable**: the values, per role, in `App.define`. **Not switchable**: that all four have a value. `0` is not an accepted setting.

### 2.4 Select the columns, not the table — baked in, widened at the call site

The framework knows what a screen renders and what an `api resource` serialises, because both are declarations. So the generated query projects exactly those columns.

| Why `SELECT *` costs more than it looks | |
|---|---|
| Transfer | every `text` column on the row crosses the socket whether or not anything reads it |
| TOAST | a large value stored out-of-line is fetched and de-compressed to be discarded |
| Index-only scans | a query that selects only indexed columns can be answered from the index. `SELECT *` never can |

The escape hatch is a widening at the call site, not a global flag: `.select_all` or an explicit `select:` list. This is not a violation of the swap points' *no call-site choice* rule — that rule governs which **backend** is named, not how a query is shaped.

### 2.5 Writes: bulk, not loops — baked in where the framework issues the write

`create :Order` in a loop is N round trips. Sequel's `Dataset#import` "can be used to efficiently insert a large number of records into a table in a single query if the database supports it", with `:slice` / `:commit_every` to bound transaction size ([Sequel::Dataset](https://sequel.jeremyevans.net/rdoc/classes/Sequel/Dataset.html)). Where Magik generates the write — a job processing a batch, a seed, an import action, a generated factory building fixtures for a test — it uses `import`/`multi_insert` with a slice, never a loop of inserts.

For app code, the DSL exposes the bulk form and `magik check --scale` reports a write inside a loop (§3, §11). It is a warning, because a legitimate counter-example exists: N writes that must each fire their own audit entry or ledger post.

### 2.6 Counter caches — opt-in

`COUNT(*)` is not cheap in Postgres and the project says so plainly. The PostgreSQL wiki's *Slow Counting* page: "The fact that multiple transactions can see different states of the data means that there can be no straightforward way for `COUNT(*)` to summarize data across the whole table. PostgreSQL must walk through all rows to determine visibility."

An index-only scan helps but does not make it constant: index entries carry no visibility information, so the scan consults the visibility map, whose bits are set by `VACUUM` — "An index-only scan, after finding a candidate index entry, checks the visibility map bit for the corresponding heap page. If it's set, the row is known visible" ([index-only scans](https://www.postgresql.org/docs/current/indexes-index-only-scans.html)). On a table that is being written to, those bits go stale and the scan falls back to the heap. Even at best it reads every matching index entry, so a per-tenant count stays **linear in that tenant's rows**.

So a `data_table` showing "1,248 orders" for a tenant with two million rows is a full scan on every page load.

```ruby
model :Customer do
  counts :orders            # maintains orders_count in the same transaction
end
```

**Opt-in, and the costs are stated at the point of declaring it**: the counter column is a single row updated by every insert and delete of a child, so concurrent writes to one parent serialise on it — a hot-row contention trade, bought deliberately. Magik generates a reconciliation job and a `magik check` rule that compares the cached value against the real count in CI, because a counter cache that has drifted is worse than no counter cache.

**The better answer is often to not need the number.** Cursor pagination (§3) does not require a total count, which is one of the places the pagination decision pays for itself.

### 2.7 Automatic indexes — baked in

A missing index on `tenant_id` is a full scan on **every query in the app**. Nobody should have to ask for it.

What Postgres does on its own, and what it does not:

| Constraint | Index created? | Postgres' own wording |
|---|---|---|
| `PRIMARY KEY` | yes | "Adding a primary key will automatically create a unique B-tree index on the column or group of columns listed in the primary key" |
| `UNIQUE` | yes | "Adding a unique constraint will automatically create a unique B-tree index on the column or group of columns listed in the constraint" |
| `FOREIGN KEY` | **no** | "…it is often a good idea to index the referencing columns too. Because this is not always needed, and there are many choices available on how to index, the declaration of a foreign key constraint does not automatically create an index on the referencing columns" |

([ddl-constraints](https://www.postgresql.org/docs/current/ddl-constraints.html))

That third row is the gap every ORM leaves open and every large table eventually falls into. `magik generate migration --from-models` closes it:

| Declaration | Index emitted | Why |
|---|---|---|
| every model (`tenant_id` is injected) | `(tenant_id)` — and it is the **leading column of every other index on the table** | see below |
| `belongs_to :customer` | `(tenant_id, customer_id)` | Postgres creates none, and both the join and the parent-side delete scan without it |
| `field :reference, unique: true` | `UNIQUE (tenant_id, reference)` | **not** `UNIQUE (reference)` |
| a `scope` filtering on `status` and ordering by `placed_at` | `(tenant_id, status, placed_at)` | the shape the scope actually issues |

**The unique-constraint row is a correctness decision wearing performance clothes.** In a multi-tenant app, `UNIQUE (reference)` means one tenant's invoice number blocks another tenant's. It is unrecoverable once two tenants have collided, which is exactly the "reversal is impossible" test — so it is baked in with no option.

**Why leading with `tenant_id` and not a separate index on it.** Postgres: "A multicolumn B-tree index can be used with query conditions that involve any subset of the index's columns, but the index is most efficient when there are constraints on the leading (leftmost) columns. The exact rule is that equality constraints on leading columns, plus any inequality constraints on the first column that does not have an equality constraint, will always be used to limit the portion of the index that is scanned" ([multicolumn indexes](https://www.postgresql.org/docs/current/indexes-multicolumn.html)). For `WHERE tenant_id = $1 ORDER BY placed_at DESC LIMIT 20`, a `(tenant_id, placed_at)` index is walked as one contiguous, already-sorted range and stopped after twenty entries. A bare `(tenant_id)` index reads every one of that tenant's entries, visits the heap for each, and sorts.

The same page's restraint is inherited too — "Multicolumn indexes should be used sparingly … Indexes with more than three columns are unlikely to be helpful unless the usage of the table is extremely stylized." The generator emits an index per declared access path, not per column, and `magik check` reports an index no declaration uses, because an unused index is pure write cost.

**On a table that already has rows — `CREATE INDEX CONCURRENTLY`, and it is not free.** Postgres: it "will build the index without taking any locks that prevent concurrent inserts, updates, or deletes on the table; whereas a standard index build locks out writes (but not reads)". The costs, in the docs' own words: "a regular `CREATE INDEX` command can be performed within a transaction block, but `CREATE INDEX CONCURRENTLY` cannot"; it "must perform two scans of the table"; and on failure it "will fail but leave behind an 'invalid' index … it will still consume update overhead" ([CREATE INDEX](https://www.postgresql.org/docs/current/sql-createindex.html)).

Two consequences Magik owns rather than leaves to the reader:

1. The generated migration is marked non-transactional. Sequel wraps migrations in a transaction by default, and a `CONCURRENTLY` index inside one fails.
2. `magik doctor` probes `pg_index.indisvalid` and reports invalid indexes with the `DROP INDEX` / `REINDEX … CONCURRENTLY` fix, because an invalid index is silent — queries ignore it and writes still pay for it.

**Not switchable.** An app may add indexes; it may not ask the generator to omit the tenant index or to make a unique constraint global.

---

## 3. Pagination

**Cursor (keyset) pagination is the default for `api resource … index`, for `data_table`, and for every generated list.** `OFFSET` is opt-in.

### Why `OFFSET` is the wrong default

Postgres states the cost itself: "The rows skipped by an `OFFSET` clause still have to be computed inside the server; therefore a large `OFFSET` might be inefficient" ([LIMIT and OFFSET](https://www.postgresql.org/docs/current/queries-limit.html)). Page 500 computes and discards the first 500 pages of rows. The degradation is linear and completely silent — nothing errors, nothing warns, the page just takes longer every month.

The correctness half is worse and less known. From the same page: "using different LIMIT/OFFSET values to select different subsets of a query result will give inconsistent results unless you enforce a predictable result ordering with `ORDER BY`." And when rows are being inserted between one page request and the next, the offset shifts under the reader — *use-the-index-luke*: "you'll get duplicates in case there were new rows inserted between fetching two pages", and "the idea to use the number of rows seen to skip over them later is simply wrong" ([no-offset](https://use-the-index-luke.com/no-offset)).

A paginated list that silently drops a row is a defect a user reports as "the invoice disappeared", and it is unattributable.

### Why this is natural *here* specifically

**Spec item 8 pays off in a place it was not designed for.** UUIDv7 primary keys were chosen for sortability and shard-safety ([`../idea/00-build-spec.md`](../idea/00-build-spec.md), [`../idea/01-thesis.md`](../idea/01-thesis.md) axiom 9). RFC 9562 §5.7 specifies `unix_ts_ms` as a "48-bit big-endian unsigned number of the Unix Epoch timestamp in milliseconds" occupying the most significant bits — so binary comparison of two v7 ids orders them by creation time ([RFC 9562](https://www.rfc-editor.org/rfc/rfc9562.html), May 2024).

Which means **the primary key is already a valid cursor and a valid tiebreaker.** Keyset pagination normally requires inventing a stable total order and bolting on a tiebreaker column; here it falls out of a decision made for a different reason.

The same RFC supplies the index-locality argument that justified the choice in the first place, worth quoting because it is the clearest statement of it anywhere: "UUID versions that are not time ordered, such as UUIDv4 … have poor database-index locality. This means that new values created in succession are not close to each other in the index; thus, they require inserts to be performed at random locations. The resulting negative performance effects on the common structures used for this (B-tree and its variants) can be dramatic" (§2.1), and "The real-world differences in this approach of index locality versus random data inserts can be one order of magnitude or more" (§6.11).

*(Postgres 18 added a native `uuidv7()` function — "Add UUID version 7 generation function `uuidv7()` … This UUID value is temporally sortable" ([PG18 release notes](https://www.postgresql.org/docs/18/release-18.html)). On earlier servers Magik generates the value in Ruby. Which one is used is a `magik doctor` line, not a behavioural difference.)*

### The shape

```sql
SELECT … FROM orders
WHERE  tenant_id = $1
  AND  (placed_at, id) < ($2, $3)
ORDER BY placed_at DESC, id DESC
LIMIT  50
```

Postgres supports row-constructor comparison, comparing "the row elements … left-to-right, stopping as soon as an unequal or null pair of elements is found" ([row constructor comparison](https://www.postgresql.org/docs/current/functions-comparisons.html)), and — unlike MySQL, Oracle and SQL Server — it can use a row-value predicate as an **index access predicate** ([use-the-index-luke](https://use-the-index-luke.com/sql/partial-results/fetch-next-page)). The matching index is emitted by §2.7 with the same column order and the same direction; the cursor columns are `NOT NULL`, because a NULL on either side of a row comparison makes it unknown.

The cursor itself is opaque and signed — an encoded `(sort values, id)` tuple, not a leaked internal key. It is stateless, which the deployment shape requires ([`../ops/README.md`](../ops/README.md)).

### The honest cost

Keyset pagination cannot do what offset pagination can: "You not only have to phrase the `where` clause very carefully — you also cannot fetch arbitrary pages" ([use-the-index-luke](https://use-the-index-luke.com/no-offset)). No "jump to page 500", no total page count without a separate count query (see §2.6).

For an admin screen where a human genuinely wants page 500, offset is available with a declared ceiling:

```ruby
index paginate: :offset, max_page: 100
```

**Default on, switchable — at the declaration, not globally**, because it is a per-list property. `magik check --scale` reports an offset paginator with no `max_page:` (proposed code `MAGIK_SCALE_OFFSET_PAGINATION`, `warning`). An `index` with no page ceiling at all is already refused: the wiki catalogue reserves `MAGIK_PAGINATION_UNBOUNDED` for it — see the [naming note](#conflicts-and-open-questions).

---

## 4. N+1 and unbounded queries

The core of this is already designed elsewhere and is not restated:

| Already covered | Where |
|---|---|
| No lazy loading — an unloaded association raises `MAGIK_LAZY_ASSOCIATION` rather than issuing a silent query | [`../../wiki/Models.md`](../../wiki/Models.md), [`../idea/05-limits.md`](../idea/05-limits.md) |
| N+1, slow query, unscoped query and missing-index detection, in the dev trace and in `magik check --scale` | [`06-observability.md`](06-observability.md) |
| Why all four are warnings rather than boot failures | [`../idea/03-guardrails.md`](../idea/03-guardrails.md) |

`MAGIK_LAZY_ASSOCIATION` is the strongest performance default in the framework and it is not on this page's classification table because it is a *guardrail*, not a tuning knob. It is worth naming why it works: it converts the most common performance bug in Ruby from an invisible one into a stack trace at the line that caused it.

### What is missing, and belongs in `--scale`

Three detections the observability page does not name, each with a legitimate counter-example — so all three are `warning`:

| Detection | Signal | Proposed code |
|---|---|---|
| **Unbounded result set** | a query reaching a render or a serializer with no `limit` and no paginator. The dev database has 40 rows; production has 4,000,000 | `MAGIK_SCALE_UNBOUNDED_QUERY` |
| **A query inside a loop** | a query site lexically inside an iteration over a dataset — the N+1's sibling that eager loading does not fix, because it is a *different* query per row, not an unloaded association | `MAGIK_SCALE_QUERY_IN_LOOP` |
| **A query with no usable index** | a declared filter or sort with no index whose leading columns match it. Detectable statically from the declaration and the schema, without a database | `MAGIK_SCALE_MISSING_INDEX` |

All three are **proposed names, not registered codes** — adding them is a change to [`03-error-codes.md`](03-error-codes.md) and to the owning subsystem's `errors.rb`, per [`00-conventions.md`](00-conventions.md).

The third one is the interesting one, because it is the only one of the four in [`06-observability.md`](06-observability.md) that can be answered **before** the query runs. "Missing index" as that page frames it is a runtime observation ("a scan over a table above a row threshold"); as a static rule it is a comparison between the access paths the declarations imply and the indexes the migrations created — which is a `magik check` rule with no database and no traffic, and therefore one an agent can run mid-edit.

**Prior art worth mining rather than reinventing.** Sequel ships `pg_auto_parameterize_duplicate_query_detection`, which raises `DuplicateQueries` when "the same query is executed more than once with the same call stack", with `:warn` and `:handler` options, and describes itself as "designed mostly to catch duplicate query issues (e.g. N+1 queries) during testing". Its notion of duplicate is *same query text*; the observability page's is *same query shape, differing only in a bound parameter* — the second is what an N+1 actually looks like, so the extension is a starting point rather than the answer.

---

## 5. HTTP

### 5.1 Compression — default on, switchable

**Falcon does not compress responses.** Its Rack adapter has no `content-encoding` handling and the docs never mention compression; the compression primitive exists in the stack (`Protocol::HTTP::Body::Deflate`, with `GZIP` and `DEFLATE` encodings) but is used mainly on the *client* side of `async-http`. So compression is `Rack::Deflater` in Magik's middleware stack, on by default for text responses.

`Rack::Deflater`'s own documented option matters here: `:sync` "determines if the stream is going to be flushed after every chunk. Flushing after every chunk reduces latency for time-sensitive streaming applications, but hurts compression and throughput. Defaults to `true`" ([deflater.rb](https://github.com/rack/rack/blob/main/lib/rack/deflater.rb)). Magik sets `sync: false` for ordinary buffered responses and leaves it `true` for streamed ones, because the default is tuned for streaming and most responses are not streams.

Two honest caveats:

| Caveat | |
|---|---|
| Small fragments | htmx swaps are often a few hundred bytes. Below a size floor, gzip costs CPU and a few bytes of framing to save nothing. Magik applies a minimum size. *htmx publishes no guidance on compression — this is Magik's position, not an htmx recommendation* |
| BREACH | compressing a response that contains a secret (a CSRF token) alongside attacker-influenced reflected content leaks the secret through response length. The mitigation is not to compress such responses, or to mask the token per response. Magik masks; the switch exists for operators who would rather not compress authenticated HTML at all |

### 5.2 Conditional requests — default on, switchable, and honest about what they save

`Rack::ConditionalGet` outside `Rack::ETag` (that order, or ETag-based 304s never happen). `Rack::ETag` generates a **weak** ETag from a SHA-256 digest, only for status 200/201, skipping responses that already carry `etag` or `last-modified` — and **it buffers the body into an array to digest it** ([etag.rb](https://github.com/rack/rack/blob/main/lib/rack/etag.rb)).

That last detail is why the honest framing matters: **an ETag on a dynamically rendered fragment saves the transfer, not the render.** The page was fully built before the digest could be computed. To save the *work*, you need the fragment cache (§6), and the two are different tools. A performance document that lists ETags next to caching without saying this is the reason people are surprised their server load did not move.

### 5.3 Fragments, htmx, and `Vary` — baked in

htmx documents this precisely, and it is the single most important HTTP-caching fact for a server-rendered htmx app:

> "Be mindful that if your server can render different content for the same URL depending on some other headers, you need to use the `Vary` response HTTP header. For example, if your server renders the full HTML when the `HX-Request` header is missing or false, and it renders a fragment of that HTML when `HX-Request: true`, you need to add `Vary: HX-Request`." — [htmx docs, Caching](https://htmx.org/docs/#caching)

That is exactly Magik's rendering model: a `screen` path answers a browser navigation with a page and an htmx request with a fragment. htmx sends `HX-Request: true` on every AJAX request ([reference](https://htmx.org/reference/)), and `Vary: HX-Request` is a cheap vary key — two values, unlike `User-Agent`, whose "very large number of variations … drastically reduces the chance that the cache will be reused" ([MDN caching guide](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Caching)).

So the emitted response carries `Vary: HX-Request` (and `HX-Boosted`, since `hx-boost` responses are near-full pages at the same URL). htmx also states, in the same section: "Always disable `htmx.config.historyRestoreAsHxRequest` so that these history full HTML requests are not cached with partial fragment responses" — that config value defaults to `true`, so Magik's generated htmx configuration sets it to `false`. And: "if your server can render different content for the same URL … the server needs to generate a different `ETag` for each content", so the fragment/page distinction is part of the ETag input, not an afterthought.

**Not switchable.** Getting this wrong serves a bare `<tr>` to someone who typed the URL, or a whole page into a table cell — a cache-poisoning-shaped bug that survives a deploy because it is in the browser's cache.

Two more htmx facts with defaults attached:

| htmx behaviour | Magik's default |
|---|---|
| "If you push a URL into the history, you **must** be able to navigate to that URL and get a full page back!" ([htmx history](https://htmx.org/docs/#history)) | the router guarantees it: a `screen` path always answers a non-htmx GET with a full page. It is a routing invariant, not an app responsibility |
| htmx snapshots the DOM into `localStorage` for history restoration (`historyCacheSize` default 10); `hx-history="false"` prevents "sensitive data entering the localStorage cache, which can be important for shared-use / public computers" | tenant-scoped screens emit `hx-history="false"`. Multi-tenant data in `localStorage` on a shared machine is a leak, not a caching trade |

### 5.4 Cache-Control — `private` is baked in, everything else is configurable

MDN on `public`: it "indicates that the response can be stored in a shared cache", and it will cause responses to authenticated requests to be stored in a shared cache ([Cache-Control](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Cache-Control)).

**In a multi-tenant app, a `public` cache directive on a tenant-scoped response is a cross-tenant data leak** — one CDN edge, two tenants, one cached page. So:

| Response | Directive | Tier |
|---|---|---|
| anything rendered from a tenant-scoped query | `private, no-store` by default; `private, max-age=…` where a declaration opts in | **baked in** that it is never `public` |
| a fingerprinted static asset | `public, max-age=31536000, immutable` | default on |
| an `api` response | `private, no-store` | switchable per resource |

Proposed, **not in the catalogue**: `MAGIK_RENDER_CACHE_PUBLIC`, `severity: :error`, at boot, for a declaration asking for a shared-cacheable tenant-scoped response.

### 5.5 Assets — default on

Content-hashed filenames plus `Cache-Control: public, max-age=31536000, immutable` — MDN's documented pattern, with its example headers given verbatim on the caching guide. htmx itself (~14kb, [`../idea/05-limits.md`](../idea/05-limits.md)) and the generated theme CSS are the whole asset list; there is no bundler, so fingerprinting is a hash and a filename rather than a build pipeline.

MDN's own realism is worth carrying: "the cache removes old entries when new entries are saved, the probability that a stored response still exists after one week is not that high — even if `max-age` is set to 1 week."

### 5.6 Connections

Falcon "supports HTTP/1 and HTTP/2 natively" ([README](https://github.com/socketry/falcon)) and its default `serve` bind is `https://localhost:9292`, so HTTP/2 is negotiated over TLS via ALPN by default. Cleartext h2c works by connection-preface detection, but there is no `Upgrade: h2c` negotiation — which matters when a load balancer speaks HTTP/1.1 to the app, and Falcon's deployment guide's own advice there is to pin `protocol: Async::HTTP::Protocol::HTTP11`. HTTP/1.1 keep-alive is the default in `async-http`; each held-open connection costs a fiber and a file descriptor, which is why Falcon's documented tuning lever is `ulimit -n`.

**Falcon has no built-in static-file handler and its docs offer no static-asset guidance.** Magik serves assets from the app process in development and expects a CDN or a reverse proxy in production. *That is Magik's stance, not an upstream Falcon recommendation.*

---

## 6. Caching — and a gap in the spec

### The gap

Spec item 11 names **cache backend** as a required swap point, [`../idea/04-swap-points.md`](../idea/04-swap-points.md) gives it a row (default: in-process memory) and states the app-facing call as `cache.fetch`, and [`../idea/02-dsl-surface.md`](../idea/02-dsl-surface.md) shows `use :cache, :memory` in `App.define`.

**There is no caching construct in the DSL.** The seam exists with no grammar on top of it, which is the one combination the design is supposed to make impossible: a backend nobody can address from a declaration. `wiki/Actions.md` already refers in passing to "the cache it invalidates" — a behaviour with no page defining it.

This is flagged, not filled. Adding a construct is a spec change and belongs in [`../idea/00-build-spec.md`](../idea/00-build-spec.md) first, in its own commit, with the argument ([`00-conventions.md`](00-conventions.md)).

### The minimum surface, if it is added

Three things, and deliberately not a fourth:

| # | Surface | Tier | Why this and not more |
|---|---|---|---|
| 1 | **`cache.fetch(key, ttl:) { … }`** — the seam's runtime API, already implied by the swap-points page | default on (the seam), the call is opt-in | the narrowest thing every backend can honour: get, set with TTL, delete, and a namespace clear. Nothing else enters the interface |
| 2 | **A fragment cache on a declaration** — `component :OrderRow do cache_on ->(order) { order } … end` | opt-in | this is the one that saves *render* time rather than transfer time (§5.2), and it is the one an agent would never write unprompted |
| 3 | **A request-scoped memo** — one store per request, discarded when the request ends | baked in as a mechanism, opt-in per use | the same lookup twice in one render is common and cheap to fix. It is **not** an identity map: it caches explicit calls, not every row loaded, because an automatic identity map means a write in the middle of a request is invisible to the read after it |

**The invalidation story is generational, not manual — baked in.** The cache key is derived, never hand-written:

```
tenant_id · declaration name · declaration digest · record id · record updated_at
```

| Component | Why it is in the key |
|---|---|
| `tenant_id` | **mandatory.** A cache key with no tenant is a cross-tenant read. Proposed code `MAGIK_CORE_CACHE_KEY_UNSCOPED`, `severity: :error` |
| declaration digest | changing a `component`'s body changes its key, so a deploy invalidates exactly the fragments whose markup changed and nothing else. The registry already knows the declaration's source ([`08-dev-loop.md`](08-dev-loop.md)) |
| `updated_at` | a write produces a new key rather than deleting an old one. Nothing has to remember to invalidate |

Explicit `cache.delete` remains available and is the escape hatch. It is not the default because "remember to invalidate" is precisely the discipline that fails — and it fails silently, as a stale page.

### The default backend is wrong for this, and the doc has to say so

The cache seam's default is **in-process memory**, chosen so a small app needs no infrastructure. A fragment cache on that backend, across the stateless fleet of [`../ops/README.md`](../ops/README.md), means:

- N app processes, N independent caches, N first-request misses;
- no cross-process invalidation, so an explicit `cache.delete` reaches one process;
- everything cold after every deploy.

None of that is a correctness violation — a cache is not state, and the stateless guardrail (`MAGIK_RENDER_SCREEN_STATEFUL`) is about request state, not memoized output. But it does mean **declaring a fragment cache while running more than one process on the memory backend is close to pointless**, and a framework that lets someone do that without a word has failed at the thing this page is about. That should be a boot warning naming the seam and the fix (`use :cache, :redis`).

---

## 7. Runtime

### 7.1 JIT warmup is a real trade, in both directions

TruffleRuby's deployment guide says it plainly, and the wording is worth having verbatim:

> "If you are running a short-running program you probably want the default, *native*, configuration. If you are running a long-running program and want the highest possible performance you probably want the *JVM* configuration, by using `--jvm`."
>
> "However to reach this peak performance you need to *warm-up* TruffleRuby, as you do with most heavily optimising virtual machines. This is done by running the application under load for a period of time."
>
> — [truffleruby/doc/user/deploying.md](https://github.com/oracle/truffleruby/blob/master/doc/user/deploying.md)

The README's comparison: Native starts "about as fast as MRI startup" and reaches peak "faster", with "good" peak performance; JVM starts "slower", warms "slower", and has "best" peak performance ([README](https://github.com/oracle/truffleruby/blob/master/README.md)).

**What that costs Magik, honestly:**

| Workload | The problem | Magik's position |
|---|---|---|
| `magik server` | the first requests after a deploy run cold. On a rolling deploy that is a latency cliff that reads like load, and autoscaling that watches p95 will mistake warmup for traffic | JVM configuration; warm before the readiness probe passes, so the load balancer does not send traffic to a cold process ([`../ops/README.md`](../ops/README.md)). Readiness already gates on config, database and guardrails — warmup joins that list |
| `magik worker` | long-lived, so it warms up. But a worker that starts, drains a queue for nine seconds and exits never does | long-lived worker processes, not one-shot invocations |
| `magik check`, `magik generate`, `magik test` | **the loop an agent runs dozens of times an hour.** A runtime that is fastest after sixty seconds of load is the wrong runtime for a command that should take one second | CRuby locally. This is why the repo already supports CRuby ≥ 3.2 "for tooling and development" — it is a performance decision, not only a convenience one |

`--engine.Mode=latency` exists and Truffle documents it as configuring "the execution mode of the engine … 'latency' and 'throughput'. The default value balances between the two" ([Truffle options](https://www.graalvm.org/latest/graalvm-as-a-platform/language-implementation-framework/Options/)). A TruffleRuby issue reports it being substantially better for a test-suite workload ([#1985](https://github.com/oracle/truffleruby/issues/1985)) — *an anecdotal data point in an issue thread, not a published benchmark.* It is a candidate for the CLI profile and it is untested here.

Auxiliary engine caching (`--engine.CacheStore`), which persists compiled code across runs and would be the real answer for short-lived processes, is **Oracle GraalVM only** — "This feature is only available in Oracle GraalVM. In GraalVM Community Edition, these options are not available" ([Auxiliary Engine Caching](https://github.com/oracle/graal/blob/master/truffle/docs/AuxiliaryEngineCachingEnterprise.md)). Whether TruffleRuby is a supported consumer of it is **unverified**. A default that requires a specific commercial distribution is not a default Magik can ship.

### 7.2 The concurrency model — and where the spec and the runtime disagree

Spec item 1 says "Concurrency via Ractors/Fibers, not threads-per-request". Two things are true about that on the actual production runtime, and both are on the record:

> "`Ractor` is currently not implemented on TruffleRuby." … "Threads are run in parallel on TruffleRuby and Threads are far more compatible with gems than `Ractor`, so `Ractor` is not so useful on TruffleRuby."
>
> "In TruffleRuby, fibers are currently implemented using operating system threads, so they have the same performance characteristics as Ruby threads."
>
> — [truffleruby/doc/user/compatibility.md](https://github.com/oracle/truffleruby/blob/master/doc/user/compatibility.md)

And on the fiber scheduler that Falcon is built on:

> "Fiber scheduler changes are not implemented because it seems not worth it until Truffle supports VirtualThread on both Native Image and HotSpot."
>
> — TruffleRuby Ruby-3.x support tracking, [#3039](https://github.com/oracle/truffleruby/issues/3039) (the same sentence appears in [#2453](https://github.com/oracle/truffleruby/issues/2453) and [#2733](https://github.com/oracle/truffleruby/issues/2733))

against Falcon's own description: "Falcon is built on top of the fiber scheduler and the async gem which allow it to handle thousands of connections concurrently" ([getting started](https://socketry.github.io/falcon/guides/getting-started/index.html)).

This is a genuine, unresolved conflict between two non-negotiable spec decisions and the runtime they name. It is written up in [Conflicts and open questions](#conflicts-and-open-questions) rather than papered over, because a performance document that quietly assumed cheap fibers on TruffleRuby would be wrong in its foundations.

What *is* settled, and is good news: **TruffleRuby has no GVL and runs threads in parallel.** The reasoning that makes threads-per-request unattractive on CRuby does not apply. Whatever the concurrency model turns out to be, the per-request rules stay the same either way — no in-process state across requests, a frozen registry after boot, no mutable globals ([`00-conventions.md`](00-conventions.md)) — and those are what make *any* of the three models safe.

One TruffleRuby detail that matters for the database driver: "Native extensions are by default considered thread-unsafe for maximum compatibility with CRuby and use the global extension lock (unless `--cexts-lock=false` is used). Extensions can mark themselves as thread-safe either by using `rb_ext_ractor_safe()` or `rb_ext_thread_safe()`" (compatibility.md). `pg` declares Ractor compatibility from 1.5.0 ([pg CHANGELOG](https://github.com/ged/ruby-pg/blob/master/CHANGELOG.md)); whether that translates into TruffleRuby dropping the global extension lock for it is **unverified and is a `magik doctor` probe worth writing**, because a global lock around every query would erase the parallelism the runtime was chosen for.

`pg` itself is in good shape on both fronts: "Add support for TruffleRuby. It is regularly tested as part of our CI" (1.3.0), and "Pg is fully compatible with `Fiber.scheduler` introduced in Ruby-3.0 since pg-1.3.0. … All possibly blocking IO operations are routed through the `Fiber.scheduler` if one is registered for the running thread" ([pg README](https://github.com/ged/ruby-pg/blob/master/README.md)). The second capability is inert on a runtime with no fiber scheduler to register.

### 7.3 `frozen_string_literal` — baked in

`# frozen_string_literal: true` on the first line of every file, framework and generated app alike. It is already the rule ([`00-conventions.md`](00-conventions.md)) and it is enforced by RuboCop, so it appears here only to be classified.

The honest scope of the claim: Ruby has not made it the default — 3.4 introduced "chilled" string literals that warn on mutation rather than raise ([Feature #20205](https://bugs.ruby-lang.org/issues/20205)), and Ruby 4.0 did not flip it. **TruffleRuby publishes no guidance that the magic comment helps or hurts there**; what is on the record is that TruffleRuby "replace[s] a call of `-"string"` with frozen string literal at parse time" ([CHANGELOG](https://github.com/oracle/truffleruby/blob/master/CHANGELOG.md)). So the argument for it here is primarily correctness and consistency — a shared mutable literal is a bug on any engine — and the allocation saving is a secondary claim nobody in this repo has measured.

### 7.4 Memory

Nothing to tune with an environment variable (see [what does not apply](#what-does-not-apply-here)). TruffleRuby's own footprint guidance is the configuration choice itself: "you may find that the simpler garbage collector and current lack of compressed ordinary object pointers (OOPS) actually increases your memory footprint and you will be better off with the JVM configuration using `--jvm` to reduce memory use" ([deploying.md](https://github.com/oracle/truffleruby/blob/master/doc/user/deploying.md)). Which configuration a Magik app should run is a deployment decision, reported by `magik doctor`, and it is one of the few places where the answer is genuinely "measure your app".

The framework-side memory decisions are structural rather than tuned: a frozen registry shared across workers, factories that build the minimum valid row ([`04-testing-strategy.md`](04-testing-strategy.md)), and projections that do not load columns nothing reads (§2.4).

---

## 8. Jobs

### 8.1 Payloads carry ids — baked in

```ruby
SettleBatch.enqueue(order_id: order.id)      # yes
SettleBatch.enqueue(order: order)            # refused
```

**This is a correctness argument before it is a performance one.** A job payload holding a serialized record is a snapshot of the row as it was at enqueue time. The job runs later — after a retry, after a queue backlog, after a deploy — and acts on a version of the record that may no longer exist. The bug it produces is a refund issued against a stale amount, and it is unattributable because the code reads correctly.

The performance argument is real too: the payload is a column in the queue table, written, read, and indexed. A serialized object graph is orders of magnitude larger than a UUID, and the redaction list cannot be applied to fields nobody declared ([`07-configuration-and-secrets.md`](07-configuration-and-secrets.md)).

**Not switchable.** Proposed code `MAGIK_JOBS_PAYLOAD_NOT_SERIALIZABLE`, at boot where the argument shape is declared and at enqueue otherwise.

The corollary the framework owes back: a job whose record was deleted between enqueue and run must fail with a code that says so, not a `NoMethodError` on `nil`.

### 8.2 Retries jitter by default — baked in

The DSL already spells retries as `retries times: 5, backoff: :exponential` ([`../idea/02-dsl-surface.md`](../idea/02-dsl-surface.md)). **In Magik, `:exponential` means exponential *with jitter*, and there is no un-jittered setting.**

The reason, from the source of the term — Marc Brooker, *Exponential Backoff And Jitter*, AWS Architecture Blog: without jitter "there are still clusters of calls. Instead of reducing the number of clients competing in every round, we've just introduced times when no client is competing." The article's *Full Jitter* form is `sleep = random(0, min(cap, base * 2 ** attempt))`.

The failure mode is specific and common: a downstream provider has a thirty-second outage, ten thousand jobs fail in that window, and every one of them retries at exactly `t + 2`, then exactly `t + 4`, then exactly `t + 8` — re-creating the original spike at each step, against a service that is still recovering. Un-jittered exponential backoff does not spread load; it *quantises* it.

There is no legitimate reason to want synchronized retries, so there is no flag. `times:` and `cap:` are configuration.

### 8.3 Scheduled jobs spread across the tenant set — baked in

`schedule cron: "0 3 * * *"` on a job that runs per tenant means every tenant's job fires at 03:00:00 — a thundering herd the app authored itself, and the second-largest self-inflicted load spike after retry storms.

Magik derives a **deterministic** offset from `tenant_id` within the schedule's window, so tenant A always runs at 03:04 and tenant B always at 03:41. Deterministic rather than random, because a job that moves every night is a job nobody can correlate with anything in a log.

**Not switchable.** A job that genuinely must run at exactly 03:00 for every tenant is a job with a different schedule declaration, not a flag on this one.

### 8.4 Batching — opt-in, with the trade stated

One job per row gives per-row retry granularity and per-row failure isolation, and costs a queue row, a lock, and a transaction per item. One job per batch inverts every one of those.

The framework does not choose. It makes both expressible and states the trade at the point of choosing, which is the difference between a default and an opinion nobody can act on:

| Shape | Buys | Costs |
|---|---|---|
| job per row | a failure affects one row; retry is precise | N queue rows, N transactions, N sets of overhead |
| job per batch | one row, one transaction, bulk writes (§2.5) | one poisoned row can fail the batch. Needs a per-item error collection and a resume point |

`unique_by` is already in the DSL and is the deduplication half of this.

### 8.5 Queue mechanics — baked in

The default backend is a Postgres queue, Que-style ([`../idea/04-swap-points.md`](../idea/04-swap-points.md)), and two of its properties are performance properties:

| Property | Why it matters |
|---|---|
| Transactional enqueue | a rolled-back transaction enqueues nothing. No compensating logic, no orphaned job, and no second datastore to keep consistent |
| `LISTEN`/`NOTIFY` wakeup plus advisory locks, not polling | a poller either burns queries at idle or adds latency to every job. The wakeup path costs neither — at the price of one held connection per listener, which is in the §2.1 arithmetic |

The worker's `statement_timeout` profile is the one from §2.3, and it is the reason those are per-role rather than global.

---

## 9. Where the defaults come from

Every default above is one of three things, and it is worth being explicit about which, because "the framework does it for you" is only trustworthy if it is inspectable:

| Source | Example |
|---|---|
| **A declaration the framework can read** | the index set (§2.7), the projected columns (§2.4), the prepared statements (§2.2), the cache key digest (§6) — all derived from `model`/`screen`/`api` declarations by the same registry that powers `magik explain` ([`06-observability.md`](06-observability.md)) |
| **A configuration value with a non-zero default** | the pool size, the timeouts, the compression floor. Printed by `magik doctor`, never silently assumed |
| **A refusal** | no lazy loading, no unbounded `index`, no `public` cache on tenant data, no serialized record in a job payload. These are guardrails and they live in [`../idea/03-guardrails.md`](../idea/03-guardrails.md) |

`magik explain query Order.recent` shows the SQL a scope compiles to including the injected tenant predicate; the same command is what shows which index the generator emitted and which one the planner chose. A framework that writes part of your SQL has to be able to show you all of it.

---

## 10. What is deliberately not here

| Not doing | Why |
|---|---|
| **Read replicas / read-write splitting** | it changes read-after-write semantics for every action in the app. That is a design decision with a guardrail attached, not a performance default, and it is not in the spec |
| **Sharding** | spec item 8 makes it *possible* later (UUIDv7, `tenant_id` everywhere) and `magik check --scale` protects the property. Nothing implements it |
| **Query result caching at the ORM layer** | the invalidation surface is every write in the app. The fragment cache (§6) caches something the framework can key correctly; a query cache is not |
| **Client-side anything** | no offline cache, no client store, no heavy client compute — permanent refusals ([`../idea/05-limits.md`](../idea/05-limits.md)), not a performance frontier |
| **Micro-optimising Ruby** | the wins on this page are one or two orders of magnitude apart from method-call overhead. A missing index costs more than every `frozen_string_literal` in the codebase combined |

---

## 11. Measurement

A performance document with no measurement is folklore. **No number on this page is a measurement**, and the rule for adding one is: the command that produced it, and the date it was run.

### What already reports

| Surface | Reports | Defined in |
|---|---|---|
| `magik check --scale [--json]` | unscoped queries, N+1, missing indexes, slow-query sites — plus the three proposed in §4 | [`06-observability.md`](06-observability.md) |
| the request trace | screen → action → model → query → job → broadcast, per-node timings, the dominant node marked, `--json` as a walkable tree | same |
| structured logs | one event per request/action/query/job, with `duration_ms` and `correlation_id` on every one; per-query logging is threshold-gated in production | same |
| `magik doctor` | Ruby engine and configuration, Postgres version, `max_connections` and the pool arithmetic (§2.1), extensions, invalid indexes (§2.7), which JSON codec resolved (§1) | same, extended by this page |
| `magik test --report=timing --json` | total wall clock, per-worker load, slowest N tests | [`04-testing-strategy.md`](04-testing-strategy.md) |

### The targets, with the commands that will test them

The spec sets one performance target. It is a target:

> Full test suite of 1,000 tests: parallel, all cores, **<10s target** — [`../idea/00-build-spec.md`](../idea/00-build-spec.md)

```bash
magik test --workers=auto --report=timing --json
```

**Which runtime that target is measured on is currently unstated**, and §7 is the reason it matters: a warmup-sensitive runtime and a ten-second budget are in tension, and the answer may be that the suite runs on CRuby while the server runs on TruffleRuby. Whoever measures it first must say which engine, which configuration (`--native` or `--jvm`), and on what hardware — a bare "9.4s" is not a result.

Everything else on this page has a command rather than a number:

| Question | Command |
|---|---|
| Which JSON codec is faster here? | the `:json` seam conformance suite, run against `:oj` and `:stdlib` on CRuby and TruffleRuby in CI ([`../idea/04-swap-points.md`](../idea/04-swap-points.md)) |
| Does this pool size hold under load? | `magik doctor` for the arithmetic; the `duration_ms` distribution of `event=query` for the queueing |
| Did that index get used? | `magik explain query <Scope>` |
| Where did this request go? | the request trace, `--json` |
| Is anything unscoped, unbounded, or unindexed? | `magik check --scale --json` |
| Does Falcon actually run concurrently on TruffleRuby? | **unresolved** — see below |

---

## Conflicts and open questions

Named rather than smoothed over, because each is a place where a performance default meets a decision the spec already made.

### 1. TruffleRuby does not implement `Ractor`, and the spec and the test runner both name it

Spec item 1 is "Concurrency via Ractors/Fibers"; [`04-testing-strategy.md`](04-testing-strategy.md) builds the parallel test runner on "one Ractor per test file group". TruffleRuby's compatibility document states `Ractor` "is currently not implemented on TruffleRuby", and that threads are already parallel there so Ractors are "not so useful".

The testing page already names Ractor maturity as a risk and already ships a forked-worker fallback and a runner-backend seam — so the *design* survives. What does not survive unexamined is the spec sentence. On the production runtime the choice is threads (genuinely parallel, no GVL) or the [`ractor-shim`](https://github.com/eregon/ractor-shim) gem that TruffleRuby's own docs point at, which runs Ractors as threads.

**Resolution: a spec amendment, not a doc.** Someone has to decide whether item 1 means "not threads-per-request" (compatible with threads used differently) or "Ractors specifically" (not currently available on the target runtime).

### 2. Falcon is built on the fiber scheduler; TruffleRuby does not implement `Fiber.set_scheduler`

Spec item 2 is "Rack + Falcon (async, fiber-based)". Falcon's guide says it "is built on top of the fiber scheduler and the async gem". TruffleRuby's Ruby-3.x support issues state that "Fiber scheduler changes are not implemented", and compatibility.md adds that TruffleRuby's fibers "are currently implemented using operating system threads, so they have the same performance characteristics as Ruby threads."

Both halves of the premise are affected: the scheduler that makes third-party I/O non-blocking, and the assumption that a fiber per request is cheap.

**This is the largest open question in the performance design, and it is upstream of most of §2.1.** If fibers are OS threads and there is no scheduler, "thousands of concurrent connections" is not the operating point, and the pool arithmetic changes shape again.

**Resolution: an experiment, not an argument.** Boot Falcon on TruffleRuby in CI, issue concurrent slow queries through `pg`, and measure whether they overlap. That is a one-afternoon test and it decides a non-negotiable spec item. Until it is run, this page treats fiber-per-request concurrency on TruffleRuby as **unverified**. *(`pg` is CI-tested on TruffleRuby by its own maintainers, so the driver is not the doubt; the scheduler is.)*

### 3. Oj is on the spec's wrap list, and TruffleRuby is not on Oj's compatibility list

Detailed in §1. The spec names Oj; Oj's compatibility page names "Ruby 2.7+ and RBX" and not TruffleRuby; the `json` gem ships a *pure-Ruby* generator specifically for TruffleRuby because that is faster there.

**Resolution: make it a seam** (`use :json, :auto`) rather than a hard dependency, add the row to [`../idea/04-swap-points.md`](../idea/04-swap-points.md), and let the conformance suite pick the per-engine default. This is the swap-point rule doing exactly the job it was written for.

### 4. The default cache backend is a poor fragment-cache backend

Detailed in §6. `use :cache, :memory` is right for "an app with no Redis"; it is close to useless for a fragment cache across the multi-process fleet the ops page describes. Not a contradiction — a documented interaction that needs a boot warning rather than silence.

### 5. `SET`-based connection setup versus a connection pooler

§2.3 sets four Postgres timeouts through `:connect_sqls`. PgBouncer lists `SET` as never working in transaction pooling mode, and `LISTEN` — the default realtime and job-wakeup transport — as never working either. So the deployment that most needs a pooler is the one whose defaults it breaks. Magik's answer is the libpq `options=` startup-parameter route when a pooler is declared, plus documentation that transaction pooling and the Postgres realtime backend are mutually exclusive. **That interaction is not currently in [`../ops/README.md`](../ops/README.md).**

### 6. A code-naming drift worth fixing

`wiki/Error-Codes.md` reserves `MAGIK_PAGINATION_UNBOUNDED`, which does not fit the `MAGIK_<SUBSYSTEM>_<CONDITION>` format from [`03-error-codes.md`](03-error-codes.md) — `pagination` is not a subsystem in [`01-module-map.md`](01-module-map.md). `MAGIK_API_PAGINATION_UNBOUNDED` would. Flagged for whoever owns the catalogue; not changed here.

---

## The classification, in one table

Every default on this page, sorted by the rule in [The rule that sorts this page](#the-rule-that-sorts-this-page). All `planned`.

### Baked in — not switchable

| # | Default | Reversal test it fails |
|---|---|---|
| 1 | One serialization front door; the codec mode is pinned; no `mimic_JSON` | a codec named at every call site cannot be swapped later; `:object` mode is not interchange JSON |
| 2 | `Sequel.extension :fiber_concurrency` before connect | thread-keyed checkout under a fiber server is a correctness bug, not a slower option |
| 3 | Bound parameters everywhere (`pg_auto_parameterize`) | literalised SQL is an injection surface and defeats plan reuse. No legitimate slow version |
| 4 | All four Postgres timeouts have a non-zero value | `0` means an unbounded query can hold a connection until someone notices |
| 5 | Column projection from the declaration | `SELECT *` is what an agent writes if the framework makes it easiest |
| 6 | An index on `tenant_id`, leading every index on the table | a missing tenant index is a full scan on every query in the app |
| 7 | An index on every foreign key | Postgres creates none, and says so |
| 8 | Unique constraints are `(tenant_id, …)` | a global unique on tenant data is unrecoverable once two tenants collide |
| 9 | `CREATE INDEX CONCURRENTLY` on non-empty tables, in a non-transactional migration | a blocking index build on a live table is an outage |
| 10 | Bulk insert wherever the framework issues the write | N round trips where one would do, in generated code nobody reviews |
| 11 | UUIDv7 primary keys as the cursor and the tiebreaker | spec item 8. Retrofitting a key strategy is a migration nobody survives |
| 12 | `Vary: HX-Request` (+ `HX-Boosted`); `historyRestoreAsHxRequest: false`; a `screen` path always answers a full page to a non-htmx GET | a fragment cached as a page survives the deploy that fixed it |
| 13 | Tenant-scoped responses are never `public`-cacheable; `hx-history="false"` on them | one CDN edge, two tenants |
| 14 | `tenant_id` in every cache key | a cache key with no tenant is a cross-tenant read |
| 15 | Generational cache keys (declaration digest + `updated_at`), not manual invalidation | "remember to invalidate" fails silently, as a stale page |
| 16 | Job payloads are ids, never records | a serialized record is stale by the time the job runs — a correctness argument first |
| 17 | Exponential backoff is always jittered | synchronized retries recreate the spike that caused the failure |
| 18 | Per-tenant scheduled jobs get a deterministic offset | `cron` per tenant is a thundering herd the app authored itself |
| 19 | `# frozen_string_literal: true` on every file | a shared mutable literal is a bug on any engine ([`00-conventions.md`](00-conventions.md)) |
| 20 | Redaction runs before serialization | a secret that reaches the serializer has already left |

### Default on, switchable

| # | Default | Switch | Seam? |
|---|---|---|---|
| 1 | JSON codec: `:oj` on CRuby, `:stdlib` on TruffleRuby | `use :json, :auto \| :oj \| :stdlib` · `MAGIK_JSON_BACKEND` | **yes — proposed new row for [`../idea/04-swap-points.md`](../idea/04-swap-points.md)** |
| 2 | Connection pool size and timeout | `database pool:, pool_timeout:` | no — configuration |
| 3 | The four timeout values, per process role | `App.define`, per role | no — configuration |
| 4 | Prepared statements, built at boot | `database prepared_statements: false` (a pooler in transaction mode) | no |
| 5 | Response compression (`Rack::Deflater`, `sync: false`, size floor) | on/off, floor, content types | no |
| 6 | ETag + conditional GET | on/off | no |
| 7 | Asset fingerprinting + `max-age=31536000, immutable` | on in production, off in dev | no |
| 8 | Cursor pagination | `index paginate: :offset, max_page: N` — per declaration | no |
| 9 | Cache backend (existing seam; default in-process memory) | `use :cache, :redis` | yes — already listed |
| 10 | Slow-query and per-query logging thresholds | configuration ([`06-observability.md`](06-observability.md)) | no |
| 11 | TruffleRuby configuration (`--jvm` vs native) per process role | deployment | no |

### Opt-in

| # | Feature | When you would want it |
|---|---|---|
| 1 | Fragment cache on a declaration | an expensive render repeated across requests — the only tool here that saves render time rather than transfer. Wants a shared cache backend to be worth declaring |
| 2 | `cache.fetch` in app code | an expensive non-render computation with a natural key and a tolerable staleness window |
| 3 | Request-scoped memo | the same lookup twice in one render. Not an identity map, on purpose |
| 4 | Counter caches (`counts :orders`) | a count displayed on a hot page over a table large enough that a scan hurts. Costs write contention on one row, and a reconciliation job |
| 5 | Offset pagination with `max_page:` | an admin screen where a human genuinely wants page 47 |
| 6 | Job batching | high-volume homogeneous work where per-row retry granularity is not worth N queue rows |
| 7 | Additional composite indexes beyond the generated set | a query shape no declaration expresses |
| 8 | OpenTelemetry export | you have a collector. The local trace and logs are the primary tool either way ([`06-observability.md`](06-observability.md)) |
| 9 | A connection pooler in front of Postgres | process × pool exceeds `max_connections`. Costs `LISTEN`, `SET`, and session advisory locks — see conflict 5 |

---

## Adding to this page

The bar, so it stays a design document rather than a tips list:

| Test | Question |
|---|---|
| Specific to this stack | is it true on TruffleRuby + Falcon + Sequel + Postgres, or is it CRuby folklore? Say which |
| Sorted by reversal | is it baked in, switchable, or opt-in — and does the answer survive the test in [the rule](#the-rule-that-sorts-this-page)? |
| Honest about cost | what does it make worse? A default with no stated cost has not been thought through |
| Measurable | what command re-derives it? A default nobody can verify is a preference |
| Cited or flagged | an upstream claim gets a link and an attribution; anything else gets the word `unverified` |
| No numbers | until something is implemented and something is measured, with the command and the date |
