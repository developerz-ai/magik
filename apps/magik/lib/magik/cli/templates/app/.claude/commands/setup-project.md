---
description: Turn this generic Magik scaffold into YOUR project — interview first, then write the architecture, the plan, the feature loop and the domain map. Run this before any other work in a new app.
argument-hint: [one line about the product, or blank to start from nothing]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# /setup-project

**Stage 2 of three.** `magik new` (stage 1) wrote a generic scaffold that knows nothing about the
product. This command turns it into *this project's* scaffold. Stage 3 — real features — starts
after it. Everything you write here is **project-owned**: no magik command ever overwrites it.

## Focus

$ARGUMENTS — blank means start from nothing, which is fine. It is a seed for the first question,
never an answer to the rest.

## First: which run is this

```bash
grep -l "magik:stage2-pending" CLAUDE.md README.md docs/PLAN.md 2>/dev/null
```

| Result | This is | What it changes |
|---|---|---|
| the sentinel is present | **the first run** | you are writing these documents from nothing |
| no sentinel | **an update run** | the documents exist and are being sharpened. Read them all before asking anything, ask only about what has changed, and **propose diffs the user approves** — never rewrite a section wholesale |

## The rule this whole command exists to enforce

**Do not invent a domain model.** Not from the app's name, not from the directory it sits in, not
from "it's a SaaS so it probably has users and teams". A plausible invented domain model is the most
expensive mistake available here: it looks right, it gets built on, and it is discovered wrong three
features later.

Facts come from the user. Conventions get written down. **A document you generated from a guess is
worse than an empty one** — an empty section says "unknown" and a confident wrong one does not.

**And do not write DSL from memory either.** The Magik DSL is in no model's training data, and the
gem ships its own docs on disk: `magik docs path` for the directory, `magik docs list` for the
pages, `magik docs Project-Layout` before you place a file. That command works today; almost nothing
else does.

Run this in the main conversation, not in a subagent. A subagent has no channel to the user, so it
cannot interview anyone; delegate the writing afterwards if it helps, never the asking.

## The interview

Ask in small batches — three or four questions, then listen. Reflect the answers back before moving
on. If an answer is vague, ask again rather than resolving it yourself.

1. **The product.** What does it do, for whom, in one paragraph? What does someone pay for?
2. **The tenant.** Who is the tenant — an organisation, a workspace, a single person? Every model in
   a Magik app is scoped by `tenant_id`, so this decides the shape of everything. What does a user
   belong to, and can they belong to more than one?
3. **The core entities.** Five to ten nouns, no more, with one line each. Which owns which? Which
   are created by users and which by the system?
4. **Money.** Does money change hands? If yes: **whose money** — the app charging its customers
   (`billing` in `config/app.rb`), the customers charging *their* customers (`app/ledgers/`), or
   both? What currencies? Who needs an audit trail, and for how long?
5. **The first screen.** What does a user see on their first successful visit, and what is the one
   action they take there? This becomes the first slice in `docs/PLAN.md`.
6. **The edges.** What outside systems does this talk to — payment processor, email, an existing
   database, an import? Which of them can retry, and therefore need `idempotent_by`?
7. **Constraints an agent cannot infer.** Compliance, a naming convention the team already uses, a
   legacy system whose vocabulary must be matched, a hard deadline.

Stop and confirm the entity list and the tenant before you write anything.

## Then write, in this order

Every one of these is project-owned. Write inside the `magik:project-block` markers where they
exist, and never touch a `magik:framework-block`.

| # | File | What goes in it |
|---|---|---|
| 1 | `docs/ARCHITECTURE.md` | the domains, what each owns, what it exposes, what it must not reach into — and the **reasoning**, which no command can re-derive. Entity list with one line each. Where money lives |
| 2 | `CLAUDE.md`, project block only | what the app is, the tenant, the boundaries in three lines, and the conventions an agent would otherwise get wrong. Keep it short — link `docs/ARCHITECTURE.md` rather than restating it |
| 3 | `docs/FEATURE.md`, project block only | this app's answers to the loop's open slots: which agent owns which domain, what "done" means here, what always needs a human look |
| 4 | `docs/PLAN.md` | the first slice from question 5, then the next three or four, each with what it proves. Delete the stage-2 banner |
| 5 | `llms.txt`, project block only | the app's inventory — domains, entities, first screens — as links, not prose |
| 6 | `domains/<name>/domain.rb` | **only if the answers actually justify domains.** Fewer than ~25 models and one team means flat, and saying so is the right answer |
| 7 | `.env.example` | any outside system from question 6 gets its variable name and a blank, in the app section at the bottom |

Then remove `<!-- magik:stage2-pending -->` and the banner around it from `CLAUDE.md`, `README.md`
and `docs/PLAN.md` — but only after every document above is written and the user has agreed with
what is in them.

## Optionally, the first slice

**Only after the user confirms the entity list**, offer to scaffold it — do not just do it:

```bash
magik generate model <Entity>       # planned; exits 1 today with MAGIK_CLI_COMMAND_NOT_IMPLEMENTED
magik generate screen <First>
magik generate action <first_action>
```

Magik is spec only, so these do not run yet. Say that rather than reporting files you did not write.

## Report

```
Run:        first | update
Product:    <one line, in the user's words>
Tenant:     <what a tenant is>
Entities:   <the confirmed list>
Money:      <none | billing | ledger | both> — <why>
Layout:     flat | domains — <why>
Written:    <file — what changed>  (one line each)
Banner:     removed | still present, because <what is still unanswered>
Next:       /next, or the first `magik generate` once Phase 1 lands
```
