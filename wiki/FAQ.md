# FAQ

**Status:** answers about a framework that is `spec only`. Where something is not built, it says so —
which is everywhere. `As of 2026-08-26`.

---

## Status

### Is this production ready?

**No.** Not "early", not "beta" — **nothing is implemented**.

`magik 0.0.1` on RubyGems is a **name reservation**. It ships a version constant, the `MAGIK_*` error
convention, and a CLI with exactly two working commands (`version`, `help`). It renders no page,
opens no database connection, and runs no job.

Resolve it yourself:

```bash
gem list magik --remote --all
magik help                       # the complete list of what works
```

Read [Known gaps](Known-Gaps.md) before you spend an afternoon on this.

### What can I actually run today?

`magik version` and `magik help`, both with `--json`. That is the whole list. Everything else exits
`1` with `MAGIK_COMMAND_NOT_IMPLEMENTED`.

### Then why does the documentation exist?

Because the reference manual **is** the specification made concrete, and writing it first is what
keeps the implementation honest. A DSL you have documented as a user would meet it is a DSL whose
awkward corners you found before you built them.

Every page is labelled. No page claims something works.

### When will it be usable?

[`ROADMAP.md`](../ROADMAP.md) has the order and the definition of "done" per phase. It has **no
dates**, deliberately — a date on unstarted work is a guess wearing a suit.

---

## The stack

### Why TruffleRuby?

Concurrency. TruffleRuby has **no GVL**, so threads there run genuinely in parallel — and that is
measured rather than assumed: `ruby scripts/probes/runtime.rb` reports 2.55–3.54× on 4 threads on
TruffleRuby against 0.80–0.89× on CRuby, `As of 2026-08-26`
([the evidence](../docs/architecture/12-runtime-verification.md)). Those are engine measurements, not
Magik measurements — there is no framework to measure yet.

CRuby `>= 3.2` is supported for tooling and development, so you can run RuboCop and the framework's
own unit tests on a normal machine. **Where the two diverge, TruffleRuby is the documented
behaviour.** Anything TruffleRuby-specific runs in CI, not in a local hook.

No benchmark comparing them appears anywhere in these docs, because none has been run.

### Why Sequel and not ActiveRecord?

**Explicit queries, no lazy-loading magic.**

| | ActiveRecord | Sequel, as Magik uses it |
|---|---|---|
| Lazy loading | an unloaded association issues a query silently — the N+1 nobody sees until production | accessing an unloaded association raises `MAGIK_LAZY_ASSOCIATION`. Load it or say so |
| Query building | a large, implicit surface | a dataset you can read and reason about |
| Coupling | Rails-shaped | a library, wrappable without adopting a framework |

Magik wraps Sequel rather than reinventing it — that is the "don't reinvent" rule from the spec, and
Sequel's dataset model is a good fit for a DSL that compiles down to explicit SQL.

The database **engine** is a swap point. The query library is not.

### Why Minitest and not RSpec?

Fast boot, simple object model, and no `let` graph to reverse-engineer at 2am. It is a spec decision
and it is not revisited.

The `test :Name do it "…" do expect(…) end end` DSL compiles to Minitest classes and methods. The
failure output is Minitest's, the backtrace is Minitest's, and `--seed` is Minitest's.

`parallel_tests` and `parallel_rspec` are prior art for the **runner mechanics** — process-per-core, a
database per worker — not a framework choice. See [Testing](Testing.md).

### Why htmx and not React?

Because the alternative is two applications, two routers, two validation layers and two definitions
of "the current state", and most SaaS products do not need the second one.

| | An SPA | Magik |
|---|---|---|
| Rendering | client, from JSON the server also had to shape | server, from the same declaration that defines the model |
| State | duplicated. Client cache, server database, and a sync problem between them | one. The server |
| Build | bundler, transpiler, minifier, source maps | none. htmx is a ~14kb file in `public/` |
| Validation | written twice, drifting | written once, on the action |

The honest trade: **you give up rich client-side interactivity.** If your product is a canvas editor,
a game, or a spreadsheet engine, this is the wrong framework and [Known gaps](Known-Gaps.md) says so
rather than letting you discover it in month four.

### Can I use my own components, or my company's component library?

**Yes, four ways, and you take the cheapest one that fits.**

| You want | You do | Cost |
|---|---|---|
| A different look | change design tokens in `config/theme.rb` | no Ruby |
| A different layout, same behaviour | `variant:`, or `component :Modal, extends: Magik::Kit::Modal` | one small component |
| Your own modal, still called `modal` everywhere | declare `component :Modal` in `app/components/` — it shadows the built-in by name | one component plus a contract |
| Your organisation's library across every app | `kit :acme_ui` in `config/backends.rb` | one gem, written once |

Shadowing a kit name carries a **contract** — props, slots, htmx targets and events — because kit
components compose each other (`data_table` opens rows in a `modal`). Declare `satisfies
Magik::Kit::Modal` and the boot verifies it; miss a slot and you get
`MAGIK_COMPONENT_CONTRACT_VIOLATION` naming exactly what is missing, with a `fix:` offering both
exits: satisfy the contract, or stop shadowing the name.

Full worked example: [Screens and components](Screens-And-Components.md#using-your-own-components). The
reasoning: [`docs/idea/08-component-overrides.md`](../docs/idea/08-component-overrides.md).

### Does "no SPA framework" mean I cannot write any JavaScript?

No. It forbids a client framework **owning rendering** — a virtual DOM, a client-side component tree,
a client router. It does not forbid attaching your own JavaScript behaviour to markup the server
rendered: a focus trap, a date picker, a drag handle, a charting library initialised on an element.

Server renders the markup; wire what you like to it. What does not change is the guardrails.

### Why no offline support?

Because offline means a local write log, conflict resolution, and a second definition of "what is
true" — which is where most of the complexity lives in every framework that tried it, and where most
of them died.

The server is the single source of truth. A PWA ships (installable, `pwa do … end`); an offline cache
does not. Asking for one gets `MAGIK_OFFLINE_UNSUPPORTED`, which refuses loudly rather than
half-working.

**This is permanent.** It is not on the roadmap at any version.

### Why one gem instead of a monorepo of gems?

One gem, `magik`, with subsystem modules under `lib/magik/<subsystem>/`. A user adds one line to a
`Gemfile` and does not choose a package set.

Extraction into separate gems stays possible later. It is **not promised**, and no page should imply
a package boundary that does not exist.

---

## Compared to Rails

### How is this different from Rails?

Same ambition — the full stack, opinionated, batteries included. Different answers.

| | Rails | Magik |
|---|---|---|
| Runtime | CRuby | **TruffleRuby**, where threads run in parallel because there is no GVL |
| ORM | ActiveRecord, lazy by default | Sequel, explicit. An unloaded association raises |
| UI | ERB/ViewComponent + Hotwire, or an SPA | one DSL compiling to HTML + htmx. No templates to write |
| Routing | `config/routes.rb` | convention. `screen :Invoices` is `/invoices`. There is no routes file |
| Mutations | controller actions, service objects, model callbacks — several places | `action`. **One** place, enforced at boot |
| Multi-tenancy | a gem, or you build it | built in. Every model scoped by `tenant_id`, UUIDv7 keys from day one |
| Money | a gem, and a decimal column you have to remember | a `:money` type. A `Float` is refused by the type system |
| Double-entry | your problem | `ledger`, balance-validated at boot |
| Conventions | documented; violations are caught in review | **enforced**. A violated convention is a boot failure with a code and a fix |
| Tests | Minitest, parallel by process | Minitest, all cores by default, transactional rollback, inferred factories |
| Frontend build | importmaps, jsbundling, cssbundling — a choice to make | none. There is no build step |

### Is it a Rails replacement?

For the app shapes the spec targets — CRUD SaaS, dashboards, fintech, ecommerce, marketplaces —
that is the ambition. Today it replaces nothing, because it does nothing.

### Can I migrate a Rails app to it?

There is no migration path and none is designed. When there is a framework, there might be a page
about it. Right now the honest answer is: no.

### What does Magik take from Rails?

The philosophy — convention over configuration, batteries included, one obvious way — and the
parallel test runner's shape. The differences above are where the answers diverge, not where the
ambition does.

---

## Working with it

### Is this an AI-first project?

Yes, and that is a design constraint rather than a marketing line. The primary developer is an AI
agent, and the framework's shape follows from it: one uniform DSL grammar across every subsystem,
boot-time guardrails as the correction mechanism, errors carrying a runnable `fix:`, convention over
configuration, and a surface small enough to fit in a context window.

Read [`docs/idea/07-ai-first.md`](../docs/idea/07-ai-first.md) for the reasoning, and
[`.claude/README.md`](../.claude/README.md) for the agent workbench committed to this repo.

### I am an agent. Where do I start?

[`llms.txt`](../llms.txt). It splits by what you are doing: **implementing** Magik, or **building a
SaaS with** Magik.

### How do I help?

[Contributing](Contributing.md), which points at the root
[`CONTRIBUTING.md`](../CONTRIBUTING.md). The fastest way to be useful is to take a phase from
[`ROADMAP.md`](../ROADMAP.md) and make [Known gaps](Known-Gaps.md) shorter.

### Where are the API docs?

Generated with YARD and published to <https://developerz-ai.github.io/magik/api/>. They document what
exists — which today is `Magik::VERSION`, `Magik::Error`, `Magik::CLI` and twenty stubs.

### Where does this live?

<https://github.com/developerz-ai/magik>. MIT licensed, copyright 2026 developerz.ai.
