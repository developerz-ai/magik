---
description: Say what the single next highest-value piece of work is, with the reason and the first command to run
allowed-tools: Read, Glob, Grep, Bash, Task
---

# /next-task

Answer with **one** task, not a list. A ranked backlog is what the roadmap already is.

## Read, in this order

1. `git log --oneline -30` and `git status --short` — what actually landed, and what is half-done in
   the tree right now. Unfinished work in the working tree outranks anything on paper.
2. [`ROADMAP.md`](../../ROADMAP.md) — the version milestones and each phase's exit criteria.
3. [`docs/idea/06-phases.md`](../../docs/idea/06-phases.md) — dependency order and what each phase
   unblocks.
4. `rake test` — the exit criteria are assertions; find the first one with no test behind it.

## Rank by

- **Unblocking beats breadth.** The phase that unblocks the most later work wins, which is why
  testing (spec Phase 9) is delivered third — build the harness before the features it should have
  driven.
- **A false doc outranks a missing feature.** If a page claims something the code does not do, fix
  that first; the next agent reads it before the code.
- **A stub that lies** — one whose YARD describes behaviour nobody built — beats a stub that is
  honestly empty.
- **Finish before you start.** A phase at 80% with no exit criterion met is worth less than nothing.

## Answer with exactly this

```
Next:     <one sentence — the task>
Because:  <what it unblocks, or which claim it makes true>
Phase:    <n> (<spec | delivery> numbering — they differ)
Proof:    <the exit criterion in ROADMAP.md this satisfies>
Start:    <the first command, verbatim — usually a failing test>
Not now:  <the runner-up, and why it loses>
```

Do not implement anything. If the honest answer is "finish the thing in the working tree", say that.
