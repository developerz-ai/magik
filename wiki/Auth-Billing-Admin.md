# Auth, billing, admin

**Status:** `Planned — not implemented`. Spec Phase 7, build step 9. Nothing on this page runs.
`As of 2026-08-26`.

The batteries. Three declarations that replace the three things every SaaS rewrites badly: who you
are, what you pay, and the internal screen someone needs at 2am.

## Auth

Backed by [Rodauth](https://rodauth.jeremyevans.net) — wrapped, not reimplemented.

```ruby
# config/app.rb
App.define :Myapp do
  auth do
    strategy :password
    oauth_providers :google, :github
    two_factor :totp, :recovery_codes
    session_timeout 14.days
    password_requirements min_length: 12
  end

  tenant_by :subdomain
end
```

That generates the full flow — registration, login, logout, password reset, email verification, OAuth
callbacks, TOTP enrolment, recovery codes — as screens and actions you can override individually
rather than a scaffold you have to maintain.

| Declaration | Gives you |
|---|---|
| `strategy :password` | email + password, with the hashing and timing-safe comparison already right |
| `oauth_providers` | the provider dance and account linking |
| `two_factor` | enrolment, challenge, recovery codes |
| `tenant_by :subdomain` | the tenant resolved per request; every model scoped to it |

`tenant_by` also accepts `:path`, `:header` and a lambda. **Multi-tenancy is not optional** — the
question is only how the tenant is identified.

## Billing

```ruby
billing provider: :stripe do
  plan :free,   price: 0
  plan :pro,    price: Money.usd("29.00"), interval: :month, trial: 14.days
  plan :scale,  price: Money.usd("99.00"), interval: :month
  plan :usage,  metered: :api_calls, unit_price: Money.usd("0.001")

  on_subscribe   { |tenant, plan| tenant.update(plan: plan.name) }
  on_cancel      { |tenant| tenant.update(plan: :free) }
  on_payment_failed { |tenant| NotifyPaymentFailed.enqueue(tenant_id: tenant.id) }
end
```

| Handles | Detail |
|---|---|
| Subscriptions and trials | lifecycle, proration, upgrades and downgrades |
| Metered billing | usage reported through the job queue, not on the request path |
| Provider webhooks | wired to the incoming webhook DSL, signature-verified — see [API and webhooks](API-And-Webhooks.md) |
| Out-of-order events | provider webhooks arrive out of order; the subscription state machine is meant to be written for that rather than surprised by it |

Plans declared here are what `rate_limit by: :plan` reads in the API.

**No card data touches your database.** `field :card_number` is refused at boot; you store a provider
token. See [Money and ledgers](Money-And-Ledgers.md).

Provider is a swap point: `:stripe` or `:paddle`, one config key.

## Admin panel

```ruby
# app/screens/admin.rb
admin_panel :Invoice do
  list_display :number, :customer, :amount, :status, :due_on
  filterable   :status, :due_on
  searchable   :number, :customer_name
  editable     :status, :due_on
  readonly     :amount, :created_at

  action :mark_paid, label: "Mark paid", confirm: true
  scope  :overdue,   label: "Overdue only"
end
```

Auto CRUD, generated from the model declaration rather than scaffolded into files you then have to
maintain. Adding a field to the model adds it to the admin panel; there is no second place to update.

| Rule | Detail |
|---|---|
| It is a real screen | the admin panel is the same rendering pipeline, the same auth, the same tenant scoping. Not a separate app with its own rules |
| Actions are **your** actions | `action :mark_paid` names the action a customer-facing button also calls. There is no admin-only write path that skips your guards |
| Access is a policy | an admin panel with no declared access rule is a boot failure (`MAGIK_ADMIN_UNPROTECTED`) |
| Audited | writes made through the admin panel go through `audited` like any other write |

## Guardrails

| Guardrail | Fails with | When |
|---|---|---|
| A tenant strategy is declared | `MAGIK_TENANT_STRATEGY_MISSING` | boot |
| An admin panel declares who may reach it | `MAGIK_ADMIN_UNPROTECTED` | boot |
| No PAN-shaped fields | `MAGIK_PAN_FIELD_FORBIDDEN` | boot |
| Billing webhooks are signature-verified | `MAGIK_WEBHOOK_UNVERIFIED` | boot |
| An admin action delegates to a real action | `MAGIK_ADMIN_INLINE_MUTATION` | boot |

## Swap points

| Seam | Default | Swap to |
|---|---|---|
| Billing provider | Stripe | Paddle, via `billing provider:` |
| Auth engine | Rodauth | — wrapped, not reimplemented |
| Tenant resolution | `:subdomain` | `:path`, `:header`, or a lambda |
| Multi-tenancy itself | — | **not a swap point.** Architecture decision 8 |

## Next

- [Models](Models.md) — what the admin panel is generated from.
- [API and webhooks](API-And-Webhooks.md) — plans and rate limits.
- [Money and ledgers](Money-And-Ledgers.md) — what billing writes into.
