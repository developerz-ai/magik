---
description: Add one DSL construct end to end — design, docs, dummy example, failing test, implementation, YARD, bin/check, CHANGELOG
argument-hint: <construct, e.g. screen | ledger | channel>
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent, Task
---

# /new-dsl

## Construct
$ARGUMENTS

**It must be in the spec.** [`docs/idea/00-build-spec.md`](../../docs/idea/00-build-spec.md) names
every construct Magik will have. If yours is not there, stop — the answer is a spec change discussed
with the owner, not a new keyword.

## The loop, in order — none of it is optional

1. **Shape** (`dsl-designer`) — the canonical Ruby into
   [`docs/idea/02-dsl-surface.md`](../../docs/idea/02-dsl-surface.md), with every option and its
   default. The grammar must read like `model`, `action` and `job` already do; one way to do each
   thing.
2. **Failure design** — what an invalid declaration raises: a stable `MAGIK_*` code, a cause naming
   the real constant, a runnable `fix:`. Boot-time rules go to
   [`docs/idea/03-guardrails.md`](../../docs/idea/03-guardrails.md) (`guardrail-author` builds
   them). Any new default names its swap in
   [`docs/idea/04-swap-points.md`](../../docs/idea/04-swap-points.md).
3. **Docs** — the construct's [`wiki/`](../../wiki/) page, marked `planned` until step 6.
4. **Worked example** — the same code in `dummy/`, at the path
   [`wiki/Project-Layout.md`](../../wiki/Project-Layout.md) prescribes. Wiki example and `dummy/`
   file are the same code, or one of them is imaginary.
5. **Failing test** (`test-writer`) — `test/magik/<subsystem>/`. Watch it fail for the right reason.
6. **Implement** (`spec-implementer`) — smallest thing that passes, in `lib/magik/<subsystem>/`.
   Sequel, no ActiveSupport, SRP: one object one job, registered — never another branch in a `case`.
7. **YARD** on every public method: summary, `@param`, `@return`, `@raise`. `rake yard` must not
   warn.
8. **`bin/check`** green.
9. **`CHANGELOG.md`**, and flip the wiki page from `planned` to real — **only now**, because only now
   does a test prove it.

## Refuse

Client-side state · an offline path · a float in a money path · an ActiveRecord idiom · an RSpec
matcher · a second way to do something the DSL already expresses. See
[`docs/idea/05-limits.md`](../../docs/idea/05-limits.md).

## Output

The shape in one fenced block · the `MAGIK_*` codes reserved · the test file and its command ·
`bin/check` result · the files touched at each of the nine steps, with any step you skipped and why.
