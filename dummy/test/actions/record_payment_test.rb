# frozen_string_literal: true
#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `test` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# dummy/test/actions/record_payment_test.rb  <->  app/actions/record_payment.rb
#
# The money path, tested where the money moves. Every property here is one the
# ledger has to hold under conditions a single-threaded test would never find.
#
# Demonstrates: perform_action, assert_enqueued, assert_broadcast, render_screen,
# and `concurrently(n)` — one Ractor per caller, which is how an idempotency
# claim gets tested rather than asserted (Phase 9).

test :RecordPayment do
  it "refuses a payment larger than the balance" do
    invoice = create(:invoice, status: :issued, lines: [{ unit_price: 10_00, quantity: 1 }])

    expect {
      perform_action :record_payment,
                     invoice_id: invoice.id, amount: money(20_00),
                     method: :card, processor_token: "tok_test",
                     idempotency_key: "k1"
    }.to_raise(code: "LEDGERLINE_OVERPAYMENT")

    expect(invoice.reload.balance).to_eq money(10_00)
  end

  it "keeps the ledger balanced, and marks the invoice paid" do
    invoice = create(:invoice, status: :issued, lines: [{ unit_price: 100_00, quantity: 1 }])

    perform_action :record_payment,
                   invoice_id: invoice.id, amount: money(100_00),
                   method: :sepa_debit, processor_token: "tok_test",
                   idempotency_key: "k2"

    # The property that must hold after every entry, forever.
    expect(Receivables.debits).to_eq Receivables.credits
    expect(invoice.reload.status).to_eq :paid
  end

  it "records a retried webhook exactly once, under concurrency" do
    invoice = create(:invoice, status: :issued)
    args = { invoice_id: invoice.id, amount: money(5_00), method: :card,
             processor_token: "tok_test", idempotency_key: "evt_same" }

    # Same key, four callers at once. A dedupe that only holds against a repeat
    # and not against a race is not a dedupe — two workers pulling the same
    # Stripe retry is the exact case it exists for.
    concurrently(4) { perform_action :record_payment, **args }

    expect(invoice.payments.count).to_eq 1
  end

  it "issues an invoice, enqueues the email and broadcasts to the dashboard" do
    invoice = create(:invoice, status: :draft)

    assert_enqueued SendInvoiceEmail, invoice_id: invoice.id do
      assert_broadcast "invoices:tenant", :issued do
        perform_action :issue_invoice, invoice_id: invoice.id
      end
    end

    expect(invoice.reload.status).to_eq :issued
  end

  it "renders the dashboard without a database query in the screen body" do
    # A screen that queries in `body` instead of in `state` fails this, because
    # render_screen supplies the state and forbids queries below it.
    html = render_screen :Dashboard, outstanding: money(1_234_56), overdue_count: 2
    expect(html).to_include "1,234.56"
  end
end
