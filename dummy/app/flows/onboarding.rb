# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `flow` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# app/flows/onboarding.rb  <->  flow :Onboarding
#
# A flow is a multi-step wizard: onboarding, KYC, checkout (Phase 5). Its own
# directory, not app/screens/, because a flow is not a page: it is an ordering
# over pages, plus the guards and the resumability between them. A screen can be
# opened directly; a step cannot.
#
# Demonstrates: flow, step, guard, resumable server-side progress. Note that no
# step holds client state: progress is a row, not a session object, which is
# what lets a user finish on their phone what they started on a laptop (spec
# decision 9).

flow :Onboarding do
  # Where a half-finished flow is stored. There is no in-process wizard state:
  # stateless app servers are a boot-enforced guardrail, not a style preference.
  progress_in :Account, field: :onboarding_step

  step :company do
    form action: :update_account do
      field :name,     :string,   label: t("onboarding.company_name")
      field :country,  :select,   options: countries
      field :currency, :currency, label: t("onboarding.currency")
      submit t("onboarding.continue")
    end
  end

  step :tax, guard: ->(account) { account.country.present? } do
    form action: :update_account do
      field :vat_id, :string, label: t("onboarding.vat_id"), optional: true
      submit t("onboarding.continue")
    end
  end

  step :first_customer do
    form action: :create_customer do
      field :name,  :string, label: t("onboarding.customer_name")
      field :email, :email
      submit t("onboarding.finish")
    end
  end

  on_complete do |account|
    # Fire and forget: the flow finishes when the data is saved, not when an
    # email provider answers. See app/jobs/ for why that is a job.
    notify :welcome, to: account.owner
    redirect_to screen(:Dashboard)
  end
end
