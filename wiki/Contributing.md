# Contributing

**Status:** the contribution process is real. The framework it contributes to is not.
`As of 2026-08-26`.

**The guide lives at [`CONTRIBUTING.md`](../CONTRIBUTING.md) in the repository root.** Read it there
— this page is a pointer, not a second copy, because two copies of a process is one copy that goes
stale.

## The short version

```bash
git clone https://github.com/developerz-ai/magik
cd magik
bundle install
bin/check        # the gate: lint, tests, doc checks
```

If `bin/check` is green, open the pull request.

## What is most useful right now

Nothing is implemented, so almost everything is available. The highest-value work is at the front of
[`ROADMAP.md`](../ROADMAP.md) — build steps 1 and 2 unblock everything after them, and build step 5
(the test harness) is what makes the rest test-driven.

Before starting, read:

| Read | For |
|---|---|
| [`docs/idea/00-build-spec.md`](../docs/idea/00-build-spec.md) | the specification. It is the source of truth and nothing contradicts it |
| [`ROADMAP.md`](../ROADMAP.md) | what order, and what "done" means per phase |
| [`docs/architecture/00-conventions.md`](../docs/architecture/00-conventions.md) | the coding contract |
| [`docs/architecture/01-module-map.md`](../docs/architecture/01-module-map.md) | which subsystem owns what |
| [`docs/architecture/02-boundaries.md`](../docs/architecture/02-boundaries.md) | what may depend on what |
| [`docs/architecture/05-adding-a-feature.md`](../docs/architecture/05-adding-a-feature.md) | the end-to-end loop, with the command per step |
| [`docs/architecture/04-testing-strategy.md`](../docs/architecture/04-testing-strategy.md) | how the test harness is meant to work |
| [Project layout](Project-Layout.md) | where a new file goes |

## Working with an agent

Magik is an AI-first repo and the workbench is committed to the tree:
[`.claude/README.md`](../.claude/README.md) has the subagents and slash commands, including
`/implement-phase`. [`docs/idea/07-ai-first.md`](../docs/idea/07-ai-first.md) explains why the repo
is arranged for that.

## Three house rules worth repeating here

They come from the root guide and they are the ones most easily forgotten:

1. **Never claim something works that does not.** Status vocabulary is `planned`, `not implemented`,
   `spec only`. No benchmark number, no passing-test count, no "it does X" for behaviour that does
   not exist.
2. **Every factual claim pairs with the command that re-derives it.** Prefer "run `x`" to a number
   that goes stale on the next commit.
3. **Every error carries a code, a cause and a runnable `fix:`.** A `fix:` reading "check your
   configuration" fails review. See [Error codes](Error-Codes.md).

## Documentation

This wiki is part of the deliverable, not an afterthought. If you implement a phase, the page that
documents it stops saying `Planned — not implemented` in the same pull request — and
[Known gaps](Known-Gaps.md) gets shorter in that pull request too.

A feature that ships without its documentation change is a feature that ships with a lie attached.

## Security

Vulnerabilities go to [`SECURITY.md`](../SECURITY.md), not to the issue tracker.
