# Realtime

**Status:** `Planned — not implemented`. Spec Phase 3, build step 6. Nothing on this page runs.
`As of 2026-08-26`.

Realtime in Magik is **opt-in per screen**. A screen with no `live` declaration opens no socket,
subscribes to nothing, and costs nothing. That is architecture decision 5, and it is the deliberate
inverse of the Meteor model where every page paid for reactivity whether it used it or not.

## Making one value live

```ruby
# app/screens/invoices.rb
screen :Invoices, policy: %i[Invoice read] do
  state :invoices, -> { Invoice.overdue.eager(:customer) }
  live  :invoices, on: "invoices:tenant"

  body do
    data_table :invoices, columns: %i[number customer amount due_on status]
  end
end
```

One line. The rest of the screen is unchanged, and every other screen in the app is still plain
request/response.

## A channel

```ruby
# app/channels/invoice_updates.rb
channel :invoice_updates, policy: %i[Invoice read] do
  subscribe_to "invoices:tenant"

  on_create :Invoice do |invoice|
    broadcast "invoices:tenant", :inserted, invoice
  end

  on_update :Invoice do |invoice|
    broadcast "invoices:tenant", :changed, invoice
  end
end
```

Or broadcast explicitly from an action, which is the common case:

```ruby
action :mark_paid, policy: %i[Invoice record_payment] do |params|
  invoice = Invoice.find!(params[:id])
  invoice.update(status: :paid)
  broadcast "invoices:tenant", :changed, invoice
end
```

## Presence

```ruby
screen :InvoiceDetail do
  presence on: "invoice:#{invoice.id}", as: :viewers

  body do
    card title: "Invoice" do
      list :viewers, template: :avatar
    end
  end
end
```

Who is here, and where their cursor is. The same opt-in rule applies: a screen without `presence`
tracks nothing.

## Channel names are tenant-scoped

A channel name is scoped to the current tenant automatically. `"invoices:tenant"` in one tenant never
reaches another. A channel name that would cross tenants is refused at boot
(`MAGIK_REALTIME_CHANNEL_CROSSES_TENANT`) — multi-tenancy that leaks over the realtime layer is the failure
mode nobody tests for.

## Backends

| Backend | Role |
|---|---|
| Postgres `LISTEN`/`NOTIFY` | the **default**. No new infrastructure — you already have the database |
| Redis pub/sub | the swap, for fanout beyond what one Postgres connection wants to carry |

```ruby
# config/backends.rb
realtime :redis, url: ENV.fetch("REDIS_URL")
```

One config key, zero app code changes. That is the swap-point contract, and per the spec it needs a
passing test on both sides before it is claimed anywhere — see
[`docs/idea/04-swap-points.md`](../docs/idea/04-swap-points.md).

## What realtime is not

| Not | Detail |
|---|---|
| Offline sync | **no offline support**, at any phase. The server is the single source of truth. A dropped connection means a stale page that refreshes on reconnect, not a local write log that merges later |
| A client-side data store | there is no client cache to invalidate. A broadcast causes a **server** re-render, swapped in by htmx |
| Free | it is opt-in precisely because it is not free. Undeclared, it costs nothing; declared, it costs a subscription and a connection |
| Measured | no capacity number appears on this page, because none has been measured. When one exists it will be a committed benchmark result with the command that reproduces it |

## Guardrails

| Guardrail | Fails with | When |
|---|---|---|
| A `live` declaration names a channel that exists | `MAGIK_REALTIME_CHANNEL_UNDECLARED` | boot |
| A channel names a policy verb | `MAGIK_POLICY_UNDECLARED` | boot |
| A policy predicate performs no I/O | `MAGIK_POLICY_IO` | boot |
| A channel name cannot cross tenants | `MAGIK_REALTIME_CHANNEL_CROSSES_TENANT` | boot |
| A screen with `live` still holds no cross-request state | `MAGIK_RENDER_SCREEN_STATEFUL` | boot |

## Next

- [Screens and components](Screens-And-Components.md) — the screen a `live` line goes on.
- [Screens and components](Screens-And-Components.md#policy) — `policy`. A channel evaluates **the same verb as the request path**; there is no second door to the data. It is also why a policy predicate may not query: a `live` screen re-evaluates one per subscriber per change.
- [Jobs](Jobs.md) — the other way work reaches a user asynchronously.
- [Testing](Testing.md) — `assert_broadcast`.
