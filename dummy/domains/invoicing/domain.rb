# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `domain` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# domains/invoicing/domain.rb  <->  domain :Invoicing
#
# The other side of the boundary, and the reason there are two domain files
# instead of one: a boundary needs two parties to be visible.
#
# This domain owns everything under app/ — the invoices Ledgerline's users send
# to THEIR customers. It needs to know when a tenant's own subscription lapses,
# and it gets that by SUBSCRIBING to an event, never by reading
# Billing::Subscription. That read would fail at boot (spec decision 12).

domain :Invoicing do
  # Named, and narrow. `depends_on :Billing` grants access to Billing's
  # `exposes` list and nothing else — not its models, not its tables.
  depends_on :Billing

  # This domain currently holds the whole app/ tree. `owns` is what makes the
  # small-app layout and the domain layout the same layout: app/models/,
  # app/screens/ and the rest belong to exactly one domain until you split them.
  owns "app/**"

  exposes :Invoice, only: %i[number status total balance]
  exposes :Customer, only: %i[name email outstanding]

  publishes_events :invoice_issued, :invoice_paid, :invoice_written_off

  # The subscription: a one-way dependency, expressed as data crossing the line
  # rather than as a call reaching across it.
  subscribes_to "Billing.payment_failed" do |event|
    as_tenant(event.account_id) { Account.current.suspend_invoicing!(reason: :payment_failed) }
  end

  subscribes_to "Billing.plan_limit_reached" do |event|
    as_tenant(event.account_id) { notify :plan_limit_reached, to: Account.current.owner }
  end
end
