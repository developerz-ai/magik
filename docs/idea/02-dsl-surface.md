# DSL surface

Every construct in the Magik grammar, in its intended Ruby shape, grouped by the spec phase that introduces it.

**Status:** spec only — every construct on this page is `planned`. No DSL method exists in `lib/`; the code blocks are design targets an implementer works from, not transcripts. Reviewed 2026-08-26.

**Vocabulary.** Four concepts recur across constructs and each has exactly one spelling — D1 durations, D2 preconditions, D3 field subsets, D4 uniqueness. This page uses them throughout, and a line that shows one carries an inline `D<n>` marker pointing at the reasoning in [`00-build-spec.md`](00-build-spec.md)'s *DSL vocabulary* section rather than repeating it.

**Every Ruby block on this page parses.** Re-derive by extracting each ` ```ruby ` block and running `ruby -c` over the concatenation. A spelling that has not been parsed has not been designed.

## The grammar

One shape, everywhere. A construct is a **keyword, a name, and a block of declarations**; options are keyword arguments; behaviour is a nested block. That uniformity is axiom 2 of [`01-thesis.md`](01-thesis.md) and it is what lets an agent that has learned `model` write a `job` without reading further.

```ruby
keyword :Name, option: value do
  declaration :name, option: value
  behaviour do |args|
    # plain Ruby
  end
end
```

| Rule | Detail |
|---|---|
| Names | `:PascalCase` for things that become constants (`model`, `screen`, `job`, `ledger`, `api`, `flow`, `component`, `test`, `domain`, `migrate`). `:snake_case` for things that become methods or routes (`action`, `channel`, `notification`, `webhook`). |
| Declarations | say *what*. `field`, `prop`, `account`, `plan`, `step`, `resource` — no side effects, evaluated once at boot. |
| Behaviour blocks | say *how*. `body`, `perform`, `up`/`down`, `on_create`, `entry` — evaluated per request, per job, per event. |
| Options | keyword arguments only. No positional booleans, ever. |
| Registration | declaring registers into the app registry; the registry is frozen when boot completes, which is what makes the stateless-server guardrail checkable ([`03-guardrails.md`](03-guardrails.md)). |

## Every construct

| Construct | Phase | Kind | One line | Status |
|---|---|---|---|---|
| [`App.define`](#appdefine) | 1 | root | the app composition root and the only boot entry point | planned |
| [`model`](#model) | 1 | declaration | a table, its fields, its associations and its invariants | planned |
| [`migrate`](#migrate) | 1 | declaration | a reversible schema change over Sequel migrations | planned |
| [`component`](#component) | 2 | declaration | a reusable UI fragment compiling to HTML + `hx-*` | planned |
| [`screen`](#screen) | 2 | declaration | a page-level component, auto-routed | planned |
| [`action`](#action) | 2 | behaviour | a mutation handler, auto-wired to an htmx POST | planned |
| [`policy`](#policy) | 2 | declaration | one authorization rule set, evaluated identically in every surface | planned |
| [`layout`](#layout) | 2 | declaration | the application shell — sidebar, topbar, nav, breadcrumbs, responsive collapse | planned |
| [`channel`](#channel-live-broadcast-presence) | 3 | declaration | a named realtime topic and its source events | planned |
| [`live`](#channel-live-broadcast-presence) | 3 | declaration | opt a single screen state variable into server push | planned |
| [`broadcast`](#channel-live-broadcast-presence) | 3 | behaviour | publish an event to a channel | planned |
| [`presence`](#channel-live-broadcast-presence) | 3 | declaration | online/cursor tracking on a channel | planned |
| [`job`](#job) | 4 | declaration | durable background work with retries and a schedule | planned |
| [`attachment`](#attachment) | 4b | declaration | a file on a model, with derivatives, validation and signed delivery | planned |
| [`ledger`](#ledger) | 5 | declaration | double-entry accounts and entries, balance-checked at boot | planned |
| [`audited` / `immutable_after`](#audited--immutable_after--idempotent_by) | 5 | annotation | automatic audit trail; append-only after a point in time | planned |
| [`idempotent_by`](#audited--immutable_after--idempotent_by) | 5 | annotation | dedupe a retried mutation on a caller-supplied key | planned |
| [`flow`](#flow) | 5 | declaration | a multi-step wizard with server-held step state | planned |
| [`api`](#api) | 6 | declaration | a versioned REST surface over models | planned |
| [`webhook`](#webhook) | 6 | declaration | signed inbound and outbound HTTP events | planned |
| [`auth`](#auth) | 7 | declaration | the full auth flow, Rodauth-backed | planned |
| [`billing`](#billing) | 7 | declaration | plans, trials, subscriptions, metered usage | planned |
| [`admin_panel`](#admin_panel) | 7 | declaration | auto CRUD admin for one model | planned |
| [`tenant_by`](#appdefine) | 7 | declaration | how a request resolves to a tenant | planned |
| [`locales` / `translatable`](#locales--translatable) | 8 | declaration | the locale set and per-field translation | planned |
| [`pwa`](#pwa) | 8 | declaration | installable app metadata — **no offline caching** | planned |
| [`notification`](#notification) | 8 | declaration | one message, several delivery channels | planned |
| [`test`](#test) | 9 | declaration | a test group compiling to Minitest | planned |
| [`domain`](#domain) | 12 | declaration | a module boundary enforced at boot | planned |

---

## Phase 1 — Foundation

### `App.define`

The composition root. One per app, in `config/app.rb`. Nothing outside it is loaded implicitly.

```ruby
App.define :Shop do
  database url: ENV.fetch("DATABASE_URL")

  tenant_by :subdomain          # phase 7 — how a request resolves to a tenant
  time_zone "UTC"               # storage zone; rendering always names its own

  use :cache,    :memory        # every `use` is a swap point — 04-swap-points.md
  use :jobs,     :postgres
  use :realtime, :postgres
  use :search,   :postgres

  load "app/models", "app/screens", "app/actions", "app/jobs"
end
```

| Rule | Detail |
|---|---|
| Boot order | `use` seams resolve → `load` evaluates declarations → guardrails run → registry frozen → server binds. A guardrail failure aborts before the socket opens. |
| `use` | the only place a backend is named. App code never mentions Redis, Kafka or Postgres by name. |
| Idempotence | `App.define` may run exactly once per process; a second call raises `MAGIK_BOOT_REDEFINED`. |

### `model`

Wraps Sequel. Explicit queries, no lazy-loading magic, `tenant_id` and a UUIDv7 primary key injected on every model.

```ruby
model :Order do
  field :reference, :string,    required: true, unique: true
  field :status,    :enum,      values: %i[draft placed captured refunded], default: :draft
  field :total,     :money,     currency: :usd
  field :placed_at, :timestamp
  field :notes,     :text,      translatable: true      # phase 8

  computed(:outstanding, :money) { total - paid_total }

  belongs_to :customer
  has_many   :line_items, model: :LineItem

  validate :reference, format: /\A[A-Z0-9-]{6,}\z/
  validate :total,     min: money(0, :usd)

  scope :recent do
    where(status: :placed).order(Sequel.desc(:placed_at))
  end

  audited                        # phase 5
  immutable_after :placed_at     # phase 5
end
```

| Element | Contract |
|---|---|
| `field` | name, type, keyword options. Types: `:string`, `:text`, `:integer`, `:decimal`, `:boolean`, `:money`, `:duration`, `:timestamp`, `:date`, `:uuid`, `:json`, `:enum`, `:vector`, `:file`. |
| `:money` | integer minor units plus a currency. A float assigned to one raises rather than rounding ([`03-guardrails.md`](03-guardrails.md)). |
| `:duration` | a unit-suffixed string coerced at boot — `"14d"`, `"10m"`, `"90s"`. A malformed one fails the boot rather than the first use (D1). |
| `:file` | an attachment, with `max_size:` and `content_types:` **required** — `MAGIK_MODEL_UNCONSTRAINED_UPLOAD` otherwise. The declaration form, derivatives and delivery are [`attachment`](#attachment), phase 4b. |
| `:timestamp` | stored UTC. Rendering without an explicit zone is a boot failure, not a formatting quirk. |
| `computed` | a derived field: `computed(:name, :type) { … }`. The parentheses are load-bearing — a brace block binds to the last call, so `computed :name, :type { … }` would bind to the symbol. |
| Injected | `id` (UUIDv7), `tenant_id`, `created_at`, `updated_at`. Never declared by hand. |
| `scope` | returns a Sequel dataset. The tenant filter is applied by the framework; writing it by hand is redundant, omitting it is not possible. |
| Never | HTTP awareness, rendering, authorization decisions, or cross-domain reads ([`domain`](#domain)). |

### `migrate`

A schema change, named, reversible, over Sequel's migration engine.

```ruby
migrate :CreateOrders do
  up do
    create_table :orders do
      uuid        :id, primary_key: true
      uuid        :tenant_id, null: false, index: true
      String      :reference, null: false
      String      :status,    null: false, default: "draft"
      Integer     :total_cents, null: false
      String      :total_currency, null: false, size: 3
      DateTime    :placed_at
      DateTime    :created_at, null: false
      DateTime    :updated_at, null: false
      index %i[tenant_id placed_at]
    end
  end

  down do
    drop_table :orders
  end
end
```

| Rule | Detail |
|---|---|
| Generated, not hand-written | `magik generate migration --from-models` diffs declarations against the applied ledger. Hand-editing the emitted file is expected; inventing one from scratch is not. |
| `down` required | a migration with no `down` fails to load. There is no `irreversible!` escape hatch in the design. |
| Money columns | one `:money` field emits `*_cents INTEGER` + `*_currency CHAR(3)`. Never a `numeric` or a `float`. |

### CLI (phase 1)

| Command | Does | Status |
|---|---|---|
| `magik new <app>` | scaffolds an app around a working `App.define` | planned |
| `magik generate model\|screen\|action\|migration <Name>` | emits a declaration plus its failing test | planned |
| `magik console` | boots the app, guardrails included, into IRB | planned |
| `magik server` | boots and binds Puma, thread-per-request | planned |
| `magik check` | runs the guardrails with no server ([`03-guardrails.md`](03-guardrails.md)) | planned |
| `magik describe [construct[.declaration]] [--json]` | the grammar as data — every option, type, default, allowed set and `MAGIK_*` code. No app, no boot, no database ([`11-dsl-as-tool-surface.md`](11-dsl-as-tool-surface.md)) | planned |

---

## Phase 2 — Rendering & actions

### `component`

A reusable UI fragment. Declares its props; the body compiles to HTML with `hx-*` attributes — no template file, no hand-written markup.

```ruby
component :OrderRow do
  prop :order, model: :Order

  body do
    row do
      cell { text order.reference }
      cell { money order.total }
      cell { timestamp order.placed_at, zone: viewer.time_zone }
      cell do
        button "Refund",
          action:  :refund_order,
          with:    { order_id: order.id },
          confirm: t("orders.refund.confirm")
      end
    end
  end
end
```

The component kit ships `button`, `form`, `field`, `data_table`, `modal`, `toast`, `card`, `list`, `grid`, `tabs`, `stat`, `chart`, and the layout primitives `sidebar`, `topbar`, `nav_item`, `breadcrumbs`, `account_menu` and `dashboard_grid`. Theming is design tokens and CSS variables, light and dark; a raw hex in a component is a convention violation, not a compile error.

**Every kit component is responsive by construction**, and no app-authored declaration is required to make a screen work on a phone. The one place it costs the author a line is [`data_table`](#data_table) on a narrow screen, which becomes a card list rather than a horizontal scroll.

Every kit component is replaceable — tokens, `extends:`, a shadowing definition in `app/components/`, or a raw escape hatch — under a contract verified at boot: [`08-component-overrides.md`](08-component-overrides.md).

### `screen`

A page-level component. Auto-routed from its name — `:Orders` → `/orders`. State is computed per request; nothing survives the response. Every screen names a [`policy`](#policy) verb — or `policy: :public` — and is rendered into a [`layout`](#layout), which defaults to `:App`.

```ruby
screen :Orders, policy: %i[Order read] do
  title { t("orders.title") }

  state :orders do
    Order.recent.limit(50)
  end

  body do
    card do
      heading t("orders.title")
      data_table of: :orders, using: :OrderRow, empty: t("orders.none")
    end
  end
end
```

### `action`

A mutation. Auto-wired to a POST endpoint derived from its name, invoked by the `hx-post` a `button` or `form` compiled to.

```ruby
action :refund_order, policy: %i[Order refund] do |params|
  order = Order.find!(params[:order_id])
  Payments.refund(order: order, amount: order.total)     # phase 5 ledger entry
  order.update(status: :refunded)

  redraw :orders                       # re-render the state var, swap the fragment
  toast t("orders.refunded"), level: :success
end
```

| Rule | Detail |
|---|---|
| Authorization | one `policy:` verb, evaluated before the block runs. A mutation with neither a verb nor an explicit `policy: :public` does not boot ([`03-guardrails.md`](03-guardrails.md)). |
| Signature | one `params` hash, already coerced to the declared field types. |
| Returns | a redraw, a redirect, or a toast — never HTML assembled by hand. |
| Never | hold instance state across requests (boot guardrail), read raw headers, or perform slow work inline — enqueue a [`job`](#job). |
| Phase 5 | `idempotent_by:` makes a retried call a no-op instead of a double charge. |

### `policy`

Authorization is decided in exactly one place and evaluated identically by a screen, an action, an API resource, a realtime channel, a job and the admin panel — because those surfaces are *generated*, and an app cannot reach inside a generated surface to add a check (architecture decision 13).

```ruby
# app/policies/invoice.rb  <->  policy :Invoice

policy :Invoice do
  default :deny                        # required. There is no implicit allow

  can :read do |actor, invoice|
    actor.role?(:viewer, :member, :admin, :owner)
  end

  can :issue do |actor, invoice|
    actor.role?(:admin, :owner) && invoice.status == :draft
  end

  can :record_payment do |actor, _invoice|
    actor.role?(:admin, :owner)
  end

  can :administer do |actor, _invoice|
    actor.staff? && actor.role?(:support_lead)
  end
end
```

The role set is declared once, beside the actor:

```ruby
App.define :Ledgerline do
  roles       :owner, :admin, :member, :viewer, default: :member
  staff_roles :support, :support_lead      # a separate axis — staff are not tenant members
end
```

Every surface **names a verb** rather than writing a check:

```ruby
screen      :Invoices,      policy: %i[Invoice read]
action      :issue_invoice, policy: %i[Invoice issue]
channel     :invoices,      policy: %i[Invoice read]
admin_panel :Invoice,       policy: %i[Invoice administer]
job         :DunningSweep,  policy: :system          # explicit, never implicit
screen      :Pricing,       policy: :public          # opting out is a declaration too
flow        :Onboarding,    policy: :public          # a flow names its own verb, never its steps'
webhook     :incoming,      acts_as: :service        # no actor to carry a role -- see `webhook`
```

| Rule | Detail |
|---|---|
| Predicates are pure | no queries, no I/O. A `live` screen re-evaluates one per subscriber per change, so a query here is one round trip per row per open socket |
| A `nil` record denies | "no record loaded" and "record not found" are the same `nil`, and absent evidence is a denial |
| The subject is any declared construct | `policy :Model` is the common case, not the only one. A `ledger` and a `flow` own data and are not models, so `policy :Receivables` is legal — the subject must simply be a name the registry knows (`MAGIK_POLICY_UNKNOWN_SUBJECT`). Requiring every surface to project onto a model would force a fake model into existence purely to satisfy a guard |
| One evaluator, every surface | the same block answers the HTTP request, the htmx post, the API call, the channel subscription and the admin render |
| Tier | the evaluator sits at **tier 1** — below `render` and `realtime`, which must call it. It takes the actor as an opaque value; `auth` at tier 3 supplies it ([`../architecture/01-module-map.md`](../architecture/01-module-map.md)) |

| Guardrail | Code |
|---|---|
| a surface reaching a model with no `policy:` and no `policy: :public` | `MAGIK_POLICY_UNDECLARED` |
| a predicate that queries | `MAGIK_POLICY_IO` |
| `policy:` naming a verb the policy does not declare | `MAGIK_POLICY_UNKNOWN_VERB` |
| a `policy` block with no `default :deny` | `MAGIK_POLICY_NO_DEFAULT` |

**Three surfaces this construct does not yet cover** — an incoming webhook (which has no actor, only a verified origin), a surface over a non-model subject such as `ledger`, and a `flow`. Each is stated with its evidence in [`00-build-spec.md`](00-build-spec.md#phase-2--rendering--actions); none blocks phase 2, and each blocks the phase that ships the surface.
| a row rule that would pass on a `nil` record | `MAGIK_POLICY_NULL_PASSES` |

`MAGIK_POLICY_UNDECLARED` is the load-bearing one: it is what makes an `admin_panel` with no policy a boot failure rather than a documented risk.

### `layout`

The application shell — the thing a `screen` is rendered *into*. A screen declares `state` and `body` and is auto-routed; the layout is what wraps it, and it is where navigation is declared.

```ruby
# app/layouts/app.rb  <->  layout :App

layout :App do
  sidebar do
    brand { text app_name }

    section t("nav.work") do
      nav_item :Dashboard, icon: :home
      nav_item :Invoices,  icon: :receipt, badge: -> { Invoice.overdue.count }
      nav_item :Customers, icon: :users
    end

    section t("nav.settings"), collapsed: true do
      nav_item :Members, icon: :users, policy: %i[Member administer]
      nav_item :Billing, icon: :card,  policy: %i[Subscription administer]
    end
  end

  topbar do
    breadcrumbs                                     # derived from each screen's `parent:`
    search action: :global_search, placeholder: t("nav.search")
    account_menu items: %i[profile theme sign_out]
  end

  content { slot :screen }

  responsive do
    sidebar collapses_below: :md, into: :drawer     # CSS + one htmx target. No build step
  end
end
```

```ruby
screen :Invoices, layout: :App, parent: :Dashboard do … end
screen :SignIn,   layout: :None do … end            # auth screens want no shell
screen :Pricing,  layout: :Marketing do … end       # a second layout, not a special case
```

| Rule | Detail |
|---|---|
| A default that exists | `magik new` generates a working `:App` layout with the conventional furniture in it. A generated app has a sidebar on its first run |
| Nav cannot rot | `nav_item :Invoices` names a screen constant; a link to a screen that does not exist fails at boot (`MAGIK_LAYOUT_UNKNOWN_SCREEN`). The same holds for an action: `search action: :global_search` above requires that `global_search` exist, or the boot fails with `MAGIK_LAYOUT_UNKNOWN_ACTION`. Only screens were guarded at first, which is how the drafted example above came to name an action no app declared |
| Nav respects authorization | `policy:` on a `nav_item` hides what the actor cannot reach. Showing a link to a 403 is the most common authorization bug in a SaaS, and it is free when both are declarations |
| Breadcrumbs are derived | from `parent:`, never typed per page |
| Every screen has one | default `:App`; opting out is `layout: :None`, written down |
| It is not a second override system | `sidebar`, `topbar`, `nav_item`, `breadcrumbs` and `account_menu` are kit components with contracts, so all four rungs of [`08-component-overrides.md`](08-component-overrides.md) apply unchanged |

| Guardrail | Code |
|---|---|
| a screen with no layout and no `layout: :None` | `MAGIK_LAYOUT_MISSING` |
| a `nav_item` naming a screen that does not exist | `MAGIK_LAYOUT_UNKNOWN_SCREEN` |

### `data_table`

The most-used component in any SaaS. Every capability below is a **server-rendered partial swap**, not client state — which is why "no SPA framework" costs nothing here.

```ruby
data_table :invoices, of: :Invoice do
  column t("invoices.number"),   :number, sortable: true
  column t("invoices.customer"), :customer_name, searchable: true
  column t("invoices.total"),    :total, align: :end
  column t("invoices.status"),   :status, as: :badge

  paginate   by: :cursor, per_page: 50          # cursor, not offset — see below
  sortable   :placed_at, :total                 # the allowed set; anything else is a 400
  searchable :number, :customer_name
  filterable :status,    :select, values: %i[draft issued paid void]
  filterable :placed_at, :date_range

  row_action t("invoices.issue"), action: :issue_invoice, when: ->(i) { i.draft? }
  bulk_action t("invoices.void"), action: :void_invoice, confirm: true

  columns   toggleable: true                    # per-actor preference, applied server-side
  exportable :csv                               # a job + a notification, over the same filter
  empty     icon: :receipt, text: t("invoices.none"), action: :create_invoice
  compact   primary: :number, secondary: %i[status total], action: :issue_invoice
end
```

| Capability | How it works, and why it is not client state |
|---|---|
| Pagination | **cursor-based on `(sort_key, id)`.** UUIDv7 primary keys are sortable, so a cursor needs no offset scan and page 900 costs what page 1 costs. This is decision 8 paying for itself |
| Sorting | column headers are `hx-get` links carrying the sort key |
| Search and filters | write to the query string; the swap re-reads it. **So a filtered view is shareable and bookmarkable** — the property client-side state destroys |
| Bulk selection across pages | encoded in the form as explicit ids, or as a "everything matching this filter" predicate the server re-evaluates. Never an opaque server-held selection — that would violate the stateless guardrail |
| Column visibility | a per-actor preference row. A preference is data, not session state |
| Loading | `hx-indicator` on the table's own target, compiled from the table's shape. Automatic, not opt-in |
| Narrow screens | `compact` turns the table into a card list below the breakpoint. **Not** a horizontal scroll |

### `chart`

```ruby
state :monthly_revenue do
  Invoice.paid.series(:month, on: :issued_on, last: 12).sum(:total)
end

chart :bar, data: :monthly_revenue, y_format: :money, series_colors: :tokens
```

| Decision | Answer |
|---|---|
| Types shipped | `line`, `bar`, `stacked_bar`, `area`, `pie`, `sparkline`. Anything beyond that is a BI product ([`05-limits.md`](05-limits.md)) |
| Data source | a `state` declaration returning a series, like every other component. **A chart never queries** — otherwise `MAGIK_COMPONENT_DIRECT_QUERY` acquires its first exception. `series` is the grouping helper the `model` DSL owes it |
| Rendering | **server-rendered inline SVG.** No client charting runtime, no payload, no build step. It themes from CSS variables, works with `live` (the re-broadcast fragment *is* the new chart), degrades to a table for screen readers, and prints |
| The cost, stated | no hover tooltips beyond `<title>`, no zoom, no pan, no legend toggling. Richer interaction is rung 4 of the override ladder — attach a charting library to a server-rendered element, which [`08-component-overrides.md`](08-component-overrides.md) already permits |
| Colours | `color_series_1..n` tokens, never a hard-coded palette, or the chart is the one thing on the page that does not follow dark mode |

---

## Phase 3 — Realtime (opt-in)

Nothing here costs anything until it is declared. A screen with no `live` is request/response and holds no socket.

### `channel`, `live`, `broadcast`, `presence`

```ruby
channel :orders, policy: %i[Order read] do
  subscribe_to :Order
  on_create { |order| broadcast "orders:#{order.tenant_id}", :insert, order }
  on_update { |order| broadcast "orders:#{order.tenant_id}", :update, order }
  presence tracking: %i[viewer_id cursor]
end

screen :Orders, policy: %i[Order read] do
  live :orders, on: "orders:{tenant}"      # this line is the entire cost of realtime

  state :orders do
    Order.recent.limit(50)
  end
end
```

`broadcast "channel", :event, payload` is also callable directly from an action or a job when the trigger is not a model write.

| Property | Design |
|---|---|
| Transport | Postgres `LISTEN`/`NOTIFY` by default, Redis pub/sub by config ([`04-swap-points.md`](04-swap-points.md)). |
| Payload | the re-rendered fragment for the `live` state var, not a JSON diff — the client is htmx, not a store. |
| Authorization | the same path as a normal request. There is no second door to the data; that is the Meteor lesson in [`01-thesis.md`](01-thesis.md). |
| Cost | one declaration per screen. No global sync engine, no app-wide socket. |

---

## Phase 4 — Jobs & async

### `job`

```ruby
job :SettleBatch, policy: :system do
  retries times: 5, backoff: :exponential
  schedule cron: "0 3 * * *"        # or: schedule every: "10m" — a :duration (D1)
  idempotent_by :tenant_id          # D4: one spelling for "a repeat with this key does nothing new"

  perform do |args|
    Order.where(tenant_id: args[:tenant_id], status: :captured).each do |order|
      Payments.settle(order: order)
    end
  end
end

SettleBatch.enqueue(tenant_id: tenant.id, run_at: 1.hour.from_now)
```

Postgres-backed transactional queue (Que-style) by default, so enqueueing inside a transaction that rolls back enqueues nothing. `magik worker` runs the process; it is horizontally scalable and holds no state the app can see.

---

## Phase 4b — Media

Media spans four phases — the `:file` field type is phase 1, the upload component is phase 2,
derivative generation and transcoding are phase 4 jobs, and signed delivery is blocked on
[`policy`](#policy). It is its own phase because its value arrives only when all four have landed
([`00-build-spec.md`](00-build-spec.md)).

### `attachment`

Files on a model. Ecommerce and marketplaces are two of the four verticals the mission sentence names, and neither is buildable without it.

```ruby
model :Product do
  attachment :hero, :image,
             max_size:      "10MB",
             visibility:    :public,                      # signed URLs not required
             direct:        true,                         # presigned, straight to storage
             content_types: %w[image/jpeg image/png image/webp] do   # sniffed, never trusted
    derivative :thumb,  resize: [200, 200]
    derivative :card,   resize: [640, 480], format: :webp
    responsive :hero,   widths: [640, 1280, 2048]         # emits srcset
    exif       :orientation                               # everything else is stripped
  end

  attachment :manual, :document,
    max_size:      "50MB",
    content_types: %w[application/pdf],
    visibility:    :private                               # signed, expiring URLs only

  attachment :demo, :video, media: :service               # transcoded by the media seam
end
```

| Rule | Detail |
|---|---|
| Direct-to-storage by default | a request server proxying a large upload holds a connection for minutes and contradicts decision 9. Proxied upload is the explicitly-chosen exception for small files |
| Content type is sniffed | from magic bytes. Never from the extension, never from the client header. A `.png` that is an `.svg` is stored XSS |
| Limits are required | an `attachment` with no `max_size` and no `content_types` fails boot |
| EXIF is stripped | on ingest, keeping only what is declared. GPS in a user photo that reached storage is already leaked |
| Derivatives are pre-generated | in a job. On-the-fly needs a cache and is a DoS vector when the transform URL is unsigned |
| Private files are policy-checked | a signed URL is issued only after the same `policy` verb that guards the record. An attachment served without one is a cached cross-tenant leak |
| Video and audio are wrapped, never built | `use :media, :mux` — the provider ingests, transcodes, packages and serves; the app stores an id. An `:ffmpeg` backend exists for teams that want no vendor, documented with its costs |
| Blobs have a lifecycle | deleting a record enqueues blob deletion; retention and GDPR erasure cover the blobs, not only the rows |

| Guardrail | Code |
|---|---|
| an `attachment` with no size or content-type bounds | `MAGIK_MODEL_UNCONSTRAINED_UPLOAD` |
| a `:private` attachment on a model with no policy | `MAGIK_POLICY_UNDECLARED` |

**One honest footnote on the client:** htmx alone cannot show byte-level progress on a direct-to-storage PUT. The framework ships a small, versioned, non-bundled `magik-upload.js` in `public/` on the same terms as htmx itself — a fixed asset, no toolchain, no build. The **app author still writes no JavaScript**, which is the claim that matters.

---

## Phase 5 — Money & compliance

### `ledger`

Double-entry, append-only, balance-validated **at boot** — the flagship guardrail.

```ruby
ledger :Payments do
  account :cash,       type: :asset
  account :revenue,    type: :revenue
  account :refunds,    type: :contra_revenue

  entry :capture do |order:, amount:|
    guard "the amount must be positive"          do amount.positive?          end
    guard "only a placed order may be captured"  do order.status == :placed   end
    debit  :cash,    amount
    credit :revenue, amount
  end

  entry :refund do |order:, amount:|
    guard "a refund cannot exceed what was captured" do
      amount <= Payments.captured_for(order)
    end
    debit  :refunds, amount
    credit :cash,    amount
  end
end
```

| Rule | Detail |
|---|---|
| Balance | every `entry`'s debits must equal its credits, proven by static analysis of the block at boot. Failing that, the app does not start. |
| Append-only | posted entries are never updated or deleted. A correction is a reversing entry. |
| `guard` | a precondition evaluated before any line is posted; a false guard raises and posts nothing. It carries its own message, so the failure names the cause rather than a line number ([`00-build-spec.md`](00-build-spec.md) D2). |
| Amounts | `:money` values only. There is no code path that accepts a float. |

### `audited` / `immutable_after` / `idempotent_by`

```ruby
model :Order do
  audited                          # every change writes who/what/when to the audit trail
  immutable_after :placed_at       # once set, declared fields refuse updates
end

action :capture_payment, idempotent_by: :payment_intent_id do |params|
  # a retried call with a seen key returns the first result and posts nothing new
end
```

### `flow`

Multi-step wizards — onboarding, KYC, checkout. Step state lives server-side, keyed by a resumable token, because app servers are stateless.

```ruby
flow :Onboarding, policy: :public do        # a flow is a surface: it names a verb, or opts out
  step :profile do
    screen :OnboardingProfile
    on_submit { |params, ctx| ctx.merge(profile: params) }
  end

  step :kyc do
    skip_when { |ctx| ctx[:country] != "US" }        # D2: `skip_when` skips; `guard` refuses
    screen :OnboardingKyc
    on_submit { |params, ctx| Kyc.submit(params) and ctx }
  end

  complete { |ctx| Account.activate!(ctx) }
end
```

**A flow names its own verb and inherits nothing.** Onboarding is reachable before an account exists,
so it declares `policy: :public`; a checkout flow would name a real verb. Inheriting the union of
every verb its steps post to was rejected: it makes a flow's authorization a function of code
elsewhere, unreadable at the declaration site and unpredictable as steps change — which is the second
door [`policy`](#policy) exists to close. The `action` behind a step still evaluates its own verb, so
a flow gates **entry** and each action gates its **write**. Two gates, one evaluator, neither
implicit.

---

## Phase 6 — API & integration

### `api`

```ruby
api :V1 do
  auth :bearer                                  # or :api_key, :jwt
  rate_limit by: :plan

  resource :orders, model: :Order do
    fields     :reference, :status, :total, :placed_at   # what the response carries
    filterable :status, :placed_at
    sortable   :placed_at, :total
    searchable :reference
    writable   :reference, :total, :status               # what create/update accept

    index per_page: 50
    show
    create
    update
    destroy
  end
end
```

`fields`, `filterable`, `sortable`, `searchable` and `writable` are **the same five words on `admin_panel`, `data_table` and `screen`** — one vocabulary for "which fields participate", decided in [`00-build-spec.md`](00-build-spec.md) as spelling decision D3. `per_page:` stays an option because it is a scalar setting, not a field subset.

Pagination, filtering and sorting are generated from the declaration. Serialization follows the model's field types — `:money` renders as minor units plus a currency, never a float.

### `webhook`

```ruby
webhook :incoming, :stripe do
  verify_signature secret: ENV.fetch("STRIPE_WEBHOOK_SECRET"), scheme: :stripe
  acts_as :service, can: %i[Order.capture]     # the verbs this endpoint may reach, and no others
  on "payment_intent.succeeded" do |event|
    Payments.capture(order: Order.find_by_intent!(event[:id]), amount: money(event[:amount], :usd))
  end
end

webhook :outgoing, :order_placed do
  fires_on :Order, :create
  deliver_to { |tenant| tenant.webhook_url }
  sign_with :hmac_sha256
  retries times: 8, backoff: :exponential
end
```

An inbound webhook with no `verify_signature` fails at boot, and so does one with no `acts_as`
(`MAGIK_WEBHOOK_UNSCOPED_ACTOR`). **A verified signature is not an actor** — it authenticates an
origin, not a person — so an incoming webhook names the verbs it may exercise rather than borrowing
`policy: :system`, which would grant every verb in the application to the one surface a stranger can
call directly. `can:` is a verb list rather than a role, because there is no actor to carry one; each
verb still resolves through the same [`policy`](#policy). Delivery of an outbound webhook runs through the job queue, so it inherits retries and transactional enqueue.

---

## Phase 7 — Auth, billing, admin

### `auth`

```ruby
auth do
  strategy :password
  oauth_providers :google, :github
  two_factor :totp
  session_ttl "14d"
  password_rules min_length: 12
end
```

Rodauth-backed. Generates the account model, migrations, screens and actions for login, signup, reset, verification and 2FA enrolment — all in the same grammar, all overridable by redeclaring the screen.

### `billing`

```ruby
billing provider: :stripe do
  plan :starter, price: money(2900, :usd), interval: :month, trial: "14d"   # D1: a :duration
  plan :growth,  price: money(9900, :usd), interval: :month
  plan :usage,   metered: :api_calls, unit_price: money(2, :usd)

  on_subscription_active   { |sub| sub.tenant.update(plan: sub.plan) }
  on_payment_failed        { |sub| notify :payment_failed, tenant: sub.tenant }
end
```

### `admin_panel`

Auto CRUD admin for one model, in the same grammar as everything else, and deep enough to be an admin rather than a list: all four view types, in the vocabulary `api` uses, benchmarked against [Avo](https://avohq.io) in [`10-saas-coverage.md`](10-saas-coverage.md).

```ruby
admin_panel :Invoice, policy: %i[Invoice administer] do
  list do
    fields     :number, :customer, :total, :status, :due_on
    filterable :status, :select, values: %i[draft issued paid void]
    filterable :due_on, :date_range
    searchable :number, "customer.name"
    saved_view :overdue, label: "Overdue", scope: :overdue
    bulk_action :void, action: :void_invoice, args: { reason: :string }, confirm: true
    exportable :csv
  end

  show do
    panel t("admin.details") do
      field :number, :status, :total, :due_on
    end
    tab t("admin.lines") do
      has_many :line_items, display: :table
    end
    sidebar do
      field :created_at, :issued_at
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

```ruby
App.define :Ledgerline do
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

`policy:` is **required** — an admin panel is by construction the surface with the broadest data
access in the application, and one without a policy is a security hole with a nice table on top. The
field vocabulary is `api`'s, because an `admin_panel` is a projection of the same model
([`00-build-spec.md`](00-build-spec.md) D3).

| Property | Why it is the right one |
|---|---|
| Admin actions **are** the app's actions | `MAGIK_ADMIN_INLINE_MUTATION` forbids a second write path. A Magik admin cannot have a mutation the product does not have — which is the one thing Avo, as a separate admin language, cannot offer |
| Generated from the model, not scaffolded into files | adding a field to the model adds it to the admin. There is no second place to update |
| One theme, one kit, one locale set | an admin that matches the product costs nothing |

Deliberately **not** copied from Avo: kanban, map view and a media-library browser. Those are product surfaces, not admin primitives.

---

## Phase 8 — i18n, PWA, notifications

### `locales` / `translatable`

```ruby
App.define :Shop do
  locales :en, :es, :de, default: :en
end

model :Product do
  field :name, :string, translatable: true
end
```

`t("key")` is the only way user-facing text reaches a screen. A key missing from a shipped locale is a check failure, not a fallback to the key.

### `pwa`

```ruby
pwa do
  name       "Shop"
  short_name "Shop"
  icon       "app/assets/icon.png"
  display    :standalone
  theme_color "#101014"
end
```

Installable only. **There is no offline mode and no service-worker cache of app data** — declaring one is refused, loudly ([`05-limits.md`](05-limits.md)).

### `notification`

```ruby
notification :order_placed do
  channel :email, :in_app, :push
  subject { |order| t("notify.order_placed.subject", reference: order.reference) }
  body    { |order| render :OrderPlacedEmail, order: order }
  deliver_via :jobs
end

notify :order_placed, to: order.customer, order: order
```

### Email production

`notification` says *what* is sent; these declarations say what an email actually is by the time it arrives. They are extensions to the existing construct, not a second one.

```ruby
notification :invoice_issued do
  channel :email do
    layout   :Transactional            # a MAIL layout — not a screen layout
    subject  { |invoice| t("notify.invoice_issued.subject", number: invoice.number) }
    body     { |invoice| render :InvoiceIssuedEmail, invoice: invoice }
    text     :auto                     # generated plain-text alternative, or a block
    inline_css true                    # default. Mail clients do not do stylesheets
    preheader { |invoice| t("notify.invoice_issued.preheader") }
    attach   { |invoice| pdf :InvoiceDocument, invoice: invoice }
  end

  unsubscribable_by :customer          # signed token, preference row, List-Unsubscribe
  deliver_via :jobs
end
```

```bash
magik mail preview :invoice_issued --locale es --out tmp/mail/    # renders, sends nothing
```

| Piece | Detail |
|---|---|
| **Preview** | renders to a file, and to a dev-only route. **This matters doubly for an agent**, which has no inbox — the framework's output is its entire diagnostic surface ([`07-ai-first.md`](07-ai-first.md)) |
| Mail layouts | a distinct artifact from screen layouts. Table-safe, inlined, dark-mode-aware, and not the app shell |
| Plain text | generated from the HTML by default. An email with no `text/plain` part is an email that scores as spam |
| Suppression | **framework-owned and consulted by `notify` before delivery.** An app-level suppression table that `notify` does not read is a suppression list that does nothing |
| Bounces and complaints | inbound provider events over the existing `webhook :incoming` DSL, writing to the suppression list |
| Unsubscribe | a signed token, a preference record and a `List-Unsubscribe` header. Required by law for anything non-transactional |

Test helpers gain content assertions, not only delivery:

```ruby
assert_notified :invoice_issued, to: customer, via: %i[email] do |mail|
  expect(mail.subject).to_include(invoice.number)
  expect(mail.text).to_be_present
  expect(mail.links).to_include(screen(:Invoices, focus: invoice.id))
end
```

---

## Phase 9 — Testing

### `test`

Compiles to Minitest. `expect` is the spec's word for the assertion helper; the matcher set is deliberately small, and plain `assert_*` is always available because this **is** Minitest ([`../architecture/04-testing-strategy.md`](../architecture/04-testing-strategy.md)).

```ruby
test :Orders do
  it "captures a payment and posts a balanced entry" do
    order = create :Order, status: :placed, total: money(1000, :usd)

    perform_action :capture_payment, order_id: order.id, payment_intent_id: "pi_1"

    expect(order.reload.status).to_eq(:captured)
    expect(Payments.balance(:cash)).to_eq(money(1000, :usd))
    assert_enqueued :SettleBatch
  end

  it "is idempotent under retry" do
    order = create :Order, status: :placed, total: money(1000, :usd)
    2.times { perform_action :capture_payment, order_id: order.id, payment_intent_id: "pi_1" }
    expect(Payments.balance(:cash)).to_eq(money(1000, :usd))
  end
end
```

Helpers: `perform_action`, `render_screen`, `concurrently(n)`, `travel_to`, `assert_enqueued`, `assert_broadcast`, `assert_notified`. Factories are inferred from model field types; tests for `required:`, `validate` and ledger balance are generated, not written.

---

## Spec item 12 — Domains

### `domain`

For large apps. One file per domain, `domains/<name>/domain.rb`. Enforced at boot, not by review.

```ruby
# domains/billing/domain.rb
domain :Billing do
  depends_on      :Accounts
  exposes         :InvoiceSummary, :charge_customer
  publishes_events :invoice_paid, :invoice_failed
end
```

| Rule | Detail |
|---|---|
| Direct access | a domain reaching another domain's model constant fails the boot with `MAGIK_DOMAIN_BOUNDARY`. |
| Legal paths | the exposed interface, or a subscription to a published event. |
| Undeclared dependency | using `Accounts` without `depends_on :Accounts` fails the boot. |
| Cycles | a dependency cycle between domains fails the boot. |

Mechanics and enforcement: [`../architecture/02-boundaries.md`](../architecture/02-boundaries.md).

---
