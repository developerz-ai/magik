# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `screen` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# app/screens/invoices.rb  <->  screen :Invoices
#
# Auto-routed to /invoices.
#
# THE SEPARATION THIS FILE IS HERE TO SHOW: it reads and it renders. It does not
# mutate. Every button below names an action in app/actions/, which is the only
# place in the app where a write happens. Grep for `action` and you have found
# every mutation in the product.
#
# Demonstrates: screen, state with params, data_table + form + modal + button
# from the component kit (Phase 2), and htmx-driven interactivity with no
# hand-written JavaScript (spec decision 4).

screen :Invoices do
  param :status, :enum, values: %i[all draft issued paid overdue], default: :all
  param :focus,  :uuid, default: nil

  state :invoices do
    scope = Invoice.eager(:customer)
    scope = scope.where(status: status) unless status == :all
    scope.order(issued_on: :desc).paginate(per_page: 50)
  end

  state :customers do
    Customer.active.order(:name)
  end

  body do
    tabs selected: status do
      %i[all draft issued paid overdue].each { |s| tab s, to: screen(:Invoices, status: s) }
    end

    button t("invoices.new"), opens: modal(:new_invoice), style: :primary

    data_table invoices, highlight: focus do
      column t("invoices.number"),   :number
      column t("invoices.customer"), ->(i) { i.customer.name }
      column t("invoices.total"),    ->(i) { MoneyBadge(amount: i.total) }
      column t("invoices.due"),      ->(i) { i.due_on }
      column t("invoices.status"),   :status, as: :badge

      # Each row action posts to an action, which is the only thing that writes.
      row_action t("invoices.issue"), action: :issue_invoice, when: ->(i) { i.status == :draft },
                 confirm: t("invoices.issue_confirm")
      row_action t("invoices.record_payment"), opens: modal(:record_payment), when: ->(i) { i.unpaid? }
    end

    modal :new_invoice, title: t("invoices.new") do
      form action: :create_invoice do
        field :customer_id, :select, options: customers, label: t("invoices.customer")
        field :due_on,      :date,   label: t("invoices.due")
        field :currency,    :currency, default: current_tenant.currency
        submit t("invoices.create")
      end
    end

    modal :record_payment, title: t("invoices.record_payment") do
      form action: :record_payment do
        field :invoice_id, :hidden
        field :amount,     :money, label: t("invoices.amount")
        field :method,     :select, options: %i[card sepa_debit bank_transfer]
        submit t("invoices.record")
      end
    end
  end
end
