---
description: Say what the single next piece of work in this app is, with the reason and the first command — read from docs/PLAN.md and the working tree.
allowed-tools: Read, Glob, Grep, Bash
---

# /next

Answer with **one** task, not a list. A ranked backlog is what `docs/PLAN.md` already is.

## Read, in this order

1. **`docs/PLAN.md`** — this app's plan, written by `/setup-project` and ticked by `/feature`. If it
   still carries the stage-2 banner, the answer is **"run `/setup-project`"** and nothing else. An
   app with no plan does not have a next task; it has an unanswered interview.
2. `git status --short` and `git log --oneline -20` — what is half-done in the tree right now.
   **Unfinished work outranks anything on paper.**
3. `docs/ARCHITECTURE.md` — which domain the next slice lands in, and what it may not reach into.
4. `docs/FEATURE.md` — this app's definition of done. A slice that does not meet it is not a slice.
5. `magik check` and `magik test` — a failing gate outranks a new feature. Both are `planned` today
   and exit `1`; say so rather than reporting a clean run.

`magik docs Known-Gaps` before you call something a defect: much of what looks missing is not built
yet on purpose, and the local docs match this app's gem.

## Rank by

- **A broken thing beats a missing thing.** A failing guardrail, a false claim in a doc, a test that
  cannot fail — all before the next feature.
- **Finish before you start.** A slice at 80% with nothing shippable is worth less than nothing.
- **Unblocking beats breadth.** The model three other slices need comes before the fourth screen.
- **A user-visible slice beats an internal one**, all else equal. This app exists to be used.
- **Money and tenancy decisions come early.** They are cheap now and structural later — a
  `tenant_id` retrofit touches every table.

## Answer with exactly this

```
Next:      <one sentence — the task>
Because:   <what it unblocks, or which claim it makes true>
Slice:     <the docs/PLAN.md line, or "not in the plan — add it first">
Owner:     <which .claude/agents/ agent's file set it lands in>
Done when: <the assertion or the screen that proves it, per docs/FEATURE.md>
Start:     <the first command, verbatim>
Not now:   <the runner-up, and why it loses>
```

Do not implement anything. If the honest answer is "finish what is in the working tree", say that.
