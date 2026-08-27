# Component overrides

The component kit is an opinionated default, so it needs the same escape hatch every other default has. This is that hatch: four rungs, a contract, and a resolution order.

**Status:** spec only. The component kit does not exist, none of the four rungs is implemented, and `MAGIK_COMPONENT_CONTRACT_VIOLATION` is a reserved name. Reviewed 2026-08-26.

## Why this page exists

Spec item 11 requires a swap point for every opinionated default, and names five infrastructure backends. The kit — `button`, `form`, `field`, `data_table`, `modal`, `toast`, `card`, `list`, `grid`, `tabs`, `stat`, `chart` — is an opinionated default too, and a much more visible one: it is on every screen the user's customers see.

A framework whose modal cannot be replaced is the Meteor failure mode one layer up ([`01-thesis.md`](01-thesis.md)): pleasant until the day the design system says otherwise, and then a rewrite. So the rule from [`04-swap-points.md`](04-swap-points.md) applies unchanged — **every opinionated default has a config-level or declaration-level swap, and a swap ships proven, not promised.**

## The override ladder

Four rungs. **You never have to jump to the top.** Most needs are answered on rung 1, and each rung costs strictly more than the one below it.

| Rung | You want | You write | You keep |
|---|---|---|---|
| **1** | a different look | design tokens / CSS variables — no Ruby | everything: behaviour, htmx wiring, accessibility, guardrails |
| **2** | a different layout, same behaviour | `variant:` on the call, or `component :Modal, extends: Magik::Kit::Modal` overriding only `body` | the prop set, the events, the composition contract |
| **3** | your own modal, still called `modal` everywhere | `component :Modal` in `app/components/` — an app definition shadows the framework one by name | the contract, verified at boot |
| **4** | not a component at all | a raw-HTML escape hatch at the call site | nothing but the surrounding page |

### Rung 1 — tokens

```ruby
theme do
  token :radius_lg,      "12px"
  token :surface_raised, light: "#ffffff", dark: "#16161c"
  token :overlay_scrim,  "rgba(0,0,0,.55)"
end
```

No Ruby beyond the token declaration; the kit reads CSS variables. If the answer to "how do I change the modal" is a colour, a radius or a shadow, it stops here.

### Rung 2 — extend

```ruby
component :Modal, extends: Magik::Kit::Modal do
  body do
    scrim
    panel class: "acme-panel" do
      slot :header
      slot :content
      footer { slot :actions }
    end
  end
end
```

The prop set, the open/close events and the htmx targets are inherited. Only markup changes, so the contract cannot drift — you did not redeclare it.

### Rung 3 — replace

```ruby
# app/components/modal.rb
component :Modal do
  satisfies Magik::Kit::Modal          # the contract declaration — checked at boot

  prop :title,      :string
  prop :dismissible, :boolean, default: true
  slot :content
  slot :actions

  body do
    tag :dialog, id: dom_id, "hx-target": target, class: "acme-modal" do
      # entirely your markup
    end
  end
end
```

Everything in the app that says `modal` now gets yours — including kit components that compose it.

### Rung 4 — escape

```ruby
screen :Orders do
  body do
    raw <<~HTML
      <dialog id="bespoke" data-controller="acme-modal">…</dialog>
    HTML
  end
end
```

`raw` is deliberately unpleasant to reach for: it is unchecked markup, no contract, no token wiring, and `magik check` reports every `raw` site so the count is visible. It exists because a framework with no escape hatch is the thing this page is preventing.

## Why rung 3 needs a contract

Kit components compose each other. `data_table` opens a row in a `modal`; `form` composes `field`; `toast` is raised by `action`. So `data_table` must be able to open **your** modal without knowing anything about it.

Each kit component therefore publishes a contract — **props in, slots, htmx targets, events out** — and a replacement declares `satisfies Magik::Kit::Modal`. Boot verifies it.

| Contract element | Meaning | Example (`Modal`) |
|---|---|---|
| Props in | names, types and required/optional status a caller may pass | `title:` string, `dismissible:` boolean |
| Slots | named regions a caller fills | `:content`, `:actions`, optional `:header` |
| htmx targets | the DOM ids/selectors the framework will aim a swap at | `dom_id`, `#{dom_id}-content` |
| Events out | what the component emits, which other components listen for | `magik:modal:open`, `magik:modal:close` |

| Failure | Code | `fix:` |
|---|---|---|
| a required prop, slot, target or event is missing from the replacement | `MAGIK_COMPONENT_CONTRACT_VIOLATION` | `magik errors explain MAGIK_COMPONENT_CONTRACT_VIOLATION` |

The error names exactly what is missing — "`app/components/modal.rb` satisfies `Magik::Kit::Modal` but declares no slot `:actions`; `data_table` fills it" — because a contract violation an agent cannot act on is not a guardrail ([`07-ai-first.md`](07-ai-first.md)). The code is registered in the catalogue at [`03-guardrails.md`](03-guardrails.md).

This is the UI form of "proven, not promised": a replacement is accepted because it satisfies the contract at boot, not because its author intended it to.

## Resolution order

Most specific wins, first match, no merging:

| # | Source | Selected by |
|---|---|---|
| 1 | `app/components/` | file present, name matches |
| 2 | `domains/<name>/components/` | the resolving domain, for domain-scoped overrides ([`02-dsl-surface.md`](02-dsl-surface.md)) |
| 3 | a kit gem | `kit :acme_ui` in `App.define` — the seam for a house component library shared across several apps |
| 4 | the Magik built-in | always present, always last |

A domain-scoped override applies inside that domain only; a domain does not silently change how another domain renders.

**Shadowing is never invisible.** `magik check` reports every override and what it shadows:

```
component :Modal      app/components/modal.rb        shadows Magik::Kit::Modal    contract: ok
component :DataTable  domains/billing/components/…   shadows Magik::Kit::DataTable  contract: ok   scope: Billing
component :Chart      kit acme_ui                    shadows Magik::Kit::Chart    contract: ok
```

Silent magic is the failure being designed against; a shadow you cannot see is exactly that. Registry mechanics and why shadowing is a boundary concern: [`../architecture/02-boundaries.md`](../architecture/02-boundaries.md).

## One boundary, stated explicitly

**"No SPA framework" forbids React or Vue *owning rendering*. It does not forbid attaching JavaScript to your own component.**

| Allowed | Not allowed |
|---|---|
| a Stimulus controller, an Alpine directive, a web component, a vanilla `<script>` on your markup | a client-side router, a client-owned application state model, hydration of a server-rendered tree by a component framework |
| a date picker, a chart library, a rich text editor mounted on a server-rendered element | a build step the framework has to know about, or a second rendering path for the same screen |

The server renders the markup; you may wire whatever you like to it ([`05-limits.md`](05-limits.md)).

And whatever you replace still obeys the boot guardrails — a replacement component holds no in-process state across requests, and renders no timestamp without an explicit zone ([`03-guardrails.md`](03-guardrails.md)). The escape hatch is from Magik's *aesthetics*, never from its invariants.
