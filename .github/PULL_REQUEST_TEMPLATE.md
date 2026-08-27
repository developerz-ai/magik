## What changed

<!-- One or two lines. The diff shows how; say why. -->

## Spec section

<!--
Which part of docs/idea/00-build-spec.md this touches — the phase, the subsystem, or the
architecture decision by number. `none` for repository plumbing (CI, tooling, docs about the repo
itself). If this change contradicts the spec, say so here and say why: the spec is the source of
truth, so changing it is a decision, not a side effect.
-->

- Spec section:
- Subsystem (`lib/magik/<name>/`):

## Checklist

- [ ] **`bin/check` is green.** Paste the summary below. `bin/check --list` shows the steps;
      `bin/check --only <step>` runs one.
- [ ] **YARD docs updated** for every public object added or changed, and
      `bin/check --only yard` still meets the coverage floor. A stub still needs a comment saying
      what it will do and that it does not do it yet.
- [ ] **CHANGELOG.md entry** under `## [Unreleased]` — written as the change lands, not at release
      time.
- [ ] **No claim of unimplemented behaviour.** Nothing in this diff — code comment, README line,
      docs page, YARD text, error message — says Magik does something it does not do. Status
      vocabulary is `planned`, `not implemented`, `spec only`. No benchmark numbers, no
      passing-test counts, no present tense about a future feature.
- [ ] **Errors carry a code.** Every new raise is a `Magik::Error` with a stable `MAGIK_*` code, a
      cause, and a runnable `fix:` line. No bare `RuntimeError`.
- [ ] **Tests added** under `test/`, and they would catch a real regression. Minitest, never RSpec.
- [ ] **Stubs raise, they do not pretend.** A not-yet-built path raises `NotImplementedError` with
      a message that says what it will do — never returns a plausible-looking fake.

## `bin/check`

```
$ bin/check
```

<!--
Paste the output. If a step was skipped because a tool is not installed on your machine, say which
and why — `bin/check` distinguishes "not installed" from "broken" on purpose, and CI runs the whole
thing anyway.
-->

## Anything a reviewer should push back on

<!--
Optional, and the most useful box on this form. A decision you were unsure about, a shortcut you
took, a second way to do something that you added and would rather not have.
-->
