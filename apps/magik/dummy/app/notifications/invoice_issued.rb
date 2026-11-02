# frozen_string_literal: true
#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `notification` is not a method that exists, and loading this
# file would raise NoMethodError. See dummy/README.md.
#
# app/notifications/invoice_issued.rb  <->  notification :invoice_issued
#
# ONE NOTIFICATION, EVERY CHANNEL IT CAN ARRIVE ON. The point of the directory
# is that "how does a customer hear about an issued invoice" has exactly one
# answer, in one file — not an email template here, a push payload there, and an
# in-app record written inline in an action.
#
# Called by app/jobs/send_invoice_email.rb, which is where the slow part
# (rendering a PDF, waiting on a mail provider) belongs.
#
# Demonstrates: notification, channel :email/:in_app/:push, per-locale content
# (Phase 8).

notification :invoice_issued do
  # Email: the one channel that carries the document itself.
  channel :email do
    template "invoices/issued"
    subject ->(invoice) { t("notifications.invoice_issued.subject", number: invoice.number) }
    # Rendered in the RECIPIENT's locale, not the sender's. An invoice from a
    # German tenant to a Spanish customer is a Spanish email.
    locale ->(invoice) { invoice.customer.locale }
  end

  # In-app: a row, not a message. It has to survive a reload, because the server
  # is the single source of truth and there is no client-side inbox
  # (spec decision 6 — no offline).
  channel :in_app do
    title ->(invoice) { t("notifications.invoice_issued.title", number: invoice.number) }
    link_to ->(invoice) { screen(:Invoices, focus: invoice.id) }
  end

  # Push: only for the case that is actually urgent. A push for every issued
  # invoice is a push notification people turn off.
  channel :push, only: %i[overdue] do
    body ->(invoice) { t("notifications.invoice_overdue.push", number: invoice.number) }
  end
end
