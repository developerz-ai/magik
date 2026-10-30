# frozen_string_literal: true
#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: nothing here is a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# config/backends.rb  —  THE SWAP POINTS, and nothing else.
#
# Spec decision 11: every opinionated default must be switchable by config,
# without touching application code. This file is that switch, and it is its own
# file so the answer to "what can I change without a rewrite" is a `cat`, not a
# search through the composition root.
#
# The lesson it encodes is Meteor's: magic with no escape hatch is an eventual
# rewrite. Every line below names a default AND the alternatives the framework
# commits to also supporting, so the escape hatch is documented before it is
# needed rather than after.
#
# Values come from the environment (see ../../.env.example) so a deployment can
# switch one without rebuilding the app image.

backends do
  # Postgres, and Sequel rather than an ORM with lazy loading (spec decision 3).
  # It is also the realtime transport and the job queue below — a single-database
  # deployment is the whole default stack, not a cut-down one.
  database url: env("DATABASE_URL"), adapter: :postgres

  # memory | redis
  # In-process by default: correct for one server, and a cache that silently
  # goes wrong across two is worse than no cache.
  cache backend: env("MAGIK_CACHE_BACKEND", :memory)

  # postgres | kafka
  # Postgres-backed and TRANSACTIONAL (Que-style): a job enqueues inside the
  # same transaction as the data it acts on, so a rolled-back write cannot leave
  # a queued job behind. That property is why this is the default.
  jobs backend: env("MAGIK_JOBS_BACKEND", :postgres), workers: :auto

  # postgres | redis
  # LISTEN/NOTIFY by default — no extra infrastructure to run a realtime screen.
  realtime backend: env("MAGIK_REALTIME_BACKEND", :postgres)

  # postgres | pgvector | elasticsearch
  # Full-text search in the database you already have; pgvector is the same
  # database with an extension, for embedding search.
  search backend: env("MAGIK_SEARCH_BACKEND", :postgres)
end
