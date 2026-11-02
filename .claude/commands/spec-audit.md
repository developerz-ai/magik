---
description: Diff the implementation against docs/idea/00-build-spec.md and report what is claimed vs what is real, naming every doc that overstates
argument-hint: [subsystem, phase, or blank for the whole repo]
allowed-tools: Read, Glob, Grep, Bash, Task, Agent
---

# /spec-audit

## Scope
$ARGUMENTS — blank means the whole repo.

Read-only. **Change nothing.** The output is a verdict table; the edits are someone else's job.

Delegate to the `spec-auditor` agent — one per area if the scope is wide, disjoint by subsystem —
and fold the reports together yourself. Do not read files an agent will report back on.

## Ground truth order

1. `apps/magik/lib/magik/<subsystem>/` — does it still raise `NotImplementedError`? A stub is not a feature.
   Machine-readable: `ruby -Iapps/magik/lib -e 'require "magik"; p Magik::SPEC_ONLY_SUBSYSTEMS'`. Diff that
   constant against reality **in both directions** — a working subsystem still listed, or an absent
   one still raising, is a finding by itself.
2. `rake -C apps/magik test` — a claim with no test behind it is a claim.
3. `ruby -Iapps/magik/lib apps/magik/exe/magik help` — the commands that actually exist.
   `ruby -Iapps/magik/lib apps/magik/exe/magik version --json` is the stable status line.
4. `git log --oneline` — what merged.

Docs come last, and only to be checked against the above.

## Audit these

[`docs/idea/00-build-spec.md`](../../docs/idea/00-build-spec.md) phases ·
[`02-dsl-surface.md`](../../docs/idea/02-dsl-surface.md) constructs ·
[`03-guardrails.md`](../../docs/idea/03-guardrails.md) rules ·
[`04-swap-points.md`](../../docs/idea/04-swap-points.md) seams ·
[`apps/magik/wiki/Error-Codes.md`](../../apps/magik/wiki/Error-Codes.md) · [`apps/magik/ROADMAP.md`](../../apps/magik/ROADMAP.md) ·
[`apps/magik/wiki/Known-Gaps.md`](../../apps/magik/wiki/Known-Gaps.md) · [`README.md`](../../README.md) ·
[`apps/magik/llms.txt`](../../apps/magik/llms.txt) · every `apps/magik/wiki/` example.

Reconcile phase numbering against [`docs/idea/06-phases.md`](../../docs/idea/06-phases.md) — the
spec's order and the delivery order differ — before calling anything late.

## Output

| Claim | Claimed at | Reality | Verdict |
|---|---|---|---|

Verdicts: `true` · `overstated` · `understated` · `unverifiable`. Then the single worst
overstatement, and the shortest edit list that would make every page true. **Report understatements
too** — a working feature still marked `planned` costs the next agent a day.
