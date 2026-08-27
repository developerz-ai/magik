# Boundaries

Two boundary systems: the tier rules between Magik's own subsystems, and the domain rules an app declares. Both are meant to fail the build or the boot, never a review.

**Status:** planned. No tier checker exists, `bin/check` has no boundaries step, and the `domain` DSL is unimplemented. Reviewed 2026-08-26.

## Rule one — tiers, inside this repo

**Imports go down a tier only.** Never sideways within a tier, never upward.

```
tier 0   core
tier 1   schema, router, i18n, policy
tier 2   model, render, realtime, jobs
tier 3   action, ledger, api, auth, notify, pwa
tier 4   billing, admin, domains
tier 5   check, testing
tier 6   cli
```

The table is duplicated in [`01-module-map.md`](01-module-map.md) and will have an executable copy in `bin/check`. Prose and code must agree; when they diverge, the code is right and the prose is a bug.

| Rule | Detail |
|---|---|
| Down only | `action` (3) may require `model` (2). `model` may not require `action`. |
| No sideways | `render` may not require `realtime`; they are both tier 2. |
| Front door only | a subsystem requires `magik/<other>`, never `magik/<other>/internal_file`. Reaching past the front door is a violation even when the tier allows the subsystem. |
| No exceptions table | the first sideways exception means a tier is wrong. Fix the tier. |

### The edges that shaped the table

Each of these was the tempting sideways import, and the design that removed the need for it:

| Tempting edge | Why it is refused | What happens instead |
|---|---|---|
| `render` → `realtime` | `live :orders, on: "orders:{tenant}"` is rendered as an attribute, so `render` needs a channel **name**, not a transport | the channel-name vocabulary is declared in `core`; both sides read it from there |
| `core` → `check` | boot has to run guardrails, so `core` looks like it needs the rule set | `core` owns the rule *interface* and the runner; each rule ships in the subsystem that owns the concept; `check` (5) owns the static set ([`01-module-map.md`](01-module-map.md)) |
| `schema` → `model` | a migration generator wants to read model declarations | the generator lives in `cli` (6) and passes a declaration snapshot **into** `schema` as a value |
| `api` → `action` | REST resources look like actions | `api` resources are generated over `model` + `router`; an app's own callbacks are blocks it supplies |
| `jobs` → `notify` | notifications deliver through the queue | inverted: `notify` (3) requires `jobs` (2) and enqueues |
| `model` → `render` | serialization of a `:money` field for the admin | `model` exposes typed values; `render` and `api` decide presentation |

**`schema` sits at tier 1, not beside `core` at 0**, because it requires `core` for error codes and column value types. Colloquially both are "the bottom"; the table records the actual direction, so no exception line is needed.

### How it will be enforced

Planned as the `boundaries` step of `bin/check`:

```
1. read       every lib/magik/**/*.rb
2. scan       require / require_relative statements (regex over source — no app boot needed)
3. resolve    specifier → owning subsystem, or "internal file of another subsystem"
4. evaluate   tier(importer) > tier(imported)? front door only?
5. report     one finding per violation: file:line, both subsystems, both tiers, allowed set
```

| Property | Detail |
|---|---|
| Codes | `MAGIK_BOUNDARY_TIER` (sideways or upward) · `MAGIK_BOUNDARY_INTERNAL_REQUIRE` (past the front door) |
| Cost | a source scan, no boot, no database |
| Where it runs | `bin/check` and CI. Not in `magik server` — a tier violation is a repo defect, not an app one |
| `--json` | one finding object per violation, same schema as every other check ([`03-error-codes.md`](03-error-codes.md)) |

Until that step exists, the tier table is a convention — and per the repo's own rule, a convention with no check does not really exist. Writing the checker is part of build-order step 12 ([`../idea/06-phases.md`](../idea/06-phases.md)).

## Rule two — domains, inside an app

Spec item 12. The same idea one level up: an app's own modules, with a boundary the boot enforces.

```ruby
# domains/billing/domain.rb
domain :Billing do
  depends_on       :Accounts
  exposes          :InvoiceSummary, :charge_customer
  publishes_events :invoice_paid, :invoice_failed
end
```

```
domains/
  billing/
    domain.rb          # the declaration above
    models/            # owned by Billing — private unless exposed
    screens/
    actions/
    components/        # domain-scoped component overrides
  accounts/
    domain.rb
```

| Declaration | Meaning |
|---|---|
| `depends_on` | the domains this one may use. Undeclared use fails at boot, even if `exposes` would have allowed it. |
| `exposes` | the only constants and methods other domains may reach — the domain's public surface. |
| `publishes_events` | the events other domains may subscribe to. The decoupled path: a subscriber needs no `depends_on`. |

### What fails, and when

| Violation | When | Code |
|---|---|---|
| Referencing another domain's model constant directly | boot | `MAGIK_DOMAIN_BOUNDARY` |
| Using a domain not in `depends_on` | boot | `MAGIK_DOMAIN_UNDECLARED_DEPENDENCY` |
| A dependency cycle between domains | boot | `MAGIK_DOMAIN_CYCLE` |
| Subscribing to an event no domain publishes | boot | `MAGIK_DOMAIN_UNKNOWN_EVENT` |
| Two domains declaring the same model | boot | `MAGIK_DOMAIN_DUPLICATE_OWNER` |

Boot-time is the whole point: a domain boundary enforced by review erodes at exactly the moment the app is large enough to need it. The intended failure shape:

```
MAGIK_DOMAIN_BOUNDARY  domains/billing/actions/charge.rb:12

  domain :Billing references Accounts::User directly.
  Accounts exposes: :AccountSummary, :find_account. Billing depends_on: [:Accounts].

  fix: magik check --domains
```

### Legal paths between domains

| Path | Shape | Coupling |
|---|---|---|
| Exposed interface | `Accounts.find_account(id)` | compile-time-ish: `depends_on` required, boot-verified |
| Published event | `on :invoice_paid do |event| … end` | loose: no `depends_on`, publisher does not know the subscriber |
| Shared value types | `Magik::Money`, `Magik::Timestamp` — framework types | none |
| Anything else | — | refused at boot |

An app that declares no domains has exactly one implicit domain, and none of these rules bites. Domains are for the large-app case the spec names; they are not a tax on a small app.

## Rule three — component shadowing

Replacing a kit component is a boundary event too: the registry resolves `component :Modal` to one definition, and every other component composes whatever it resolved to.

| Rule | Detail |
|---|---|
| Resolution order | `app/components/` → `domains/<name>/components/` → a `kit :name` gem → the Magik built-in. First match wins, no merging ([`../idea/08-component-overrides.md`](../idea/08-component-overrides.md)). |
| Scope | a domain-scoped override applies inside that domain only; it never changes another domain's rendering. |
| Contract | a replacement declaring `satisfies Magik::Kit::X` is verified at boot — missing prop, slot, target or event fails with `MAGIK_COMPONENT_CONTRACT_VIOLATION`. |
| Visibility | `magik check` prints every shadow and its scope. An override nobody can see is the silent magic the design exists to prevent. |

## Why boundaries at all

| Without | With |
|---|---|
| every subsystem eventually requires every other, and the gem cannot be reasoned about or split | the dependency graph is a DAG you can read in one table |
| domain boundaries hold only while the team is small and disciplined | they hold because the app does not boot otherwise |
| a component override changes rendering somewhere nobody looked | the shadow is reported and its contract is verified |
