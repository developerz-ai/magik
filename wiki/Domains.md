# Domains

**Status:** `Planned — not implemented`. Spec architecture decision 12, build step 13 — the last
thing built. Nothing on this page runs. `As of 2026-08-26`.

Domains are how a Magik app stops being one large namespace. A domain owns its own models, screens,
actions and jobs, declares what it depends on, and declares what it lets others touch. **A domain
cannot reach another domain's models directly** — and that is enforced at boot, not reviewed in a
pull request.

**Small apps have no domains.** A fresh `magik new` app has no `domains/` directory. Introducing one
is something you do when the app has earned it — see
[when to move](Project-Layout.md#when-to-move).

## A domain declaration

```ruby
# domains/billing/domain.rb
domain :Billing do
  depends_on :Identity

  exposes :Invoice,          # a model, read-only to others
          :charge,           # an action
          :outstanding_total # a query method

  publishes_events :invoice_paid, :invoice_voided, :subscription_started
end
```

```ruby
# domains/reporting/domain.rb
domain :Reporting do
  depends_on :Billing
  subscribes :invoice_paid, :invoice_voided
end
```

| Declaration | Means |
|---|---|
| `depends_on` | this domain may use another's **exposed** interface. The graph must be acyclic |
| `exposes` | the only names other domains can reach. Everything else is private, including every other model |
| `publishes_events` | the events this domain emits. Another domain may subscribe without depending on it |
| `subscribes` | events this domain reacts to. Creates no dependency edge — that is the point |

## The layout

A domain contains the **same `app/` tree** a flat app has. It is a namespace wrapped around an
identical tree, not a different tree — which is what makes the move mechanical.

```text
domains/
├── billing/
│   ├── domain.rb
│   ├── app/                         # the same tree a flat app has, one level in
│   │   ├── models/invoice.rb        # model :Invoice — private unless exposed
│   │   ├── screens/invoices.rb
│   │   ├── actions/mark_paid.rb
│   │   ├── jobs/sweep_overdue.rb
│   │   └── components/              # visible only inside this domain
│   └── test/
├── identity/
│   ├── domain.rb
│   └── app/models/user.rb
└── reporting/
    ├── domain.rb
    ├── app/screens/revenue.rb
    └── test/
```

That sameness is what makes moving from a flat app to a domained one `git mv` plus one file — see
[Project layout](Project-Layout.md#the-migration-is-mechanical).

## What enforcement looks like

Reach across a boundary and the app does not boot:

```text
MAGIK_DOMAIN_BOUNDARY: :Reporting reads :Billing::Invoice directly
  cause: domains/reporting/app/screens/revenue.rb:14 references Billing::Invoice, which :Billing does not expose
  fix:   add `exposes :Invoice` to domains/billing/domain.rb,
         or subscribe to :invoice_paid and keep your own projection
```

| Violation | Code |
|---|---|
| Direct model access across a boundary | `MAGIK_DOMAIN_BOUNDARY` |
| A `depends_on` cycle | `MAGIK_DOMAIN_CYCLE` |
| Depending on a domain that does not exist | `MAGIK_DOMAIN_UNKNOWN` |
| Subscribing to an event nobody publishes | `MAGIK_DOMAIN_UNKNOWN_EVENT` |
| A file in `domains/x/` declaring something in another domain's namespace | `MAGIK_CHECK_DECLARATION_MISPLACED` |

Boot time, every time. A boundary you can cross by accident is documentation, not a boundary.

## The two ways to talk

### Through the exposed interface — synchronous, creates a dependency

```ruby
# domains/reporting/app/screens/revenue.rb
screen :Revenue, policy: %i[Invoice read] do
  state :total, -> { Billing.outstanding_total }     # an exposed method, not a model
end
```

Use it when you need an answer now and the coupling is one you accept.

### Through an event — asynchronous, creates no dependency

```ruby
# domains/billing/app/actions/mark_paid.rb
action :mark_paid, policy: %i[Invoice record_payment] do |params|
  invoice = Invoice.find!(params[:id])
  invoice.update(status: :paid)
  publish :invoice_paid, invoice_id: invoice.id, amount: invoice.amount
end
```

```ruby
# domains/reporting/app/subscribers/invoice_paid.rb
on :invoice_paid do |event|
  RevenueRollup.record(event[:amount], at: event[:at])
end
```

`Reporting` needs no `depends_on :Billing` to subscribe. Events are delivered through the job queue,
so a slow subscriber never slows down the publisher, and a failing subscriber retries rather than
rolling back the publisher's transaction. See [Jobs](Jobs.md).

**Prefer events.** A dependency edge you did not need is a refactor you will pay for.

## Inspecting the graph

```bash
magik check --domains          # violations, cycles, unpublished events
magik domains --json           # the graph as data: nodes, edges, exposures, events
magik domains --graph          # a rendered dependency graph
```

`magik check --domains` is the one to put in CI. A boundary that is only enforced on a developer's
machine is a boundary that erodes.

## Guardrails

| Guardrail | Fails with | When |
|---|---|---|
| No direct cross-domain model access | `MAGIK_DOMAIN_BOUNDARY` | boot |
| The dependency graph is acyclic | `MAGIK_DOMAIN_CYCLE` | boot |
| Every subscribed event is published by someone | `MAGIK_DOMAIN_UNKNOWN_EVENT` | boot |
| A declaration sits in the domain that owns it | `MAGIK_CHECK_DECLARATION_MISPLACED` | boot |
| Tenant scoping crosses no domain boundary either | `MAGIK_SCALE_UNSCOPED_QUERY` | `magik check --scale` |

## What domains are not

| Not | Detail |
|---|---|
| Microservices | one process, one database, one deploy. A domain is a compile-time wall, not a network hop |
| Free | every boundary is a place where a change now needs two edits. Do not draw one before the app has earned it |
| A promise of extraction | a domain boundary is a **plausible** seam for a future service. Nothing here promises the extraction will be easy, and no page should imply it |

## Next

- [Project layout](Project-Layout.md) — the flat-to-domains migration, step by step.
- [Jobs](Jobs.md) — how events are delivered.
- [`docs/idea/03-guardrails.md`](../docs/idea/03-guardrails.md) — why boot-time enforcement.
- [CLI reference](CLI-Reference.md) — `magik check`.
