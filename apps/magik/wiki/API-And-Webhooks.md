# API and webhooks

**Status:** `Planned — not implemented`. Spec Phase 6, build step 11 — after auth/billing/admin,
because the admin panel is the first real consumer of the resource DSL. Nothing on this page runs.
`As of 2026-08-26`.

## A REST API

```ruby
# app/api/v1.rb
api :V1 do
  auth :bearer, :api_key

  resource :invoices, model: :Invoice, policy: %i[Invoice read] do
    fields     :id, :number, :amount, :status, :due_on, :customer_id
    filterable :status, :customer_id, :due_on
    sortable   :due_on, :amount, :created_at
    searchable :number
    writable   :customer_id, :amount, :due_on

    index   scope: -> { Invoice.outstanding }, per_page: 50
    show
    create  action: :create_invoice
    update  action: :update_invoice
    destroy action: :void_invoice
  end

  resource :customers, model: :Customer, policy: %i[Customer read] do
    fields :id, :name, :email
    index
    show
  end
end
```

| Piece | Does |
|---|---|
| `index` | paginated list. Cursor pagination; `per_page` is a ceiling, not a suggestion |
| `show` | one record, tenant-scoped like everything else |
| `create` / `update` / `destroy` | delegate to an **existing action**. The API never reimplements the mutation a screen already performs |
| `policy:` | the verb evaluated before anything is read or written. Required, exactly as on a screen — see [`policy`](Screens-And-Components.md#policy) |
| `fields` | what leaves the building. A field not on the list is not in the response |
| `filterable` / `sortable` / `searchable` | the allowed sets. A filter on an undeclared column is a 400, not an open query surface |
| `writable` | what `create` and `update` accept. A whitelist, deliberately — not a `read_only` blacklist |

**Those five declarations are one vocabulary, shared with `admin_panel`, `data_table` and `screen`.**
There is not one concept here but five — shown, filtered, sorted, searched, written — so "one
spelling" means one word per role, identical on every surface. They are declarations inside the
block, never per-verb options; `per_page:` stays an option, because it is a scalar setting rather
than a field subset.

Serialization follows the model's field types: `:money` renders as minor units plus a currency, never
a float.

Routes are convention: `GET /api/v1/invoices`, `POST /api/v1/invoices`, `PATCH
/api/v1/invoices/:id`. No route file.

**The API and the UI share one mutation path.** `create` names `:create_invoice`, the same action the
form on the screen posts to — so there is never a second implementation to keep in step, and never a
validation the API skips.

## API authentication

| Strategy | For |
|---|---|
| `:bearer` | server-to-server tokens |
| `:api_key` | long-lived integration keys, scoped and revocable |
| `:jwt` | mobile clients |

```ruby
api :V1 do
  auth :bearer
  rate_limit by: :plan, default: 1000, window: "1h"    # a :duration
end
```

Rate limits are declared **by plan**, so the limit follows the subscription rather than being
hard-coded per route. A request over the limit gets a `429` with a `Retry-After`, and the code
`MAGIK_API_RATE_LIMITED`.

## Incoming webhooks

```ruby
# app/webhooks/stripe_incoming.rb
webhook :incoming, :stripe do
  verify_signature header: "Stripe-Signature", secret: ENV.fetch("STRIPE_WEBHOOK_SECRET")

  on "invoice.payment_succeeded" do |event|
    MarkInvoicePaid.enqueue(external_id: event.dig(:data, :object, :id))
  end

  on "customer.subscription.deleted" do |event|
    CancelSubscription.enqueue(external_id: event.dig(:data, :object, :customer))
  end
end
```

| Rule | Detail |
|---|---|
| Signature verification runs **before** the handler | an unverified body never reaches your code. A bad signature is `MAGIK_WEBHOOK_SIGNATURE_INVALID` and a `401` |
| A handler enqueues | webhook endpoints answer fast and do the work in a job. A provider that times out retries, and now you have two |
| Delivery is at-least-once | providers redeliver. Handlers are idempotent, and a money-moving one declares `idempotent_by` |
| An unhandled event type is a no-op `200` | not a `404`. Providers disable endpoints that return errors |

Routed to `POST /webhooks/stripe` by convention.

## Outgoing webhooks

```ruby
# app/webhooks/invoice_paid_outgoing.rb
webhook :outgoing, :invoice_paid do
  fires_on :Invoice, :updated, when: -> (i) { i.status == :paid }
  deliver_to -> (invoice) { invoice.tenant.webhook_endpoints }
  sign_with  :hmac_sha256, secret: -> (endpoint) { endpoint.secret }
  retries times: 8, backoff: :exponential
end
```

Deliveries go through the job queue, are retried with backoff, and are inspectable — a customer asking
"did you send it" gets an answer from the delivery log rather than from a grep.

## Guardrails

| Guardrail | Fails with | When |
|---|---|---|
| A resource names a policy verb | `MAGIK_POLICY_UNDECLARED` | boot |
| An incoming webhook declares signature verification | `MAGIK_WEBHOOK_UNVERIFIED` | boot |
| An API resource's mutations delegate to actions | `MAGIK_API_INLINE_MUTATION` | boot |
| A filter names a declared column | `MAGIK_API_FILTER_UNDECLARED` | request |
| An index has a page ceiling | `MAGIK_API_PAGINATION_UNBOUNDED` | boot |
| Serialized fields are declared explicitly | `MAGIK_API_SERIALIZER_UNDECLARED` | boot |
| Everything stays tenant-scoped | `MAGIK_SCALE_UNSCOPED_QUERY` | `magik check --scale` |

## Swap points

| Seam | Default | Swap to |
|---|---|---|
| Rate-limit store | Postgres | Redis, via `config/backends.rb` |
| Outgoing delivery transport | the job queue | whatever the job backend is swapped to |
| Serialization | Oj | — wrapped, not reimplemented |
| The API style | REST | **not a swap point.** No GraphQL layer is planned |

## Next

- [Actions](Actions.md) — what every resource mutation delegates to.
- [Screens and components](Screens-And-Components.md#policy) — `policy`. An API resource evaluates the same verb the screen does.
- [Jobs](Jobs.md) — where webhook handling actually happens.
- [Auth, billing, admin](Auth-Billing-Admin.md) — plans, which the rate limits key off.
