# Money and ledgers

**Status:** `Planned — not implemented`. The `:money` type is spec Phase 1; ledgers, audit and
idempotency are spec Phase 5, build step 9. Nothing on this page runs. `As of 2026-08-26`.

Magik has no "fintech mode". A ledger is declared with the same grammar as a model, and the money
guarantees are on by default for every app — the spec's success criterion is that fintech-grade
handling is *the same DSL*, not a separate product.

## The `:money` type

Integer cents with an attached currency. **Floats are forbidden at the type-system level**, not
discouraged in a style guide.

```ruby
model :Invoice do
  field :amount, :money, required: true, currency: :usd
end

Invoice.create(amount: 149_99)          # cents. Correct.
Invoice.create(amount: Money.usd(149.99))
Invoice.create(amount: 149.99)          # refused
```

```text
MAGIK_MONEY_FLOAT: :Invoice#amount received a Float (149.99)
  fix: pass integer cents (14999) or Money.usd("149.99")
```

Arithmetic across currencies is refused (`MAGIK_CURRENCY_MISMATCH`) rather than silently converted at
a rate nobody chose. Conversion is an explicit call with an explicit rate and an audit trail.

## A ledger

Double-entry, append-only, balance-validated at boot.

```ruby
# app/ledgers/receivables.rb
ledger :Receivables do
  account :accounts_receivable, type: :asset
  account :revenue,             type: :income
  account :cash,                type: :asset

  entry :invoice_issued do |invoice|
    debit  :accounts_receivable, invoice.amount
    credit :revenue,             invoice.amount
    guard  invoice.amount.positive?, "cannot issue a non-positive invoice"
  end

  entry :invoice_settled do |invoice|
    debit  :cash,                 invoice.amount
    credit :accounts_receivable,  invoice.amount
  end
end
```

| Rule | Detail |
|---|---|
| Debits equal credits | an entry whose sides disagree **fails at boot**, not at the first transaction |
| Append-only | a ledger entry cannot be updated or deleted through the DSL. Corrections are reversing entries |
| Guards | a precondition on the entry, checked before anything is written |
| One currency per entry | mixing currencies inside one entry is refused |

```text
MAGIK_LEDGER_UNBALANCED: :Receivables entry :invoice_issued debits 14999, credits 14900
  fix: correct the amounts in app/ledgers/receivables.rb — debits must equal credits
```

Boot-time validation is the point. A balance check that runs at transaction time tells you about the
bug after it has already happened to a customer.

## Audit and immutability

```ruby
model :Invoice do
  audited                        # every change recorded: who, when, before, after
  immutable_after :paid          # once status is :paid, the record is frozen
end
```

`audited` writes an append-only trail alongside the record. `immutable_after:` refuses writes past a
state:

```text
MAGIK_IMMUTABLE_RECORD: :Invoice 0192... is :paid and immutable_after :paid
  fix: issue a credit note instead of editing a settled invoice
```

## Idempotency

A retried mutation must not perform twice.

```ruby
action :charge_invoice, policy: %i[Invoice record_payment] do
  idempotent_by :invoice_id, window: "24h"      # a :duration

  perform do |params|
    invoice = Invoice.find!(params[:invoice_id])
    Billing.charge(invoice)
    Receivables.invoice_settled(invoice)
  end
end
```

A second call with the same key inside the window returns the first call's result and performs
nothing. An action that writes to a ledger **without** `idempotent_by` is a boot failure
(`MAGIK_IDEMPOTENCY_REQUIRED`) — a double-submittable payment is not something to catch in review.

## Flows

Multi-step processes with persisted state: onboarding, KYC, checkout.

```ruby
# app/flows/onboarding.rb
flow :Onboarding do
  step :company_details do
    form action: :save_company do
      field :legal_name, :string, required: true
      field :country,    :enum, values: Countries.all
    end
  end

  step :identity_check, if: -> { tenant.country == :us } do
    form action: :submit_kyc do
      field :document, :file
    end
  end

  step :payment_method do
    form action: :attach_payment_method do
      field :payment_method_token, :string      # a token. Never a PAN
    end
  end

  on_complete { |tenant| tenant.update(onboarded_at: Time.now.utc) }
end
```

Flow state lives in the database, not in a session — stateless app servers, architecture decision 9.
A user can close the tab and resume on another server.

## Card data never lands

`field :card_number` is refused at boot under any type, as is any PAN-shaped field name. Tokenize
with the billing provider; store the token. The framework does not offer the storage that a PCI audit
exists to find.

```text
MAGIK_PAN_FIELD_FORBIDDEN: :PaymentMethod declares field :card_number
  fix: store the provider token — `field :payment_method_token, :string`
```

## Guardrails

| Guardrail | Fails with | When |
|---|---|---|
| Ledger entries balance | `MAGIK_LEDGER_UNBALANCED` | boot |
| No PAN-shaped field names | `MAGIK_PAN_FIELD_FORBIDDEN` | boot |
| A ledger-writing action declares idempotency | `MAGIK_IDEMPOTENCY_REQUIRED` | boot |
| No `Float` in a `:money` field | `MAGIK_MONEY_FLOAT` | assignment |
| No cross-currency arithmetic | `MAGIK_CURRENCY_MISMATCH` | arithmetic |
| No update or delete of a ledger entry | `MAGIK_LEDGER_APPEND_ONLY` | write |
| No write past `immutable_after:` | `MAGIK_IMMUTABLE_RECORD` | write |
| Money moves only through a ledger | `MAGIK_MONEY_OUTSIDE_LEDGER` | boot |

## Swap points

| Seam | Default | Swap to |
|---|---|---|
| Ledger storage | the app's Postgres | another Sequel-supported engine, via `config/backends.rb` |
| Currency arithmetic | the `money` gem | — wrapped, not reimplemented |
| Billing provider | Stripe | Paddle, via `billing provider:` — see [Auth, billing, admin](Auth-Billing-Admin.md) |
| Double-entry itself | — | **not a swap point.** A single-entry balance column is the bug this exists to prevent |

## Next

- [Models](Models.md) — the `:money` field type in context.
- [Actions](Actions.md) — `idempotent_by`.
- [Auth, billing, admin](Auth-Billing-Admin.md) — the provider side.
- [Testing](Testing.md) — auto-generated ledger balance tests.
