# The dev loop

Hot code reloading, the dev server and the console, designed as a subsystem — because the inner loop is where a developer or an agent spends every minute that is not spent waiting on CI.

**Status:** planned. There is no dev server, no reloader and no file watcher. Reviewed 2026-08-26.

## What the loop is

```
edit a declaration  →  save  →  registry rebuilt  →  next request serves the new code
```

No restart, no build step, no bundler, no compile. The target is **sub-second**, and it is a target with a command that will measure it, not a benchmark:

```bash
magik server --report=reload     # prints ms per reload and what triggered it
```

## What reloads, and what cannot

| Reloads | Why it can |
|---|---|
| `model` declarations | a declaration is a value in a registry, not an open class scattered across files |
| `screen`, `component` declarations | same, plus the compiled HTML is derived, so it is regenerated |
| `action` declarations | same |
| `job` declarations | the definition reloads; a job **in flight** finishes on the code it started with |
| `channel` declarations | the definition reloads; existing subscriptions are re-attached to the new definition |
| `ledger`, `flow`, `api`, `webhook`, `notification`, `admin_panel` declarations | all registry-backed |
| locale catalogs | re-read from disk |
| plain Ruby under `app/` | reloaded with the declarations that reference it |

| Requires a restart | Why not |
|---|---|
| `App.define` — the composition root | it selects the seams and opens the connections; re-running it mid-process is the `MAGIK_BOOT_REDEFINED` case ([`../idea/03-guardrails.md`](../idea/03-guardrails.md)) |
| initializers and `config/` | they configure long-lived objects — pools, backends, the logger |
| `Gemfile` / `Gemfile.lock` | the loaded gem set is a property of the process |
| migrations | a schema change is applied with `magik migrate`, and the reloader re-reads the schema afterwards |
| the framework's own `lib/magik/` | when developing Magik itself, not an app |

**Refused loudly, never stale.** When a change lands in a file that cannot be hot-reloaded, the dev server does not quietly serve the old code: it prints what changed, why it needs a restart, and the command — and, with `--restart-on-boot-change`, restarts itself. The rule from the spec applies here too: no silent failure.

```
config/app.rb changed — the composition root cannot be hot-reloaded.
  reason: it selects backends and opens connections
  fix:    restart the server (or run: magik server --restart-on-boot-change)
Serving previous code until then.
```

## The mechanism

### Prior art

| Prior art | How it works | What it pays |
|---|---|---|
| Rails `ActiveSupport::Reloader` | a file watcher marks the app dirty; `to_prepare` hooks run; autoloaded constants are unloaded and re-resolved on next reference | unloading constants is the hard part — anything holding a reference to the old class keeps it alive, and the two versions coexist |
| `Zeitwerk::Loader#reload` | removes the constants it defined and re-resolves them from the file tree | the same hazard, cleanly implemented: it can only manage what it defined, and it cannot know who kept a reference |

Both are fighting the same fact: in Ruby, a constant is a reference other objects can capture, and unloading it does not reach those captures.

### What Magik does instead

**Rebuild the registry; do not chase constants.**

Every declaration is registered in a known registry ([`01-module-map.md`](01-module-map.md)) rather than scattered through open classes and callback lists. So a reload is:

```
1. watch      file changed under app/ or domains/
2. graph      resolve the changed file to the declarations it defines, plus dependents
3. rebuild    re-evaluate those declaration files into a NEW registry, off to the side
4. guardrail  run the boot guardrails against the new registry
5. swap       atomically replace the live registry — or, on failure, keep the old one and show the error
6. freeze     the new registry is frozen, exactly as at boot
```

| Property | Consequence |
|---|---|
| Deterministic | the new registry is built from source, not patched. There is no half-updated state |
| Atomic | in-flight requests finish against the registry they started with |
| Guardrailed | a reload that would violate a boot rule **fails the reload**, not the next request an hour later — the same codes as boot |
| Idempotent subscriptions | channels, jobs and webhooks are entries in the new registry, so a reload cannot double-register a subscriber. That failure mode is structurally absent, not defended against |

### The hazards Ruby reloading always has

Named, because a page claiming reloading is solved would be the dishonest version:

| Hazard | Magik's answer |
|---|---|
| Stale constant references | app code refers to declarations by **name** through the registry (`Order`, resolved per request), not by captured class object. Code that captures a Ruby constant directly is the case that can go stale, and `magik check` reports it |
| Values memoized at boot | memoization inside a declaration body is re-evaluated on rebuild. Memoization inside an initializer is not — which is part of why initializers are restart-only |
| Subscribers registered twice | impossible via the registry path, since the registry is replaced rather than appended to |
| Long-lived objects holding old definitions | jobs in flight and open channel connections; both are explicitly documented as finishing on the code they started with |

**Spec item 9 is what makes this tractable**: app servers hold no in-process state across requests. There is no session cache, no per-connection view state and no memoized request-scoped graph to reconcile — so swapping the registry between two requests is safe by construction, and the stateless guardrail is the thing that keeps it that way ([`../idea/03-guardrails.md`](../idea/03-guardrails.md)).

## The dev server

```bash
magik server                       # Puma, dev mode, watching
magik server --port 3000
magik server --report=reload       # reload timings
magik server --restart-on-boot-change
```

| Property | Detail |
|---|---|
| Server | Puma in dev and in production — one server, so dev behaviour predicts production behaviour |
| Watching | the OS file-watch API where available, polling as a fallback; the watched set is `app/`, `domains/`, `config/locales/` |
| Debounce | rapid saves coalesce into one rebuild |
| Target | sub-second from save to served, measured by `--report=reload` |

**When reloaded code raises**, the developer gets the same object the CLI would print — code, cause, app-code location, `fix:` line — as an error page, with framework frames collapsed ([`06-observability.md`](06-observability.md)). Never a raw backtrace, and never a different string from the one the terminal shows.

## The browser half

There is no JavaScript build step because there is no JavaScript to build ([`../idea/05-limits.md`](../idea/05-limits.md)). The browser side of a reload:

| Change | Browser behaviour |
|---|---|
| a screen, component or action body | the next htmx request returns the new HTML — no refresh needed for the part being worked on |
| the currently open page's own structure | the dev server pushes a reload signal on the dev channel and the page refreshes once |
| CSS tokens / theme | the stylesheet is re-fetched; no page reload |
| a model or job with no visual effect | nothing visible; the reload line in the terminal is the feedback |

The dev reload channel is a dev-only concern and is not present in a production build.

## `magik console`

```bash
magik console            # boots the app, guardrails included, into IRB
> reload!                # rebuild the registry in place
> Order.recent.sql       # inspect, not guess
> magik_routes           # the same table as `magik routes`
```

The console shares the reloader with the dev server, and the **dependency graph** it uses is the same one `magik test --changed` and `--watch` use ([`04-testing-strategy.md`](04-testing-strategy.md)). One implementation, three consumers:

| Consumer | Question it asks the graph |
|---|---|
| the dev-server reloader | what declarations does this changed file define, and what depends on them? |
| `magik test --changed` | which tests can this diff affect? |
| `magik test --watch` | which tests should re-run right now? |

A second implementation of "what changed and what depends on it" would drift, and the drift would be invisible — a reload that missed a dependent and a test run that skipped one look identical to working correctly.

## Generators are part of the loop

```bash
magik generate model Order
magik generate screen Orders
magik generate action refund_order
```

Generated files are **live immediately** — the watcher picks them up, the registry rebuilds, and the route exists on the next request. No restart, no registration step, no route file to edit. Each generator also emits a failing test, so the loop's next move is obvious ([`05-adding-a-feature.md`](05-adding-a-feature.md)).

**A generated surface arrives declared, not blank.** A `screen` or an `action` reaches a model, so it names a `policy:` verb and a `layout:`; a generator that emitted either without them would emit a file whose only effect is to fail the next reload with `MAGIK_POLICY_UNDECLARED` or `MAGIK_LAYOUT_MISSING`. The generated authorization test — one per verb, including a cross-tenant denial — comes in the same pass ([`04-testing-strategy.md`](04-testing-strategy.md)). This is what makes the reload loop usable rather than a boot-failure loop: the guardrails run on **every** rebuild, so anything the generator leaves undeclared is felt on the next save rather than at deploy.

## Configuration in the loop

Config and secrets interact with reloading in exactly one way worth stating: **they do not reload.** Credentials, `.env` files and `config/` are read once, at boot, because the objects they configure are long-lived ([`07-configuration-and-secrets.md`](07-configuration-and-secrets.md)). Changing one prints the restart notice above rather than being partially applied.
