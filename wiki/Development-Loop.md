# Development loop

**Status:** `Planned — not implemented`. Spec Phase 2, build step 4. Nothing on this page runs — the
loop it describes is the target developer experience. `As of 2026-08-26`.

The day-to-day. Two terminals, no build step, and a save-to-see time short enough that you stop
thinking about it.

```bash
magik server         # terminal 1 — reloads on save
magik test --watch   # terminal 2 — re-runs what your save affected
```

That is the whole setup. There is no third terminal running a bundler, a watcher, a CSS compiler or a
type checker, because none of those exist in this stack.

---

## Hot reload

`magik server` watches the app and reloads changed declarations in place. You save; you refresh; it
is there. No restart, no lost database connection, no waiting for a boot.

### Reloads instantly

| Change | Effect |
|---|---|
| `app/models/*.rb` | the model is redefined. Existing rows are untouched; new queries use the new declaration |
| `app/screens/*.rb` | the next render uses the new screen |
| `app/components/*.rb` | every screen composing it re-renders |
| `app/actions/*.rb` | the next POST runs the new body |
| `app/jobs/*.rb` | the next enqueue and the next worker pickup use the new definition |
| `app/channels/*.rb` | subscriptions are re-established |
| `app/ledgers/*.rb` | re-validated; an unbalanced entry surfaces immediately rather than at the next boot |
| `locales/*.yml` | the next render uses the new strings |
| `config/theme.rb` | tokens re-emit; a refresh shows the new palette |
| `domains/*/domain.rb` | boundaries are re-checked. A violation you just introduced appears on the next request |

### Needs a restart

Short list, on purpose. Each one is something the process is built *around* rather than something it
holds.

| Change | Why |
|---|---|
| `config/app.rb` — the `App.define` root | it is the composition root; rebuilding it is a boot |
| `config/initializers/*` | they run once, and running them twice is not generally safe |
| `config/backends.rb` — the swap points | changing the job or realtime backend re-opens connections |
| `db/migrate/*` | schema changes are applied by `magik db migrate`, not by a file watcher. A watcher that silently altered your schema would be a bad surprise |
| `Gemfile` | a new gem needs `bundle install` |
| `.env` | environment is read at boot — see [`docs/architecture/07-configuration-and-secrets.md`](../docs/architecture/07-configuration-and-secrets.md) |

The server tells you when it hits one rather than silently doing nothing:

```text
MAGIK_RESTART_REQUIRED: config/app.rb changed and cannot be hot-reloaded
  fix: restart `magik server`
```

**Silent no-ops are the worst reload failure.** A framework that reloads *most* things and quietly
skips the rest teaches you to distrust reload entirely, so the ones that cannot reload say so.

---

## When reloaded code raises

You get an error page carrying **the same code, cause and `fix:` line** the CLI would print. Not a
raw backtrace with the useful part on line 40.

```text
MAGIK_SCREEN_DIRECT_QUERY: :Invoices builds a query inside its body block

  cause: app/screens/invoices.rb:11 calls Invoice.where(...) inside `body`
  fix:   move it to a `scope` on the model and declare it as `state`

  app/screens/invoices.rb:11
     9 |   body do
    10 |     card title: "Overdue" do
  → 11 |       data_table Invoice.where(status: :sent)
    12 |     end
```

| The page carries | Because |
|---|---|
| The `MAGIK_*` code | it is greppable, linkable, and the same string in the terminal, the page and `--json` |
| The cause | one sentence about what actually happened |
| A runnable `fix:` | "check your configuration" is not a fix. See [Error codes](Error-Codes.md) |
| The source excerpt | the failing line, in context |
| The full backtrace, collapsed | available, not in your way |

In development only. In production the same error is a log line with the same three fields and a
generic page — see [`docs/architecture/06-observability.md`](../docs/architecture/06-observability.md).

---

## Generating code

```bash
magik generate model Invoice
magik generate screen Invoices
magik generate action mark_paid
```

Files land in the paths [Project layout](Project-Layout.md) prescribes, and they are **live
immediately** — the running server picks them up, and `--watch` picks up the test that was generated
alongside them. There is no registration step and nothing to add to a manifest.

| Rule | Detail |
|---|---|
| Every generator writes a test too | never a `# TODO: write a test` stub |
| A generator never overwrites hand-written code | `MAGIK_GENERATE_WOULD_OVERWRITE`, naming the file |
| `--dry-run` prints what it would write | and `--dry-run --json` gives you the list as data |

---

## The console

```bash
magik console
```

A REPL with the app loaded: models, actions, jobs, the current tenant.

```ruby
> reload!                                  # re-read changed files without restarting
> Invoice.overdue.count
> perform_action :mark_paid, id: invoice.id
> SendInvoiceEmail.perform_now(invoice_id: invoice.id)
> sandbox!                                 # everything from here rolls back on exit
```

`sandbox!` opens a transaction that is rolled back when the console exits. Poking at production data
without it is how people learn about it.

---

## No JavaScript build step. Ever.

This is a feature, and it is worth naming.

| Not present | Consequence |
|---|---|
| No `package.json`, no `node_modules` | nothing to install, nothing to audit, nothing to upgrade |
| No bundler, no transpiler, no minifier | nothing between saving a file and seeing it |
| No CSS pipeline | tokens are CSS custom properties, emitted by the framework |
| No source maps to configure | the line number in the error is the line number in your file |

htmx is a ~14kb file in `public/`. Your markup comes from the DSL. The reload path is: save a Ruby
file, the server re-reads it, the next render is different. There is no compile in the middle, which
is why there is nothing to wait for.

---

## Before you push

```bash
magik check              # guardrails, tenancy, ledgers, domain boundaries, contracts
magik test --changed     # what your diff can have broken
bin/check                # the app's own gate: both of the above, and lint
```

`magik check --scale` additionally reports queries missing `tenant_id` in their `WHERE` clause. Run it
before a schema you cannot easily shard is already in production.

---

## Next

- [Getting started](Getting-Started.md) — the first run.
- [Testing](Testing.md) — `--watch`, `--changed`, and the parallel runner.
- [CLI reference](CLI-Reference.md) — every command and flag.
- [`docs/architecture/08-dev-loop.md`](../docs/architecture/08-dev-loop.md) — how reload actually works, and what it cannot do.
