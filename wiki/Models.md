# Models

**Status:** `Planned — not implemented`. Spec Phase 1, build step 2. Nothing on this page runs.
`As of 2026-08-26`.

A `model` declares a table, its fields, its validations, its associations and its scopes. It wraps
[Sequel](https://sequel.jeremyevans.net) — explicit queries, no lazy-loading magic, no implicit N+1.

## The shape

```ruby
# app/models/invoice.rb
model :Invoice do
  field :number,   :string, required: true, unique_per_tenant: true
  field :amount,   :money,  required: true, currency: :usd
  field :status,   :enum,   values: %i[draft sent paid void], default: :draft
  field :due_on,   :date
  field :notes,    :text,   translatable: true
  field :sent_at,  :timestamp

  belongs_to :customer
  has_many   :line_items

  validate :amount, positive: true
  validate :due_on, after: :created_at

  scope :outstanding, -> { where(status: %i[draft sent]) }
  scope :overdue,     -> { outstanding.where { due_on < Date.today } }

  audited
  immutable_after :paid
end
```

Four things you did **not** write, and never write:

| Injected | Value |
|---|---|
| `id` | UUIDv7 — sortable by creation time, shard-safe, no sequence to coordinate |
| `tenant_id` | set from the current tenant on insert, and in the `WHERE` clause of every read |
| `created_at` / `updated_at` | maintained by the framework |
| The `WHERE tenant_id = ?` predicate | added to every query. Forgetting it is not a thing you can do |

## Field types

| Type | Backed by | Notes |
|---|---|---|
| `:string` | `text` | `limit:` adds a check constraint, not a truncation |
| `:text` | `text` | for prose. `translatable: true` makes it per-locale |
| `:integer` | `bigint` | — |
| `:decimal` | `numeric` | for quantities and rates. **Not** for currency |
| `:currency` | `text` + check constraint | an ISO-4217 code. What a `:money` amount is denominated in |
| `:money` | `bigint` cents + a currency | integer cents. A `Float` is refused by the type system — see [Money and ledgers](Money-And-Ledgers.md) |
| `:boolean` | `boolean` | — |
| `:date` | `date` | no time, no zone |
| `:timestamp` | `timestamptz` | stored UTC. Rendering one without an explicit zone is a **boot failure** |
| `:enum` | `text` + check constraint | `values:` is required |
| `:json` | `jsonb` | for genuinely schemaless data. If you find yourself querying into it, it wanted to be columns |
| `:uuid` | `uuid` | for foreign keys you manage yourself |
| `:vector` | `pgvector` | embeddings, for search |

`field :card_number` — under any type — is **refused at boot**. So is any field whose name matches a
PAN-shaped pattern. The framework does not let you build the storage that a PCI audit exists to find.
Tokenize with the billing provider instead; see [Auth, billing, admin](Auth-Billing-Admin.md).

```text
MAGIK_PAN_FIELD_FORBIDDEN: :Invoice declares field :card_number
  fix: store a provider token instead — `field :payment_method_token, :string`
```

## Migrations

Schema changes are a separate DSL over Sequel migrations, in `db/migrations/`, ordered and append-only.

```ruby
# db/migrations/002_create_invoices.rb
migrate :CreateInvoices do
  up do
    create_table_for :Invoice          # derives columns from the model declaration
    add_index :invoices, %i[tenant_id status due_on]
  end

  down do
    drop_table :invoices
  end
end
```

`create_table_for :Invoice` reads the model and emits the columns, the UUIDv7 default, the
`tenant_id`, the timestamps, the enum check constraint and the foreign keys. Hand-writing columns is
allowed and is what you do for anything the model does not describe.

| Rule | Detail |
|---|---|
| Append-only | a migration that has run anywhere is never edited. Add a new one |
| `down` is required | a migration with no `down` is refused. "It is irreversible" is a statement you make explicitly, with `irreversible!` |
| `db/schema.rb` is generated | committed, never hand-edited. It is the reproducible truth |
| Drift is a failure | a schema that does not match the migrations is caught by `magik check` |

```bash
magik generate model Invoice     # writes the model and its migration together
magik generate migration AddPaidAtToInvoices
```

## Querying

Sequel datasets, tenant-scoped, explicit.

```ruby
Invoice.outstanding.order(:due_on).limit(50)
Invoice.overdue.eager(:customer)                # explicit preload — there is no lazy fallback
Invoice.where(customer_id: id).sum(:amount)
Invoice.find!(id)                               # raises MAGIK_RECORD_NOT_FOUND, never returns nil
```

**There is no lazy loading.** `invoice.customer` on a record loaded without `eager(:customer)` is
intended to raise rather than silently issue a query, because a silent query in a loop is the N+1 that
nobody sees until production.

```text
MAGIK_LAZY_ASSOCIATION: :Invoice#customer was not eagerly loaded
  fix: add `.eager(:customer)` to the query that loaded this record
```

## Guardrails

| Guardrail | Fails with | When |
|---|---|---|
| PAN-shaped field names are forbidden | `MAGIK_PAN_FIELD_FORBIDDEN` | boot |
| Every query carries `tenant_id` | `MAGIK_TENANT_SCOPE_MISSING` | `magik check --scale` |
| A `:money` field cannot take a `Float` | `MAGIK_MONEY_FLOAT` | assignment |
| A `:timestamp` cannot render without a zone | `MAGIK_TIMEZONE_UNSPECIFIED` | boot |
| A record past `immutable_after:` cannot be updated | `MAGIK_IMMUTABLE_RECORD` | write |
| Associations are not lazily loaded | `MAGIK_LAZY_ASSOCIATION` | access |

Full catalogue: [Error codes](Error-Codes.md). Why each exists:
[`docs/idea/03-guardrails.md`](../docs/idea/03-guardrails.md).

## Swap points

| Seam | Default | Swap to | How |
|---|---|---|---|
| Database engine | PostgreSQL | any Sequel adapter | `config/backends.rb` |
| Search | Postgres full-text | pgvector, or an external engine | `config/backends.rb` |
| Primary key strategy | UUIDv7 | — | **not a swap point.** Sortable, shard-safe keys are load-bearing for the scale story |
| Tenancy | `tenant_id` column | — | **not a swap point.** Multi-tenant by default is architecture decision 8 |

The rule from the spec: every opinionated default has a **working, tested** config-level swap, proven
before merge rather than promised in a doc. The two rows above marked "not a swap point" are stated as
such deliberately — pretending everything is swappable is its own dishonesty.
See [`docs/idea/04-swap-points.md`](../docs/idea/04-swap-points.md).

## Next

- [Money and ledgers](Money-And-Ledgers.md) — the `:money` type in full.
- [Screens and components](Screens-And-Components.md) — putting a model on a page.
- [Actions](Actions.md) — changing one.
- [Testing](Testing.md) — factories inferred from the field types above.
