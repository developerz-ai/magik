# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `policy` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# app/policies/customer.rb  <->  policy :Customer
#
# ONE POLICY PER MODEL A SURFACE REACHES. There are two policy files in this app
# and not five, because there are two models a surface names: app/screens/ and
# app/api/v1.rb reach :Invoice and :Customer, and everything else is reached
# through one of them. A model nothing exposes needs no policy, and writing one
# anyway is a rule nobody evaluates.
#
# Read app/policies/invoice.rb first — it carries the rationale for the shape,
# and this file is deliberately the plainer of the two.
#
# Demonstrates: policy, default :deny, can (Phase 2), and a verb set that is
# narrower than the model's field list because reading and administering a
# customer are the only two things any surface here actually asks for.

policy :Customer do
  default :deny

  can :read do |actor, _customer|
    actor.role?(:viewer, :member, :admin, :owner)
  end

  can :create do |actor, _customer|
    actor.role?(:member, :admin, :owner)
  end

  # A row rule. An archived customer is read-only: the invoices that reference
  # it still have to render, so it cannot be deleted, and editing something a
  # tenant has deliberately retired is how a name changes under an issued
  # invoice.
  can :update do |actor, customer|
    actor.role?(:member, :admin, :owner) && !customer.archived
  end

  can :administer do |actor, _customer|
    actor.staff? && actor.role?(:support_lead)
  end
end
