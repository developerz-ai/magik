---
description: Take a feature or a defect sweep from plain language to merged — trace it to the spec, distrust the paperwork, explore in parallel, slice by subsystem, build with at most four agents in this one checkout, land bin/check green, PR, merge. Tracks in GitHub issues.
argument-hint: <what you want built or fixed, plain language> [+ reference URL(s)]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent, Task, SendMessage, Skill, WebFetch
---

# /feature

Take one feature or defect sweep from idea to merged. `/implement-phase` is for a whole delivery
phase; this is for work that arrives as a request rather than as a phase.

## Request
$ARGUMENTS

**Done means merged with `bin/check` green.** Magik ships nothing, so there is no deploy to hide
behind: the tree and the gate are the whole of reality. Report which steps you ran, not which you
assume passed.

**The prompt is the context.** "Just ship it" → decide everything yourself, merge on green, surface
decisions in the PR body instead of asking. A tentative ask → clarify what is genuinely ambiguous and
let the user review before you merge. Always stop for anything reserved to the owner in
[`CLAUDE.md`](../../CLAUDE.md#who-decides), and for anything the spec does not frame, where deciding
is invention rather than derivation.

## The flow

1. **Restate the goal in a line**, and **name the spec section** —
   [`docs/idea/00-build-spec.md`](../../docs/idea/00-build-spec.md). No section, no change: propose a
   spec amendment ([`CONTRIBUTING.md`](../../CONTRIBUTING.md)) instead of inventing one. If the ask
   cites URLs, `WebFetch` them for the *mechanism*, then translate it onto this stack rather than
   importing its shape.

2. **Distrust the paperwork.** The spec reads like documentation for a working framework and is a
   **plan**. Before planning off any status claim — `CLAUDE.md`, `README.md`, `ROADMAP.md`, a `docs/`
   page — check it against the code and `git log`: `ruby -Ilib -e 'require "magik"; p
   Magik::SPEC_ONLY_SUBSYSTEMS'`, `grep -rln NotImplementedError lib/magik`, `rake test`. Delegate to
   `spec-auditor` when the surface is wide. **Say which claims you falsified** and fix those docs in
   the same change — nobody should re-implement shipped work or "fix" working code.

3. **Explore in parallel.** Fan out `Explore` agents (very thorough) over **disjoint** subsystems.
   Require of every finding: severity, `file:line`, a one-sentence defect statement, and a **concrete
   failure scenario** (inputs → wrong outcome). Demand two more things: the doc claims they
   **falsified**, and which of your brief's premises held. **Protect your own context** — you are the
   only participant who must survive to the merge, so do not read what an agent will report back.

4. **Track in GitHub issues — search before you create.** `gh issue list --search "<area>"`, open
   *and* recently closed. Already tracked, partly tracked (add a child to the parent), or a closed
   issue that already decided this — all three beat a fresh ticket. Create the parent *after*
   exploration so it carries `file:line` findings and the deferred list. One child per slice.

5. **Branch first, then fan out.** `git fetch origin && git status --short`, then
   `git checkout -b <type>/<slug>` per [`CONTRIBUTING.md`](../../CONTRIBUTING.md). Do it now, while
   the tree is clean.

   Then read [the hive rules](#the-hive) below and cut the slices **before launching anyone**. A
   **DSL construct needs its canonical shape in
   [`docs/idea/02-dsl-surface.md`](../../docs/idea/02-dsl-surface.md) first** (`dsl-designer` owns
   that), and a drafted spelling **is not designed until a parser has seen it** — extract the ```ruby
   blocks and run `ruby -c`. Build a shared primitive first with its first real caller; no abstraction
   before a consumer.

6. **Fold in live user reports as first-class findings.** A pasted trace or failing command mid-run is
   confirmed, and outranks a finding derived from reading. If a live agent holds those files, extend
   its brief with `SendMessage` — never spawn a second agent onto the same paths.

7. **Look for causal chains across reports.** Only you see all of them; one defect is frequently seen
   three times across `model` → `policy` → `render`. Spend one pass on "does A explain B?" before you
   fix anything. It changes what you fix and what you can drop.

8. **Verify.** Run the full gate **once, yourself**: `bin/check`. Prove it from the outside too —
   `ruby -Ilib exe/magik <cmd>` for CLI surface, `/dummy-app` when the change should make the
   reference app get further. Green gate **and** the new test failing without the fix is the bar.

9. **PR + merge — one PR in flight at a time, start to finish.** Parallel *building* is the point of
   the hive; merging serialises. Open PR *n* → wait for the merge → `git fetch` → only then stage
   *n+1*. "I will open both so I am not serialising on CI" is banned: waiting on CI is the step where
   the PR is told whether it works, and opening the next turns one PR you are watching into two you
   are half-watching. **If the work is too big to serialise, the answer is more agents, never more
   PRs.**

   **Sweep the agents' leftovers first** — scratch tests, debug output, a stray probe at the repo
   root. Then plain git: `git add <this slice's paths>`, read `git status --short`, `git commit` with
   a Conventional Commit scoped to the subsystem, `git push -u origin HEAD`. **Never `git stash`** —
   one global stack shared with every live agent. If `main` moved, **three-way merge** any real
   overlap (`git merge-file -p ours base theirs`) and verify both sides' symbols survive; never take a
   side wholesale.

   `gh pr create` with the [`CONTRIBUTING.md`](../../CONTRIBUTING.md) convention: the spec section,
   what is **not** done, `Closes #N`, and **a table of any new `MAGIK_*` codes — code, cause, `fix:`**
   so the reviewer can check each `fix:` is a command that exists. No emojis, no decorative footer.
   Merge only with every check green and the review clean; never `--force`, never `--no-verify`.
   **Zero registered checks reads as "pass"** — wait for a plausible count and zero pending, or you
   merge red right after a rebase.

10. **Leave the trail straight**, in the same change: `CHANGELOG.md` under `## [Unreleased]`, YARD
    with an `@example` on every public method, the `docs/architecture/` or `wiki/` page when the shape
    is new, and **every status row you just made wrong** — `README.md`, `ROADMAP.md`, `CLAUDE.md`,
    `llms.txt`, this harness. `docs-keeper` flips `planned` → real **only where a test proves it**.
    Record any non-obvious decision in
    [`docs/idea/13-decisions.md`](../../docs/idea/13-decisions.md): what, instead of what, why in
    terms of a constraint that already existed, what would reopen it. When the defect could recur,
    land the guard in the same PR — a boot-time guardrail, a `scripts/checks/*.rb` assertion, a test.

## The hive

**Hiving is a judgement call, not a ritual.** It is justified by **searching** (you want conclusions,
not file dumps) or **scale** (enough path-separable work that serialising takes hours). A single-file
fix or a change you already understand — do it yourself; three agents on a two-file change cost more
in briefing and collision-mediation than the change is worth.

**At most FOUR live agents — a ceiling, not a target.** Three is often right, one usually is. Four is
what one coordinator can run: four briefs, four disjoint file sets, four reports. Past four,
disjointness stops being cuttable honestly and two agents write the same file. More hands means a
second wave re-cut by the first wave's findings, or a second PR — never a fifth agent.

**Only the coordinator spawns; the hive is flat.** An agent must not call `Agent`, and every brief
says so. A nested spawn is not counted against the four and inherits no file lock, so a grandchild
edits paths nobody claimed and you find out at `git status`.

- **You coordinate; you do not code.** You own git, the ledger and the merge. Editing `lib/`
  yourself takes a slice from someone who had room for it.
- **The file set is the lock**, and the slice is `lib/magik/<subsystem>/` plus its mirrored
  `test/magik/<subsystem>/`. Two agents that must edit one file are ONE slice. An agent needing a file
  it does not own **stops and reports** — never edits across the line, never negotiates peer-to-peer.
- **Every slice you name, you must dispatch.** Briefs tell agents who holds which paths, so a
  named-but-unlaunched slice makes them defer work to somebody who does not exist. Reconcile the
  roster against the dispatched set before reading any report.
- **Keep an unowned bucket and expect to fill it mid-run**: `lib/magik.rb`, `magik.gemspec`,
  `CHANGELOG.md`, `llms.txt`, `wiki/Error-Codes.md`, `scripts/checks/`, `dummy/`,
  `.github/workflows/`. A homeless finding is the one quietly dropped — assign it the moment a report
  says "the real fix is outside my set".
- **Agents are teammates, not one-shot jobs.** New work in a held area goes to that agent by
  `SendMessage`; it keeps its context and its lock. An agent dying is not the run dying — its work is
  uncommitted in the shared tree, and `SendMessage` resumes it from its transcript. `git status` and
  `git diff` to see how far each got, then resume with what survived, what is missing, and what
  changed while it was down. Expect the common shape: **the code landed and the tests did not.**
- **Expect the hive to contradict you.** A brief built from a survey contains claims the code
  disproves. Drop the premise; that is the agent working correctly.

### Every brief carries all of these

Its **exclusive file set** and never to edit outside it · **which other agents are live on which
paths** · each finding with `file:line`, defect and failure scenario, plus permission to **drop any
finding the code contradicts** · **evidence first, diagnosis second** — symptom and failing input,
*then* your hypothesis labelled unverified, because a brief leading with a confident root cause sends
an agent to the wrong file · the house non-negotiables binding its area, from
[`.claude/README.md`](../README.md#rules-every-agent-here-inherits) and
[`docs/architecture/00-conventions.md`](../../docs/architecture/00-conventions.md) · **the guardrail
ships with the feature**, same change, with its `MAGIK_*` code, cause and a `fix:` that is a
**command, never advice** · **tests first, failure case first** · **its own tests only**, never
`bin/check` · **no subagents** · **no git operations at all** — you own all git, work is left
uncommitted.

**Never tell an agent to "ask me" — it cannot.** A subagent has no channel to the user, so a question
blocks or it guesses. Give it two legal moves: **decide and flag it** (act on the most defensible
reading, state the assumption, mark the artifact so you can overwrite it), or **stop and report** with
the evidence when either path would be unsafe. Then *you* take the question to the user and re-task
the agent with `SendMessage`.

### Who runs which checks

**Never let an agent run `bin/check`.** It gates the whole tree, and in a hive that tree holds every
agent's half-finished work — so each fails on the others' incomplete edits and the red they report is
noise. Whole-repo green is the coordinator's job and nobody else's.

| | Agent, per iteration | Coordinator, once at the end |
|---|---|---|
| tests | `rake test TEST=test/magik/<its own file>_test.rb` | `bin/check` |
| lint | `bundle exec rubocop <the files it edited>` | covered by `bin/check` |
| docs | `bundle exec yard stats --list-undoc` when otherwise done | covered by `bin/check` |

RuboCop and YARD are development dependencies and may be absent. **A missing tool is a skip, never a
pass** — run `bin/setup` first, and never report a run you did not complete.

## One concern per PR

**"It is all one coherent concern" is NOT a reason to bundle** — it is the rationalisation that
produces fat PRs. Neither is "the slices share a file, so separate PRs need rebases". The honest test:
could a reviewer approve one slice and reject another? Then they are separate PRs, however tidy the
story. A guardrail, a missing test and a new construct are three reviews.

**An explicit "one PR" from the user overrides that** — the paragraph above is about resisting your
own urge to bundle, not theirs. Two things still override the user: a PR past ~110–120 files stops
being reviewable, and two slices that both edit one file must not be hand-separated into hunks. Say
which forced your hand.

## Output

Be as explicit about what did not ship as what did — a sweep fixing 12 of 30 findings is a success
only if the other 18 are named.

```
Spec:       <section of 00-build-spec.md>
Root cause: <the one-line mechanism, for a defect sweep>
Fixed:      <n> findings across <m> PRs → #…
Deferred:   <n> — <what, and why not now>          [never omit this line]
Falsified:  <doc claims that were wrong, now corrected>
Codes:      <new MAGIK_* codes, or none>
Guards:     <guardrail / repo check / test, or none>
Gate:       bin/check <pass|fail>, <n>/7 steps, on <engine>
Docs:       <CHANGELOG, status rows, wiki pages touched>
Issues:     #<parent> closed (<k> children)
```
