---
description: Drive dummy/ — the invoicing/billing example SaaS — toward being runnable as phases land, and report exactly how far it gets
argument-hint: [construct or phase to exercise, or blank to assess]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# /dummy-app

## Focus
$ARGUMENTS — blank means assess where it stands.

`dummy/` is the proving ground: an invoicing/billing SaaS that exercises every DSL construct once,
idiomatically. **A framework change that does not show up in `dummy/` is unverified.** There is no
production to test against — this is it.

## Rules

- **It is the layout, not just the code.** Every file goes where
  [`wiki/Project-Layout.md`](../../wiki/Project-Layout.md) prescribes. The prescribed tree and its
  separation of concerns are part of the product; never invent a path here.
- **One idiomatic use of each construct**, not an exhaustive matrix. It is a teaching surface.
- It carries the house rules where a reader will copy them: Sequel, integer-cents money, `tenant_id`
  scoping, UUIDv7, Minitest, SOLID/SRP — one object one job.
- **No HTML, CSS or JavaScript written by hand.** The under-30-lines CRUD claim is measured here.
- Copy examples from the wiki rather than paraphrasing them: the wiki page and the `dummy/` file
  must be the same code.

## What to do

1. Establish how far it gets **today** — most of it cannot run yet, and that is the honest state:
   `cd dummy && ruby -Ilib -e 'require "magik"'`, then the phase's entry point.
   `ruby -Ilib -e 'require "magik"; p Magik::SPEC_ONLY_SUBSYSTEMS'` tells you which subsystems are
   still stubs before you waste a run finding out.
2. Add or update the file for the construct in focus. Mark anything still unrunnable with a comment
   naming the phase that unblocks it.
3. Report the exact boundary: the first line that raises `NotImplementedError`, and which subsystem
   owns it.

## Output

```
Runs:       <what actually executes today, with the command>
Stops at:   <file:line> — <the MAGIK_* code or NotImplementedError> — <subsystem>
Covers:     <constructs demonstrated>   Missing: <constructs with no dummy usage>
CRUD lines: <count for the model+screen+action example, or "not yet possible">
```
