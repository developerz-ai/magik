# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `component` is not a method that exists, and loading this
# file would raise NoMethodError. See dummy/README.md.
#
# app/components/money_badge.rb  <->  component :MoneyBadge
#
# A reusable piece of UI. Compiles to HTML plus htmx attributes — no React, no
# Vue, ever (spec decision 4). No JavaScript is written here or generated for
# it; the colour decision happens on the server, where the data already is.
#
# Demonstrates: component, prop, body, the component kit (Phase 2), and
# rendering :money without ever seeing a Float.

component :MoneyBadge do
  prop :amount,  :money, required: true
  prop :label,   :string, default: nil
  prop :emphasis, :enum, values: %i[normal warn danger], default: :normal

  # A pure function of its props. A component that queries the database is a
  # component you cannot render in a test without a database, and an N+1 waiting
  # for a list to grow. Screens fetch; components display.
  body do
    span class: ["money", "money--#{emphasis}"] do
      text label if label
      # Formatted server-side in the request's locale (Phase 8). The client is
      # never handed cents and asked to divide by 100.
      text amount.format(locale: current_locale)
    end
  end
end
