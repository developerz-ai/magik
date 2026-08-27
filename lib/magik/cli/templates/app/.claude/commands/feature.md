---
description: Build one feature end to end and leave the gate green — the loop you run over and over. With an argument it builds that; with none it takes the next slice from docs/PLAN.md.
argument-hint: [what a user should be able to do — blank takes the next slice from docs/PLAN.md]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
---

# /feature

**The loop.** `magik new` scaffolded this app, `/setup-project` made it yours, and `/feature` builds
it — one slice at a time, for as long as the app lives. Most days it is the only command you need.

It has to work as well on feature #40 as on feature #2, which is the whole design constraint here:
**read the app as it is now, never as the template imagined it.**

## 0 — Orient

Every run starts here. Three minutes of reading is what keeps run #40 from inventing a second way to
do something this app already does.

```bash
grep -c "magik:stage2-pending" CLAUDE.md      # not 0 → STOP, run /setup-project first
sed -n '/## Now/,/## Later/p' docs/PLAN.md    # where the loop left off
ls app/models app/screens app/actions         # what exists — reuse before you add
ls domains/*/domain.rb 2>/dev/null            # flat, or domained
magik domains --json                          # the enforced boundary graph
git log --oneline -15                         # how the last few slices were actually built
```

Then read `docs/FEATURE.md` — its project block carries this app's own answers: who owns which
domain, what "done" means here, what always needs a human look.

**Where the code and the documents disagree, the code wins.** A convention `app/models/` has
followed for thirty files is this app's convention whether or not anyone wrote it down. Follow it,
and add it to `docs/FEATURE.md`'s project block in the same run — that is how the loop stops
degrading instead of drifting.

## 1 — Read the docs for what you are about to write

**The Magik DSL is not in your training data**, and run #40 is exactly where an agent stops looking
and starts writing from memory. It comes out confident, plausible and Rails-shaped.

```bash
magik docs path                  # the directory — point your ordinary grep/glob/read at it
magik docs search <construct>    # before you guess an option name
magik docs Models                # …and the page for each thing this slice touches
```

Local, instant, and matched to this app's gem — unlike anything on the web. One command, and it
prevents the most expensive failure available here.

## 2 — Settle the slice

$ARGUMENTS — one thing a user should be able to do.

**Blank**: take the top item from `## Now` in `docs/PLAN.md`, or the first of `## Next` if `Now` is
empty, and **confirm it before starting**. State the slice, what proves it, and which files it will
touch; then build.

If it is more than one thing, say so and build the first. A feature you cannot describe in a
sentence is two features, and the second one is where the mess goes.

## 3 — Build, in review order

The order below is also the order a human reads a diff in, which is the scarce resource. Finish each
unit before starting the next, and say which one you are on.

| # | Unit | Lands in | Agent | Command |
|---|---|---|---|---|
| 1 | **Data** — fields, scopes, the append-only migration | `app/models/`, `db/migrations/` | `data-modeler` | `magik generate model <Name>` · `magik generate migration <Name>` |
| 2 | **Who may** — the verbs this slice needs, and the rule behind each | `app/policies/` | `policy-author` | — |
| 3 | **The write** — typed params, a `policy:` verb, guards, `idempotent_by` where a retry can reach | `app/actions/` | `action-author` | `magik generate action <name>` |
| 4 | **Money**, if any — a ledger entry, never a balance column | `app/ledgers/` | `ledger-author` | `magik generate ledger <Name>` |
| 5 | **The UI** — a screen naming declared `state` and a `policy:` verb; controls naming the action from unit 3 | `app/screens/`, `app/layouts/` | `screen-builder` | `magik generate screen <Name>` |
| 6 | **Tests** — one file per declaration, mirroring `app/` | `test/` | `test-writer` | `magik test` |

**Data before policy before writes before UI.** A screen written first invents the state it wishes
existed, and that invention is what gets built; a surface written before its verb gets a verb chosen
to fit it. Units 1–6 touch disjoint directories, so they parallelise once the names are fixed — and
not before; two agents guessing the same name differently is the collision this ordering prevents.

`magik generate` rather than placing files yourself: it writes the test too, and it cannot invent a
path. Layout rules: `magik docs Project-Layout`.

## 4 — The gate. Done means green

```bash
bin/check        # lint · tests · magik check · every rule in scripts/checks/
```

**Done is `bin/check` exiting `0`, not "files were written."** `69` means a step could not run and
is not a pass. A red gate is not a result to report; it
is the rest of the work. Triage each finding to a file, a rule and an owning agent, fix it, re-run.
`/check` has the full triage table. Never narrow the gate to reach green.

Run `guardrail-reviewer` on the diff as well when the slice touched money, auth, tenancy or a domain
boundary.

**`As of` magik `0.0.1`, `magik check` and `magik test` are `planned` and exit `1` with
`MAGIK_COMMAND_NOT_IMPLEMENTED`** — `magik version --json` says which world you are in. While that
is true, `guardrail-reviewer` reading the diff is the entire gate, and a report that does not say so
has overstated itself.

## 5 — Leave the loop where the next run can pick it up

The command maintains its own state so you never have to remember where you were:

- **`docs/PLAN.md`** — move the slice to `## Done` with the date, and promote the next one into
  `## Now`. If building it taught you something, add the row to *"What building this taught us"*.
- **`.env.example`** — any new variable, with a comment saying what reads it. Never a value.
- **`docs/FEATURE.md`**, project block — any convention this run had to discover. If the convention
  is checkable, write it into `scripts/checks/` instead: a rule in a document holds until somebody
  does not read it, and a rule in the gate holds forever (`scripts/README.md`).
- **`llms.txt`**, project block — the inventory, if this slice added a domain, model or screen.

Then `/feature` again.

## Report

```
Slice:      <one sentence>   (from: argument | docs/PLAN.md)
Reused:     <what already existed that you built on, rather than adding beside>
Declared:   <file:line> — <kind :Name>   (one line per unit, in build order)
Tests:      <file:line> — <what each pins>
Gate:       magik check — <green | findings, each triaged> | not implemented (exits 1)
Reviewer:   <guardrail-reviewer findings, or why it was not needed>
Plan:       <moved to Done> / <promoted to Now>
Learned:    <anything added to docs/FEATURE.md, scripts/checks/, or the PLAN retrospective>
Left:       <what is not done, and why>
```
