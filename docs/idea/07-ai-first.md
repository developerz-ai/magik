# AI-first

Magik is a framework for building SaaS with AI agents doing most of the typing. This page is the argument: what that changes about the design, and what the repo owes each of its two agent audiences.

**Status:** spec only — none of the mechanisms below exists. The agent-facing tooling (`magik check --json`, `magik errors explain`, the generators) is `planned`. Reviewed 2026-08-26.

## The claim

**The primary developer is an AI agent; the secondary is an engineer driving one.** That is axiom 1 of [`01-thesis.md`](01-thesis.md), and it is a constraint, not a marketing line — it decides the grammar, the error format, the size of the surface area and where failures are caught.

The observation underneath it: **agents fail on ambiguity, not on syntax.** An agent will write syntactically perfect Ruby all day. What it cannot do is choose correctly between two equally defensible options with no local signal — it guesses, the guess is plausible, and the guess is discovered in production. Every "you could do A or B here" is a tax the agent pays, and Magik's job is not to levy it.

A framework optimised for an agent turns out to be the calmest one for a human, because both want the same thing: fewer decisions with consequences.

## What "AI-first" means concretely

Six design consequences. Each is a thing an implementer can check, not a sentiment.

### 1. The DSL is designed to be generated, not just written

| Property | Why an agent needs it |
|---|---|
| The grammar is a lookup, not a memory | a DSL's cost to its author is **recall**, and recall is the one cost automation removes — but only where the surface is lookupable. `magik describe` is what makes it one ([`11-dsl-as-tool-surface.md`](11-dsl-as-tool-surface.md)). |
| One block shape for every construct | learning `model` teaches `job`, `ledger` and `api`. The grammar has one lesson, not twenty ([`02-dsl-surface.md`](02-dsl-surface.md)). |
| Keyword arguments only | no positional booleans to get backwards, no argument order to remember. |
| Declarations are order-independent | a generated file can be appended to without reasoning about what came before. |
| Names are derivable | `screen :Orders` → `/orders`, `action :refund_order` → its POST endpoint. There is no route file to keep in sync, so there is nothing to keep in sync incorrectly. |
| No template language | no second syntax, no escaping rules, no HTML for an agent to malform. The UI is Ruby. |

### 2. One obvious answer per decision

Every place the framework could offer a choice, it ships a default instead. The escape hatches exist — but they are **operator** configuration in `App.define`, resolved at boot, not a decision at every call site ([`04-swap-points.md`](04-swap-points.md)). An agent writing a feature never picks a cache backend, a job backend or a serialization format; it writes `cache.fetch` and moves on.

### 3. The guardrail list is the specification an agent is checked against

[`03-guardrails.md`](03-guardrails.md) is not documentation of an implementation detail — it is the machine-checkable half of "did the agent build this correctly". An agent that produces an unbalanced ledger, an unscoped query, a stateful screen or a raw card-number column finds out **at boot**, with the rule named and the file and line pointed at.

This is the difference the whole design rests on: a human reviewer catches those mistakes sometimes, and a boot check catches them every time, in a loop the agent can run itself.

### 4. `magik check` is the feedback loop

An agent needs a fast, unattended, machine-readable answer to "is this right yet".

| Command | Answers | Status |
|---|---|---|
| `magik describe <construct>[.<declaration>] --json` | what the grammar allows: every option, its type, its default, its allowed set and the codes it can raise ([`11-dsl-as-tool-surface.md`](11-dsl-as-tool-surface.md)) | planned |
| `magik check` | do the guardrails pass, with no server and no ceremony | planned |
| `magik check --json` | the same, as structured findings with code, location, cause and fix | planned |
| `magik check --scale` | which query sites will hurt when this app shards | planned |
| `magik errors explain <CODE> --json` | what a code means and what to do about it, without reading source | planned |
| `magik test --changed` | only the tests the current diff can affect ([`../architecture/04-testing-strategy.md`](../architecture/04-testing-strategy.md)) | planned |

The rule that makes them usable: **every error carries a runnable `fix:` line.** Advice is something an agent has to interpret; a command is something it can run ([`../architecture/03-error-codes.md`](../architecture/03-error-codes.md)). The diagnostic surface around this — structured logs, the request trace, the dev inspection commands — is [`../architecture/06-observability.md`](../architecture/06-observability.md).

### 5. The surface is small enough to fit in a context window

An agent's working memory is finite, and a framework whose API does not fit inside it is a framework the agent reasons about from half-remembered training data.

| Budget decision | Effect |
|---|---|
| ~30 constructs, one grammar | the whole DSL is a page ([`02-dsl-surface.md`](02-dsl-surface.md)) |
| No SPA, no template language, no build config | three toolchains that are not in the context window because they are not in the framework ([`05-limits.md`](05-limits.md)) |
| One gem, subsystems under `lib/magik/<subsystem>/` | one dependency, one namespace, one place a symbol can live |
| Declarations over configuration | an app's behaviour is readable from its declarations; there is no `config/` archaeology to reconstruct |

The intended test of this: a whole small app — models, screens, actions, jobs — read in one pass, with room left to think.

### 6. The docs are the context

The repo is structured so that a machine-readable map plus the spec is enough to start work, with no tribal knowledge in between.

| Artifact | Role |
|---|---|
| `llms.txt` (repo root) | the machine-readable repo map — the first thing an agent reads |
| [`00-build-spec.md`](00-build-spec.md) | the source of truth for what to build |
| [`02-dsl-surface.md`](02-dsl-surface.md) | the shape of every construct, for an agent implementing one or calling one |
| [`03-guardrails.md`](03-guardrails.md) | the rules the result is checked against |
| [`../architecture/05-adding-a-feature.md`](../architecture/05-adding-a-feature.md) | the loop, with the exact commands |
| `.claude/agents/*`, `.claude/commands/*` | the loop, pre-packaged as agent definitions and slash commands |
| `wiki/` | the reference manual for app authors |

### 7. The agent decides, not only types

The six points above are about an agent *writing* Magik. This one is about an agent *deciding* it,
and it is the version this project actually runs on: design questions that arrive mid-task are
answered and recorded rather than queued for a human to arbitrate.

It is the same argument this page already makes about boilerplate, applied one level up. A framework
generates hundreds of decisions and most have one defensible answer reachable from the constraints
already written down; routing each through a person converts them into a bottleneck for work they
would rubber-stamp. **Direction is the scarce input. Adjudication is not.**

The claim is narrow, and every clause is load-bearing: *on a decision space that is already framed,
with a gate that runs in a minute and nothing shipped to break, an agent deciding and recording beats
a person adjudicating a queue.* Remove the frame and it is invention; remove the gate and it is
guesswork; remove "nothing shipped" and it is someone else's outage. That is why the model is stated
with its boundary rather than as a principle — what stays with the owner, what a decision owes, and
the log of decisions taken this way are in [`13-decisions.md`](13-decisions.md).

Note that this does not contradict [the honest limits below](#honest-limits-of-the-claim), and must
not be read as trust in the agent's judgement: **the entire guardrail design assumes the agent errs**
([`03-guardrails.md`](03-guardrails.md)). What makes delegation work is not that the decisions are
right, it is that a wrong one is cheap to find and cheap to reverse.

## Two audiences

Both are agents. They need different things from this repo, and conflating them is how a doc ends up useful to neither.

| | **Agent A — implementing Magik** | **Agent B — building an app with Magik** |
|---|---|---|
| Works in | this repo, `lib/magik/<subsystem>/` | a generated app |
| Source of truth | [`00-build-spec.md`](00-build-spec.md) | `wiki/` + [`02-dsl-surface.md`](02-dsl-surface.md) |
| Needs | the tier rules, the conventions, the failing test first, YARD on every public method | the DSL grammar, the guardrail catalogue, the generators |
| Its loop | [`../architecture/05-adding-a-feature.md`](../architecture/05-adding-a-feature.md) → `bin/check` | `magik generate …` → `magik check` → `magik test` |
| Its gate | `bin/check` green | `magik check` + `magik test` green |
| Its failure mode | inventing framework behaviour the spec does not describe | inventing DSL that does not exist |
| Guarded by | "no framework code that is not spec-backed" ([`../architecture/00-conventions.md`](../architecture/00-conventions.md)) | boot guardrails and a boot that refuses unknown constructs |

Both failure modes are the same defect — a plausible invention — and both are answered the same way: a narrow, written surface, and a check that runs without a human.

Agent B does not assemble its own harness: the framework generates it. `magik new` emits that app's `CLAUDE.md`, `AGENTS.md`, `llms.txt`, `.claude/` and `docs/` as stage 1 of a three-stage scaffold — [`09-app-scaffold.md`](09-app-scaffold.md) is this page's argument applied one level out, to the app rather than the framework. Planned: the templates exist, `magik new` does not.

## Honest limits of the claim

| Limit | Detail |
|---|---|
| None of this is proven | there is no framework, no `magik check`, and no agent has built anything with it. This page is a design intent, `As of 2026-08-26`. |
| An agent can still write bad Ruby | guardrails cover the framework's invariants — money, tenancy, boundaries, statelessness. They do not cover whether a feature is the right feature. |
| Small surface is a budget, not a law | every construct added spends it. That is the cost side of any proposal to extend the grammar. |
| Ruby has no compile step to lean on | which is exactly why the boot check has to do this much work ([`01-thesis.md`](01-thesis.md) — the Magik/Ultimate trade). |
