# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `model` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# app/models/invoice_line.rb  <->  model :InvoiceLine
#
# One model per file, even when the model is six fields. `has_many :lines` in
# invoice.rb has to resolve to a file you can guess the name of.
#
# Demonstrates: :money arithmetic in a computed field, quantity as an integer,
# a percentage held as basis points rather than a float.

model :InvoiceLine do
  field :description, :string, required: true, translatable: true
  field :quantity,    :integer, required: true, min: 1
  field :unit_price,  :money,   required: true

  # Basis points, not 0.21. A tax rate stored as a Float is a rounding bug with
  # a date on it; 2100 bp is exact, and the money type does the multiplication
  # in integer cents.
  field :tax_rate_bp, :integer, default: 0, min: 0, max: 10_000

  belongs_to :invoice

  computed(:amount,     :money) { unit_price * quantity }
  computed(:tax_amount, :money) { amount * tax_rate_bp / 10_000 }
end
