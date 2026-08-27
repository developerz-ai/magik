---
description: Write a concise, self-contained execution plan to .claude/plans/<YYYY>/<MM>/<DD>/<1NN>-<slug>/ for another agent to implement
argument-hint: <what you want planned>
allowed-tools: Read, Write, Glob, Grep, Bash, Agent, Task
---

# /planx

Produce a plan another agent can execute with **zero extra context**. Plan only — no implementation,
no edits outside the plan directory.

## Goal
$ARGUMENTS

## 1. Trace it to the spec, or stop

Every plan names the section of [`docs/idea/00-build-spec.md`](../../docs/idea/00-build-spec.md) it
serves. No section means no plan — propose a spec amendment instead
([`CONTRIBUTING.md`](../../CONTRIBUTING.md)). Say which of spec-phase or delivery-order numbering you
mean; they differ, and spec Phase 9 ships third ([`ROADMAP.md`](../../ROADMAP.md)).

## 2. Resolve the path

`date +%Y`, `date +%m`, `date +%d` → `.claude/plans/<YYYY>/<MM>/<DD>/`. Glob `1*` in it; next number
is the highest `1NN-*` plus one, else `101`. Slug is kebab-case, five words at most.

**Not `docs/`.** `Magik::Docs::PACKAGED_GLOBS` packages `docs/**/*.md` into the gem and `magik docs`
serves it, so a plan written there ships to every app builder and lands in the catalogue.

## 3. Explore before you write

`Agent` (`Explore`, very thorough) over the affected subsystems: the files to touch with `file:line`,
the patterns to mirror, the tests, the `MAGIK_*` codes already taken, the guardrails the spec names
for this surface. `spec-auditor` when the claim surface is wide — **distrust the paperwork**, check
every status claim against the code and `git log` before planning off it, and say which you
falsified. Skip exploration only for a genuinely trivial ask.

## 4. Write it as multiple files — never one `plan.md`

Always an `overview.md` index plus one `<NN>-<aspect>.md` per separable area, split so each is
independently executable and short. Slice by **subsystem module** — `core cli model schema render
action router policy realtime jobs ledger api auth billing admin i18n pwa notify testing domains
check` — because that is also the file lock an executing hive will use. House style: terse fragments,
`file:line` refs, tables.

`overview.md`: **Goal** (what + why, two sentences) · **Spec section** (the traceability line) ·
**Context** (only the stack facts this plan needs — TruffleRuby, real parallel threads, Rack+Puma,
Sequel, Minitest, htmx, `tenant_id`, UUIDv7, integer cents — plus reference patterns as
`lib/magik/<x>.rb:12 — follow this for Z`) · **Plan files** (ordered, one line each) · **Done when**
(verifiable criteria spanning the whole change) · **Risks / open questions**.

Each `<NN>-<aspect>.md`: a `> Part of overview.md. Depends on: <NN or none>.` line · **Files to
change** (`path:line` — what, why) · **Steps** (ordered, concrete, referencing `Class#method`, not
restating code) · **Guardrail** (the boot-time refusal the spec names for this, its `MAGIK_*` code
and its runnable `fix:` — or "none required, because …") · **Tests** (Minitest in `test/`, failing
first; `rake test TEST=test/magik/<x>_test.rb`) · **Docs** (YARD on every public method; the wiki or
`docs/architecture/` page; the `CHANGELOG.md` entry) · **Done when**.

## 5. Write `status.yml` beside `overview.md`

The one tracker in the directory; the `.md` slices stay reference maps with no checkboxes. Valid
YAML, these enums, `created_by`/`owner` from `git config user.name`, `worked_by` empty until an
executor claims it:

```yaml
plan: <1NN>-<slug>
title: <from overview.md>
spec_section: <the 00-build-spec.md section this serves>
status: not_started      # not_started | in_progress | blocked | complete | superseded
created_by: <git user.name>
worked_by: ""
owner: <git user.name>
percent: 0
current_focus: ""
slices:
  - file: 01-<aspect>.md
    status: not_started  # not_started | in_progress | complete
    percent: 0
evidence: []             # commits/PRs, e.g. ["#12", "abc1234"]
notes: ""
last_updated: <YYYY-MM-DD>
```

## Rules

Compact English, fragments over sentences, `file:line` and `Class#method` over prose, tables for
structured data. Reference code, never paste it. No checkboxes outside `status.yml`. Self-contained:
the executor reads `overview.md`, its slice, and the files those cite — nothing else.

The plan inherits every house non-negotiable and must not plan around one: **Sequel never
ActiveRecord · Minitest in `test/`, never RSpec or `spec/` · no ActiveSupport · SOLID, SRP hardest —
new behaviour is a new registered object, never another branch in a `case` · integer-cents money ·
UUIDv7 and `tenant_id` on every model · htmx, never an SPA or a build step · `policy` at tier 1, one
evaluator, no second door · one gem, no second gemspec · the guardrail ships in the same change as
the feature · every `MAGIK_*` carries a cause and a `fix:` that is a command · no new dependency
without an argument · nothing described in the present tense that is not implemented and tested.**

## Output

```
plan: .claude/plans/<YYYY>/<MM>/<DD>/<1NN>-<slug>/
      overview.md + 01-<aspect>.md, 02-<aspect>.md, … + status.yml
spec:  <section of 00-build-spec.md>
falsified: <doc claims that were wrong, or none>
next:  run an executor on overview.md
```
