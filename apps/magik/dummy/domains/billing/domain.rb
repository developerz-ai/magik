# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `domain` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# domains/billing/domain.rb  <->  domain :Billing
#
# THE LARGE-APP SHAPE. Everything under app/ is the small-app shape: one flat
# set of directories, every model visible to every other. That works until it
# does not. A domain is the escape hatch, and it is enforced at BOOT rather than
# by review (spec decision 12): a domain that reaches into another domain's
# models directly fails to start.
#
# This domain owns the money Ledgerline charges its own users — subscriptions
# and plan limits. It is deliberately NOT the same thing as
# app/ledgers/receivables.rb, which is Ledgerline's users invoicing their
# customers. Two money flows that sound identical in English and must never
# share a model.
#
# See dummy/README.md for when to move a slice from app/ into domains/.

domain :Billing do
  # What this domain may reach for. Anything not listed is refused at boot, so
  # the dependency graph is a fact you can read rather than one you infer from
  # imports.
  depends_on :none

  # Its own models live under domains/billing/app/models/ and are private by
  # default. `exposes` is the entire public surface — the only names another
  # domain may reference.
  exposes :Subscription, only: %i[active? plan seats_used seats_limit]
  exposes :charge_for_overage

  # The events it publishes. Another domain subscribes to these instead of
  # calling in, which is what keeps the boundary a boundary.
  publishes_events :subscription_started,
                   :subscription_cancelled,
                   :plan_limit_reached,
                   :payment_failed

  # A domain-local guardrail: nothing outside this file may write a plan.
  invariant "plan changes happen through this domain only" do
    writes_to(:Subscription).all? { |site| site.within?(:Billing) }
  end
end
