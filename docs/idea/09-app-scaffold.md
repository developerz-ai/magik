# The app scaffold

`magik new myapp` has to produce an application that is **agent-ready on the first commit**. The AI
harness — `CLAUDE.md`, `AGENTS.md`, `llms.txt`, `.claude/agents/`, `.claude/commands/`, `docs/` — is
part of what the framework generates, not something the user assembles afterwards.

**Status:** the templates in [`lib/magik/cli/templates/app/`](../../lib/magik/cli/templates/app/README.md)
are real files. `magik new` is **planned and not implemented**, so nothing here has ever been
rendered by the CLI, and a generated app could not run if it were. Reviewed 2026-08-26.

This page is one level out from [`07-ai-first.md`](07-ai-first.md), which argues why *the framework*
is shaped for an agent. This one argues why *the app the framework generates* is too.

## Why the framework writes the app's contract

An app's `CLAUDE.md` cannot be written well by the app's author on day one. On day one the author
knows the product and knows nothing about Magik: not that a screen may not query, not that money is
integer cents at the type level, not that `app/actions/void_invoice.rb` is the only legal home for
`action :void_invoice`, not which `MAGIK_*` code fires when they get one of those wrong. The
framework knows all of it, and knows it *for the version installed*.

So the alternatives to generating it are a blank file, or a file copied from a blog post about a
different version. Both produce the same failure: an agent working from Rails-shaped assumptions in
a framework that is not Rails, discovering the difference at review time or not at all.

Generating it means every Magik app starts from a correct, current contract. The cost is that a
generated file rots — which is [the ownership question below](#ownership-and-regeneration), and it
is the hard part of this design, not an afterthought.

## Three stages

Creating a working Magik app is three distinct acts, and keeping them distinct is the organising
idea of the whole scaffold. They differ in every property that matters.

| | **Stage 1 — static boilerplate** | **Stage 2 — AI boilerplate** | **Stage 3 — real work** |
|---|---|---|---|
| Entry point | `magik new myapp` | `/setup-project` | `/feature`, `/screen`, `/check`, `/next` |
| Run by | the CLI | an agent, interviewing the user | an agent, feature by feature |
| Nature | **deterministic** — same inputs, same bytes | **generative** — a conversation | generative |
| Needs a model? | no. Offline, no network, no LLM | yes | yes |
| Frequency | once | once, then re-runnable as the product changes | continuously |
| Produces | a *generic but complete* app harness | *this project's* architecture, plan and conventions | declarations, tests, screens |
| Owned by | the framework | the project | the project |
| Verified by | **unit tests** — [`test/magik/app_templates_test.rb`](../../test/magik/app_templates_test.rb) | review, by the person interviewed | `magik check` + `magik test` |

That last row is the reason the split earns its keep. Stage 1 is a pure function, so it can be
tested exhaustively and cheaply: the manifest matches the directory, every template parses and
renders, the JSON is valid, no secret ships, no file claims a capability the framework lacks. Stage
2 cannot be tested that way, because its correctness is "does this describe the user's product",
which only the user can answer. **Putting them in one step would make the testable half untestable.**

### Stage 1 — static boilerplate

`magik new myapp` copies [`lib/magik/cli/templates/app/`](../../lib/magik/cli/templates/app/README.md)
and interpolates a documented variable set with ERB from the standard library. No prompts, no
network, no model. Every choice is a flag with a default, so `--dry-run` and the real run cannot
disagree.

It emits three things — the AI harness, the starter docs and **the project tooling** — and all of
them generically but completely, so the tree stands on its own if the user never runs stage 2:

| Emitted | Is |
|---|---|
| `CLAUDE.md` | the working contract. Layout, non-negotiables, commands, the loop, where to read |
| `AGENTS.md` | a relative symlink to `CLAUDE.md`. One file, two names, no drift |
| `llms.txt` | the app's link map: local docs first, the framework's web pages as fallback |
| `.claude/settings.json` | an allowlist for the safe, high-frequency commands; a denylist for the destructive ones and everything touching `.env` or `config/master.key` |
| `.claude/agents/*.md` | six agents, scoped by **file set** |
| `.claude/commands/*.md` | five commands, one per workflow |
| `docs/{README,ARCHITECTURE,FEATURE,PLAN}.md` | the starter doc set — a map, and three frames stage 2 fills |
| `.env.example` | every variable the app reads, with a name and a blank. Never a value |
| `README.md` | the human entry point, carrying both banners below |
| `Gemfile`, `Rakefile`, `.rubocop.yml`, `.editorconfig`, `.gitignore`, `.gitattributes`, `lefthook.yml`, `.github/workflows/ci.yml`, `docker/compose.yml` | the tooling. **A Magik user never configures a linter, a formatter, a task runner, a git hook or a CI workflow** |
| `bin/setup`, `bin/check`, `bin/dev`, `bin/console`, `bin/test`, `bin/magik` | the verbs |
| `scripts/lib/`, `scripts/checks/` | the team's own rules, as executable checks |

The line between "generate it now" and "defer to Phase 1" is **not** app-code versus framework-code.
It is whether the file can be written *correctly today*. Tooling is static configuration and can;
`config/app.rb`, `app/**`, `db/**`, `locales/**` and `public/**` must be generated against a
`model`/`screen`/`action` DSL that does not exist, and a code template written before its DSL is a
template that ships wrong. Those are exactly the rows in the *"what a generated app has that this
does not"* table in [`dummy/README.md`](../../dummy/README.md).

### The tooling half genuinely works

This is worth stating precisely, because "nothing works yet" is the easy sentence and it is false.
The framework is unimplemented; the tooling is not.

| Works on a generated app today | Planned |
|---|---|
| `bundle install`, `bin/setup` — gems, `.env`, git hooks | `magik server`, `magik console`, `bin/dev` |
| `rake test`, `bundle exec rubocop` | `magik test`, `magik check`, `magik db …` |
| `bin/check` — lint, suite, and every rule in `scripts/checks/` | `magik generate …` |
| `scripts/checks/*.rb` — plain Ruby over plain files | booting, migrating, rendering, serving |
| `magik docs path` — the DSL reference, versioned with the gem | everything else `magik help` marks `planned` |

`bin/check` reports the magik steps `MISSING` and exits **`69`** (`EX_UNAVAILABLE`), never `1`.
"Not built yet" and "your app is wrong" must never look the same to a script, and a fresh app whose
gate is red teaches its owner to ignore the gate.

### `bin/` and `scripts/`: the verbs, and the team's rules

The generated app carries both directories, mirroring the framework repository, because the agent
working in a user's project deserves the affordances the agent working on Magik has.

| | Holds | Owner | On update |
|---|---|---|---|
| `bin/` | the **verbs**: `setup`, `check`, `dev`, `console`, `test`, `magik`. Stable, few | the framework | `replace` |
| `scripts/lib/scripts.rb` | `Check`, `Result`, `Finding`, `Registry`, `Runner` — the framework repo's contract in one file | the framework | `replace` |
| `scripts/checks/*.rb` | **the team's own rules**, discovered by `bin/check`'s glob | the team | `never` |

The second directory is the valuable one, and the argument is the same one this whole framework
rests on, moved one level out:

> **When the developer is an agent, a convention that is not executable does not exist.**

A rule written in `CLAUDE.md` — *always scope reports by `tenant_id`*, *never call the billing API
outside a job* — is advice. An agent follows it on feature #3, while the sentence is near the top of
the context, and quietly does not on feature #40. Nothing catches the difference. The same rule as a
file in `scripts/checks/` is a gate failure with a runnable `fix:`, and it holds for as long as the
app does.

Magik already makes that argument for *its* invariants: money, tenancy, statelessness and domain
boundaries are refused at boot rather than in review ([`03-guardrails.md`](03-guardrails.md)). This
hands the user the same mechanism for the rules the framework has no opinion about, because they are
about their business. It is how a team's standards survive an agent writing most of the code.

The loop it creates — **notice a convention → write the check → it is enforced from then on** — is
wired into `docs/FEATURE.md`, `/feature` and `/check`, so it is part of the everyday path rather
than a facility somebody has to remember exists.

Three checks ship as working examples, each a different shape: `domain_boundaries` (a rule over a
declared graph), `i18n_coverage` (a rule joining code and locale files) and `migration_safety` (a
rule that accepts an explicit acknowledgement rather than forbidding). Each splits a pure
`self.findings_for` from the collector that reads the tree, because **a rule that can only be tested
by breaking the app has no negative case**.

One deliberate departure from the framework repo's check library: an app check may report
`not_applicable`, a pass that says why. There, an empty corpus is always a failure — `lib/magik/**`
matching nothing means a directory moved and the check went quiet. Here, a flat app with no
`domains/` and a new app with no migrations are ordinary. The distinction is *absence by design*
versus *a glob that should have matched*; the second is still a failure.

### Judgement calls

| Question | Answer, and why |
|---|---|
| Copy the RuboCop rules into every app, or inherit them? | **`inherit_gem`.** The rules live in the gem; the app's `.rubocop.yml` is a dozen lines that inherit them and hold project overrides. Style improves with `gem update magik`, no app is pinned to the style of the magik that generated it, and **there is nothing to regenerate.** For the one file users most legitimately edit, that is strictly better than any regeneration scheme — the right answer to rot is sometimes to move the thing that rots out of the app entirely |
| Are `bin/*` generated scripts or shims? | **Shims wherever there is no logic.** `bin/dev`, `bin/console`, `bin/test`, `bin/magik` delegate to the installed gem, so fixes arrive with `gem update` instead of being frozen into every app ever generated. `bin/setup` and `bin/check` are real scripts, because they compose *other* commands and must work before and independently of a functioning framework |
| Is `bin/check` therefore frozen? | **No — it is `replace`, and it is extended by data rather than by edits.** You add a rule by adding a file to `scripts/checks/`, which its glob discovers. That is what makes overwriting it safe, and the script says so in its own header |
| `.devcontainer/`? | **Not generated.** Over-provisioning: an editor preference that pins a base image which rots unattended, when the app already gets `docker/compose.yml` for the one service it needs. The framework repo needs one because contributors must reproduce a TruffleRuby toolchain; an app author needs Ruby and Postgres |
| CI opt-in behind `--ci`? | **Generated by default; `magik new --no-ci` skips it.** A repo with no CI on day one is a repo where CI arrives after the first regression. An unwanted file costs one `git rm`; a missing gate costs a bad merge. It is inert outside GitHub and says so |

### Stage 2 — `/setup-project`

The first thing every Magik user ever runs with an agent, and the most important document in the
`.claude/commands/` roster. It turns the generic scaffold into *their* scaffold: an interview about
the product, and only then `docs/ARCHITECTURE.md`, `docs/PLAN.md`, the project half of
`docs/FEATURE.md`, the project half of `CLAUDE.md` and `llms.txt`, and `domains/` if the answers
justify domains.

Three properties are load-bearing.

**It asks; it does not guess.** A stage-2 command that infers a domain model from the app's name is
the failure mode this design exists to prevent. The invented model is plausible, so it gets built
on, and it is discovered wrong several features later. The command says so in its own text: *a
document you generated from a guess is worse than an empty one — an empty section says "unknown" and
a confident wrong one does not.*

**It runs in the main conversation, never in a subagent.** A subagent has no channel to the user, so
it cannot interview anyone. Its two legal moves are decide-and-flag or stop-and-report, neither of
which is an interview. Delegating the *writing* afterwards is fine; delegating the *asking* is a
category error.

**It is re-runnable, and updates rather than clobbers.** Products change. On a later run the command
reads what exists, asks only about what changed, and proposes diffs the user approves. It knows
which run it is in by looking for the sentinel below — not by asking, and not by guessing from
whether a file looks empty.

### Stage 3 — real work

`/feature` for a vertical slice, `/screen` for one page, `/check` for the gate, `/next` for the
single next task read from `docs/PLAN.md`. Behind them, six agents scoped by directory rather than
by role — see [the roster](#the-roster).

## The app must know which stage it is in

A freshly generated app carries an unmissable marker, in `README.md`, `CLAUDE.md`,
`docs/PLAN.md`, `docs/ARCHITECTURE.md` and `llms.txt`:

```html
<!-- magik:stage2-pending -->
```

with a visible banner beside it naming `/setup-project` by that exact string. `/setup-project`
removes both on its first successful run.

It does two jobs at once. An agent that opens a never-bootstrapped app **routes the user to stage 2
instead of inventing a domain model** — the single highest-value instruction in the whole scaffold.
And the command itself uses the sentinel's presence to tell a first run from an update run, which is
a fact in the tree rather than a memory nobody has.

## Ownership and regeneration

A generated `CLAUDE.md` rots twice over: as the app grows past what the generator knew, and as Magik
changes underneath it. The honest failure mode of Rails-style templates is that **nobody ever
regenerates them**, and the evidence is not hypothetical — the TypeScript sibling's own demo app has
`.claude/agents` and `.claude/commands` that no longer resemble its generator's output, and a
`settings.json` that went missing without anything noticing. Its only update path rewrites the whole
tree, which is precisely why nobody ran it.

Magik's answer has three parts.

**1. Ownership is written into the file, not into a convention.** Two of the emitted files are
jointly owned, and the boundary is a marker pair:

```html
<!-- magik:framework-block BEGIN version=0.0.1 generated=2026-08-26 -->
  … framework-owned. Rewritten wholesale. Edits here are lost.
<!-- magik:framework-block END -->

<!-- magik:project-block BEGIN -->
  … project-owned. No magik command ever writes here.
<!-- magik:project-block END -->
```

**2. Every emitted file declares what an update may do to it**, in the manifest's `on-update`
column, and the test suite enforces that only the marked files claim `merge-blocks`:

| `on-update` | Applies to | Means |
|---|---|---|
| `replace` | `.claude/**`, `AGENTS.md`, `bin/*`, `scripts/lib/scripts.rb`, `.editorconfig`, `.gitattributes` | framework-owned with **no project content by construction**, so an update is a whole-file write. This is why the agent and command files carry no interpolation at all, and why `bin/check` is extended by dropping a file into `scripts/checks/` rather than by editing it |
| `merge-blocks` | `CLAUDE.md`, `llms.txt`, `docs/FEATURE.md`, `Gemfile`, `Rakefile`, `.gitignore` | only the framework block is rewritten. Missing markers is a refusal, not a guess. The marker text is identical everywhere; only the comment syntax around it changes (`<!-- -->` or `#`) |
| `never` | `README.md`, `.env.example`, `.rubocop.yml`, `lefthook.yml`, `ci.yml`, `docker/compose.yml`, `scripts/checks/*`, `docs/{README,ARCHITECTURE,PLAN}.md` | project-owned from the moment they are written. The updater does not read them |

The updater touches **only files the manifest names**. A helper added at `scripts/lib/<yours>.rb` is
not in the table, so it is never read, let alone written — which is how an app extends the library
without giving up updates to the half the framework owns.

**3. The stale harness is a finding, not a reminder.** The framework block carries the gem version
that wrote it. `magik check` compares that stamp to the running gem and reports a finding with a
runnable `fix:` — so the user learns about it from the gate they already run on every change, not
from a changelog they did not read:

```text
MAGIK_HARNESS_STALE: CLAUDE.md's framework block was written by magik 0.0.1; this app runs 0.4.0
  cause: the layout rules and error codes in that block predate 3 minor releases
  fix:   magik generate agents --update
```

`MAGIK_HARNESS_STALE` and `MAGIK_HARNESS_MARKERS_MISSING` are **reserved names, proposed here and
not yet in the catalogue** ([`../architecture/03-error-codes.md`](../architecture/03-error-codes.md)).
The command is `magik generate agents --update`, an addition to the `generate` kinds in
[`../../wiki/CLI-Reference.md`](../../wiki/CLI-Reference.md); if Phase 1 grows a broader
`magik upgrade`, it delegates to the same code path rather than becoming a second one.

None of this is implemented. What is implemented is the part that makes it *possible*: the markers
are in the templates, the version stamp is in the markers, the ownership rule is in the manifest,
and [the test suite](../../test/magik/app_templates_test.rb) fails if any of the three drifts.

## The DSL is not in the model's training data

The highest-value paragraph in the generated `CLAUDE.md` is not a rule. It is this: **`model`,
`screen`, `action`, `ledger`, `channel`, `flow` and `component` are in no model's training data.**
Written from memory they come out confident, plausible and Rails-shaped, for a framework that does
not work that way — which is the [`07-ai-first.md`](07-ai-first.md) failure mode ("a plausible
invention") in its most expensive form.

Two mitigations that do not work: telling the agent to be careful, and sending it to a URL. A web
fetch is slow, rate-limited, and **version-blind** — it answers for `main`, not for the gem the app
has installed.

So the gem ships its own documentation and the templates route every agent to it:

```bash
magik docs path            # the directory — point ordinary grep/glob/read at it
magik docs list            # every page and its slug
magik docs search ledger
```

`magik docs path` is the one that matters. It turns the shipped docs into **files an agent's normal
search already reaches**, which beats any CLI output format. And because the docs travel with the
gem, what the agent reads and what the code does cannot disagree.

This appears in the generated `CLAUDE.md`, in `llms.txt`, as step 0 of `docs/FEATURE.md`, and — not
by reference, but restated and scoped — in **every one of the six agent definitions**, because an
agent activated with only its own file in context never reads the shared contract. The test suite
asserts it: no agent or command file may ship without routing to the local docs.

## The two-way contract

The generated agents encode the app layout ([`../../wiki/Project-Layout.md`](../../wiki/Project-Layout.md))
and the boot-time guardrails ([`03-guardrails.md`](03-guardrails.md)), which means an agent working
in a Magik app is corrected by `magik check` rather than by a reviewer three days later. That is the
[`07-ai-first.md`](07-ai-first.md) argument — guardrails as the correction signal an agent can act
on unattended — applied one level out, to the app rather than the framework.

The contract runs both ways, and that is the point:

- **The framework tells the app what is legal.** One declaration per file, in its kind's directory;
  integer cents; `tenant_id` on every scope; UUIDv7 keys; a screen that does not query; an action
  that is the only write. Generated into `CLAUDE.md` and `docs/FEATURE.md`, enforced at boot.
- **The app tells the framework what it is.** `config/app.rb`, `domains/*/domain.rb` and the
  declarations in `app/` are what `magik check`, `magik domains` and `magik routes` read. The
  project block of `CLAUDE.md` is the human-readable half of the same statement.

The failure the pairing prevents: a rule that lives only in prose. If a rule in the generated
`CLAUDE.md` has no `MAGIK_*` code behind it, it is decoration, and an agent will eventually violate
it in a way that looks reasonable in review.

## The roster

**Agents are scoped by file set; commands are scoped by workflow.** A researcher/coder/reviewer trio
has no file set, so it cannot be told what it may not touch — and two of them running at once
collide. The six agents *tile* the app tree with no overlap, which is what makes steps 2–6 of a
feature parallelisable.

| Agent | Owns | Why it is separate |
|---|---|---|
| `data-modeler` | `app/models/`, `db/migrations/`, `db/seeds.rb` | fields, scopes and append-only migrations are where tenancy, the money type and UUIDv7 are actually decided |
| `action-author` | `app/actions/`, `jobs/`, `channels/`, `flows/`, `webhooks/`, `api/` | the whole write side. Keeping it in one agent is what keeps `ls app/actions/` the complete list of writes |
| `screen-builder` | `app/screens/`, `app/components/`, `config/theme.rb`, `locales/` | the only agent that needs the component kit and the four-rung override ladder ([`08-component-overrides.md`](08-component-overrides.md)) |
| `ledger-author` | `app/ledgers/` | one directory, deliberately. Everywhere else a wrong guess is a bug; here it is a wrong number in someone's accounts. Double-entry, append-only, no balance columns |
| `test-writer` | `test/` | tests have their own rules — no shared state, no truncation, no wall clock — set by a parallel worker-thread runner that does not exist yet and will not forgive tests written without it |
| `guardrail-reviewer` | **nothing. Read-only, no `Write` or `Edit`** | a reviewer that fixes what it finds stops reporting what it found. It is also the whole gate until `magik check` exists |

**Two directories the roster does not yet tile.** `policy` and `layout` are phase-2 constructs
([`00-build-spec.md`](00-build-spec.md)), so a generated app has `app/policies/` and `app/layouts/`
and no agent owns either. The tiling rule says which way it goes: `app/layouts/` is `screen-builder`'s
— a layout is built out of kit components and is where navigation is declared — and `app/policies/`
is its own concern rather than `action-author`'s, because a policy guards reads as much as writes and
`ls app/policies/` should be the complete list of authorization rules the way `ls app/actions/` is the
complete list of writes. The agent templates in
[`lib/magik/cli/templates/app/.claude/agents/`](../../lib/magik/cli/templates/app/README.md) predate
both constructs and are owed that change.

| Command | Does | Reads |
|---|---|---|
| `/setup-project` | stage 2, in full | the sentinel, then the user |
| `/feature` | one vertical slice, model → migration → action → screen → test → gate | `docs/FEATURE.md` |
| `/screen` | one screen or component, with the right rung of the override ladder | `magik docs Screens-And-Components` |
| `/check` | `magik check` then `magik test`, every finding triaged to a file, a rule, a fix and an owning agent | the error catalogue |
| `/next` | the single next task | `docs/PLAN.md` |

## `PLAN.md` and `FEATURE.md`, but no `DOMAIN.md`

The TypeScript sibling's generated apps carry `PLAN.md` and `DOMAIN.md`. Magik takes the first,
adds a second, and refuses the third.

| Document | Answers | Kept because |
|---|---|---|
| `docs/PLAN.md` | **what** is being built, in order, and what each slice proves | not derivable from code. `/next` reads it; `/feature` ticks it |
| `docs/FEATURE.md` | **how** a unit of work gets built *in this app* | the app-level counterpart to [`../architecture/05-adding-a-feature.md`](../architecture/05-adding-a-feature.md). Stage 1 ships the generic Magik loop; stage 2 fills in who owns which domain, what "done" means here, and what always needs a human look |
| ~~`DOMAIN.md`~~ | what the app is made of | **refused.** In a Magik app the domain map is *executable*: `domains/<name>/domain.rb` declares `depends_on`, `exposes` and `publishes_events`, boot enforces them, and `magik domains --json` prints the graph. A prose copy is a second statement of the same fact, and the copy is the one that rots |

What prose is genuinely needed for is the part no command can re-derive: **why** a boundary is where
it is, and what would have to become true to move it. That is `docs/ARCHITECTURE.md`, which carries
the reasoning and points at `magik domains` for the facts.

The same rule kills three other candidates. No copy of the DSL reference — `magik docs` ships it,
versioned. No `CHANGELOG.md` until the app releases to someone. No `gotchas.md` until something has
actually gone wrong, at which point it should be headed by the **literal error string**, so the next
person finds it by pasting.

## What must not be generated

| Never emitted | Why |
|---|---|
| **A claim the app cannot back** | every emitted file states that Magik is spec only and that the app cannot run. The vocabulary is `planned`, `not implemented`, `spec only`. The test suite asserts it on `CLAUDE.md`, `README.md`, `llms.txt` and `PLAN.md`, and the statement leaves the templates when Phases 1–2 land — not before |
| **A secret** | `.env.example` holds names and blanks. `SECRET_KEY_BASE` ships empty with the command that generates one, because a secret written by a generator is a secret in git history. Asserted by the test suite |
| **An `.mcp.json`** | pointing a user's agent at a server they did not ask for is not a default anyone gets to pick for them. The sibling framework's demo app carries one its generator never wrote, and documents it as a day-one guarantee — a claim about a file that does not exist. Asserted absent |
| **A hook that silently no-ops** | a `PostToolUse` hook running `magik check` would be useful the day `magik check` exists. Today it would fail on every edit and be swallowed, which is worse than no hook: it looks like coverage. `magik generate agents --update` adds it when the command is real |
| **A relative Markdown link in a copied file** | a generated app is a different repository. `../docs/…` resolves to nothing there. Framework references are absolute URLs or `magik docs` slugs; in-app paths are code spans. Asserted by the test suite |
| **Anything the user cannot delete** | every generated file is a starting point the user owns. The framework claims write access to the framework blocks and nothing else, and it says so in the file it is claiming |

## What is proven, and what is only designed

| Claim | How to check it | State |
|---|---|---|
| the templates exist and are internally consistent | `rake test TEST=test/magik/app_templates_test.rb` | **real** — manifest, ERB parse and render, JSON, YAML, frontmatter, markers, budgets, no secrets |
| the tooling half runs on a fresh app | `cd lib/magik/cli/templates/app && ./bin/check --list` | **real** — the test suite runs `bin/check` over the seeded checks and requires it green |
| `magik new` writes them into a directory | `magik help` | **not implemented** |
| `magik generate agents --update` refreshes a framework block | — | **not implemented**, and no marker-merge code exists |
| `magik check` reports a stale harness | — | **not implemented**. `MAGIK_HARNESS_STALE` is a reserved name |
| a generated app boots | — | **impossible today.** There is no `App.define` |
| the harness helps an agent build faster | — | **unmeasured.** No app has been built with Magik by anyone |

The test that is missing, and that Phase 1 owes: generate into a temporary directory and **boot the
result**. String-matching a template proves the template, not the generator — a standing requirement
in [`.claude/agents/cli-author.md`](../../.claude/agents/cli-author.md).

## Next

- [`07-ai-first.md`](07-ai-first.md) — the same argument for the framework itself, and the two agent
  audiences this scaffold serves the second of.
- [`../../wiki/Project-Layout.md`](../../wiki/Project-Layout.md) — the app tree the templates encode.
- [`../../lib/magik/cli/templates/app/README.md`](../../lib/magik/cli/templates/app/README.md) — the
  template set, its ERB variables and the rules for adding to it.
- [`../../dummy/README.md`](../../dummy/README.md) — the reference app, and what a generated app has
  that it deliberately does not.
- [`../../scripts/`](../../scripts/) — the framework repo's own check library, whose contract the
  generated `scripts/lib/scripts.rb` mirrors.
