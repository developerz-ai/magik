# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `layout` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# app/layouts/app.rb  <->  layout :App
#
# THE APPLICATION SHELL — the thing a screen is rendered *into*. A screen
# declares `state` and `body` and is auto-routed; this file is what wraps it,
# and it is the one place navigation is declared.
#
# Before this file existed, Ledgerline had two screens and no way to get from
# one to the other: `app/screens/dashboard.rb` and `app/screens/invoices.rb`
# both opened their `body` directly with content, and neither carried a sidebar,
# a header or a link to the other. A reference app for a framework claiming to
# cover most of SaaS cannot be a set of pages with no navigation between them.
#
# `magik new` is specified to generate a working `:App` layout, so a generated
# app has a sidebar on its first run. This file is what that generated one looks
# like once an app has edited it.
#
# Demonstrates: layout, sidebar, topbar, nav_item, breadcrumbs, account_menu,
# content, responsive (Phase 2).

layout :App do
  # --- Navigation ----------------------------------------------------------
  #
  # `nav_item` names a SCREEN CONSTANT, never a URL string. A link to a screen
  # that does not exist fails the boot with MAGIK_LAYOUT_UNKNOWN_SCREEN, which
  # is the whole reason navigation is a declaration: a hand-written href to a
  # renamed page is dead the moment someone renames the page, and nothing tells
  # you until a customer finds the 404.
  #
  # That is also why this sidebar is short. There are exactly two screens under
  # app/screens/ that take a shell, and a nav_item for a Customers page nobody
  # has written yet would not boot.
  sidebar do
    brand { text app_name }

    section t("nav.work") do
      nav_item :Dashboard, icon: :home, policy: %i[Invoice read]

      # The badge is the one place the shell reads data. It names a scope the
      # model already owns (`scope :overdue` in app/models/invoice.rb) rather
      # than building a query here — a layout that queries is a screen wearing
      # a different hat.
      nav_item :Invoices,
               icon: :receipt,
               badge: -> { Invoice.overdue.count },
               policy: %i[Invoice read]
    end
  end

  # --- Header --------------------------------------------------------------

  topbar do
    # Derived from each screen's `parent:` — Dashboard › Invoices — and never
    # typed per page. A breadcrumb trail maintained by hand is a breadcrumb
    # trail that lies after the second refactor.
    breadcrumbs

    # `search action: :global_search` is in the spec's drafted layout and is
    # deliberately absent here: there is no app/actions/global_search.rb, and a
    # layout naming an action that does not exist is the same class of rot as a
    # nav_item naming a screen that does not exist. It goes in when the action
    # does.

    # The items are the screens and actions `auth` generates (spec Phase 7), so
    # they resolve without a file under app/screens/ — signing out is not a page
    # this app writes.
    account_menu items: %i[profile theme sign_out]
  end

  # Where the screen's `body` lands. One slot: a layout with two content areas
  # is a layout that has started deciding what the page is about.
  content { slot :screen }

  # --- Narrow screens ------------------------------------------------------
  #
  # A media query and one htmx target. No breakpoint JavaScript, no client
  # router, no build step (spec decision 4) — and no app-authored declaration
  # needed to make the screens themselves work on a phone, because every kit
  # component is responsive by construction.
  responsive do
    sidebar collapses_below: :md, into: :drawer
  end
end
