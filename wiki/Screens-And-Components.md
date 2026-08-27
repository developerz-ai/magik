# Screens and components

**Status:** `Planned — not implemented`. Spec Phase 2, build steps 3–4. Nothing on this page runs.
`As of 2026-08-26`.

A `component` is reusable UI. A `screen` is a page-level component that is automatically routed. Both
compile to server-rendered HTML with [htmx](https://htmx.org) attributes. There is no React, no Vue,
and no per-screen escape hatch — that is architecture decision 4 and it does not move.

You write no HTML, no CSS and no JavaScript. Not "less of it" — none.

## A screen

```ruby
# app/screens/invoices.rb
screen :Invoices, policy: %i[Invoice read], layout: :App, parent: :Dashboard do
  state :invoices, -> { Invoice.overdue.eager(:customer) }
  state :total,    -> { Invoice.outstanding.sum(:amount) }

  body do
    stat label: "Outstanding", value: :total, format: :money

    card title: "Overdue" do
      data_table :invoices,
                 columns: %i[number customer amount due_on status],
                 empty: "Nothing overdue. Good.",
                 row_action: :mark_paid

      button "New invoice", opens: :new_invoice_modal
    end

    modal :new_invoice_modal, title: "New invoice" do
      form action: :create_invoice do
        field :customer_id, :select, options: -> { Customer.all }
        field :amount,      :money
        field :due_on,      :date
      end
    end
  end
end
```

Auto-routed to `/invoices`. There is **no** `config/routes.rb` — the router is convention. `screen
:InvoiceDetail` is `/invoice_detail`; a screen taking a record takes it as a path segment.

Two of those three options are not decoration. `policy:` names the verb the framework evaluates
before the screen renders — see [`policy`](#policy) — and `layout:` names the shell it renders into,
see [`layout`](#layout). Both are **required**, and both can be opted out of explicitly
(`policy: :public`, `layout: :None`). `parent:` is what `breadcrumbs` is derived from.

### `state` is the only way a screen reads data

A screen names a `state` and the state is a **model scope**. A `Sequel` dataset built inside a `body`
block is refused at boot:

```text
MAGIK_RENDER_SCREEN_DIRECT_QUERY: :Invoices builds a query inside its body block
  fix: move it to a `scope` on the model and declare it as `state`
```

This is the separation-of-concerns rule with teeth. See
[Project layout](Project-Layout.md#separation-of-concerns-concretely).

### A screen holds no state across requests

App servers are stateless — architecture decision 9, and the thing that makes "add more servers"
work. A screen or component that stashes an instance variable between requests fails at boot:

```text
MAGIK_RENDER_SCREEN_STATEFUL: :Invoices assigns @cursor outside a render pass
  fix: put it in the URL, or in a `state` declaration that recomputes per request
```

## `policy`

**Authorization is decided in exactly one place.** A screen, an action, an API resource, a realtime
channel, a job and an admin panel are all *generated* surfaces, and an app cannot reach inside a
generated surface to add a check — so every one of them **names a verb** instead. Architecture
decision 13.

```ruby
# app/policies/invoice.rb
policy :Invoice do
  default :deny                        # required. There is no implicit allow

  can :read do |actor, invoice|
    actor.role?(:viewer, :member, :admin, :owner)
  end

  can :issue do |actor, invoice|
    actor.role?(:admin, :owner) && invoice.status == :draft
  end

  can :administer do |actor, _invoice|
    actor.staff? && actor.role?(:support_lead)
  end
end
```

The role set is declared once, beside the actor:

```ruby
App.define :Myapp do
  roles       :owner, :admin, :member, :viewer, default: :member
  staff_roles :support, :support_lead      # a separate axis — staff are not tenant members
end
```

Every surface names a verb rather than writing a check, and **opting out is a declaration too**:

```ruby
screen      :Invoices,      policy: %i[Invoice read]
action      :issue_invoice, policy: %i[Invoice issue]
channel     :invoices,      policy: %i[Invoice read]
admin_panel :Invoice,       policy: %i[Invoice administer]
job         :DunningSweep,  policy: :system          # explicit, never implicit
screen      :Pricing,       policy: :public          # a marketing page says so
```

| Rule | Detail |
|---|---|
| Predicates are pure | no queries, no I/O. A `live` screen re-evaluates one per subscriber per change, so a query here is a round trip per row per open socket |
| A `nil` record denies | "no record loaded" and "record not found" are the same `nil`, and absent evidence is a denial |
| One evaluator, every surface | the same block answers the HTTP request, the htmx post, the API call, the channel subscription and the admin render. There is no second door to the data |
| It is not a swap point | a second authorization backend is a second authorization system, which is the failure this design is organised against |
| `auth` supplies the actor, and never decides | `policy` lands in phase 2 and takes the actor as an opaque value; `auth` arrives in phase 7 and nothing in the policy layer changes at the handover |

## `layout`

The application shell — the thing a screen is rendered *into*, and where navigation is declared. A
screen declares `state` and `body`; the layout is what wraps it.

```ruby
# app/layouts/app.rb
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
    sidebar collapses_below: :md, into: :drawer     # CSS plus one htmx target. No build step
  end
end
```

A screen names one, and opting out is written down:

```ruby
screen :Invoices, layout: :App, parent: :Dashboard do … end
screen :SignIn,   layout: :None do … end            # auth screens want no shell
screen :Pricing,  layout: :Marketing do … end       # a second layout, not a special case
```

| Rule | Detail |
|---|---|
| A default that exists | `magik new` is specified to generate a working `:App` layout, so a generated app has a sidebar on its first run |
| Nav cannot rot | `nav_item :Invoices` names a screen constant. A link to a screen that does not exist fails at boot |
| Nav respects authorization | `policy:` on a `nav_item` hides what the actor cannot reach. Showing a link to a 403 is the most common authorization bug in a SaaS, and it is free when both are declarations |
| Breadcrumbs are derived | from `parent:`, never typed per page |
| It is not a second override system | its pieces are kit components with contracts, so all four rungs of [Using your own components](#using-your-own-components) apply unchanged |

## A component

```ruby
# app/components/invoice_status_badge.rb
component :InvoiceStatusBadge do
  prop :status, :enum, values: %i[draft sent paid void]

  body do
    badge text: status.to_s.capitalize,
          tone: { draft: :neutral, sent: :info, paid: :success, void: :muted }[status]
  end
end
```

Used from anywhere:

```ruby
invoice_status_badge status: invoice.status
```

| Rule | Detail |
|---|---|
| Props are declared and typed | an undeclared prop is a boot failure, not a `nil` at runtime |
| Components never query | a component that reads the database is a screen wearing a disguise. Refused |
| Components compose | a component may render other components; a screen is a component with a route |

## The component kit

Ships with the framework. These are the vocabulary — you extend it with your own `component`
declarations rather than dropping to HTML.

| Component | For |
|---|---|
| `button` | actions and navigation. Wires itself to an `action` via htmx |
| `form` | a set of fields posting to one `action` |
| `field` | one input. Type comes from the model field where it can be inferred |
| `data_table` | rows, columns, sorting, pagination, per-row actions |
| `modal` | overlay, opened by `opens:` on a button |
| `toast` | transient feedback, usually from an action's return |
| `card` | a titled container |
| `list` | a vertical collection with a per-item template |
| `grid` | a responsive two-dimensional layout |
| `tabs` | sectioned content, with the selected tab in the URL — not in memory |
| `stat` | a single number with a label and optional delta |
| `chart` | a rendered chart. **Server-rendered**; see the limit below |
| `sidebar` | the shell's primary navigation column. Declared inside a [`layout`](#layout) |
| `topbar` | the shell's header strip: breadcrumbs, search, account menu |
| `nav_item` | one navigation link. Names a screen constant, and takes a `policy:` |
| `breadcrumbs` | derived from each screen's `parent:`, never typed per page |
| `account_menu` | the signed-in actor's menu — profile, theme, sign out |
| `dashboard_grid` | the landing-screen arrangement of `stat`, `chart` and `card` |

**Every kit component is responsive by construction.** No app-authored declaration is required to
make a screen work on a phone, and that is meant to be a tested claim rather than an asserted one:
`render_screen … at: :mobile` in a test, and a phase 2 exit criterion that the generated app renders
correctly at 375px. The one place it costs you a line is `data_table` on a narrow screen, which
becomes a **card list** — never a horizontal scroll.

## Using your own components

The question everyone asks first: *the kit gives me a `modal`, but I want my own modal — now what?*

**Four rungs, and you almost never need the top one.** Take the cheapest rung that fits; each is a
strict superset of the one below. The reasoning behind the ladder is
[`docs/idea/08-component-overrides.md`](../docs/idea/08-component-overrides.md), under the general
rule in [`docs/idea/04-swap-points.md`](../docs/idea/04-swap-points.md) — this section is how you use
it.

| Rung | You want | You write | Cost |
|---|---|---|---|
| 1 | A different **look** | design tokens in `config/theme.rb`, or CSS custom properties | no Ruby at all |
| 2 | A different **layout**, same behaviour | `variant:` on the call, or `component :Modal, extends: Magik::Kit::Modal` overriding only `body` | one small component |
| 3 | **Your own** modal, still called `modal` everywhere in app code | `component :Modal` in `app/components/` — it shadows the built-in by name | one component + a contract |
| 4 | Raw HTML, once, at one call site | `raw_html` at the call site | you own that markup forever |

### Rung 1 — tokens

```ruby
# config/theme.rb
theme do
  color   :overlay,      light: "rgba(15,23,42,.45)", dark: "rgba(0,0,0,.6)"
  radius  :modal,        "1rem"
  shadow  :modal,        "0 24px 48px -12px rgb(0 0 0 / .35)"
  motion  :modal_enter,  "160ms cubic-bezier(.2,.8,.2,1)"
end
```

Every kit modal in the app changes. No Ruby, no override, nothing to keep in step on upgrade.

### Rung 2 — a variant, or extend the built-in

```ruby
modal :confirm_void, title: "Void invoice?", variant: :sheet   # slides from the edge
```

Or keep the behaviour and replace only the markup:

```ruby
# app/components/modal.rb
component :Modal, extends: Magik::Kit::Modal do
  body do
    dialog_shell do                 # your chrome
      header { slot :title }
      section { slot :default }
      footer  { slot :actions }
    end
  end
end
```

`extends:` inherits the props, the slots and the htmx wiring; you are overriding one method. This is
the rung most apps stop at.

### Rung 3 — your own component, same name

Define `component :Modal` in `app/components/` and it **shadows the built-in by name**. Every
`modal ... do` call in every screen — including calls made by other kit components — now renders
yours. No screen changes, no import, no registration.

```ruby
# app/components/modal.rb
component :Modal do
  satisfies Magik::Kit::Modal          # the contract, verified at boot

  prop :title,       :string, required: true
  prop :dismissible, :boolean, default: true
  prop :size,        :enum, values: %i[sm md lg full], default: :md

  slot :default
  slot :actions, optional: true

  body do
    raw_html <<~HTML
      <div class="acme-scrim" data-acme-modal="#{id}" #{htmx_target_attrs}>
        <div class="acme-panel acme-panel--#{size}" role="dialog" aria-modal="true"
             aria-labelledby="#{id}-title">
          <h2 id="#{id}-title">#{escape title}</h2>
          #{render_slot :default}
          <footer>#{render_slot :actions}</footer>
          #{dismissible ? close_button : ""}
        </div>
      </div>
    HTML
  end
end
```

### Why rung 3 carries a contract

**Kit components compose each other.** `data_table` opens a row in a `modal`. `form` composes
`field`. `tabs` renders its panels through the same slot machinery. So a replacement is not only used
by your code — it is used by framework code that was written against the original.

Every kit component therefore publishes a contract: its **props**, its **slots**, and its **htmx
targets and events**. `satisfies Magik::Kit::Modal` declares that yours honours it, and the boot
verifies it rather than trusting the declaration.

```bash
magik check --contract Modal        # the contract you must satisfy, printed
```

```text
Magik::Kit::Modal
  props   title:String(required)  dismissible:Boolean(default true)  size:Enum(sm|md|lg|full)
  slots   default(required)  actions(optional)
  htmx    target #modal-{id}    emits modal:opened, modal:closed    accepts hx-swap="innerHTML"
```

Miss one and boot fails, naming exactly what is missing:

```text
MAGIK_COMPONENT_CONTRACT_VIOLATION: :Modal declares `satisfies Magik::Kit::Modal` but omits slot :actions
  cause: data_table renders per-row buttons into the :actions slot; a modal without it drops them silently
  fix:   add `slot :actions, optional: true` to app/components/modal.rb — or drop `satisfies` and stop
         shadowing the kit name, declaring `component :AcmeModal` instead
```

The `fix:` always offers both exits: satisfy the contract, or **stop shadowing the built-in name**. A
component that does not want the contract does not have to take it — it just cannot be called `Modal`.

### Rung 4 — raw HTML at one call site

```ruby
card title: "Legacy report" do
  raw_html File.read(Rails.root.join("legacy/report.html"))   # you own this forever
end
```

The escape hatch exists because a framework with none is a framework you eventually leave. It is
rung 4 because everything the kit gives you — theming, dark mode, htmx wiring, the guardrails — stops
at its boundary.

### Resolution order

Most specific wins. `magik check` reports what shadows what, so an override is never invisible.

| # | Source | For |
|---|---|---|
| 1 | `app/components/` | this app's own components |
| 2 | `domains/<name>/components/` | one domain's components, visible only inside it |
| 3 | A **kit gem** chosen in config | a house component library shared across your apps |
| 4 | `Magik::Kit::*` | the built-ins |

```ruby
# config/backends.rb
kit :acme_ui        # your organisation's component gem, ahead of the built-ins
```

The kit gem is the seam that matters at company scale: write `acme_ui` once, `kit :acme_ui` in every
app, and every app's `modal` is your modal without a single screen changing.

```bash
magik check --components
```

```text
Modal      app/components/modal.rb          shadows acme_ui → Magik::Kit::Modal   ✓ satisfies contract
Button     acme_ui                          shadows Magik::Kit::Button            ✓ satisfies contract
DataTable  Magik::Kit::DataTable            built-in
Field      domains/billing/components/field.rb  shadows Magik::Kit::Field  (billing only)  ✓
```

### What "no SPA framework" does and does not forbid

People read the rule too broadly, so here it is exactly:

| Forbidden | Allowed |
|---|---|
| React, Vue, Svelte or any framework **owning rendering** — a client-side component tree, a virtual DOM, a client router | attaching your own JavaScript **behaviour** to markup the server rendered: a focus trap, a date picker, a drag handle, a chart library initialised on an element |
| A client-side data store that becomes a second source of truth | reading a `data-` attribute the server put there and acting on it |
| A build step that compiles your UI | a plain `.js` file in `public/`, loaded with a `<script>` tag |

The server renders the markup; you wire what you like to it. What does **not** change is the
guardrails: an override still cannot query the database, still cannot hold cross-request state, and
still cannot render a timestamp without a zone. The rules are about the architecture, not about who
authored the component.

## htmx, and where interactivity stops

The DSL compiles to htmx attributes. A `row_action:` becomes `hx-post` plus a target and a swap
strategy; a `form` becomes `hx-post` with the action's path; `opens:` becomes a target swap.

You never write `hx-*` by hand, and you never write a fetch call.

**The limit, stated loudly:** no heavy client-side compute. Canvas editors, games, in-browser video
editing, spreadsheet engines — out of scope. A `chart` is rendered server-side and re-rendered on
change; it is not a client charting runtime you can drive from JavaScript. If your product needs a
canvas, Magik is the wrong framework and this page is the place that says so rather than letting you
find out in month four. See [`docs/idea/05-limits.md`](../docs/idea/05-limits.md).

## Theming

Design tokens, light and dark from one set, CSS custom properties. No stylesheet to write.

```ruby
# config/theme.rb
theme do
  color :brand,   light: "#2563eb", dark: "#60a5fa"
  color :surface, light: "#ffffff", dark: "#0b1120"
  color :text,    light: "#0f172a", dark: "#e2e8f0"

  radius  :md, "0.5rem"
  spacing :md, "1rem"
  font    :body, "system-ui, sans-serif"
end
```

Components reference roles (`tone: :success`), never raw colours. A component that hard-codes a hex
value is a component that breaks in dark mode, so the kit does not offer the option.

## Timestamps need a zone

Rendering a `:timestamp` without an explicit timezone conversion is a **boot failure**, not a subtly
wrong string in someone else's country:

```ruby
field :sent_at, format: :datetime, zone: :tenant     # or an explicit IANA zone
```

```text
MAGIK_RENDER_TIMESTAMP_NO_ZONE: :Invoices renders :sent_at with no zone
  fix: add `zone: :tenant` — or an IANA name — to the field
```

## Guardrails

| Guardrail | Fails with | When |
|---|---|---|
| A screen may not query directly | `MAGIK_RENDER_SCREEN_DIRECT_QUERY` | boot |
| A screen or component may not hold cross-request state | `MAGIK_RENDER_SCREEN_STATEFUL` | boot |
| A timestamp may not render without a zone | `MAGIK_RENDER_TIMESTAMP_NO_ZONE` | boot |
| A component may not read the database | `MAGIK_COMPONENT_DIRECT_QUERY` | boot |
| An undeclared prop is refused | `MAGIK_COMPONENT_PROP_UNDECLARED` | boot |
| A component shadowing a kit name satisfies its contract | `MAGIK_COMPONENT_CONTRACT_VIOLATION` | boot |
| Every surface reaching a model names a policy verb | `MAGIK_POLICY_UNDECLARED` | boot |
| The verb it names is declared | `MAGIK_POLICY_UNKNOWN_VERB` | boot |
| A policy predicate performs no I/O | `MAGIK_POLICY_IO` | boot |
| A policy states `default :deny` | `MAGIK_POLICY_NO_DEFAULT` | boot |
| A row rule denies a `nil` record | `MAGIK_POLICY_NULL_PASSES` | boot |
| Every screen has a layout, or `layout: :None` | `MAGIK_LAYOUT_MISSING` | boot |
| A `nav_item` names a screen that exists | `MAGIK_LAYOUT_UNKNOWN_SCREEN` | boot |

## Swap points

| Seam | Default | Swap to |
|---|---|---|
| Realtime transport, when a screen declares `live` | Postgres `LISTEN`/`NOTIFY` | Redis pub/sub, via `config/backends.rb` |
| Cache backend for rendered fragments | in-process | Redis, via `config/backends.rb` |
| Individual kit components | `Magik::Kit::*` | your own, by name — see [Using your own components](#using-your-own-components) |
| The whole component kit | the built-ins | a kit gem: `kit :acme_ui` in `config/backends.rb` |
| The client interactivity layer | htmx | **not a swap point.** No SPA framework, ever — architecture decision 4 |
| Authorization | `policy` | **not a swap point.** A second authorization backend is a second authorization system |

## Next

- [Actions](Actions.md) — what the forms and buttons above post to.
- [Realtime](Realtime.md) — making a screen update itself, opt-in.
- [Models](Models.md) — where `state` scopes come from.
- [Auth, billing, admin](Auth-Billing-Admin.md) — who the actor a `policy` receives is, and `admin_panel`.
- [Testing](Testing.md) — `render_screen` in a test.
