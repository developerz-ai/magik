# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `model` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# app/models/account.rb  <->  model :Account
#
# THE TENANT. `tenant_by :subdomain, model: :Account` in config/app.rb points
# here, so this is the one model in the app that is NOT scoped by tenant_id —
# it is what tenant_id points at.
#
# Demonstrates: model, field, has_many, validate, scope, the tenant root.

model :Account do
  field :name,      :string, required: true
  field :subdomain, :string, required: true, unique: true, format: /\A[a-z0-9-]+\z/
  field :plan,      :enum, values: %i[free team scale], default: :free
  field :country,   :string, required: true, length: 2 # ISO 3166-1 alpha-2
  field :currency,  :currency, default: "EUR"          # not :string — see invoice.rb

  has_many :customers
  has_many :invoices
  has_many :users

  validate :subdomain, "is reserved" do |value|
    !%w[www api admin app status].include?(value)
  end

  scope :on_paid_plan, -> { where(plan: %i[team scale]) }

  # The one place tenancy is opted out of, stated explicitly rather than
  # inferred. Everything else in app/models/ carries an implicit
  # `where(tenant_id: current_tenant)` on every query.
  tenant_root true
end
