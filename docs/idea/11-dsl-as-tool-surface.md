# The DSL as a tool surface

Magik's grammar is shaped like a well-designed MCP server: few constructs, heavily parameterized, with a constant-size catalogue and the detail loaded on demand. This page argues that the resemblance is structural rather than cute, states the priority ordering it forces, and derives the rules for how new DSL gets designed.

**Status:** spec only. The DSL is unimplemented ([`02-dsl-surface.md`](02-dsl-surface.md)); `magik describe` and `magik mcp` **do not exist and are not in [`00-build-spec.md`](00-build-spec.md)** — this page proposes both. The one thing here that runs is `magik docs` ([`../architecture/09-shipped-docs.md`](../architecture/09-shipped-docs.md)). Reviewed 2026-08-26.

## Who this is for

Not "Ruby developers who want an AI assistant". **Developers whose code is written by agents, who need a framework the agent gets right.** That audience changes the objective function, and this page is where the change is made explicit: where machine-authorability and human ergonomics conflict, **Magik optimises for the machine.** Most frameworks optimise for the human typing, and get a DSL an agent guesses wrong. Magik inverts it deliberately — see [the priority ordering](#the-priority-ordering-machine-first-legible-under-review), which is the sharpest claim on this page.

## The claim, in three sentences

The `gold-standards-in-ai` rule for MCP servers is **few parameterized tools beat many** — a constant-size discovery surface (`list_resources` / `describe_resource` / `manage_resource`) with composition pushed into parameters, because every tool definition is re-sent on every step and a per-action tool surface grows linearly and never amortizes. Magik's DSL is that same shape applied to a framework: twenty-six rows in [`02-dsl-surface.md`](02-dsl-surface.md)'s construct table instead of a few hundred API methods, each construct carrying its variation in keyword options, so the whole vocabulary fits in a context window and one construct's shape predicts the next. If that is what the DSL *is*, then it inherits the obligations of a tool surface — it must be introspectable, its options enumerable and defaulted, its errors naming the option and the legal values — and none of those obligations is currently met.

---

## 1. The isomorphism, and its limits

### The same economics, one level up

The MCP argument (`gold-standards-in-ai`, `docs/writing-for-agents/memory-and-mcp.md`) is arithmetic: at ~200 tokens per tool definition, 50 resources × 6 verbs is ~60k tokens re-sent on every step, while three meta-tools stay flat at ~0.6k however large the catalogue behind them grows. The fix is not a smaller catalogue — it is a catalogue that is *reachable* rather than *resident*.

Magik pays a version of that bill, at a different frequency and with a different symptom.

| | MCP tool surface | Magik DSL |
|---|---|---|
| The always-on artifact | tool definitions in the request | the grammar an agent must hold to write a declaration |
| Re-paid | every step | every session, and every turn the reference is quoted into context |
| Grows with | one tool per action | one construct per capability |
| Constant-size discovery | `list_resources` | the construct table in [`02-dsl-surface.md`](02-dsl-surface.md) |
| Lazy detail | `describe_resource` | `magik docs <slug>` (exists) · `magik describe` (**proposed**, §2) |
| Composition lives in | `filters`, `sort`, `fields`, `include` | keyword options on the construct |
| The failure when it overflows | the tool block does not fit; routing degrades | the agent reasons from half-remembered Rails and invents a plausible DSL |

The last row is where the two diverge in consequence, and it is why this matters more here. An over-budget tool surface fails *loudly* — wrong tool picked, or the request rejected. An over-budget framework surface fails *silently*: the agent writes fluent Rails-shaped Ruby and nothing in the transcript says it guessed ([`../architecture/09-shipped-docs.md`](../architecture/09-shipped-docs.md)). Same disease, quieter symptom, and the quieter symptom is the more expensive one.

### The mapping

| MCP concept | Magik concept | Note |
|---|---|---|
| Tool | Construct (`model`, `screen`, `job`, `ledger`, …) | the unit an agent must know exists |
| Tool input schema | The construct's declarations, options and blocks | what varies inside one unit |
| `manage_resource({resource, action, …params})` | `keyword :Name, option: value do … end` | dispatch by name, composition by parameter |
| Whitelisted filters/sorts per resource | Enumerated option values per construct | the closed set is the checkable part |
| Auth in the handler, not the dispatcher | Guardrails at boot, per construct | the check lives with the thing, not the front door |
| `describe_resource` returning a schema | *nothing yet* | §2 is about this hole |

### The design rule it implies

Both surfaces are governed by one asymmetry: **the catalogue is expensive and the parameters are cheap.** Which gives the rule already half-stated in [`10-saas-coverage.md`](10-saas-coverage.md) and stated in full by Magik's sibling:

> **A new capability arrives as a factory over an existing construct, never as a new construct.**

`developerz-ai/ultimate` applies exactly this to its eight closed primitives: `llm()` is not a ninth primitive, it is a function returning an `action` — which is why a model call inherits the route, the client, the job handle, the manifest entry and the one authz path for free. The Magik translation, and the tests that decide it:

| Test | Question |
|---|---|
| Does it fit an existing construct's shape? | a report is a `job` that writes a file and a `notification` that delivers the link. It is not a construct. |
| Does it inherit? | a factory's product gets the construct's guardrails, registry entry, trace node and `--json` rendering. A new construct inherits none of it and must re-earn all of it. |
| What does it cost the catalogue? | a construct is paid by every agent in every session forever. An option is paid only where it is used. |
| Is it a construct wearing an option? | the inverse failure. A `mode:`/`kind:`/`type:` option selecting a branch is a second responsibility smuggled in — the SRP smell already listed in [`../architecture/00-conventions.md`](../architecture/00-conventions.md). |

Growth defaults to the lazy axis; moving to the resident axis requires an argument. [`10-saas-coverage.md`](10-saas-coverage.md) is what that argument looks like when it succeeds — two proposals cleared the bar out of sixty-four surveyed surfaces.

### Where the analogy breaks

**A declaration is authored once and read forever; a tool call is transient.** A badly named tool parameter costs one wasted turn and is fixed by editing a schema nobody has to migrate. A badly named DSL option is in every app that ever used it, in git history, in generated code, and renaming it is a breaking change under semver. Magik therefore gets **less** freedom than an MCP server to iterate its parameter names — so §4's rules apply before the first construct ships, not after.

**The collapse target is different.** MCP collapses to *three* tools because tool definitions are re-sent every step, so the marginal tool has a per-step price. Magik constructs are not re-sent; they are read on demand. A Magik that collapsed to three constructs (`declare`, `render`, `run`) would be strictly worse — it would push the vocabulary into string parameters where no guardrail can see it, and destroy the property that `ledger` reads like `model` reads like `screen`. **The isomorphism is "few, parameterized", not "collapse to three".**

**There is no handshake in the middle of writing a file.** The honest tradeoff in the MCP pattern is that lazy schemas cost a round-trip: first touch of a resource burns a turn on `describe_resource`. An agent writing `app/models/order.rb` does not stop mid-line — unless the lookup is cheap enough that it does. That is exactly what §2 is for, and it is why `magik describe` is not a nicety.

**A DSL is read by humans; a tool schema is not.** `manage_resource({resource: "posts", action: "list", filters: {status_eq: "published"}, sort: "-created_at"})` is a good tool call and would be a terrible DSL — `_eq` suffixes as a filter grammar, `-created_at` as a sort spelling, a generic `params` bag. Which raises the question the rest of this section answers: if the human's needs and the machine's conflict, which wins?

One asymmetry with no Magik term at all, noted so it is not mistaken for an oversight: MCP hides resources by role and returns `ToolNotFound` rather than `Forbidden`. A DSL has no such notion — every construct is visible to every author, and there is nothing to hide.

### The priority ordering: machine first, legible under review

**Magik optimises for machine authorship. Where that conflicts with human ergonomics, the machine wins.** Stated plainly because it is a differentiator, not a compromise.

The precedent is Kubernetes. Its YAML is declarative, exhaustively schema'd and heavily parameterized, and an LLM handles it well precisely because every field is named, enumerated and validated. Its reputation for misery is a cost paid by **people writing YAML by hand** — which is exactly the job Magik removes. The verbosity was never the problem; hand-authoring was. So Kubernetes is evidence *for* the direction, not a caution against it: an exhaustively-schema'd declarative surface works extremely well for a machine author.

What Magik takes and what it refuses are separable properties, and conflating them is the mistake:

| From Kubernetes, kept | Refused |
|---|---|
| Declarative: state the desired shape, not the steps | Untyped YAML — a string is a string is a typo |
| Every fact has one obvious place | No locality — a resource's meaning spread across three files |
| Enumerated, schema-validated options | No readable unit — deep nesting with no shape you can take in at a glance |
| Verbosity where it buys explicitness | Verbosity for its own sake, in the common case |

A Ruby block gives both halves at once. `ledger :Payouts do … end` is as declarative as a manifest and reads as a sentence, and the whole declaration sits at one indentation level in one file. **That is the answer to "why Ruby and not YAML or a config format"**: a YAML-shaped Magik satisfies the machine half and fails the other one.

The other half, stated honestly rather than buried: **humans do not stop reading the code, they stop writing it.** Review, 3am debugging, onboarding and answering an auditor are all reading tasks that survive full automation, and the person who merges the diff is still accountable for it. So the position is not "humans do not matter" but **optimised for machine authorship, still legible under review** — and the two costs are not symmetric. Verbosity at authoring time is free when a machine authors. Illegibility at review time is never free, because review is the job the human keeps.

Read that way, [`01-thesis.md`](01-thesis.md)'s claim — *"readability is a first-order property of generated code … the scarce resource is a human's ability to audit a diff at a glance"* — is a **review-time** property, which is what it always meant. It does not compete with this ordering; it is the constraint the ordering operates under.

The DSL should therefore be **concise in the common case and parameterized when it needs to be**: a minimal declaration is short (§4, R3), the option surface is large, and you meet the surface only where you need it. And the honest limit: if a construct's options ever grow to where one declaration cannot be read at a glance, **the construct is wrong, not the reader** — and the escape is the factory rule above, not a plea for patience.

---

## 2. Discoverability: recall is the cost automation removes

This is the pivot of the whole argument, and it dissolves the apparent conflict above.

**A DSL's cost to a human is recall, not comprehension.**

| | Cost | Example |
|---|---|---|
| **Comprehension** — reading it | cheap, and needs no prior exposure | `retries times: 5, backoff: :exponential` is understood instantly in a diff |
| **Recall** — writing it from memory | expensive, and does not scale | *is it* `times:` *or* `attempts:` *or* `max_retries:`? *is it* `:exponential` *or* `"exponential"`? |

Nobody retains that across twenty-six constructs and a few hundred options. This is the real, honest cost of every DSL ever designed and the reason DSLs get a reputation for being hard.

**Recall is exactly the cost automation eliminates.** An agent does not memorize; it looks up — on every invocation, at effectively no cost, and it never misremembers *if the surface is discoverable*. So the DSL's one genuine human weakness is the precise thing the AI-first premise removes, while its strength — legibility under review — survives untouched. That is not a coincidence to be admired; it is a load-bearing reason the whole design works.

It also lands the MCP analogy properly. `describe_resource` exists for exactly this reason: the agent does not carry the schema, it fetches it. **`magik describe` is the same mechanism for the same reason**, which is what makes the isomorphism structural rather than superficial.

### Why it does not come for free

An LLM writes decent nginx configuration and decent bash because both are everywhere in its training data — millions of examples of `try_files` ordering and `set -euo pipefail`. Magik's DSL is in **zero** of it ([`07-ai-first.md`](07-ai-first.md), and the argument is not restated here). So the advantage does not transfer; it has to be **manufactured**, by shipping the reference and the schema with the gem. That is the more interesting claim: Magik has to do work nginx never had to do, and `magik docs` ([`../architecture/09-shipped-docs.md`](../architecture/09-shipped-docs.md)) is the first half of it.

And the narrow, accurate version of the claim, because the framework's central design decision depends on it: **on a recall-heavy declarative surface, an agent with lookup and a gate outperforms a human working from memory.** Three parts, all necessary — lookup replaces the recall the agent also lacks for an unseen DSL, the gate catches what it still gets wrong, and the declarative surface is what makes both mechanisable. A human hand-writing nginx has none of the three, which is why hand-written nginx is a byword for subtle breakage. Nothing here assumes the agent is infallible: [`03-guardrails.md`](03-guardrails.md) calls the guardrails the product precisely because it is not.

### The proposed surface: `magik describe`

Status: **proposed on this page, not in the spec, not implemented.** Adding it is a spec change under the "no framework code that is not spec-backed" rule in [`../architecture/00-conventions.md`](../architecture/00-conventions.md).

```bash
magik describe                          # the catalogue: every construct, one line each
magik describe model                    # one construct, in full
magik describe model --json             # the same, as data
magik describe model.field --json       # one declaration inside a construct
magik describe field.money --json       # one field type and its options
```

One construct, as data:

```json
{
  "command": "describe.construct",
  "construct": "model",
  "kind": "declaration",
  "phase": 1,
  "status": "planned",
  "name_style": "PascalCase",
  "doc": "docs/idea/02-dsl-surface.md#model",
  "options": [],
  "declarations": [
    { "name": "field",
      "positional": [
        { "name": "name", "type": "symbol", "required": true },
        { "name": "type", "type": "symbol", "required": true,
          "allowed": ["string","text","integer","decimal","boolean","money",
                      "timestamp","date","uuid","json","enum","vector"] }
      ],
      "options": [
        { "name": "required", "type": "boolean", "default": false },
        { "name": "unique",   "type": "boolean", "default": false },
        { "name": "values",   "type": "array<symbol>", "default": null,
          "applies_when": { "type": "enum" }, "required_when": { "type": "enum" } },
        { "name": "currency", "type": "symbol", "default": null,
          "applies_when": { "type": "money" } },
        { "name": "translatable", "type": "boolean", "default": false, "phase": 8 }
      ],
      "guardrails": ["MAGIK_MODEL_FORBIDDEN_FIELD", "MAGIK_MODEL_FLOAT_MONEY"] }
  ],
  "blocks": [{ "name": "scope", "yields": [], "returns": "Sequel::Dataset" }],
  "injected": ["id", "tenant_id", "created_at", "updated_at"],
  "guardrails": ["MAGIK_MODEL_NO_TENANT", "MAGIK_SCHEMA_DRIFT"]
}
```

| Property | Rule |
|---|---|
| **Complete** | every option, type, default and allowed value. A lookup missing one option sends the agent straight back to guessing, which is the failure mode the whole design exists to prevent. Completeness is the bar, not coverage. |
| **Derived, never hand-maintained** | the option list is *the same table the DSL validates against* — one `Option` value object per option (name, type, default, allowed set, applicability, doc anchor, the `MAGIK_*` codes it can raise), read by the coercer at boot and serialized by `describe`. Two tables drift; one cannot. |
| No app, no boot, no database | it answers about the *grammar*, so it works in an empty directory — which is when an agent needs it most, before `magik new` has run. |
| Not `magik registry` | [`../architecture/06-observability.md`](../architecture/06-observability.md) already plans `magik registry [--json]` for **what this app declared**. `describe` is **what the grammar allows**. Neither may grow into the other: one needs a booted app and one must not have one. |
| Ships in the gem | same argument as the docs: a schema fetched from `main` describes a version the reader is not running. Deriving it from the loaded code makes version-matching a property, not a promise. |
| Guarded by a check | a `scripts/checks/` step asserting every option in [`02-dsl-surface.md`](02-dsl-surface.md) appears in `magik describe --json` and vice versa. A convention that is not a check does not exist. |
| Additive-only schema | the same stability contract as every other `--json` output ([`../architecture/03-error-codes.md`](../architecture/03-error-codes.md)). |

### How it relates to `magik docs`

`magik docs` is the **prose half** and it exists today. `magik describe` is the **schema half** and it does not. They answer different questions and must not restate each other.

| | `magik docs` (implemented) | `magik describe` (proposed) |
|---|---|---|
| Answers | why this construct exists, when to reach for it, what it refuses | what options it takes, of what type, with what default and what legal values |
| Source | markdown packaged in the gem | the option tables the DSL validates against |
| Fails when | prose rots relative to code | impossible by construction — it *is* the code |
| Entry point for | "I do not know which construct this is" | "I know it is a `job`; I do not know the retry option's spelling" |

The join is one field: every `describe` entry carries a `doc:` slug that `magik docs` resolves, so an agent goes schema → prose in one hop and never has to search.

---

## 3. The MCP server — `magik mcp`

**Status: proposed, not implemented, not in the spec.** Designed by following `gold-standards-in-ai`'s 3-tool pattern rather than by inventing a shape.

### The surface

| Tool | Role | `{}`-callable |
|---|---|---|
| `magik_catalogue` | every construct with its one-line summary and declaration names; every shipped doc page with slug and audience; every `MAGIK_*` code; and — if the working directory holds an app — its declared models, screens, actions, jobs, ledgers and domains | **yes** |
| `magik_describe` | the lazy schema for one construct, declaration, field type or error code. Accepts an array, so multi-construct work is one handshake | no |
| `magik_run` | the dispatcher over **read-only** operations: `{ op, …params }` | no |

`magik_run`'s `op` set, each an existing or planned CLI command with `--json`:

| `op` | Wraps | Underlying command |
|---|---|---|
| `docs.search` · `docs.read` · `docs.path` | `magik docs …` | implemented |
| `check` | `magik check [--scale] --json` | planned |
| `errors.explain` | `magik errors explain <CODE> --json` | planned |
| `registry` | `magik registry --json`, filtered by `kind` | planned |
| `routes` | `magik routes --json` | planned |
| `explain` | `magik explain screen :X` / `magik explain query …` | planned |

The catalogue is deliberately **rich enough to act on** — construct names, declaration names, a one-line option hint — because the pattern's honest cost is that a first touch otherwise burns a turn on `describe`. `magik_describe` is reserved for the long tail: full option tables, allowed-value sets, guardrail codes.

### Is this a parameter or a tool? Showing the working

| Candidate | Verdict | Why |
|---|---|---|
| `search_docs`, `read_doc`, `docs_path` | **parameter** (`op: "docs.*"`) | three verbs over one resource, one result shape, one safety profile — precisely the `list_recent_posts` / `list_published_posts` split the pattern forbids |
| `list_models`, `list_screens`, `list_actions`, … | **parameter** (`op: "registry", kind: "model"`) | the per-verb explosion in its purest form: twenty-six constructs is twenty-six tools differing only in a filter value. `kind` is a whitelisted enum, per "whitelist, don't blacklist" |
| `describe_model`, `describe_job`, … | **parameter of `magik_describe`** | the construct name is data, not identity |
| `run_check`, `run_scale_check` | **parameter** (`op: "check"`, `scale: true`) | `--scale` is a flag; a second tool would be a flag wearing a name |
| `explain_error` | **parameter** (`op: "errors.explain"`) | a catalogue lookup keyed by a string |
| `explain_screen`, `explain_query` | **parameter** (`op: "explain"`, `subject`) | one operation, two subjects, one result shape (a tree) |
| `magik_catalogue` | **tool** | it is the discovery entry point; it cannot be a parameter of the thing it makes discoverable |
| `magik_describe` | **tool** | its result is a schema, not data, and it is what a host caches per session. Folding it into `magik_run` makes the cacheable and the volatile share one shape |
| `generate`, `new`, `migrate`, `console`, `server`, `worker`, `test` | **neither — excluded** | see below |

Two rules the surface keeps room for rather than applies today:

- **Genuinely non-CRUD operations stay separate tools.** Nothing read-only qualifies. If `magik mcp` ever grows a streaming operation — a `test --watch` feed — that is a fourth tool, because its result shape and lifecycle differ, not because it is another verb.
- **Large results go behind a handle, never truncated.** `docs.read` on a long page, or `check` on an app with four hundred findings, returns `{handle, bytes, shape, preview, next}` and the agent pulls chunks. "It was too big" must never become a missing finding.

### What must be read-only, and why

**Every operation, without exception, in this product.**

| Excluded | Why |
|---|---|
| `magik generate`, `magik new` | they write files. An agent already has file tools and a shell in the repo, behind its host's permission system and in front of git. Routing the same writes through MCP moves them *outside* both, for no capability gained. |
| `magik migrate`, anything touching a database | irreversible, and the credential is in the environment the server inherits |
| `magik console`, `server`, `worker`, `test` | `console` is arbitrary code execution with an app's connections open. A tool that evaluates Ruby is not an introspection surface, it is a shell with a friendlier schema. |

The reasoning is the gateway argument from `gold-standards-in-ai` (`docs/ai-agents/tools-and-mcp.md`, "Audited capability access"). Read-only introspection and audited mutation are different products with different obligations:

| Property | `magik mcp` as designed | What a mutating server would owe |
|---|---|---|
| Credentials | none needed; reads source and shipped docs | must never leave a gateway — the caller sends an intent, never a connection string |
| Identity | not required | end-to-end: caller → grant → audit row |
| Permissions | none to grant | config-as-code, reviewed, most-restrictive-wins |
| Audit | not required | **synchronous** — the row commits before the response; a failed audit write rolls the response back |
| Blast radius of a bug | a wrong answer | a wrong write |

A mutating `magik mcp` is therefore not a flag on this design — it is a separate binary with a separate name that must earn all four rows first. This page does not propose one.

Two further constraints:

- **The server must start with no app present.** An agent scaffolding an app has no app yet, and a discovery surface requiring the thing being discovered is useless at the moment it is most needed. Framework-only mode answers `catalogue`, `describe` and `docs.*`; the rest return a `MAGIK_*` code naming the missing app with a runnable `fix:` ([`../architecture/03-error-codes.md`](../architecture/03-error-codes.md)).
- **The gain over the CLI must be stated honestly.** An agent with a shell can already run `magik docs search` and `magik check --json`. `magik mcp` earns its existence where shell access is absent or expensive, and by making the catalogue a first-class object the host caches per gem version — schemas are stable between releases, which is an unusually good cache key. Where an agent has a shell, the CLI is the better path and the docs should say so.

### The constant-size claim

| DSL size | One tool per construct per verb (`list` · `describe` · `explain`) | The 3-tool pattern |
|---|---|---|
| 26 constructs (today's spec) | 78 tools | 3 |
| plus a later construct set | linear, forever | 3 |
| plus one op (`errors.explain`) | +1 tool | +1 enum value, +0 tools |

The property that matters is not the count — it is that **no tool is per-construct**, so the surface stops tracking the size of the framework.

---

## 4. What this changes about the DSL's design

If the DSL is a tool surface, its options are a schema, and a schema has rules. Each is stated as a rule for *how new DSL is designed*, and each is testable rather than tasteful.

### R1 — One concept, one spelling, everywhere

An agent generalises from one construct to the next; every idea spelled two ways turns that generalisation into a plausible wrong guess. [`02-dsl-surface.md`](02-dsl-surface.md) already gets this mostly right — `retries times:, backoff:` is spelled identically on `job` and on `webhook :outgoing` — and the rule exists to keep it that way. Four concepts currently carry more than one spelling; each is a design question to settle **before** implementation, because a renamed option is a breaking change:

| Concept | Spellings today | The question |
|---|---|---|
| A duration | `session_ttl "14d"` · `schedule every: "10m"` · `trial_days: 14` | one convention — a unit-suffixed string everywhere, or an explicit `*_days`/`*_ms` integer everywhere. Not both. |
| A precondition | `guard { … }` on a `ledger` entry · `if: ->(ctx) { … }` on a `flow` step | one spelling for "do not proceed unless". A block and a lambda-in-an-option are two grammars for one idea. |
| A field subset | `only: %i[…]` on `api create` · `filter:`/`sort:` on `api index` · `list_display`/`filterable`/`searchable`/`read_only` on `admin_panel` | four spellings of "which fields participate". `admin_panel` is a projection of `model`; its vocabulary should be `api`'s. |
| Uniqueness | `unique: true` on `field` · `unique_by :tenant_id` on `job` | different meanings (a constraint vs a dedupe key) sharing a stem. Either they converge or they diverge — sharing a prefix while meaning different things is the worst of both. |

**Enforcement:** a `scripts/checks/` step over the option tables. Unenforceable as prose, mechanical as data — which is the point of §2.

### R2 — Enumerated beats free-form

An option whose legal values are a closed set is a `Symbol` from that set. A free-form `String` is permitted only where the space is genuinely open — a URL, a cron expression, a regex, a translation key — and then it carries a format check and a named error code.

| Property | Enumerated | Free-form |
|---|---|---|
| Checkable at boot | exhaustively | only against a pattern |
| Discoverable | `allowed:` in `magik describe` | a sentence in prose |
| Error quality | "got `:exponential_backoff`; allowed `:exponential`, `:linear`, `:none`" | "invalid value" |
| Typo failure mode | refused at boot | accepted, misbehaves later |

This is the Kubernetes strength, kept: enumerated options are checkable, discoverable and completable. The closed-set case is the default; an open string needs a reason.

### R3 — Every option has a default; the minimal declaration is valid

```ruby
model :Order do
  field :reference, :string
end
```

This must boot. It is the tool-surface rule that read verbs are `{}`-callable, and it is what keeps the DSL **concise in the common case** while the option surface stays large — the "under 30 lines" success criterion and a hundred-option construct are only compatible through defaults.

The exception, stated as a rule and not a loophole: an option with **no defensible default** is required *and* enumerated, so the failure names the choices. A `field`'s type has none; `webhook :incoming` without `verify_signature` has no safe one and is a boot failure by design ([`03-guardrails.md`](03-guardrails.md)). What is not acceptable is a required option whose legal values are undiscoverable.

### R4 — Verbose is acceptable; unreadable is not

An option spelled out in full beats a terse flag whose meaning must be looked up. Machine authorship makes length free at write time (§1); it does nothing about legibility at review time, which is the cost that never goes away. When the two pull apart — a short cryptic spelling against a long obvious one — the long one wins.

**Limit:** if a construct's options grow to where one declaration cannot be read at a glance, the construct is wrong. The escape is a factory over it, per §1 — never a plea for a more patient reader.

### R5 — Locality is non-negotiable

A declaration's meaning must be visible without opening another file. This is the property Kubernetes lacks and the direct argument against config sprawl: no `config/` archaeology, no registry file to cross-reference, no behaviour that lives in a second place. Routes derive from names; `use` seams are named once in `App.define`; everything else is in the block you are reading.

### R6 — Every option is discoverable through the schema surface, or it is a defect

An option that cannot be looked up — undocumented, dynamically constructed, implicit, accepted-but-unlisted — may as well not exist. The human will not recall it (§2) and the agent cannot find it, so neither will use it correctly, and both will invent something else. Concretely: an option is legal only if it has a row in the option table, and the option table is what both the coercer and `magik describe` read.

### R7 — Errors name the option and the allowed values

The contract in [`../architecture/03-error-codes.md`](../architecture/03-error-codes.md) is extended, not replaced: an option-level failure carries the four facts that let an agent fix it without reading source.

```json
{ "code": "MAGIK_MODEL_UNKNOWN_OPTION",
  "cause": "field :status, :enum was given `options:`; the option is spelled `values:`",
  "location": "app/models/order.rb:4",
  "details": { "construct": "model", "declaration": "field", "option": "options",
               "given": "options", "did_you_mean": "values",
               "allowed": ["required","unique","default","values","currency","translatable"] },
  "fix": "magik describe model.field --json" }
```

The `fix:` line is load-bearing: it points at §2's surface. The error is what teaches the agent the lookup exists; the lookup is what makes the next error unnecessary.

### R8 — The guardrails are the schema validation

Option validation and guardrail checking are **one pass over one table**, not two subsystems that happen to agree. [`01-thesis.md`](01-thesis.md)'s axiom 7 says guardrails are the product; this says the schema is how a large class of them is implemented. For anyone adding an option, the table row, the allowed-value set, the `MAGIK_*` code and the `magik describe` output are **one artifact serialized four ways** — the same "define once, project everywhere" move the framework already makes for `model` → table + migration + factory + admin panel.

### R9 — Keyword arguments; behaviour in blocks; no positional booleans

Already stated in [`02-dsl-surface.md`](02-dsl-surface.md) and [`../architecture/00-conventions.md`](../architecture/00-conventions.md). What this page adds is the reason, stronger than style: **a positional argument has no name, so it cannot appear in a schema, so it cannot be described, so it cannot be discovered.** A positional boolean is an option that has opted out of being a tool surface — an R6 violation by construction.

### R10 — Adding a construct is a budget decision; adding an option is not

| | Construct | Option |
|---|---|---|
| Paid by | every agent, every session, used or not | only the declarations that use it |
| Cost of a wrong one | the whole grammar is harder to hold | one lookup |
| Bar to add | a written argument against the context budget ([`07-ai-first.md`](07-ai-first.md), axiom 5), plus a spec change | fits an existing construct's shape, has a default, has an allowed set, is in the schema |
| Failure mode of over-use | the surface stops fitting in a window | an option that changes what the construct *is* — a construct in disguise (§1) |

### Proposed for `docs/architecture/00-conventions.md`

R1–R10 are design rules for whoever implements a construct, which is what that file is for. **Not edited by this page — proposed here and reported to its owner.**

---

## What this page does not claim

| Not claimed | Reality |
|---|---|
| `magik describe` exists | it does not, and it is not in [`00-build-spec.md`](00-build-spec.md). Adding it is a spec change. |
| `magik mcp` exists | it does not. No MCP server has been written, run or measured. |
| The DSL is introspectable today | no DSL method exists in `lib/`. The option tables §2 depends on are not written. |
| The token figures are Magik's | they are `gold-standards-in-ai`'s MCP measurements, cited to establish the shape of the argument. Nothing here is measured, `As of 2026-08-26`. |
| Agents do not make mistakes | they do, constantly, and [`03-guardrails.md`](03-guardrails.md) is the whole framework's answer. The claim is narrower: **with lookup and a gate, an agent beats a human working from memory on a recall-heavy surface.** |
| R1's four inconsistencies are bugs | they are **open design questions** in a spec-only document, raised because §1 shows they get expensive after the first release, not before. |

Magik is not betting that the agent is infallible. It is betting that a fallible agent, given a discoverable surface and an unforgiving gate, ships better code than a careful human working from memory — and the architecture is arranged to win that bet.

## See also

- [`02-dsl-surface.md`](02-dsl-surface.md) — the construct table this page treats as a catalogue, and the option spellings R1 examines.
- [`07-ai-first.md`](07-ai-first.md) — why the surface must fit in a context window, and why the DSL's absence from training data is the governing constraint.
- [`10-saas-coverage.md`](10-saas-coverage.md) — the factory-over-a-construct rule applied to sixty-four candidate surfaces.
- [`03-guardrails.md`](03-guardrails.md) — the gate half of the bet.
- [`../architecture/09-shipped-docs.md`](../architecture/09-shipped-docs.md) — the prose half of discoverability, and the one part of it that runs.
- [`../architecture/06-observability.md`](../architecture/06-observability.md) — `magik registry`, `routes` and `explain`, which `magik_run` dispatches to and must not duplicate.
- [`../architecture/03-error-codes.md`](../architecture/03-error-codes.md) — the error contract R7 extends.
- [`../../wiki/CLI-Reference.md`](../../wiki/CLI-Reference.md) — the CLI surface as shipped.
