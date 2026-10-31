# frozen_string_literal: true
#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `test` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# dummy/test/models/invoice_test.rb  <->  app/models/invoice.rb
#
# THE TEST TREE MIRRORS app/ EXACTLY. One test file per declaration, at the same
# path. Given a file you know where its test is; given a failing test you know
# what it covers. No searching, no naming convention to remember beyond "the
# same path".
#
# This is NOT part of the framework's own suite. `rake test` at the repo root
# runs test/, not dummy/test/, and RuboCop excludes dummy/ entirely — none of
# this parses as anything the framework can execute yet.
#
# Demonstrates the Phase 9 test DSL: `test`/`it`/`expect` compiling to Minitest
# (never RSpec — spec decision), factories INFERRED from the field types in
# app/models/ (note the absence of any factory definition or fixture file), and
# `travel_to`.

test :Invoice do
  it "derives its total from its lines, never from a stored column" do
    invoice = create(:invoice, lines: [
                       { unit_price: 100_00, quantity: 2, tax_rate_bp: 2100 },
                       { unit_price: 50_00,  quantity: 1, tax_rate_bp: 0 }
                     ])

    expect(invoice.subtotal).to_eq money(250_00)
    expect(invoice.tax).to_eq money(42_00) # 21% of 200_00, in integer cents
    expect(invoice.total).to_eq money(292_00)
  end

  it "refuses to change its total once issued" do
    invoice = create(:invoice, status: :issued)

    expect { invoice.update!(currency: "USD") }.to_raise(code: "MAGIK_MODEL_IMMUTABLE_VIOLATION")
  end

  it "records who changed what, and when" do
    invoice = create(:invoice, status: :draft)

    as_user(create(:user, name: "Ana")) { invoice.update!(due_on: Date.new(2026, 4, 30)) }

    change = invoice.audit_trail.last
    expect(change.field).to_eq :due_on
    expect(change.by.name).to_eq "Ana"
  end

  it "is overdue the morning after it was due" do
    invoice = create(:invoice, status: :issued, due_on: Date.new(2026, 3, 31))

    travel_to Time.utc(2026, 4, 1, 7, 0) { run_job DunningSweep }

    expect(invoice.reload.status).to_eq :overdue
  end
end
