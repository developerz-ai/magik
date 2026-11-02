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
# Demonstrates: App.define (Phase 1), tenant_by (Phase 7), roles + staff_roles
# (Phase 2, beside auth), auth (Phase 7), billing (Phase 7), locales + pwa
# (Phase 8), admin_panel (Phase 7), and the domain module system (spec
# decision 12).
#
# What is deliberately NOT here, and where it went:
#
#   config/backends.rb                   the swap points (spec decision 11)
#   config/theme.rb                      design tokens, light/dark
#   app/notifications/invoice_issued.rb  one file per notification
#   app/policies/invoice.rb              the authorization RULES. The role set
#                                        they read is here, because it is a
#                                        property of the app; what each role may
#                                        do is a property of the model
#   app/layouts/app.rb                   the shell and the navigation
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

  # --- Roles (Phase 2) -----------------------------------------------------
  #
  # THE ROLE SET, DECLARED ONCE. Every `actor.role?(...)` in app/policies/ reads
  # from this line and nothing else, so a typo in a policy predicate is a boot
  # failure rather than a rule that silently never matches.
  #
  # It sits here rather than in a policy file because the role set is a property
  # of the application, not of any one model — and it is declared with `roles`
  # rather than inferred from the policies for the same reason `tenant_by` is
  # declared: a set you can only discover by reading every rule is not a set.

  roles :owner, :admin, :member, :viewer, default: :member

  # A SEPARATE AXIS, not four more values above. A support engineer helping a
  # tenant is not a member of that tenant: they have no seat, no share of the
  # plan's limits, and their access is auditable in a way a member's is not.
  # `actor.staff?` in app/policies/invoice.rb's `can :administer` is asking
  # about this list, and the admin panels below are the only surfaces that use
  # it.
  staff_roles :support, :support_lead

  # --- Auth (Phase 7) ------------------------------------------------------
  #
  # `required_for: [:owner]` names a role declared above. Before `roles`
  # existed, this line pointed at a role nothing in the app defined — the kind
  # of dangling reference a declaration set is here to make impossible.

  auth do
    strategy :email_password
    oauth_providers :google, :github
    two_factor :totp, required_for: [:owner]
    # A :duration — a unit-suffixed string coerced at boot (spec D1), never
    # `12.hours`. There is no ActiveSupport in a Magik app.
    session_ttl "12h"
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
    # A :duration, not `trial_days 14`: putting the unit in the option name is
    # how `trial_days` and `trial_hours` become two spellings of one concept
    # (spec D1).
    trial "14d"
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

  # `policy:` is REQUIRED here — there is no admin panel without one. An admin
  # is by construction the surface with the broadest data access in the
  # application, and one with no policy is a security hole with a nice table on
  # top. Both verbs below are declared in app/policies/, and both ask
  # `actor.staff?` rather than a tenant role: administering a tenant's invoices
  # is a support job, not a member's.

  admin_panel :Invoice, policy: %i[Invoice administer] do
    # `fields`, `filterable`, `sortable`, `searchable` and `writable` are the
    # SAME five words app/api/v1.rb and `data_table` use (spec D3), because an
    # admin panel is a projection of the same model rather than a second
    # language. `writable` and not `read_only`: a whitelist beats a blacklist.
    list do
      fields     :number, :customer, :total, :status, :due_on
      filterable :status, :select, values: %i[draft issued paid void overdue]
      filterable :due_on, :date_range
      searchable :number, "customer.name"
    end

    form do
      writable :customer_id, :due_on
      # Shown, never written — `audited` and `immutable_after :issued` on
      # app/models/invoice.rb mean the total is not the admin's to change, and
      # a correction is a credit note rather than an edit.
      fields   :total, :issued_at
    end
  end

  admin_panel :Customer, policy: %i[Customer administer] do
    list do
      fields     :name, :email, :outstanding
      searchable :name, :email
    end
  end

  # --- Domains (spec decision 12) ------------------------------------------
  #
  # Boot-time enforced module boundaries. See dummy/domains/ and the section on
  # when to reach for this in dummy/README.md — a small app does not need it.

  domains :billing, :invoicing
end
