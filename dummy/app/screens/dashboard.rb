# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `screen` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# app/screens/dashboard.rb  <->  screen :Dashboard
#
# Auto-routed to /dashboard by the file name — there is no routes file in this
# app, on purpose (see dummy/README.md).
#
# THE ROOT OF THE NAVIGATION. It names no `parent:`, which is what makes it the
# first crumb in every breadcrumb trail app/layouts/app.rb renders, and it is
# the screen `app/flows/onboarding.rb` redirects to when a tenant finishes
# setting up.
#
# Demonstrates: screen, policy + layout (Phase 2), state, live (Phase 3), the
# component kit stat/chart/card/dashboard_grid (Phase 2), and what "realtime is
# opt-in" costs: two `live` lines here, and nothing at all on every other screen
# (spec decision 5).

screen :Dashboard, policy: %i[Invoice read], layout: :App do
  # ONE VERB, NAMED — not a check written inline. The rule itself is in
  # app/policies/invoice.rb and is evaluated by the same evaluator that answers
  # the action, the channel, the API call and the admin render. A screen with
  # neither a verb nor `policy: :public` fails the boot with
  # MAGIK_POLICY_UNDECLARED, which is what makes authorization non-optional
  # rather than well-intentioned.
  #
  # `layout: :App` names the shell in app/layouts/app.rb. It is the default, and
  # it is still written down: MAGIK_LAYOUT_MISSING refuses a screen that names
  # neither a layout nor `layout: :None`.

  # The breadcrumb label and the browser title, from one key.
  title { t("dashboard.title") }

  # State is computed per request, server-side. It is NOT instance state that
  # survives the response — a screen that holds state across requests fails at
  # boot (spec: Guardrails), which is what makes "add more servers" work.
  state :outstanding do
    Customer.owing.sum(:outstanding)
  end

  state :overdue_count do
    Invoice.overdue.count
  end

  state :monthly_revenue do
    Invoice.where(status: :paid).group_by_month(:issued_on, last: 12).sum(:total)
  end

  # OPT-IN REALTIME. These two lines are the entire cost of a live dashboard:
  # the channel is defined in app/channels/invoices.rb, the broadcast is fired
  # by app/actions/issue_invoice.rb, and a screen without these lines pays
  # nothing — no socket, no subscription, no poll.
  #
  # They are also the reason app/policies/invoice.rb may not query: the channel
  # re-evaluates `can :read` once per subscriber per change, and a query in that
  # predicate would be one round trip per open socket per invoice.
  live :outstanding,    on: "invoices:tenant"
  live :overdue_count,  on: "invoices:tenant"

  body do
    dashboard_grid do
      stat title: t("dashboard.outstanding"), value: MoneyBadge(amount: outstanding, emphasis: :warn)
      stat title: t("dashboard.overdue"),     value: overdue_count, emphasis: overdue_count.zero? ? :normal : :danger
      stat title: t("dashboard.plan"),        value: current_tenant.plan
    end

    card title: t("dashboard.revenue_12m") do
      chart :bar, data: monthly_revenue, y_format: :money
    end

    # Every timestamp rendered here carries an explicit zone. Rendering one
    # without a conversion fails at boot, rather than quietly showing UTC to
    # someone in Madrid (spec: Guardrails).
    list Invoice.overdue.limit(5) do |invoice|
      link to: screen(:Invoices, focus: invoice.id) do
        text invoice.number
        text invoice.due_on.in_zone(current_user.timezone).to_date
        MoneyBadge(amount: invoice.balance, emphasis: :danger)
      end
    end
  end
end
