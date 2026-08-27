# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `ledger` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# app/ledgers/receivables.rb  <->  ledger :Receivables
#
# THE ONLY FILE IN THIS APP THAT TOUCHES MONEY MOVEMENT. Not "the main one" —
# the only one. Nothing anywhere else increments a balance, and there is no
# `balance` column to increment: a balance is the sum of entries, always
# derivable, never stored and never wrong.
#
# Double entry, append-only, boot-validated. Every entry's debits must equal its
# credits or the app does not start (spec: Guardrails). That check runs against
# the DECLARATIONS at boot, not against production data at 3am.
#
# Demonstrates: ledger, account, entry, debit/credit, guard (Phase 5).

ledger :Receivables do
  currency_from ->(invoice) { invoice.currency }

  # The chart of accounts. Naming them here means an entry cannot post to an
  # account nobody declared, which is how a typo becomes a reconciliation job.
  account :accounts_receivable, type: :asset
  account :revenue,             type: :income
  account :tax_payable,         type: :liability
  account :cash,                type: :asset
  account :bad_debt,            type: :expense

  # An invoice is issued: the customer now owes us. Revenue and the tax we owe
  # the state are recognised at the same moment, from the same numbers.
  entry :invoice_issued do |invoice:|
    debit  :accounts_receivable, invoice.total
    credit :revenue,             invoice.subtotal
    credit :tax_payable,         invoice.tax

    # Redundant with the double-entry check by design. The guard names the
    # business rule in the language of the business; the balance check is
    # arithmetic. When this fails, the message says which one broke.
    guard "an issued invoice must have at least one line" do
      invoice.lines.any?
    end
  end

  # A payment arrives: cash up, receivable down. Note that nothing here updates
  # Invoice#balance — there is no such column. `computed :balance` in
  # app/models/invoice.rb derives it, so it cannot drift from this ledger.
  entry :payment_received do |invoice:, payment:|
    debit  :cash,                payment.amount
    credit :accounts_receivable, payment.amount

    guard "a payment cannot exceed the invoice balance",
          code: "LEDGERLINE_OVERPAYMENT" do
      payment.amount <= invoice.balance
    end
  end

  # Writing off an unrecoverable invoice. The receivable does not vanish — it
  # moves to an expense account, because append-only means the original entry
  # stays exactly as it was posted.
  entry :written_off do |invoice:|
    debit  :bad_debt,            invoice.balance
    credit :accounts_receivable, invoice.balance
  end
end
