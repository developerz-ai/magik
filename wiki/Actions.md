# Actions

**Status:** `Planned — not implemented`. Spec Phase 2, build step 3. Nothing on this page runs.
`As of 2026-08-26`.

An `action` is a mutation handler. It is **the only thing in a Magik app that changes data.** A
button, a form, an API resource, a webhook and a job all end up calling one; there is no second place
where a write can happen.

## The shape

```ruby
# app/actions/mark_paid.rb
action :mark_paid, policy: %i[Invoice record_payment] do |params|
  invoice = Invoice.find!(params[:id])

  guard invoice.status == :sent, "only a sent invoice can be marked paid"

  invoice.update(status: :paid, paid_at: Time.now.utc)
  Receivables.settle(invoice)
  SendReceiptEmail.enqueue(invoice_id: invoice.id)

  toast "Invoice #{invoice.number} marked paid"
  refresh :Invoices
end
```

| Piece | Does |
|---|---|
| `params` | the posted parameters, coerced against the form's declared field types |
| `guard` | a precondition. Failing one is a `MAGIK_GUARD_FAILED` with your message, rendered to the user — not a 500 |
| `toast` | transient feedback, swapped into the page by htmx |
| `refresh :Screen` | re-renders the named screen fragment. This is how the page updates without a reload |
| `policy:` | the verb the framework evaluates **before** the block runs. Required, like everywhere else — see [`policy`](Screens-And-Components.md#policy). Opting out is `policy: :public` or `policy: :system`, written down |

## Routing is convention

`action :mark_paid` is `POST /actions/mark_paid`. There is no route file, and a `button` or `form`
referencing the action emits the `hx-post` attribute pointing at it.

| Declaration | Path |
|---|---|
| `action :mark_paid` | `POST /actions/mark_paid` |
| `action :create_invoice` | `POST /actions/create_invoice` |

An action name that collides with an existing route is refused at boot rather than shadowing it.

## Parameters are typed

Params are coerced against the declaring form's field types, or against an explicit `params` block:

```ruby
action :create_invoice do
  params do
    field :customer_id, :uuid,  required: true
    field :amount,      :money, required: true
    field :due_on,      :date
  end

  perform do |params|
    Invoice.create(params.merge(status: :draft))
    refresh :Invoices
  end
end
```

A missing `required:` param is `MAGIK_PARAM_MISSING`; a `Float` posted into a `:money` param is
`MAGIK_MONEY_FLOAT`, refused at the boundary rather than rounded silently.

## Idempotency

A retried mutation must not perform twice. Declare what makes a call the same call:

```ruby
action :charge_invoice do
  idempotent_by :invoice_id, window: "24h"        # a :duration

  perform do |params|
    Billing.charge(Invoice.find!(params[:invoice_id]))
  end
end
```

A second call with the same key inside the window returns the **first** call's result and performs
nothing. This is Phase 5 work; see [Money and ledgers](Money-And-Ledgers.md).

An action that moves money and has no `idempotent_by` is intended to be a boot failure — a payment
you can double-submit is not a bug you get to find in production:

```text
MAGIK_IDEMPOTENCY_REQUIRED: :charge_invoice writes to a ledger with no idempotent_by
  fix: add `idempotent_by :invoice_id` to app/actions/charge_invoice.rb
```

## Actions hold no state

Stateless app servers — architecture decision 9. An action that keeps an instance variable across
requests fails at boot with `MAGIK_STATEFUL_ACTION`. Everything an action needs comes from `params`,
the current tenant, and the database.

## Async work belongs to jobs

An action returns to a rendered page. Work that outlives the request is a `job`:

```ruby
SendReceiptEmail.enqueue(invoice_id: invoice.id)
```

Spawning a fiber or thread inside an action is refused (`MAGIK_ASYNC_OUTSIDE_JOB`). The enqueue and
the row that caused it commit together — see [Jobs](Jobs.md).

## Guardrails

| Guardrail | Fails with | When |
|---|---|---|
| An action is the only thing that mutates | `MAGIK_MUTATION_OUTSIDE_ACTION` | boot |
| An action names a policy verb | `MAGIK_POLICY_UNDECLARED` | boot |
| An action holds no cross-request state | `MAGIK_STATEFUL_ACTION` | boot |
| Async work happens in a job | `MAGIK_ASYNC_OUTSIDE_JOB` | boot |
| A money-moving action declares idempotency | `MAGIK_IDEMPOTENCY_REQUIRED` | boot |
| Params match their declared types | `MAGIK_PARAM_MISSING`, `MAGIK_PARAM_TYPE` | request |
| A guard failure is user-facing, never a 500 | `MAGIK_GUARD_FAILED` | request |

## Swap points

An action itself has no backend to swap. What it calls does: the job queue, the cache it invalidates,
the ledger's storage. See [`docs/idea/04-swap-points.md`](../docs/idea/04-swap-points.md).

## Next

- [Screens and components](Screens-And-Components.md) — what posts to an action.
- [Jobs](Jobs.md) — where the slow half goes.
- [Money and ledgers](Money-And-Ledgers.md) — `idempotent_by` and the ledger rules in full.
- [Testing](Testing.md) — `perform_action` in a test.
