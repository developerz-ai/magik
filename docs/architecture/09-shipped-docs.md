# Shipped documentation

The gem carries its own manual, and the CLI serves it locally. `magik docs` is the command an agent runs instead of a web search.

**Status:** implemented. This is one of the few pages in `docs/architecture/` that describes running code — `Magik::Docs`, `magik docs` and the packaging rule in `apps/magik/magik.gemspec` all exist and are tested. Verify with `ruby -Iapps/magik/lib apps/magik/exe/magik docs list` and `rake -C apps/magik test`. Reviewed 2026-08-26; amended 2026-10-31 — every checkout-root `docs/` page ships as a generated mirror, and shipped pages link those copies.

## The problem

Magik invents a DSL. `model`, `screen`, `action`, `ledger`, `channel`, `flow` — none of it is in any language model's training data, and the words are all common Ruby nouns that mean something else in Rails, Sequel and Hanami. An agent asked to write Magik code without the reference in front of it does not fail loudly; it writes fluent, plausible, Rails-shaped Ruby and hands it over. That is the failure mode [`../idea/07-ai-first.md`](../idea/07-ai-first.md) names as *the* defect this whole framework is arranged against: a plausible invention.

The obvious answer — "the agent can look it up" — has three defects of its own.

| Fetching docs over the network | Why it fails an agent |
|---|---|
| **Slow** | a web search plus a fetch is seconds of latency inside a loop that runs dozens of times per feature. It gets skipped, and the agent guesses instead. |
| **Rate-limited and offline-hostile** | a sandboxed or air-gapped run has no network at all. The manual has to be present, not reachable. |
| **Version-blind** | a fetch returns whatever is on `main`. An app pinned to `magik 0.3` reads the DSL of `magik 0.9` and writes code its own gem cannot parse. Nothing in the transcript reveals the mismatch. |

Version-blindness is the one that actually hurts, because it is silent.

## The decision

**The documentation ships inside the gem, and the CLI reads it off the local filesystem.**

An installed gem carries exactly the documentation for the version installed. Not "roughly the same"; the same `.gem` archive. Version matching stops being something anyone has to check and becomes a property of how the file got there.

Three pieces:

| Piece | Where | Does |
|---|---|---|
| The packaging rule | [`../../apps/magik/magik.gemspec`](../../apps/magik/magik.gemspec) | `spec.files` is the allowlist `exe/**`, `lib/**/*`, `sig/**/*` plus `Magik::Docs::PACKAGED_GLOBS` — `llms.txt`, `wiki/**/*.md`, the generated mirrors under `docs/**/*.md`, and the checkout-only `../../docs/**/*.md` spelling |
| The resolver | [`../../apps/magik/lib/magik/docs.rb`](../../apps/magik/lib/magik/docs.rb) | finds the tree, derives the catalogue from the files, finds and searches pages |
| The command | [`../../apps/magik/lib/magik/cli/docs_command.rb`](../../apps/magik/lib/magik/cli/docs_command.rb) | `magik docs list` · `magik docs <slug>` · `magik docs search <term>` · `magik docs path` |
| The mirror check | [`../../apps/magik/scripts/checks/shipped_mirrors.rb`](../../apps/magik/scripts/checks/shipped_mirrors.rb) | renders every checkout-root `docs/` page into the gem at the same path relative to the gem root, and fails the gate when any committed copy is stale; `--write` regenerates |
| The link check | [`../../apps/magik/scripts/checks/shipped_links.rb`](../../apps/magik/scripts/checks/shipped_links.rb) | every relative link in a packaged page must resolve to another packaged file inside the gem root; no packaged page may link a packaged page through the repository's mutable `main`; no target may resolve against the reader's filesystem root |

The glob list lives in exactly one place. `magik.gemspec` reads `Magik::Docs::PACKAGED_GLOBS` to decide what to package, and `Magik::Docs.pages` reads the same constant to build the catalogue, so an installed gem's `magik docs list` cannot advertise a page `gem build` left out; a checkout catalogue is wider by design and also lists the repo-root trees under their `../../` spellings. `apps/magik/test/magik/docs_test.rb` asserts the packaging split anyway, because a constant shared today is a constant somebody forks tomorrow.

## What ships, and what does not

Shipping everything by reflex is not a decision. This is the decision.

### Ships

| Tree | Why |
|---|---|
| `wiki/**/*.md` | the app author's reference manual. The whole point of the exercise. |
| `llms.txt` | the machine-readable map, the first thing an agent reads. Links to packaged pages are gem-relative, so the map works offline inside the gem; only targets the gem does not carry keep repository URLs. |
| `docs/**/*.md` | the GENERATED mirrors of every checkout-root `docs/` page — the build spec the errors name, and every design page the manual itself links. Version-matched by construction. |
| `exe/**`, `lib/**/*`, `sig/**/*` | the code itself — in the same allowlist as the doc globs, not documentation, and the reason `spec.files` is one list rather than two. |

### The repo-root `docs/` trees, mirrored

Every page under the checkout-root `docs/` ships as a GENERATED mirror at the same path relative to the gem root — `apps/magik/docs/idea/00-build-spec.md`, `apps/magik/docs/architecture/…`, `apps/magik/docs/ops/…` — rendered from the original by [`apps/magik/scripts/checks/shipped_mirrors.rb`](../../apps/magik/scripts/checks/shipped_mirrors.rb), which fails the gate when any mirror is stale. A hand-maintained copy would drift; a generated one cannot, because the check is its only writer. Re-derive them: `ruby apps/magik/scripts/checks/shipped_mirrors.rb`.

Two reasons, one decision. `docs/idea/00-build-spec.md` is named by `Magik::Error::DEFAULT_FIX` and every spec-only stub's error message, and an installed gem has no repository around it — without the mirror, the recovery instruction in every error is unusable exactly where errors are handled. And the manual links the design pages — wiki pages point at [`04-swap-points.md`](../../docs/idea/04-swap-points.md) and the component-override ladder, the build spec at the DSL surface — so a shipped page that carried a repository URL would send an installed gem's reader to mutable `main`: the version-blindness failure this page names above, reproduced inside the manual (PR #11's review caught it). The mirror makes the packaged copy exist, and `shipped_links.rb` (`MAGIK_DEV_SHIPPED_LINK_MUTABLE_MAIN`) makes the `main` link impossible to reintroduce.

The originals stay at the checkout root, two levels above the gemspec — they are the source of truth, and the mirror is the check's render of them, never edited by hand. A checkout catalogue also serves the originals under their `../../` spelling: `PACKAGED_GLOBS` carries `../../docs/**/*.md`, which resolves in a checkout and is dropped by the gemspec's `../` reject, so only the mirrors ship. [`apps/magik/test/magik/docs_test.rb`](../../apps/magik/test/magik/docs_test.rb) asserts both halves of that split.

`docs/architecture/**` was once the close call, on the argument that these pages are the design record of *this repository* rather than reading for app authors. What retired the argument was the review above: version-matched design pages beat a link to `main`, and "who this is for" is the audience split's job — not the packaging's.

"Not for you" belongs in the catalogue, not in the packaging. `Magik::Docs.pages` gives every page an `:audience`, and `magik docs list` groups by it.

### Does not ship

| Excluded | Why |
|---|---|
| `.claude/**` | subagents and slash commands for implementing *this framework*. Dropped into a user's app they are confidently wrong. An app gets its own `.claude/` from `lib/magik/cli/templates/app/.claude/`, which does ship. |
| `CONTRIBUTING.md`, `PUBLISHING.md`, `ROADMAP.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CLAUDE.md`/`AGENTS.md` | this repository's process, not the DSL. `llms.txt` and the wiki link to them by absolute repository URLs, so nothing dangles — [`apps/magik/scripts/checks/shipped_links.rb`](../../apps/magik/scripts/checks/shipped_links.rb) asserts no packaged page carries a relative link that leaves the gem dir. |
| `dummy/**` | the demonstration app: large, and the rule it demonstrates is already written down in [`../../apps/magik/wiki/Project-Layout.md`](../../apps/magik/wiki/Project-Layout.md). |
| `test/`, `bin/`, `scripts/`, `docker/`, `.github/` | development machinery. |

`spec.files` is built as an **allowlist**, not a reject list, so a new top-level directory cannot reach a published gem until somebody names it in the gemspec on purpose.

## The audience split

Derived from the tree a page lives in — a rule, not a hand-maintained list, so a new file is catalogued the moment it is written.

| Prefix | Audience | Label in `magik docs list` |
|---|---|---|
| `wiki/`, `docs/ops/` — and, from a checkout, `../../docs/ops/` | `app` | Building an app with Magik |
| `docs/idea/`, `../../docs/idea/` | `both` | Both audiences — the design and the reference |
| `docs/architecture/`, `../../docs/architecture/` | `framework` | Contributing to Magik itself |
| anything else (`llms.txt`, `docs/README.md`) | `both` | — |

This is the same A/B split [`../idea/07-ai-first.md`](../idea/07-ai-first.md) draws between the agent implementing Magik and the agent building an app with it, made machine-readable.

## The interface

```bash
magik docs                        # the catalogue, grouped by audience
magik docs list --json            # the same, as data
magik docs wiki/models            # one page, raw markdown
magik docs models                 # the same page, by shorthand
magik docs search ledger          # matching pages, with line numbers
magik docs path                   # the directory, and nothing else
```

Raw markdown is deliberate: the reader is an agent, not a pager, and rendering only removes information.

**`magik docs path` is the load-bearing one.** It prints one absolute path and nothing else, so an agent can point the file tools it already has at the tree:

```bash
grep -rn "tenant_id" "$(magik docs path)"
```

That beats any output format this command could invent. A CLI can only answer the questions it anticipated; a directory answers the ones it did not. Every other subcommand is a convenience on top of the fact that the files are simply *there*.

This is why the generated app harness leans on `magik docs path` rather than on `magik docs <slug>`: every subagent and slash command in [`../idea/09-app-scaffold.md`](../idea/09-app-scaffold.md) restates the instruction scoped to its own surface, because an activated subagent never reads the app's shared `CLAUDE.md`. A path an agent can grep needs no instruction beyond the path.

`--json` is on every subcommand, with a stable schema keyed by `"command"`: `docs.list`, `docs.page`, `docs.search`, `docs.path`. Errors follow the house rule — `MAGIK_*` code, cause, runnable `fix:`, and with `--json` they go to stdout, not stderr.

| Code | Raised when |
|---|---|
| `MAGIK_DOCS_UNAVAILABLE` | no shipped documentation tree could be found under any candidate root |
| `MAGIK_DOCS_PAGE_NOT_FOUND` | a slug or path names no shipped page |
| `MAGIK_DOCS_AMBIGUOUS_PAGE` | a shorthand matches several pages — it refuses rather than guessing |
| `MAGIK_DOCS_MISSING_TERM` | `magik docs search` was given nothing to search for |

## The prose half of a two-part surface

`magik docs` is one of two lookup surfaces the design calls for, and it is the half that exists. The other is **`magik describe`** — a phase-1 command, **not implemented** — which serializes the option tables the DSL validates against ([`01-module-map.md`](01-module-map.md#the-option-tables-and-magik-describe)). They answer different questions and must not restate each other:

| | `magik docs` (implemented) | `magik describe` (planned) |
|---|---|---|
| Answers | why this construct exists, when to reach for it, what it refuses | what options it takes, of what type, with what default and what legal values |
| Source | markdown packaged in the gem | the option tables the coercer reads — derived, never hand-maintained |
| Fails when | prose rots relative to code | impossible by construction: it *is* the code |
| Entry point for | "I do not know which construct this is" | "I know it is a `job`; I do not know the retry option's spelling" |

The join is one field: every `describe` entry carries a `doc:` slug this command resolves, so an agent goes schema → prose in one hop and never has to search. That is also why both ship **inside the gem** rather than being fetched: a schema or a page pulled from `main` describes a version the reader is not running. Design: [`../idea/11-dsl-as-tool-surface.md`](../idea/11-dsl-as-tool-surface.md) §2.

## Why there is no index

`Magik::Docs.search` reads every shipped file and does a case-insensitive substring match. No index, no inverted list, no dependency.

The tree is a few dozen small markdown files. Reading all of them is a few milliseconds — orders of magnitude faster than the network round trip it replaces, and faster than the index-invalidation bug an index would eventually introduce. Magik has **zero runtime dependencies** and this feature does not get to be the one that breaks that. If the tree ever grows to where a full scan is measurable, the fix is a benchmark first, an index second.

Results are ordered deterministically: pages with a matching **heading** first, then by hit count, then alphabetically. An agent re-running the same search gets the same answer in the same order.

## Root resolution

`Magik::Docs.root` is the directory that has `wiki/` and `llms.txt` inside it — and, in a repository checkout, the repo-root `docs/` trees one `../../` step above it. Candidates, in order:

1. `MAGIK_DOCS_ROOT`, if set — for a vendored copy or a test fixture.
2. `Magik.root`, the parent of `lib/`: `apps/magik` when Magik is loaded from this checkout, the gem root when it is installed. One candidate covers both layouts.
3. The path RubyGems recorded for the loaded `magik` gem, for the cases where `lib/` was symlinked in.

The first candidate that actually contains a packaged page wins, so a layout with no docs is skipped rather than returned empty and confusing. Both layouts are tested in `apps/magik/test/magik/docs_test.rb`; the installed one against a throwaway tree built in `Dir.mktmpdir`.

## What this costs

Two real costs. Neither is hidden.

**Gem size.** Whether the manual travels with the gem is the difference between a code-only archive and a documented one — measure it rather than trusting a number here, especially now that the generated mirrors carry the checkout-root `docs/` trees, which are the largest share of the prose:

```bash
(cd apps/magik && gem build magik.gemspec) && ls -l apps/magik/magik-*.gem
ruby -Iapps/magik/lib -e 'require "magik"; puts Magik::Docs.pages.size'
ruby -Iapps/magik/lib apps/magik/exe/magik docs list --json | ruby -rjson -e 'puts JSON.parse($stdin.read)["count"]'
```

It is worth it. That is one small image, downloaded once at install, in exchange for removing the failure mode that produces wrong code silently. The alternative is not "a smaller gem" — it is an agent inventing a DSL.

**A doc change is now part of a release.** Editing `wiki/` on `main` does not reach anybody's installed gem. Every reader on `0.3` keeps reading the `0.3` manual until `0.4` ships. That is the trade, and it is the right way round: **a reader can never be shown a page that does not match the code they are running.** In practice it means [`PUBLISHING.md`](../../apps/magik/PUBLISHING.md)'s release checklist covers documentation, and a documentation fix is a patch release rather than a push to `main`.

## See also

- [`../idea/07-ai-first.md`](../idea/07-ai-first.md) — the argument this page implements, and the two-audience table the `:audience` field encodes.
- [`03-error-codes.md`](03-error-codes.md) — the `MAGIK_*` convention the four `MAGIK_DOCS_*` codes follow.
- [`../idea/09-app-scaffold.md`](../idea/09-app-scaffold.md) — the generated app harness, which points every subagent at `magik docs path`.
- [`../../apps/magik/wiki/CLI-Reference.md`](../../apps/magik/wiki/CLI-Reference.md) — the CLI surface as a whole.
