# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `migrate` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# db/migrations/20260826120000_create_customers_and_invoices.rb
#   <->  migrate :CreateCustomersAndInvoices
#
# The filename carries the ordering (a UTC timestamp prefix) and the declaration
# name carries the meaning; both halves must agree, and `magik check` says so if
# they do not.
#
# Demonstrates: migrate, up/down, uuid_v7 primary keys, automatic tenant_id,
# the :money and :file column helpers, a :duration column, and indexes that
# exist because of how the app queries.

migrate :CreateCustomersAndInvoices do
  up do
    create_table :accounts do
      # uuid_v7 by default from config/app.rb: time-sortable, shard-safe, and
      # no sequence to reconcile when the table is split (spec decision 8).
      primary_key :id
      column :name,      :string, null: false
      column :subdomain, :string, null: false
      column :plan,      :string, null: false, default: "free"
      column :country,   :string, null: false
      column :currency,  :string, null: false, default: "EUR"
      timestamps

      index :subdomain, unique: true
    end

    create_table :customers do
      primary_key :id
      # tenant_id is INJECTED, not written here — every table but the tenant
      # root gets one, with its index and its foreign key. Declaring it by hand
      # is how one table quietly ends up without it.
      column :name,     :string, null: false
      column :email,    :string, null: false
      column :vat_id,   :string
      column :notes,    :jsonb, default: "{}" # translatable: one key per locale
      column :archived, :boolean, null: false, default: false
      # A :duration is stored as the unit-suffixed string it was declared with
      # ("30d"), coerced at boot rather than at read time. One column, and the
      # unit is in the value where it belongs rather than in the column name.
      column :payment_terms, :string, null: false, default: "30d"
      timestamps

      index %i[tenant_id email]
    end

    create_table :invoices do
      primary_key :id
      foreign_key :customer_id, :customers, null: false
      column :number,    :string, null: false
      column :status,    :string, null: false, default: "draft"
      column :currency,  :string, null: false
      column :issued_on, :date
      column :due_on,    :date
      column :issued_at, :timestamptz # never a bare `timestamp`
      # `file` emits the blob reference for a `:file` field, exactly as `money`
      # below emits two columns for a `:money` one. The bytes are not in the
      # database; the row points at them.
      file   :purchase_order
      timestamps

      index %i[tenant_id number], unique: true
      # The index behind `scope :overdue`. Partial, because the unpaid rows are
      # the small minority that anyone ever sweeps.
      index %i[tenant_id due_on], where: "status IN ('issued', 'overdue')"
    end

    create_table :invoice_lines do
      primary_key :id
      foreign_key :invoice_id, :invoices, null: false, on_delete: :cascade
      column :description, :jsonb, null: false # translatable
      column :quantity,    :integer, null: false
      # :money is two columns — integer cents plus an ISO currency code. There
      # is no float, numeric or decimal anywhere near currency in this schema
      # (spec decision 10).
      money  :unit_price
      column :tax_rate_bp, :integer, null: false, default: 0
      timestamps
    end
  end

  down do
    drop_table :invoice_lines, :invoices, :customers, :accounts
  end
end
