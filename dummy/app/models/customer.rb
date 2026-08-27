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
# Demonstrates: field types, belongs_to, has_many, computed money, scope,
# translatable fields (Phase 8).

model :Customer do
  field :name,     :string, required: true
  field :email,    :email,  required: true
  field :vat_id,   :string
  field :notes,    :text,   translatable: true # Phase 8: per-locale content
  field :archived, :boolean, default: false

  belongs_to :account
  has_many :invoices

  # A :money field is integer cents with a currency, never a Float — the type
  # system refuses floats for currency (spec decision 10). Derived rather than
  # stored, so it cannot drift from the invoices it summarises.
  computed :outstanding, :money do
    invoices.unpaid.sum(:total)
  end

  scope :active,   -> { where(archived: false) }
  scope :owing,    -> { active.having { outstanding > 0 } }

  validate :email, "must be deliverable" do |value|
    value.include?("@") # a real app checks MX; the point here is the DSL shape
  end
end
