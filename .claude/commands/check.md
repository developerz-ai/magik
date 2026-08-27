---
description: Run bin/check and triage every failing step to a file and a fix
allowed-tools: Bash, Read, Edit, Grep, Glob
---

# /check

`bin/check` is **the** gate: it runs `rake test`, `rake rubocop` and `rake yard`. Green means
shippable; nothing else does.

Rake tasks it composes: `test` · `rubocop` · `yard` · `docs:coverage` · `build`. `rake check` runs
the same set. `rake test` works on bare Ruby with no bundler installed.

**RuboCop and YARD are not installed on every machine.** A missing tool is a **skip**, reported as
`skipped — <tool> not installed`. Never report it as a failure, and never claim a lint you did not
run. Install them with `bundle install`, or say plainly that the gate ran partially.

1. Run `bin/check`.
2. On failure, re-run the failing step alone to see its real output:
   `rake test` · `rake rubocop` · `rake yard`.
3. Fix one, re-run **only** that step, then `bin/check` again at the end.

Report one line per step: `✓ <step>` or `✗ <step> — <file:line> — <what and the fix>`.

## Triage

| Failure | Fix |
|---|---|
| Test failure | Read the assertion **before** touching anything. Never edit a test to match new behaviour unless that behaviour is what was asked for. A test failing against a stub that raises `NotImplementedError` is the honest state — the fix is the feature |
| RuboCop offence | Fix the code. `rubocop -a` for the mechanical ones. **Never** a `# rubocop:disable`, never a new `.rubocop.yml` exclusion to get to green |
| YARD warning | Document the method — summary, `@param`, `@return`, `@raise`. Warnings are failures here |
| `docs:coverage` below bar | Same fix: document the undocumented public method it names |
| A `MAGIK_*` code raised at you | Run its `fix:` line before improvising. If the `fix:` is not runnable, that is a bug in the error — say so |
| The gate itself is wrong | Fix `bin/check` and [`.github/workflows/`](../../.github/workflows/) **together**; local and CI disagreeing is the parity bug |

Never narrow the gate, skip a step or loosen a rule to pass. If you cannot make it green, say which
step and why, and stop.
