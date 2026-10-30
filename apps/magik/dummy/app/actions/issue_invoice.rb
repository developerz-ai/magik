# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `action` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# app/actions/issue_invoice.rb  <->  action :issue_invoice
#
# ACTIONS ARE THE ONLY PLACE THIS APP WRITES. Screens read, components display,
# jobs run later, ledgers record money — and every mutation in the product is a
# file in this directory. That is the whole reason the directory exists.
#
# Auto-wired to an htmx POST by name; there is no route to declare and no
# controller to write (Phase 2).
#
# Demonstrates: action, policy (Phase 2), params, idempotent_by (Phase 5),
# transaction boundary, enqueue, broadcast (Phase 3).

action :issue_invoice, policy: %i[Invoice issue] do
  # ONE VERB, NAMED. The rule lives in app/policies/invoice.rb and says that an
  # admin or owner may issue an invoice that is still a draft. It is evaluated
  # BEFORE this block runs, by the same evaluator that answers the screen, the
  # channel, the API and the admin panel.
  #
  # An earlier draft of this app wrote the check by hand instead, in three
  # incompatible spellings across three files. That is the failure `policy`
  # exists to prevent, and it is why the verb is an ARGUMENT rather than a block
  # inside the construct: an argument is checkable at boot, so a mutation cannot
  # ship without one. See dummy/README.md, "What writing this taught us".
  params do
    field :invoice_id, :uuid, required: true
  end

  # Retried mutations dedupe on this key. A double-clicked button, an htmx retry
  # and a webhook replay are the same request, and issuing an invoice twice
  # means charging someone twice.
  idempotent_by ->(params) { "issue:#{params[:invoice_id]}" }

  perform do |params|
    invoice = Invoice.find(params[:invoice_id])

    # Everything inside this block commits or rolls back together — including
    # the enqueued job, because the queue is Postgres-backed and transactional
    # (spec Phase 4). No "the email went out but the invoice did not save".
    transaction do
      invoice.update!(
        status: :issued,
        issued_on: Date.today,
        issued_at: Time.now,
        number: NumberSequence.next_for(current_tenant)
      )

      # Money is recorded in the ledger, never by mutating a balance column.
      # See app/ledgers/receivables.rb for why that is not optional.
      Receivables.record(:invoice_issued, invoice: invoice)

      enqueue SendInvoiceEmail, invoice_id: invoice.id
    end

    # After commit, not inside it: a subscriber must never see an event for a
    # row that then rolls back. This is what makes screen(:Dashboard)'s
    # `live :outstanding` update without a poll.
    broadcast "invoices:tenant", :issued, id: invoice.id, total: invoice.total

    redirect_to screen(:Invoices, status: :issued, focus: invoice.id)
  end
end
