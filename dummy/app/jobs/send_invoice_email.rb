# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `job` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# app/jobs/send_invoice_email.rb  <->  job :SendInvoiceEmail
#
# JOBS ARE THE ONLY PLACE THIS APP RUNS ASYNCHRONOUSLY. If it can fail slowly,
# talk to a third party, or take longer than a request should, it is a file in
# this directory and nowhere else.
#
# Enqueued inside the transaction in app/actions/issue_invoice.rb. The queue is
# Postgres-backed and transactional (Phase 4), so a rolled-back invoice cannot
# leave a queued email behind — the two commit together or neither does.
#
# Demonstrates: job, retry with backoff, perform, on_failure, run by
# `magik worker`.

job :SendInvoiceEmail do
  queue :mailers

  # Five attempts over roughly an hour. An email provider having a bad minute is
  # not a reason to lose an invoice; an email provider having a bad week is not
  # a reason to retry forever.
  #
  # Spelled `retries`, not `retry`, because `retry` is a Ruby keyword and cannot
  # be a method name. A design-by-example finding: the spec writes `retry` and
  # the language will not allow it. See dummy/README.md, "What writing this
  # taught us".
  retries times: 5, backoff: :exponential, base: 30.seconds

  perform do |invoice_id:|
    invoice = Invoice.find(invoice_id)

    # Rendering a PDF is why this is a job and not part of the request.
    pdf = render_pdf("invoices/document", invoice: invoice)

    notify :invoice_issued,
           to: invoice.customer,
           attach: { "#{invoice.number}.pdf" => pdf },
           locale: invoice.customer.locale
  end

  on_failure do |error, invoice_id:|
    # A dead job is an operational fact someone has to see. Swallowing it means
    # a customer silently never received their invoice.
    Invoice.find(invoice_id).flag!(:delivery_failed, reason: error.message)
  end
end
