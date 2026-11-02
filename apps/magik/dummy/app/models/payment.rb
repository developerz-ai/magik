# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `model` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# app/models/payment.rb  <->  model :Payment
#
# Demonstrates the guardrail that has no opt-out: there is no card number here,
# and there cannot be. `field :card_number` is refused at boot (spec:
# Guardrails), which is why this model holds a processor token instead. A
# framework that lets you store a PAN is a framework that will be used to store
# one.

model :Payment do
  field :amount,      :money, required: true
  field :method,      :enum, values: %i[card sepa_debit bank_transfer credit_note]
  field :status,      :enum, values: %i[pending settled failed refunded], default: :pending
  field :received_at, :timestamp

  # The processor's opaque handle. Not a card number, not a PAN, not a last-4
  # you reconstructed from one. `field :card_number, ...` fails the boot check.
  field :processor_token, :string, required: true
  field :processor,       :enum, values: %i[stripe adyen manual], default: :stripe

  belongs_to :invoice
  belongs_to :account

  scope :settled, -> { where(status: :settled) }

  # The processor's idempotency key. A retried webhook or a double-clicked
  # button must not create a second payment; see app/actions/record_payment.rb,
  # where `idempotent_by` reads this.
  field :idempotency_key, :string, required: true, unique_per_tenant: true

  audited
  immutable_after :settled
end
