# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `model` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# app/models/invoice.rb  <->  model :Invoice
#
# The centre of the product, and the file that exercises the most of the spec at
# once. Read the annotations at the bottom before the fields: `audited` and
# `immutable_after` are the reason an invoicing app can be trusted, and they are
# two lines.
#
# Demonstrates: :money (Phase 1), has_many, computed, scope, state machine,
# audited + immutable_after (Phase 5), timezone-safe :timestamp (Phase 8).
#
# NOTE ON WHAT IS NOT HERE. This file declares data and invariants. It does not
# issue an invoice (app/actions/issue_invoice.rb), does not email one
# (app/jobs/send_invoice_email.rb), does not post to the ledger
# (app/ledgers/receivables.rb) and does not render one (app/screens/invoices.rb).
# A model that does any of those is a model you cannot reason about.

model :Invoice do
  field :number,   :string, required: true, unique_per_tenant: true
  field :status,   :enum, values: %i[draft issued paid void overdue], default: :draft
  field :currency, :currency, required: true

  # Dates a human chose, not instants. `:date` has no timezone because "due on
  # the 30th" is not a moment.
  field :issued_on, :date
  field :due_on,    :date

  # An instant. `:timestamp` carries a zone and cannot be rendered without an
  # explicit conversion — a boot guardrail, not a lint (spec: Guardrails).
  field :issued_at, :timestamp

  belongs_to :account
  belongs_to :customer
  has_many   :lines, model: :InvoiceLine
  has_many   :payments

  # Money is integer cents. There is no Float anywhere in this file and the type
  # system will not permit one (spec decision 10).
  computed(:subtotal, :money) { lines.sum(:amount) }
  computed(:tax,      :money) { lines.sum(:tax_amount) }
  computed(:total,    :money) { subtotal + tax }
  computed(:paid,     :money) { payments.settled.sum(:amount) }
  computed(:balance,  :money) { total - paid }

  scope :unpaid,  -> { where(status: %i[issued overdue]) }
  scope :overdue, -> { unpaid.where { due_on < Date.today } }
  scope :for_month, ->(month) { where(issued_on: month.beginning..month.end) }

  # Legal transitions, declared once. Anything not listed is refused, so no
  # action can walk an invoice from :paid back to :draft.
  transitions do
    from :draft,   to: %i[issued]
    from :issued,  to: %i[paid void overdue]
    from :overdue, to: %i[paid void]
  end

  # --- The two lines that make this auditable ------------------------------

  # Every field change is recorded with who, when and the before/after value.
  # A tax authority asking "what did this invoice say in March" gets an answer.
  audited

  # Once issued, the money is frozen. An issued invoice whose total can still
  # change is not an invoice. Corrections happen by issuing a credit note, which
  # is a new row — never by editing history.
  immutable_after :issued, except: %i[status]

  # Realtime, opt-in per model (spec decision 5). Declaring the channel here —
  # next to the data whose changes it publishes — is what lets
  # app/screens/dashboard.rb say `live :outstanding` and cost nothing on every
  # other screen. The subscriber side lives in app/channels/invoices.rb.
  publishes_to "invoices:tenant"
end
