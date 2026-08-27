# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `model` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# domains/billing/app/models/subscription.rb  <->  model :Subscription
#
# A DOMAIN-LOCAL MODEL. Note the path: a domain repeats the same app/<concern>/
# layout inside itself, so moving a slice out of app/ and into domains/ is a
# `git mv` and a domain.rb, not a rewrite. The file/declaration mapping is
# identical at both levels.
#
# This model is PRIVATE to :Billing. Only the methods listed in
# domains/billing/domain.rb's `exposes` line are reachable from outside, and a
# direct `Subscription.where(...)` in app/ or in another domain fails at boot,
# not in review.

model :Subscription do
  field :plan,          :enum, values: %i[free team scale], default: :free
  field :status,        :enum, values: %i[trialing active past_due cancelled], default: :trialing
  field :seats_limit,   :integer, default: 1
  field :trial_ends_on, :date
  field :price,         :money, required: true

  # The Stripe subscription. A token, never card data — `field :card_number` is
  # refused at boot everywhere, including here (spec: Guardrails).
  field :processor_id,  :string, required: true

  belongs_to :account

  computed(:seats_used, :integer) { account.users.active.count }

  def active? = %i[trialing active].include?(status)

  audited

  # Crossing the boundary outward: an event, not a method call into :Invoicing.
  after_transition to: :past_due do |subscription|
    publish :payment_failed, account_id: subscription.account_id, plan: subscription.plan
  end
end
