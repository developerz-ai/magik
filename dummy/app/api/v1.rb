# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `api` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# app/api/v1.rb  <->  api :V1
#
# The machine-facing surface, mounted at /api/v1. It is a thin declaration on
# purpose: `create` and `pay` below delegate to the same actions the UI posts
# to, so the API and the browser cannot drift into two sets of rules. An API
# that reimplements a mutation is an API that will validate it differently.
#
# AUTHENTICATION IS NOT AUTHORIZATION, and this file is where the difference is
# easiest to lose. `auth :bearer, :api_key` decides WHO is calling; the
# `policy:` on each resource below decides WHAT they may do, using the same
# verbs app/screens/, app/channels/ and the admin panels name. A resource with
# neither a verb nor `policy: :public` fails the boot
# (MAGIK_POLICY_UNDECLARED), which is what stops an API from quietly becoming
# the widest door into the data.
#
# Demonstrates: api, resource, policy per resource (Phase 2), auto-paginate/
# filter/sort, :bearer and :api_key auth, per-plan rate limiting (Phase 6).

api :V1 do
  auth :bearer, :api_key

  # Rate limits by plan, matching config/app.rb's billing plans. Declared with
  # the API rather than in a proxy config, so the limit and the plan that
  # defines it live in the same repository.
  rate_limit free: "60/hour", team: "1000/hour", scale: "20000/hour"

  # One representation, used by every endpoint below. A per-endpoint serializer
  # is how two clients end up seeing two different shapes of the same invoice.
  representation :Invoice do
    expose :id, :number, :status, :issued_on, :due_on
    expose :total, :balance, as: :money   # { "amount_cents": 12000, "currency": "EUR" }
    expose :customer, only: %i[id name email]
    # Never exposed: internal tenant_id, the audit trail, processor tokens.
  end

  # The resource's verb guards reading it. The write endpoints do NOT inherit
  # it: each delegates to an action that carries its own verb — `issue_invoice`
  # names `%i[Invoice issue]`, `record_payment` names `%i[Invoice record_payment]`
  # — so the API cannot be a route around a rule the UI obeys.
  resource :invoices, policy: %i[Invoice read] do
    index  filterable: %i[status customer_id due_on], sortable: %i[issued_on total], per_page: 50
    show

    # Delegation, not reimplementation: exactly the action app/screens/ posts to.
    create action: :create_invoice
    member :issue, action: :issue_invoice, verb: :post
    member :pay,   action: :record_payment, verb: :post
  end

  resource :customers, policy: %i[Customer read] do
    index filterable: %i[archived], searchable: %i[name email]
    show
    create action: :create_customer
    update action: :update_customer
  end

  # Read-only, and deliberately so. The ledger is append-only; there is no
  # endpoint that can edit history because there is no code that can.
  #
  # The verb is `%i[Invoice read]` because these rows describe invoices and
  # payments, and an actor who may read the invoice may read the postings that
  # explain it. It is also the one place in this app where naming a verb was
  # awkward: `ledger :Receivables` is not a model, so there is no
  # `policy :LedgerEntry` to point at without inventing a model to hang it on.
  # See dummy/README.md, "What writing this taught us".
  resource :ledger_entries, policy: %i[Invoice read] do
    index filterable: %i[account entry_type posted_on], sortable: %i[posted_on]
    show
  end
end
