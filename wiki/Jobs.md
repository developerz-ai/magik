# Jobs

**Status:** `Planned — not implemented`. Spec Phase 4, build step 7. Nothing on this page runs.
`As of 2026-08-26`.

A `job` is background work. It is **the only thing in a Magik app that runs asynchronously** —
spawning a fiber or a thread anywhere else is refused at boot, because work the framework cannot see
is work it cannot retry, schedule or observe.

## The shape

```ruby
# app/jobs/send_invoice_email.rb
job :SendInvoiceEmail do
  retries times: 5, backoff: :exponential
  queue :mailers

  perform do |invoice_id:|
    invoice = Invoice.find!(invoice_id)
    Notify.invoice_sent(invoice)
  end
end
```

Enqueue it from an action:

```ruby
SendInvoiceEmail.enqueue(invoice_id: invoice.id)
```

## The enqueue and the write commit together

The default queue is **Postgres-backed and transactional** (Que-style). The job row and the row that
caused it are written in the same transaction:

```ruby
action :send_invoice do |params|
  invoice = Invoice.find!(params[:id])
  invoice.update(status: :sent, sent_at: Time.now.utc)
  SendInvoiceEmail.enqueue(invoice_id: invoice.id)   # same transaction
end
```

Either the invoice is `sent` **and** the email is queued, or neither happened. There is no window
where the update committed and the enqueue was lost, and none where an email goes out for a rollback
that never landed. This is the reason the default queue is the database rather than an external
broker: an external queue cannot join your transaction.

## Scheduling

```ruby
job :SweepOverdue do
  schedule cron: "0 6 * * *", zone: "UTC"

  perform do
    Invoice.overdue.each { |i| NotifyOverdue.enqueue(invoice_id: i.id) }
  end
end

job :RefreshExchangeRates do
  schedule every: 15.minutes
  perform { Rates.refresh! }
end
```

`zone:` is required on a `cron:` schedule. A cron expression with no zone is a job that runs at a
different wall-clock time twice a year and nobody notices until it matters
(`MAGIK_SCHEDULE_ZONE_MISSING`).

## Running workers

```bash
magik worker                       # all queues
magik worker --queue mailers       # one queue
magik worker --concurrency 8
```

Workers are horizontally scalable and hold no coordinating state: add processes, add throughput. Two
workers never claim the same job.

## Retries and failure

| Setting | Meaning |
|---|---|
| `retries times: N` | attempts before the job is dead-lettered |
| `backoff: :exponential` | the default. `:linear` and a lambda are also accepted |
| `discard_on` | an error class that means "this will never succeed" — do not retry |
| `timeout:` | how long one attempt may take before it is abandoned and retried |

A job is **at-least-once**. An attempt killed after its side effect but before its acknowledgement
replays. Handlers must be idempotent, and a job whose side effect is money movement must declare
`idempotent_by` on the action it calls — see [Money and ledgers](Money-And-Ledgers.md).

## Backends

| Backend | Role |
|---|---|
| Postgres | the **default**. Transactional, no new infrastructure |
| Kafka | the swap, for volumes and fanout the database should not carry |

```ruby
# config/backends.rb
jobs :kafka, brokers: ENV.fetch("KAFKA_BROKERS")
```

One config key, zero app code changes. **The transactional guarantee is a property of the Postgres
backend, not of the abstraction** — swapping to Kafka buys throughput and loses the shared
transaction. That trade is stated here rather than discovered later; see
[`docs/idea/04-swap-points.md`](../docs/idea/04-swap-points.md).

Which gem the Postgres backend wraps, why advisory locks rather than `SELECT … FOR UPDATE SKIP
LOCKED`, what a CPU-bound job costs its worker, and where a Postgres queue stops being the right
answer:
[`docs/architecture/11-jobs-backend.md`](../docs/architecture/11-jobs-backend.md).

## Guardrails

| Guardrail | Fails with | When |
|---|---|---|
| Async work happens in a job | `MAGIK_ASYNC_OUTSIDE_JOB` | boot |
| A `cron:` schedule names a timezone | `MAGIK_SCHEDULE_ZONE_MISSING` | boot |
| A job's arguments are serialisable | `MAGIK_JOB_ARGS_UNSERIALISABLE` | enqueue |
| A job that moves money runs through an idempotent action | `MAGIK_IDEMPOTENCY_REQUIRED` | boot |

## Next

- [Actions](Actions.md) — where jobs are enqueued from.
- [Money and ledgers](Money-And-Ledgers.md) — idempotency, in full.
- [Realtime](Realtime.md) — the other asynchronous path to a user.
- [Testing](Testing.md) — `assert_enqueued`.
- [The jobs backend](../docs/architecture/11-jobs-backend.md) — the engine decision, the mechanism, and the ceiling.
