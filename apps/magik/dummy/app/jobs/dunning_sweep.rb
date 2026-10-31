# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `job` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# app/jobs/dunning_sweep.rb  <->  job :DunningSweep
#
# The scheduled half of the jobs story: a cron-style recurring job rather than
# one enqueued by an action. Dunning is chasing invoices that are past due.
#
# Demonstrates: job, policy: :system (Phase 2), schedule :cron, a job that
# enqueues other jobs, and per-tenant iteration in a multi-tenant app.

job :DunningSweep, policy: :system do
  # Explicit, never implicit — see app/jobs/send_invoice_email.rb for why the
  # opt-out is written down. This sweep crosses every tenant in the app, which
  # is exactly the kind of reach that should be impossible to acquire by
  # omitting a line.
  queue :maintenance

  # Every morning at 07:00 UTC. Declared with the job, not in a crontab on one
  # machine that nobody remembers is the reason the emails stopped.
  #
  # The other spelling is `schedule every: "10m"`, which takes a :duration —
  # a unit-suffixed string coerced at boot (spec D1), never `10.minutes`.
  schedule cron: "0 7 * * *"

  # A sweep that overlaps itself sends two reminders for the same invoice.
  #
  # One spelling, not two (spec D4): `idempotent_by` is the dedupe key on a job
  # exactly as it is on an action -- a repeat with this key produces one effect.
  # `unique:` is a database constraint on a field and stays a different thing.
  idempotent_by :tenant_id

  perform do
    # Multi-tenant explicitly: a scheduled job has no current tenant, so it must
    # choose one for every unit of work. `magik check --scale` flags a query in
    # here that forgot to.
    Account.on_paid_plan.each do |account|
      as_tenant(account) do
        Invoice.overdue.each do |invoice|
          invoice.update!(status: :overdue) unless invoice.status == :overdue
          enqueue SendInvoiceEmail, invoice_id: invoice.id
        end
      end
    end
  end
end
