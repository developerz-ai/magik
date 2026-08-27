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
# Demonstrates: api, resource, auto-paginate/filter/sort, :bearer and :api_key
# auth, per-plan rate limiting (Phase 6).

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

  resource :invoices do
    index  filterable: %i[status customer_id due_on], sortable: %i[issued_on total], per_page: 50
    show

    # Delegation, not reimplementation: exactly the action app/screens/ posts to.
    create action: :create_invoice
    member :issue, action: :issue_invoice, verb: :post
    member :pay,   action: :record_payment, verb: :post
  end

  resource :customers do
    index filterable: %i[archived], searchable: %i[name email]
    show
    create action: :create_customer
    update action: :update_customer
  end

  # Read-only, and deliberately so. The ledger is append-only; there is no
  # endpoint that can edit history because there is no code that can.
  resource :ledger_entries do
    index filterable: %i[account entry_type posted_on], sortable: %i[posted_on]
    show
  end
end
