# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `App.define` is not a method that exists, and loading this
# file would raise NoMethodError. See dummy/README.md.
#
# THE COMPOSITION ROOT. One file, read top to bottom, that answers "what is this
# application made of" without opening anything else. Everything here is a
# declaration about the app as a whole; anything about one model, one screen or
# one job lives in that thing's own file.
#
# Demonstrates: App.define (Phase 1), tenant_by (Phase 7), auth (Phase 7),
# billing (Phase 7), locales + pwa (Phase 8), admin_panel (Phase 7), and the
# domain module system (spec decision 12).
#
# What is deliberately NOT here, and where it went:
#
#   config/backends.rb                   the swap points (spec decision 11)
#   config/theme.rb                      design tokens, light/dark
#   app/notifications/invoice_issued.rb  one file per notification
#
# Each of those is a thing a different person edits on a different day. A
# composition root that also holds the colour palette is a file everybody has to
# touch, and therefore a file nobody can read.

App.define :Ledgerline do
  # --- Runtime -------------------------------------------------------------

  # Multi-tenant by default (spec decision 8). Every model is auto-scoped by
  # tenant_id and every query without one fails `magik check --scale`. The
  # subdomain names the tenant: acme.ledgerline.test -> Account[subdomain: "acme"].
  tenant_by :subdomain, model: :Account

  # UUIDv7 primary keys everywhere, from day one (spec decision 8). Sortable by
  # creation time, shard-safe, and never a sequence to reconcile after a split.
  primary_key :uuid_v7

  # --- Swap points (spec decision 11) --------------------------------------
  #
  # In their own file, because "what can I change without a rewrite" deserves to
  # be answerable with a `cat`. See config/backends.rb.

  load_config :backends

  # --- Auth (Phase 7) ------------------------------------------------------

  auth do
    strategy :email_password
    oauth_providers :google, :github
    two_factor :totp, required_for: [:owner]
    session_timeout 12.hours
  end

  # --- Billing (Phase 7) ---------------------------------------------------
  #
  # This is the app charging ITS OWN customers for using Ledgerline. Not to be
  # confused with app/ledgers/receivables.rb, which is Ledgerline's users
  # invoicing THEIR customers. Two different money flows, two different files,
  # and conflating them is the classic invoicing-SaaS bug.

  billing provider: :stripe do
    plan :free,  price_cents: 0,     invoices_per_month: 5
    plan :team,  price_cents: 4900,  invoices_per_month: 500,  seats: 5
    plan :scale, price_cents: 24_900, invoices_per_month: :unlimited, metered: :api_calls
    trial_days 14
  end

  # --- Presentation (Phase 2) ----------------------------------------------
  #
  # The one part of the app a designer edits and a backend developer does not.
  # See config/theme.rb.

  load_config :theme

  # --- i18n, PWA (Phase 8) -------------------------------------------------
  #
  # One file per locale under locales/. Every `t("...")` key in app/ has an entry
  # in locales/en.yml, and `magik check` is specified to enforce that.

  locales :en, :es, :de, default: :en

  pwa do
    name "Ledgerline"
    short_name "Ledger"
    icon "icons/ledgerline-512.png"
    display :standalone
    # NO offline support (spec decision 6). Installable, not offline-capable:
    # the server is the single source of truth, and an invoice total computed
    # against stale local state is a wrong number with a confident UI.
    offline false
  end

  # Notifications are one file each, under app/notifications/ — see
  # app/notifications/invoice_issued.rb. Declared there, not here, because "how
  # does a customer hear about this" is a per-event answer.

  # --- Admin (Phase 7) -----------------------------------------------------
  #
  # Auto-generated CRUD over the models named here. A composition-root concern:
  # it decides which models are administrable at all, which is an app-level
  # policy question, not a property of the model.

  admin_panel :Invoice do
    list_display :number, :customer, :total, :status, :due_on
    filterable :status, :due_on
    searchable :number, "customer.name"
    read_only :total, :issued_at # audited + immutable_after on the model
  end

  admin_panel :Customer do
    list_display :name, :email, :outstanding_cents
    searchable :name, :email
  end

  # --- Domains (spec decision 12) ------------------------------------------
  #
  # Boot-time enforced module boundaries. See dummy/domains/ and the section on
  # when to reach for this in dummy/README.md — a small app does not need it.

  domains :billing, :invoicing
end
