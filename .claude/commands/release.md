---
description: Walk the guarded release checklist — verify, stage and hand back. Never publishes.
argument-hint: <version, e.g. 0.1.0>
allowed-tools: Read, Bash, Glob, Grep
---

# /release

## Version
$ARGUMENTS

**You never publish.** No `gem push`, no `gem signin`, no `git push --tags`, no `bin/release`. Those
are denied in [`.claude/settings.json`](../settings.json) on purpose. You verify, you stage, you
report — the owner runs the publishing step from
[`PUBLISHING.md`](../../PUBLISHING.md), which is the authority. If this file and `PUBLISHING.md`
disagree, `PUBLISHING.md` wins and you say so.

## Before anything else

`magik 0.0.1` is a **name reservation**. A release only happens when a version's phase is genuinely
done — every exit criterion in [`ROADMAP.md`](../../ROADMAP.md) true and proven by a test. **A
version bump is a claim.** Refuse to stage one the tests do not support.

## Checklist — report each line ✓ or ✗ with evidence

1. `git status --short` clean · on `main` · `git log --oneline -10` reviewed.
2. `bin/check` green — tests, RuboCop, YARD.
3. Run `/spec-audit`. **Zero overstatements**, or stop. Shipping a doc that lies is worse than
   shipping late.
4. The phase's `ROADMAP.md` exit criteria: each one true, each naming the test that proves it.
5. Every swap point the version claims is proven against **both** backends — proven, not promised.
6. `lib/magik/version.rb` matches `$ARGUMENTS`; `CHANGELOG.md` has a dated entry for it that
   describes what landed, not what is planned.
7. `gem build magik.gemspec` succeeds; inspect the file list for anything that should not ship.
   Gem author is `developerz.ai` / `admin@developerz.ai`; the repo is
   `https://github.com/developerz-ai/magik` (public). A gemspec that disagrees is a blocker.
8. `Magik::SPEC_ONLY_SUBSYSTEMS` matches reality — nothing implemented is still listed, nothing
   listed is silently working.
8. While the major version is `0`, a minor bump may break the DSL — say plainly what breaks.

## Hand back

```
Version:  <x.y.z>   Gate: bin/check ✓/✗   Spec audit: <n> overstatements
Exit:     <criterion> ✓/✗ — <test>
Blocking: <what stops the release, or none>
Next:     the owner runs the publish step in PUBLISHING.md / bin/release — not you
```
