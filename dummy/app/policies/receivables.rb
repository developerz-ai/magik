# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `policy` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# app/policies/receivables.rb  <->  policy :Receivables
#
# A POLICY WHOSE SUBJECT IS NOT A MODEL, and the reason the spec allows one.
#
# `ledger :Receivables` (app/ledgers/receivables.rb) owns data and is not a
# model. `api resource :ledger_entries` reaches that data, so it must name a
# verb — and for a while it borrowed `%i[Invoice read]`, because a policy
# subject had to be a model. That was a workaround wearing a comment: an
# invoice and the ledger that records its money are different things, and a
# reader could not tell from the API declaration which one was being guarded.
#
# The alternative was to invent a `LedgerEntry` model purely so there would be
# something to hang the guard on. That is a data model written to satisfy an
# authorization rule, which is backwards, and it is the pressure to write fake
# framework code this repository is organised against. So the subject rule is
# the looser one: any declared construct that owns data. The registry still has
# to know the name (MAGIK_POLICY_UNKNOWN_SUBJECT).
#
# Demonstrates: policy over a non-model subject, default :deny, pure predicates.

policy :Receivables do
  # No implicit allow, here or anywhere (MAGIK_POLICY_NO_DEFAULT).
  default :deny

  # Reading the books is broader than reading one invoice: an ledger entry
  # aggregates across customers, so a viewer who may see their own invoice may
  # not see the account it posts to.
  can :read do |actor, _ledger|
    actor.role?(:admin, :owner)
  end

  # Staff support can read the books of a tenant they are helping without being
  # a member of it — that is what the separate staff axis is for.
  can :administer do |actor, _ledger|
    actor.staff? && actor.role?(:support_lead)
  end
end
