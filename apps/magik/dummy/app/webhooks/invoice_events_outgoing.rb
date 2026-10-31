# frozen_string_literal: true
#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `webhook` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# app/webhooks/invoice_events_outgoing.rb  <->  webhook :outgoing, :invoice_events
#
# Events leaving FOR a third party — a tenant's own systems, subscribed from
# their settings page. One file per webhook, and the `_incoming` / `_outgoing`
# suffix is the direction, because a directory listing should tell you which way
# the trust runs without opening anything.
#
# Demonstrates: webhook :outgoing, fires_on, deliver_to, sign_with (Phase 6).

webhook :outgoing, :invoice_events do
  # The events, named. Not "everything that happens" — a firehose nobody asked
  # for is a firehose you cannot change later without breaking a subscriber.
  fires_on :invoice_issued, :invoice_paid, :invoice_overdue

  # Per-tenant endpoints, so this is a function of the tenant rather than a
  # constant in a config file.
  deliver_to ->(tenant) { tenant.webhook_endpoints }

  # Signed so the receiver can verify us, with the same scheme we require of
  # Stripe in stripe_incoming.rb. Asking for a guarantee you do not provide is
  # not a policy.
  sign_with :hmac_sha256, secret: ->(endpoint) { endpoint.signing_secret }

  # Spelled `retries`, not `retry`: `retry` is a Ruby keyword and cannot be a
  # method name. See dummy/README.md, "What writing this taught us". `base:` is
  # a :duration (spec D1), never `1.minute` — there is no ActiveSupport here.
  retries times: 8, backoff: :exponential, base: "1m"

  # The same shape app/api/v1.rb returns. A webhook payload that differs from
  # the API's representation of the same object is two contracts to maintain.
  payload :Invoice, representation: :V1
end
