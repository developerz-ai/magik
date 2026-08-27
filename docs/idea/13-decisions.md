# How decisions get made

> **Status:** this page is a governance record, and it is the only page in `docs/idea/` that is not
> about the framework. It is about who decides what the framework is.
>
> `As of 2026-08-26` every decision below is a decision about a design. None of it is implemented —
> re-derive what runs with `ruby -Ilib exe/magik help` and `rake test`.

## The premise, taken seriously

[`07-ai-first.md`](07-ai-first.md) argues that Magik is designed to be *written* by an agent. This
page states the stronger version that the project actually operates on: **the agent also decides.**

That is not a slogan about the product, it is how this repository is run. The owner supplies
direction — what the framework is for, who it serves, what it refuses to do. The agent supplies the
work *and the judgement inside it*: which construct absorbs a missing capability, what a code is
called, which of two spellings survives, whether a measurement changes a decision. A design question
that arrives mid-task is answered and recorded, not queued for a human to arbitrate.

**The reason is throughput, and the argument is the same one the framework makes about glue code.**
A framework this size generates hundreds of decisions, and the overwhelming majority have one
defensible answer that a careful reader would reach from the constraints already written down. Asking
about each of them converts a person into a bottleneck for work they would rubber-stamp. Direction is
the scarce input; adjudication is not.

## Why this is safe here, and where it would not be

An agent deciding is only safe when a decision that is wrong is **cheap to find and cheap to
reverse**. Three properties make that true in this repository, and all three are load-bearing:

| Property | What it buys |
|---|---|
| **The spec is the constraint** | [`00-build-spec.md`](00-build-spec.md) is the source of truth, and every change must trace to a section of it. An agent decides *within* a frame it did not set. A decision that contradicts the spec is not a decision, it is a bug — and changing the spec is an amendment with an argument, not a commit |
| **The gate is the check** | `bin/check` is seven steps and CI runs the same ones across four engines. A decision that breaks something is red within a minute, and "it seemed right" does not survive a failing test |
| **Nothing is shipped** | the version is a name reservation. Almost every decision here is reversible for free *right now* and permanent later, which inverts the usual caution: **deciding late is the expensive option** |

Take any one of those away and this model stops being appropriate. A framework with users, a decision
with no test behind it, or a question the spec does not frame — those are the cases that go back to
the owner.

## What is reserved to the owner, always

Delegation is not abdication, and the boundary is not "important decisions". It is **decisions whose
cost cannot be undone by an edit**:

- **Anything outward-facing.** Publishing a gem, cutting a tag, pushing to a public branch someone
  else builds on, posting anywhere. A release is immutable and a bad one is a permanent artefact.
- **Anything that spends money or makes a commitment** in the owner's name.
- **Anything that changes what the product is for.** The mission sentence, the permanent limits
  ([`05-limits.md`](05-limits.md)), the audiences ([`12-the-range.md`](12-the-range.md)). Those are
  direction, and direction is the input the agent does not supply.
- **Anything the spec does not frame**, where a decision would be invention rather than derivation.
- **Destructive operations** on anything not reconstructible from the repository.

The rule of thumb: *if being wrong costs an edit, decide it; if being wrong costs a release, a
relationship, or the point of the project, bring it back.*

## What a decision owes

A decision that is not written down is indistinguishable from a preference, and the repository will
not be able to tell in six months which is which. Every non-obvious decision carries:

1. **What was decided**, in one sentence.
2. **What the alternative was** — a decision with no discarded option is a description.
3. **Why**, in terms of a constraint that already existed rather than taste.
4. **What would reopen it.** A decision with no reopening condition is a dogma, and the runtime
   decisions in this project have already moved once on a measurement.

That last point is the one that keeps this honest.
[`../architecture/12-runtime-verification.md`](../architecture/12-runtime-verification.md) exists
because a decision was reversed by running a probe rather than by re-reading the argument.

## Decisions taken this way

The record, newest first. Each links to where it is argued in full — this table is an index, not the
argument.

| Decision | Instead of | Because | Reopened by |
|---|---|---|---|
| **Agent plans live in `.claude/plans/`, and this repo commits no `.claude/settings.json`** | `docs/plans/` beside the other prose, and a checked-in permission allowlist | `Magik::Docs::PACKAGED_GLOBS` packages `docs/**/*.md` into the gem and `magik docs` serves it, so a plan written there ships to every app builder and shows up in `magik docs list` — an ephemeral working note inside the DSL reference. `settings.json` goes the same way for the mirror-image reason: it is one operator's tolerance for what runs unprompted, and nothing the repo depends on may live somewhere a contributor can silently not have — the lint runs because `bin/check` runs it, not because a hook did | a docs catalogue that can exclude a subtree, which would make `docs/plans/` free |
| **An incoming webhook declares a service actor with an explicit verb list** | letting it inherit `policy: :system`, the way a job does | a verified signature authenticates an *origin*, not a person. `:system` would grant every verb in the application to the one surface a stranger can call directly. A job is triggered by the app on its own schedule; a webhook is triggered by anyone who can reach the URL | a design for an actor a webhook could legitimately impersonate — none is currently plausible |
| **A `policy` subject is any declared construct, not only a `model`** | requiring every surface to project onto a model | `ledger :Receivables` is not a model, so `api resource :ledger_entries` had no legal verb to name. The alternative would have forced a fake `LedgerEntry` model into existence purely to satisfy a guard — inventing a data model to satisfy authorization, which is backwards | — |
| **A `flow` names its own verb and inherits nothing from its steps** | inheriting the union of the verbs its steps' actions name | inheritance makes a flow's authorization a function of code elsewhere: unreadable at the declaration site, and silently changed by editing a step. That is the second door `policy` exists to close. A flow gates entry; each action still gates its write | — |
| **Rack + Puma, thread-per-request, single mode** | Falcon and a fiber scheduler, which the spec originally named | Falcon cannot boot on TruffleRuby — there is no fiber scheduler and `async` raises on its first block. `fork` is absent too, so there are no clustered workers and capacity comes from containers | TruffleRuby implementing a fiber scheduler ([`../architecture/12-runtime-verification.md`](../architecture/12-runtime-verification.md)) |
| **Concurrency is real parallel OS threads** | Ractors, which the spec originally named | measured, not assumed — and the parallelism survives the driver, because `pg` releases the runtime lock. CPU parallelism behind a serialising driver would be a queue wearing a thread pool | a probe regression on a new engine release |
| **`policy` is a phase-2 construct at tier 1** | authorization living with `auth` in phase 7 | `render` and `realtime` are tier 2 and must evaluate it, and imports go strictly down. Adding a `policy:` argument to six constructs after all six exist is the retrofit this spec calls a migration nobody survives | nothing — this is the decision the whole authorization design rests on |
| **`layout` is a primitive, not a component recipe** | assembling a shell from `grid` and `card` | the reference app had no way to navigate itself, and nobody noticed. An absence in a grammar is invisible until someone tries to use it | — |
| **Authorization is not a swap point** | a pluggable authorization backend, like the DB and cache seams | a second authorization backend is a second authorization system, which is the failure the design is organised against | — |
| **Media is its own phase (4b)** | spreading it across phases 1, 2, 4 and 7 | a capability whose value arrives only when all four have landed is a phase; otherwise each phase ships a quarter and the app still cannot store a photo | — |
| **Shipped error codes were renamed to fit the format** | grandfathering them under "stable forever once shipped" | the stability promise protects consumers' error handling and `fix:` scripts, and a name-reservation release has none. The window to fix a convention closes the moment someone depends on it | the first real release — after which the promise binds for good |
| **`scripts/checks/*.rb` runs in `bin/check`** | leaving them as scripts a contributor runs by hand | two of the eight had been red for an unknown number of commits and nobody noticed, because nothing ran them. A check that is not in the gate is a check that does not exist | — |

## The failure mode this page is guarding against

An agent that decides everything, quickly, and is confidently wrong is worse than one that asks about
everything — because the mistakes arrive faster and each one looks deliberate. The three properties
above are what separate the two, and **the guardrail design in this repository already assumes the
agent errs** ([`03-guardrails.md`](03-guardrails.md)). Nothing here contradicts that. The claim is
narrow and it is the same one [`07-ai-first.md`](07-ai-first.md) makes about authorship:

> On a decision space that is already framed, with a gate that runs in a minute and nothing shipped
> to break, an agent deciding and recording beats a person adjudicating a queue.

All three conditions are doing work. Remove the frame and it is invention; remove the gate and it is
guesswork; remove "nothing shipped" and it is someone else's outage.
