# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `migrate` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# db/migrations/20260826120100_create_payments_and_ledger.rb
#   <->  migrate :CreatePaymentsAndLedger
#
# Demonstrates: an append-only table, a unique index that enforces idempotency
# in the database rather than only in Ruby, and the fact that there is no
# `balance` column anywhere — balances are derived from entries, always.

migrate :CreatePaymentsAndLedger do
  up do
    create_table :payments do
      primary_key :id
      foreign_key :invoice_id, :invoices, null: false
      money  :amount
      column :method,          :string, null: false
      column :status,          :string, null: false, default: "pending"
      column :received_at,     :timestamptz
      column :processor,       :string, null: false, default: "stripe"
      # A processor token. There is no card_number column and there cannot be:
      # `field :card_number` is refused at boot (spec: Guardrails).
      column :processor_token, :string, null: false
      column :idempotency_key, :string, null: false
      timestamps

      # `idempotent_by` in app/actions/record_payment.rb is enforced here too.
      # A dedupe that lives only in application code loses to two workers
      # racing on the same webhook retry.
      index %i[tenant_id idempotency_key], unique: true
    end

    create_table :ledger_entries do
      primary_key :id
      column :entry_type, :string, null: false # :invoice_issued, :payment_received, ...
      column :posted_on,  :date, null: false
      column :reference,  :string, null: false # the invoice or payment it describes
      timestamps

      index %i[tenant_id posted_on]
      index %i[tenant_id reference]
    end

    create_table :ledger_postings do
      primary_key :id
      foreign_key :ledger_entry_id, :ledger_entries, null: false, on_delete: :restrict
      column :account,   :string, null: false # matches `account` in the ledger DSL
      column :direction, :string, null: false # debit | credit
      money  :amount

      index %i[tenant_id account]
    end

    # Append-only, enforced by the database and not only by convention. The
    # ledger's whole value is that history cannot be edited, and "we agreed not
    # to write an UPDATE" is not a guarantee.
    append_only :ledger_entries, :ledger_postings
  end

  down do
    drop_table :ledger_postings, :ledger_entries, :payments
  end
end
