# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `policy` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# app/policies/invoice.rb  <->  policy :Invoice
#
# AUTHORIZATION IS DECIDED HERE AND NOWHERE ELSE. Every surface that reaches an
# invoice — the screen, the action, the channel, the API resource, the admin
# panel — names one of the verbs below rather than writing a check of its own.
# Grep for `policy:` and you have found every authorization decision in the
# product, in the same way that grepping app/actions/ finds every write.
#
# That is not a style preference. A screen, an API resource and an admin panel
# are all GENERATED from declarations, and an app cannot reach inside generated
# code to add an `if`. If the rule is not declared where the generator can read
# it, the generated surface has no rule at all.
#
# Demonstrates: policy, default :deny, can (Phase 2), and the four ways this
# file's verbs are consumed — see app/screens/invoices.rb, app/actions/,
# app/channels/invoices.rb and the admin_panel blocks in config/app.rb.

policy :Invoice do
  # Required. There is no implicit allow, and a policy block without this line
  # fails the boot with MAGIK_POLICY_NO_DEFAULT rather than defaulting to
  # something a reader has to guess.
  default :deny

  # PREDICATES ARE PURE. No queries, no I/O, no `Invoice.find` — MAGIK_POLICY_IO
  # refuses one at boot. The reason is app/screens/dashboard.rb: a `live` screen
  # re-evaluates a predicate once per subscriber per change, so a query here is
  # one round trip per row per open socket. The actor and the record are the
  # only inputs, and both are already loaded by the time this runs.
  #
  # A nil record denies. "No record loaded" and "record not found" are the same
  # nil, and absent evidence is a denial — so a ROW rule, one that consults the
  # record, never sees one. MAGIK_POLICY_NULL_PASSES is the boot check for a row
  # rule written so that it would pass on an absent record.
  #
  # The rules spelled `|actor, _invoice|` below are the other kind: they are
  # asked about the model, not about a row. `can :create` is the clearest case —
  # there is no invoice yet to consult.

  # Reading. Every member of the tenant may see the invoices; the tenant scope
  # is applied by the framework, so "which invoices" is not a question this file
  # answers (spec decision 8).
  can :read do |actor, _invoice|
    actor.role?(:viewer, :member, :admin, :owner)
  end

  can :create do |actor, _invoice|
    actor.role?(:member, :admin, :owner)
  end

  # A row rule: the actor's role AND the record's state. Issuing is the point at
  # which the money becomes real and `immutable_after :issued` closes the door,
  # so it is deliberately narrower than reading.
  can :issue do |actor, invoice|
    actor.role?(:admin, :owner) && invoice.status == :draft
  end

  can :record_payment do |actor, invoice|
    actor.role?(:admin, :owner) && %i[issued overdue].include?(invoice.status)
  end

  can :void do |actor, invoice|
    actor.role?(:owner) && invoice.status != :paid
  end

  # Staff, not members. A support engineer is not a member of the tenant they
  # are helping, which is why `staff_roles` in config/app.rb is a separate axis
  # from `roles` rather than two more values in the same list.
  can :administer do |actor, _invoice|
    actor.staff? && actor.role?(:support_lead)
  end
end
