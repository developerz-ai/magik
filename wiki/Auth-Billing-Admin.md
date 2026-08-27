# Auth, billing, admin

**Status:** `Planned — not implemented`. Spec Phase 7, build step 10. Nothing on this page runs.
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
    session_ttl "14d"                    # a :duration — a unit-suffixed string, coerced at boot
    password_rules min_length: 12
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

`auth` identifies; it does not decide. Authorization is [`policy`](Screens-And-Components.md#policy),
a phase 2 construct evaluated by every surface — `auth` supplies the actor and nothing changes in the
policy layer at that handover.

### Teams, and the abuse defaults

Phase 7 also carries the data model authorization needs in order to decide anything, and the
defaults an agent building a signup flow will not add on its own.

| Planned | Detail |
|---|---|
| Teams, memberships, seats, invitations | generated the way `auth` generates accounts. Every B2B SaaS needs it in week one, and `policy` needs it to answer "is this actor in this tenant" |
| Login throttling and lockout | **on by default**, not a documented recommendation |
| Enumeration resistance | login and reset answer identically for a known and an unknown address, with equal timing; comparisons are constant-time. **On by default** |
| A bot-challenge seam | **off** by default. A CAPTCHA has a real accessibility and privacy cost, and the vendor space is what swap points exist to survive |
| Disposable-domain policy on signup | off by default |
| Impersonation | a mandatory audit record and a visible banner. Neither is optional, and neither is a setting |
| Feature flags | a **factory over `policy`** — a flag is an authorization rule whose subject is a cohort rather than a role. Not a second permission system |

## Billing

```ruby
billing provider: :stripe do
  plan :free,   price: 0
  plan :pro,    price: Money.usd("29.00"), interval: :month, trial: "14d"   # a :duration
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
# app/admin/invoice.rb
admin_panel :Invoice, policy: %i[Invoice administer] do
  list do
    fields      :number, :customer, :total, :status, :due_on
    filterable  :status, :select, values: %i[draft issued paid void]
    filterable  :due_on, :date_range
    searchable  :number, "customer.name"
    saved_view  :overdue, label: "Overdue", scope: :overdue
    bulk_action :void, action: :void_invoice, args: { reason: :string }, confirm: true
    exportable  :csv
  end

  show do
    panel t("admin.details") do
      field :number, :status, :total, :due_on
    end
    tab t("admin.lines") do
      has_many :line_items, display: :table
    end
    sidebar do
      field  :created_at, :issued_at
      action :issue_invoice, when: ->(i) { i.draft? }
    end
  end

  form do
    writable :customer_id, :due_on
    writable :status, in: %i[edit]        # per-view visibility
    fields   :total, :issued_at           # shown, never written
  end
end
```

Auto CRUD, generated from the model declaration rather than scaffolded into files you then have to
maintain. Adding a field to the model adds it to the admin panel; there is no second place to update.

**`policy:` is required.** The admin is by construction the surface with the broadest data access in
the application, and an admin panel without a policy is a security hole with a nice table on top. It
is not a special rule for the admin — it is [`MAGIK_POLICY_UNDECLARED`](Error-Codes.md#authorization-layout-and-uploads),
the same code every other surface answers to.

### All four views, and one field vocabulary

Benchmarked against [Avo](https://avohq.io). *An admin who can list orders and cannot open one is not
an admin* — so `admin_panel` carries a `list`, a `show` with panels, tabs and a sidebar, and a `form`
with per-view field visibility.

The five declarations inside those blocks are **the same five words `api`, `data_table` and `screen`
use** — one vocabulary for "which fields participate", because an `admin_panel` is a projection of
the model rather than a second description of it.

| Declaration | Means |
|---|---|
| `fields` | shown |
| `filterable` | filtered on, with a typed filter |
| `sortable` | sorted by |
| `searchable` | matched by the search box |
| `writable` | writable. A whitelist, deliberately — not a `read_only` blacklist |

They are declarations inside the block, never per-verb options. `per_page:` stays an option: it is a
scalar setting, not a field subset.

Deliberately **not** copied from Avo: kanban, map view and a media-library browser. Those are product
surfaces, not admin primitives.

| Rule | Detail |
|---|---|
| It is a real screen | the admin panel is the same rendering pipeline, the same authorization, the same tenant scoping. Not a separate app with its own rules |
| Actions are **your** actions | `action :issue_invoice` names the action a customer-facing button also calls. There is no admin-only write path that skips your guards |
| Access is a policy | `policy:` is required, and the verb is evaluated by the same evaluator a screen uses |
| Audited | writes made through the admin panel go through `audited` like any other write |

### App-wide admin

```ruby
App.define :Myapp do
  admin do
    searchable    :Invoice, :Customer, :Account       # global, across resources
    impersonation policy: %i[Account impersonate], banner: true, audited: true
    dashboard do
      metric :mrr, from: :monthly_recurring_revenue
      chart  :bar, data: :signups_by_week
    end
  end
end
```

## Guardrails

| Guardrail | Fails with | When |
|---|---|---|
| A tenant strategy is declared | `MAGIK_TENANT_STRATEGY_MISSING` | boot |
| An admin panel names a policy verb | `MAGIK_POLICY_UNDECLARED` | boot |
| The verb it names is declared | `MAGIK_POLICY_UNKNOWN_VERB` | boot |
| No PAN-shaped fields | `MAGIK_PAN_FIELD_FORBIDDEN` | boot |
| Billing webhooks are signature-verified | `MAGIK_WEBHOOK_UNVERIFIED` | boot |
| An admin action delegates to a real action | `MAGIK_ADMIN_INLINE_MUTATION` | boot |

## Swap points

| Seam | Default | Swap to |
|---|---|---|
| Billing provider | Stripe | Paddle, via `billing provider:` |
| Auth engine | Rodauth | — wrapped, not reimplemented |
| Tenant resolution | `:subdomain` | `:path`, `:header`, or a lambda |
| Bot challenge | **off** | a provider, behind the seam. Off is the default, deliberately |
| Multi-tenancy itself | — | **not a swap point.** Architecture decision 8 |
| Authorization itself | — | **not a swap point.** A second authorization backend is a second authorization system, which is the failure the design is organised against |

## Next

- [Screens and components](Screens-And-Components.md#policy) — `policy`, the verb every surface names.
- [Models](Models.md) — what the admin panel is generated from.
- [API and webhooks](API-And-Webhooks.md) — plans and rate limits.
- [Money and ledgers](Money-And-Ledgers.md) — what billing writes into.
