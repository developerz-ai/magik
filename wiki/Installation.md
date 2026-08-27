# Installation

**Status:** `Partially real`. `gem install magik` works and installs the **name-reservation** gem.
Everything it would install *for building an app* is `Planned — not implemented`.
`As of 2026-08-26`.

## What happens today if you install it

```bash
gem install magik
magik version
magik help
```

That is the whole surface. You get:

- `Magik::VERSION` — a version string.
- `Magik::Error` — the `MAGIK_*` code / cause / `fix:` convention.
- `magik version` and `magik help` — two working commands.
- One documented stub module per planned subsystem. Calling into any of them raises
  `NotImplementedError` with a message naming the spec section it will implement.

You do **not** get: `magik new`, a model DSL, a renderer, a router, a server, a worker, or a database
connection. `magik new myapp` is not a typo you can work around — it is a command that has not been
written. See [CLI reference](CLI-Reference.md) for exactly which two commands run.

Verify rather than trust:

```bash
gem list magik --remote --all                          # what RubyGems serves
ruby -e 'require "magik"; puts Magik::VERSION'         # what you installed
magik help                                             # the commands that exist
```

## Runtime targets

| Runtime | Role | Required version |
|---|---|---|
| **TruffleRuby** | the **production target**. Concurrency is Ractors and Fibers, not a thread per request | the version CI pins — read `.github/workflows/` |
| **CRuby** | supported for tooling and local development: editors, RuboCop, YARD, running the framework's own unit tests | `>= 3.2` |

`required_ruby_version` in the gemspec is `>= 3.2`, which both satisfy. That is deliberately the
looser of the two constraints: the gem installs anywhere modern, and the **runtime** decision is the
app's deployment choice, not an install-time gate.

**The framework is designed against TruffleRuby and will be measured on it.** CRuby is a development
convenience. Where the two diverge — Ractor semantics most of all — TruffleRuby is the behaviour the
docs describe, and a CRuby-only difference is a bug in the docs, not in TruffleRuby.

Anything TruffleRuby-specific runs in CI, not in a local hook. Do not assume a contributor's machine
has TruffleRuby on it.

## Prerequisites, once there is something to install

Planned, for a generated app rather than for the gem:

| Dependency | Why | Swappable |
|---|---|---|
| PostgreSQL | the default database, the default job queue, and the default realtime transport (`LISTEN`/`NOTIFY`) | the DB engine is a [swap point](../docs/idea/04-swap-points.md); the defaults are not the only options |
| A TruffleRuby install | production runtime | no — this is the non-negotiable runtime decision |
| Nothing else | no Node, no bundler for the frontend, no build step for CSS or JS. htmx is ~14kb served from the app | — |

There is **no Node toolchain** in the plan, at any phase. If a future page tells you to run `npm`,
that page is wrong.

## How you will install it

Planned. None of this works today.

```bash
gem install magik            # the CLI, globally
magik new myapp              # scaffold an app
cd myapp
bin/setup                    # bundle, create the database, migrate, seed — idempotent
magik server                 # boot it
```

Inside an app, `magik` resolves through the app's own bundle, so the app's `Gemfile` pins the version
it runs. The global install exists to make `magik new` reachable before there is a bundle.

Read [Getting started](Getting-Started.md) for what each of those steps is intended to produce.

## Installing from a checkout

Real today, and the only way to see the code:

```bash
git clone https://github.com/developerz-ai/magik
cd magik
bundle install
ruby -Ilib -e 'require "magik"; puts Magik::VERSION'
rake -T                      # the tasks this checkout defines
bin/check                    # the repo's own gate
```

`rake -T` and `bin/check` are the honest answer to "what does this repo do" — they list what exists
rather than what is planned.

## Next

- [Getting started](Getting-Started.md) — the intended first run, end to end.
- [Project layout](Project-Layout.md) — what `magik new` will emit, and how this repo is arranged.
- [Known gaps](Known-Gaps.md) — the full, honest list of what is missing.
