---
description: Implement one delivery phase of Magik end to end — read the spec, reconcile the numbering, plan, fan the work out to path-disjoint agents, land it green on bin/check with docs left true
argument-hint: <phase number, e.g. 1> [or a construct name to scope it down]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent, Task, SendMessage
---

# /implement-phase

## Target
$ARGUMENTS

**Nothing in Magik is built.** Every `lib/magik/*.rb` is a documented stub raising
`NotImplementedError`. Done means: the phase's exit criteria in [`ROADMAP.md`](../../ROADMAP.md) are
each true, proven by a test you ran, with `bin/check` green. Not "the code is written".

The seam: each stub exposes `SPEC_PHASE`, `DSL_SURFACE`, `STATUS` and a `.define` that raises;
`Magik::SPEC_ONLY_SUBSYSTEMS` lists every one. **A phase is landed when its subsystems have left
that list**, with tests behind them — check it at the start and at the end:
`ruby -Ilib -e 'require "magik"; p Magik::SPEC_ONLY_SUBSYSTEMS'`.

## 1. Reconcile the numbering before anything else

The spec's phases and the delivery order are **not the same sequence** — spec Phase 9 (testing) is
delivered third. Say in one line which phase you are building, under which numbering, and what its
exit criteria are. Sources: [`docs/idea/00-build-spec.md`](../../docs/idea/00-build-spec.md) ·
[`docs/idea/06-phases.md`](../../docs/idea/06-phases.md) · [`ROADMAP.md`](../../ROADMAP.md).

## 2. Distrust the paperwork

Check the phase's claims against the code and `git log` before planning off them. Delegate to
`spec-auditor` if the surface is wide. State which claims you falsified and fix those docs in the
same change.

## 3. Design before you implement

Every DSL construct in the phase needs a canonical shape in
[`docs/idea/02-dsl-surface.md`](../../docs/idea/02-dsl-surface.md) first — `dsl-designer` owns that.
Implementing before the shape exists produces a DSL discovered one keyword at a time.

## 4. Slice by subsystem, then fan out

`lib/magik/<subsystem>/` **is** the lock: `core, cli, model, schema, render, action, router,
realtime, jobs, ledger, api, auth, billing, admin, i18n, pwa, notify, testing, domains, check`. A
slice owns its subsystem and its mirrored `test/magik/<subsystem>/`.

- **One checkout, never a worktree.** At most 4 workers; one is often right.
- Every brief names: the exclusive file set, who holds the neighbouring paths, the house
  non-negotiables (Sequel · Minitest · no ActiveSupport · SOLID/SRP · integer-cents money · UUIDv7 ·
  `tenant_id` · htmx not SPA · `MAGIK_*` with a runnable `fix:` · nothing that is not spec-backed),
  and **two legal moves when stuck**: decide and flag it, or stop and report. A subagent cannot ask
  the user.
- Agents run `rake test TEST=<their file>`; **only you run `bin/check`**, once, at the end.
- Roster: `spec-implementer` · `dsl-designer` · `guardrail-author` · `test-writer` ·
  `swap-point-prover` · `cli-author` · `docs-keeper` · `spec-auditor` (read-only).
- **Every slice you name, you must dispatch.** A named-but-unlaunched slice makes the others defer
  work to a teammate who does not exist.
- Keep an unowned bucket: `lib/magik.rb`, `CHANGELOG.md`, `llms.txt`, `wiki/Error-Codes.md`,
  `dummy/`. Homeless findings are the ones silently dropped.

## 5. Land it

1. `bin/check` green — the gate. Never narrow it, never disable a cop to pass.
   RuboCop and YARD may not be installed here — a missing tool is a reported skip, never a claimed
   pass.
2. Every guardrail the phase names has a test that fires **and** one that proves it does not
   over-fire.
3. Every swap point the phase names is proven against both backends, or stays `planned`.
4. `dummy/` exercises the new constructs; `wiki/` and `docs/` flip `planned` → real **only where a
   test proves it**; `CHANGELOG.md` records what landed; `ROADMAP.md` exit criteria ticked only if
   true.

## Stop for

A construct the spec does not name · a shipped `MAGIK_*` code you would have to change · a swap you
cannot prove · anything needing a guardrail disabled. Those are decisions, not steps.

## Output

```
Phase:      <n> (<spec | delivery> numbering) — <name>
Exit:       <criterion> ✓/✗ — <the test that proves it>
Gate:       bin/check ✓/✗
Codes:      <new MAGIK_* codes, or none>   wiki row: <y/n>
Swaps:      <seam: proven against A+B | still planned, because …>
Deferred:   <what, and why not now>            [never omit this line]
Falsified:  <doc claims that were wrong, now corrected>
```
