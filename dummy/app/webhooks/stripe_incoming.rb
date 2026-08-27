# frozen_string_literal: true
#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `webhook` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# app/webhooks/stripe_incoming.rb  <->  webhook :incoming, :stripe
#
# Events arriving FROM a third party. Its own directory rather than app/api/,
# because the direction of trust is the opposite: `api/` is a surface we
# authenticate callers against, `webhooks/incoming` is a surface we authenticate
# ourselves against a signature we did not choose.
#
# Note what this file does NOT contain: any business logic. An incoming webhook
# is just another caller of an existing action, and giving it its own copy of
# the rules is how a Stripe payment and a hand-entered payment end up validated
# differently.
#
# Demonstrates: webhook :incoming, verify_signature, on :event (Phase 6).

webhook :incoming, :stripe do
  # Verified before the body is parsed, let alone trusted. An unsigned webhook
  # endpoint is an unauthenticated mutation endpoint with better branding.
  verify_signature header: "Stripe-Signature", secret: credential(:stripe_webhook_secret)

  on "payment_intent.succeeded" do |event|
    # The same action the UI modal posts to — one set of invariants, two callers.
    # Stripe retries aggressively; `idempotent_by` in that action reads the key
    # passed here, so a replayed delivery records nothing twice.
    perform_action :record_payment,
                   invoice_id: event.metadata[:invoice_id],
                   amount: Money.new(event.amount_received, event.currency),
                   method: :card,
                   processor_token: event.payment_method,
                   idempotency_key: event.id
  end

  on "charge.dispute.created" do |event|
    Invoice.find(event.metadata[:invoice_id]).flag!(:disputed, reason: event.reason)
  end
end
