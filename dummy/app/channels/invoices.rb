# frozen_string_literal: true

#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `channel` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# app/channels/invoices.rb  <->  channel :invoices
#
# The subscriber half of realtime. The publisher half is `broadcast` in
# app/actions/, and the consumer half is `live` in app/screens/dashboard.rb.
# Three files, three verbs, and a screen that declares none of them pays nothing
# (spec decision 5).
#
# Transport: Postgres LISTEN/NOTIFY by default — no extra infrastructure for a
# single-database deployment — switchable to Redis pub/sub with
# MAGIK_REALTIME_BACKEND, with no change to this file (spec decision 11).
#
# Demonstrates: channel, subscribe_to, on_create/on_update, presence (Phase 3).

channel :invoices do
  # Tenant-scoped by construction. A channel name that is not scoped by tenant
  # is a cross-tenant data leak with a socket attached.
  name { "invoices:#{current_tenant.id}" }

  authorize { |user| user.can?(:read, Invoice) }

  subscribe_to :Invoice

  on_create { |invoice| broadcast :created, id: invoice.id, total: invoice.total }
  on_update(:status) { |invoice| broadcast :status_changed, id: invoice.id, status: invoice.status }

  # Who is looking at this invoice right now — the "Ana is editing this" line.
  # Presence is per-channel and opt-in for the same reason the channel is.
  presence key: ->(user) { { id: user.id, name: user.name } }
end
