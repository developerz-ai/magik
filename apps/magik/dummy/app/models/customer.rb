# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `model` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# app/models/customer.rb  <->  model :Customer
#
# A person or company that this tenant invoices. Note what is absent: no
# tenant_id field is declared, because every model outside the tenant root gets
# one injected and scoped automatically (spec decision 8). Writing it by hand
# would be the bug, not the safety.
#
# Demonstrates: field types including :duration, belongs_to, has_many, computed
# money, scope, translatable fields (Phase 8).

model :Customer do
  field :name,     :string, required: true
  field :email,    :email,  required: true
  field :vat_id,   :string
  field :notes,    :text,   translatable: true # Phase 8: per-locale content
  field :archived, :boolean, default: false

  # Net-30, as a :duration — a unit-suffixed string coerced at boot, so "30d"
  # and "45d" are the same type and a typo fails the boot rather than the first
  # invoice. The alternative, `payment_terms_days: 30`, puts the unit in the
  # field name and makes "two weeks" a second field (spec D1).
  field :payment_terms, :duration, default: "30d"

  belongs_to :account
  has_many :invoices

  # A :money field is integer cents with a currency, never a Float — the type
  # system refuses floats for currency (spec decision 10). Derived rather than
  # stored, so it cannot drift from the invoices it summarises.
  # The parentheses are load-bearing everywhere `computed` appears: a brace
  # block binds to the last call, so `computed :name, :type { ... }` would bind
  # the block to the symbol. See dummy/README.md, "What writing this taught us".
  computed(:outstanding, :money) do
    invoices.unpaid.sum(:total)
  end

  scope :active,   -> { where(archived: false) }
  scope :owing,    -> { active.having { outstanding > 0 } }

  validate :email, "must be deliverable" do |value|
    value.include?("@") # a real app checks MX; the point here is the DSL shape
  end
end
