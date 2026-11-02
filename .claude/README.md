# `.claude/`

The harness that makes this repo buildable by an agent. Everything here is read by an agent, so
every file pays its token cost on activation — keep them short.

**Status: Magik is spec only.** Every `apps/magik/lib/magik/*.rb` is a documented stub raising
`NotImplementedError`. Nothing in this directory claims otherwise, and neither may anything you add.
The point of the harness is to turn that state into working code one tested piece at a time.

## What actually runs today

```bash
ruby -Iapps/magik/lib apps/magik/exe/magik version --json       # → {"status":"spec only", …}
ruby -Iapps/magik/lib -e 'require "magik"; p Magik::SPEC_ONLY_SUBSYSTEMS'   # every unbuilt subsystem
rake -C apps/magik test                                         # works on bare Ruby, no bundler
bin/check                                                  # the gate: test · rubocop · yard · docs:coverage
```

That is the whole of it. Each `apps/magik/lib/magik/<subsystem>.rb` exposes `SPEC_PHASE`, `DSL_SURFACE`,
`STATUS` and a `.define` that raises `NotImplementedError`. **`Magik::SPEC_ONLY_SUBSYSTEMS` is the
seam**: landing a phase means its subsystems leave that list, with tests behind them. `Magik::Error`
is real — every error carries a `MAGIK_*` code, a `cause_text` (`Exception#cause` is reserved), a
runnable `fix:`, and `#to_h` for `--json`.

RuboCop and YARD may not be installed on a given machine. A missing tool is a **skip**, never a
failing gate and never a lint you claim to have run.

| Path | Is | Triggered by |
|---|---|---|
| `agents/*.md` | role specialists | delegation from the main agent |
| `commands/*.md` | canned workflows | `/name` typed by the user |

**There is no committed `settings.json` here, on purpose.** Permission allowlists and post-edit
hooks are one operator's tolerance and one machine's tooling, so they stay untracked
(`.gitignore`). Nothing in this repo may depend on one existing: the lint runs because
`bin/check` runs `rake -C apps/magik rubocop`, not because a hook auto-fixed the file, and publishing is guarded
by [`PUBLISHING.md`](../apps/magik/PUBLISHING.md) and `bin/release`, not by a deny rule. Write your own
`settings.json` or `settings.local.json` if you want one; never commit either.

Not to be confused with [`apps/magik/lib/magik/cli/templates/app/.claude/settings.json`](../apps/magik/lib/magik/cli/templates/app/.claude/README.md),
which **is** committed — it is a template `magik new` will render into somebody else's app, and it
is a product artifact, not this repo's configuration.

## Two audiences — do not conflate them

1. **Framework contributors** — an agent implementing Magik itself, phase by phase, from
   [`docs/idea/00-build-spec.md`](../docs/idea/00-build-spec.md). **Everything here is for them.**
2. **Magik app builders** — an agent building a SaaS *with* Magik. Their harness does not live here;
   it is written and lives in [`apps/magik/lib/magik/cli/templates/app/`](../apps/magik/lib/magik/cli/templates/app/README.md),
   designed in [`docs/idea/09-app-scaffold.md`](../docs/idea/09-app-scaffold.md), owned by
   [`cli-author`](agents/cli-author.md). `magik new`, which would emit it, is **planned and not
   implemented** — the templates have never been rendered. Do not mix the two: an agent told to run
   `bin/check` inside a generated app is being handed the wrong repo's gate.

## Where this fits

Magik is the deliberate Ruby sibling of the house TypeScript framework: same thesis — one uniform
primitive grammar, server-authoritative, AI-first, **guardrails as the product** — aimed at
developers who want Ruby and specifically do not want a TypeScript toolchain. The prescribed app
file tree is part of that product, documented in
[`apps/magik/wiki/Project-Layout.md`](../apps/magik/wiki/Project-Layout.md) and demonstrated by `apps/magik/dummy/`, an
invoicing/billing SaaS.

## The roster

| Agent | Does |
|---|---|
| [`dsl-designer`](agents/dsl-designer.md) | decides the Ruby shape of a construct **before** anyone implements it |
| [`spec-implementer`](agents/spec-implementer.md) | one spec-backed slice under `apps/magik/lib/magik/<subsystem>/`, failing test first |
| [`guardrail-author`](agents/guardrail-author.md) | one boot-time rule: check, `MAGIK_*` code, `fix:`, both tests, wiki row |
| [`test-writer`](agents/test-writer.md) | Minitest that fails when the code breaks, and survives the parallel thread runner |
| [`swap-point-prover`](agents/swap-point-prover.md) | one contract test, two backends — a swap ships proven, not promised |
| [`cli-author`](agents/cli-author.md) | `apps/magik/exe/magik`, `apps/magik/lib/magik/cli/`, exit codes, `--json`, the generators |
| [`docs-keeper`](agents/docs-keeper.md) | flips `planned` → real only where a test proves it |
| [`spec-auditor`](agents/spec-auditor.md) | read-only: what is claimed vs what is real |

## The commands

| Command | Does |
|---|---|
| [`/next-task`](commands/next-task.md) | one task, with the reason and the first command |
| [`/planx`](commands/planx.md) | a multi-file execution plan another agent runs cold |
| [`/feature`](commands/feature.md) | one request, idea → merged: explore, slice, hive, gate, PR |
| [`/implement-phase`](commands/implement-phase.md) | a whole delivery phase: plan, fan out, land it green |
| [`/new-dsl`](commands/new-dsl.md) | one construct, all nine steps, design → CHANGELOG |
| [`/check`](commands/check.md) | `bin/check`, and triage each failure to a file and a fix |
| [`/dummy-app`](commands/dummy-app.md) | drive `apps/magik/dummy/` toward runnable; report exactly where it stops |
| [`/spec-audit`](commands/spec-audit.md) | every doc claim vs reality, overstatements named |
| [`/release`](commands/release.md) | the guarded checklist — it never publishes |

## The workflow

`/next-task` → `/implement-phase N` (or `/new-dsl <construct>` for one construct, `/feature` for
work that arrives as a request rather than as a phase) → `/check` until green → `/dummy-app` to prove
it in an app → `/spec-audit` before anyone believes a doc. `/planx` writes the plan when the work is
big enough that an executor should start from a map instead of from this conversation; it writes to
`.claude/plans/`, never `docs/` — `Magik::Docs::PACKAGED_GLOBS` serves `docs/**/*.md` in a checkout's
`magik docs` catalogue, so a plan written there would appear in `magik docs list`.

## Rules every agent here inherits

- **`bin/check` is THE gate** — `rake -C apps/magik test`, `rake -C apps/magik rubocop`,
  `rake -C apps/magik yard`. Never narrowed, never a
  disabled cop to get to green.
- **Nothing claims the framework works.** Status vocabulary: `planned`, `not implemented`,
  `spec only`. No benchmark numbers, no passing-test counts. Date claims that go stale.
- **Sequel · Minitest · no ActiveSupport · SOLID/SRP · integer-cents money · UUIDv7 · `tenant_id` ·
  htmx not SPA · nothing that is not spec-backed.** The conventions and how they are enforced:
  [`docs/architecture/00-conventions.md`](../docs/architecture/00-conventions.md).
- **Errors are instructions**: a stable `MAGIK_*` code, a cause naming the real constant, a runnable
  `fix:`. Shipped codes never change.
- **Phase numbers differ** between [the spec](../docs/idea/00-build-spec.md) and the delivery order
  in [`apps/magik/ROADMAP.md`](../apps/magik/ROADMAP.md) — spec Phase 9 (testing) ships third. Say which you mean.
- **One checkout, no worktrees.** Concurrency 1 per agent; the coordinator runs the gate once, at
  the end. No git operations in a subagent, and never `git stash`.

## Budgets

Agent ≤ 90 lines · command ≤ 60 · this file ≤ 130. Three commands are over budget and each says why
it earns it: `/implement-phase` (90) spans a whole phase, `/planx` (107) carries the file shapes it
tells you to write, `/feature` (206) carries the hive rules — the four-agent cap, the file lock, the
brief contents — which exist nowhere else and are the part a run goes wrong without.
Compress prose; never compress a path, a command or an error code.
