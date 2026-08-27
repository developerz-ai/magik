---
description: Run this app's gate — magik check then magik test — and triage every finding to a file, a rule and a fix.
argument-hint: [--scale | --domains | --components, or blank for everything]
allowed-tools: Read, Edit, Glob, Grep, Bash, Agent
---

# /check

The gate is **`bin/check`**. It runs, cheapest first: lint, the test suite, `magik check`,
`magik test`, and **every rule in `scripts/checks/`** — this team's own conventions, as executable
checks. A guardrail failure explains a test failure; a test failure never explains a guardrail
failure, which is why the order is the order.

```bash
bin/check                 # everything
bin/check --list          # what the steps are
bin/check --only test     # one step, repeatable
bin/check --json          # the summary as data
```

Exit status is the contract: `0` green · `1` this app is wrong · `64` bad usage · `69` a step could
not run. **`69` is not a pass.**

**Magik is spec only:** both commands exit `1` today with `MAGIK_COMMAND_NOT_IMPLEMENTED`. That is
not a red gate — it is an unbuilt one. Report it as `not implemented`, never as `passing`, and fall
back to `guardrail-reviewer` reading the diff. `magik version --json` tells you which you are in.

## Run

```bash
magik check --json        # every boot guardrail, as findings with code, cause, fix and location
magik check --scale       # queries with no tenant_id predicate — sharding pain, pre-empted
magik check --domains     # boundary violations, dependency cycles, unpublished events
magik check --components  # every component override and what it shadows
magik test                # then, and only then
```

$ARGUMENTS narrows it. Blank runs everything. `bin/check --only <name>` narrows the gate itself.

## Triage

Every finding carries a **runnable `fix:`**. Run it before improvising. A `fix:` that is not
runnable is a defect in the error — report that too, with the code.

| Finding | What it means and who owns it |
|---|---|
| `MAGIK_LEDGER_UNBALANCED` | debits ≠ credits in a declared entry. `ledger-author`. Never "fix" it by adjusting an amount until it balances — find which leg is wrong |
| `MAGIK_TENANT_SCOPE_MISSING` | a query with no `tenant_id`. `data-modeler` — the fix is a scope on the model, not a `where` at the call site |
| `MAGIK_SCREEN_DIRECT_QUERY` | a screen built its own dataset. `screen-builder` + `data-modeler`: the screen names a `state`, the model owns the scope |
| `MAGIK_MUTATION_OUTSIDE_ACTION` | something writes outside `app/actions/`. `action-author`. Move the write; do not add an exception |
| `MAGIK_ASYNC_OUTSIDE_JOB` | a fiber or thread outside `app/jobs/`. Untracked and unretryable |
| `MAGIK_MONEY_OUTSIDE_LEDGER` | a `:money` field written outside a ledger entry. `ledger-author` |
| `MAGIK_DECLARATION_MISPLACED` / `MAGIK_FILE_MULTIPLE_DECLARATIONS` | the layout rule. One declaration per file, in its kind's directory |
| `MAGIK_COMPONENT_CONTRACT_VIOLATION` | a rung-3 override is missing a slot, prop, target or event the kit composes. `screen-builder` |
| `MAGIK_DOMAIN_BOUNDARY_VIOLATION` | a domain reached into another's models. Add `exposes`, or subscribe to the event — do not widen the dependency without saying why |
| a test failure | read the assertion **before** touching anything. Never edit a test to match new behaviour unless that behaviour is what was asked for |
| `MAGIK_SETUP_INCOMPLETE` | no bundle or no database. `bin/setup` |
| a code you do not recognise | `magik errors explain <CODE> --json` · `magik docs Error-Codes` |

| a `scripts/checks/` finding (`APP_*`) | one of **this team's own rules**. Read the check — it is a short file and it says what it wants. Fix the code, not the check |

**Never narrow the gate to get to green** — no skipped guardrail, no deleted assertion, no scope
widened to silence a boundary error, and never a check deleted to stop it firing.

**If the finding is a rule this app should have had, add it.** `scripts/checks/` is where a
convention becomes enforceable; `scripts/README.md` shows the shape. A rule you only write in a
document is a rule that holds until the next agent does not read it.

## Report

One line per step, and nothing softer than the truth:

```
✓ magik check          <n> guardrails, clean
✗ magik check --scale  <file:line> — MAGIK_TENANT_SCOPE_MISSING — <the fix, run or not>
– magik test           not implemented (exits 1 with MAGIK_COMMAND_NOT_IMPLEMENTED)
```

If you could not make it green, say which finding and why, and stop.
