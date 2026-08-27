# Shipped documentation

The gem carries its own manual, and the CLI serves it locally. `magik docs` is the command an agent runs instead of a web search.

**Status:** implemented. This is one of the few pages in `docs/architecture/` that describes running code — `Magik::Docs`, `magik docs` and the packaging rule in `magik.gemspec` all exist and are tested. Verify with `ruby -Ilib exe/magik docs list` and `rake test`. Reviewed 2026-08-26.

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
| The packaging rule | [`../../magik.gemspec`](../../magik.gemspec) | `spec.files` includes `docs/**/*.md`, `wiki/**/*.md` and `llms.txt`, from `Magik::Docs::PACKAGED_GLOBS` |
| The resolver | [`../../lib/magik/docs.rb`](../../lib/magik/docs.rb) | finds the tree, derives the catalogue from the files, finds and searches pages |
| The command | [`../../lib/magik/cli/docs_command.rb`](../../lib/magik/cli/docs_command.rb) | `magik docs list` · `magik docs <slug>` · `magik docs search <term>` · `magik docs path` |

The glob list lives in exactly one place. `magik.gemspec` reads `Magik::Docs::PACKAGED_GLOBS` to decide what to package, and `Magik::Docs.pages` reads the same constant to build the catalogue, so `magik docs list` cannot advertise a page `gem build` left out. `test/magik/docs_test.rb` asserts the two agree anyway, because a constant shared today is a constant somebody forks tomorrow.

## What ships, and what does not

Shipping everything by reflex is not a decision. This is the decision.

### Ships

| Tree | Why |
|---|---|
| `wiki/**/*.md` | the app author's reference manual. The whole point of the exercise. |
| `docs/idea/**/*.md` | the DSL surface, the guardrails, the limits, the phases. `docs/idea/00-build-spec.md` in particular is named verbatim by `Magik::Error::DEFAULT_FIX` and by every spec-only stub's `NotImplementedError`. A `fix:` line pointing at a file the installed gem does not contain is a broken `fix:` line, and [`03-error-codes.md`](03-error-codes.md) forbids advice nobody can follow. |
| `docs/architecture/**/*.md` | contributor-facing, and it ships anyway — see below. |
| `docs/ops/**/*.md` | how to run the app you just built. |
| `llms.txt` | the machine-readable map, the first thing an agent reads. Its links are absolute `raw.githubusercontent.com` URLs, so it never dangles. |

`docs/architecture/**` was the close call. It documents how to build *this repository* — tier rules between `lib/magik/<subsystem>/`, `bin/check`, the YARD gate — none of which exists in a user's app, and an agent that follows those instructions inside an app is following the wrong loop. Two arguments carried it anyway:

1. **Dangling links are worse than surplus pages.** [`../README.md`](../README.md) and several `idea/` pages link into `architecture/` with relative paths. A shipped index whose links resolve to nothing teaches the reader that the tree is unreliable, which is a more expensive lesson than one extra directory.
2. **[`03-error-codes.md`](03-error-codes.md) is the design of the `MAGIK_*` catalogue** — the first thing anyone reads after hitting a code, in an app or in the framework.

"Not for you" belongs in the catalogue, not in the packaging. `Magik::Docs.pages` gives every page an `:audience`, and `magik docs list` groups by it.

### Does not ship

| Excluded | Why |
|---|---|
| `.claude/**` | subagents and slash commands for implementing *this framework*. Dropped into a user's app they are confidently wrong. An app gets its own `.claude/` from `lib/magik/cli/templates/app/.claude/`, which does ship. |
| `CONTRIBUTING.md`, `PUBLISHING.md`, `ROADMAP.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CLAUDE.md`/`AGENTS.md` | this repository's process, not the DSL. `llms.txt` links to them absolutely, so nothing dangles. |
| `dummy/**` | the demonstration app: large, and the rule it demonstrates is already written down in [`../../wiki/Project-Layout.md`](../../wiki/Project-Layout.md). |
| `test/`, `bin/`, `scripts/`, `docker/`, `.github/` | development machinery. |

`spec.files` is built as an **allowlist**, not a reject list, so a new top-level directory cannot reach a published gem until somebody names it in the gemspec on purpose.

## The audience split

Derived from the tree a page lives in — a rule, not a hand-maintained list, so a new file is catalogued the moment it is written.

| Prefix | Audience | Label in `magik docs list` |
|---|---|---|
| `wiki/`, `docs/ops/` | `app` | Building an app with Magik |
| `docs/idea/` | `both` | Both audiences — the design and the reference |
| `docs/architecture/` | `framework` | Contributing to Magik itself |
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

## Why there is no index

`Magik::Docs.search` reads every shipped file and does a case-insensitive substring match. No index, no inverted list, no dependency.

The tree is a few dozen small markdown files. Reading all of them is a few milliseconds — orders of magnitude faster than the network round trip it replaces, and faster than the index-invalidation bug an index would eventually introduce. Magik has **zero runtime dependencies** and this feature does not get to be the one that breaks that. If the tree ever grows to where a full scan is measurable, the fix is a benchmark first, an index second.

Results are ordered deterministically: pages with a matching **heading** first, then by hit count, then alphabetically. An agent re-running the same search gets the same answer in the same order.

## Root resolution

`Magik::Docs.root` is the directory that has `docs/`, `wiki/` and `llms.txt` inside it. Candidates, in order:

1. `MAGIK_DOCS_ROOT`, if set — for a vendored copy or a test fixture.
2. `Magik.root`, the parent of `lib/`. This is the checkout root when Magik is loaded from source and the gem root when it is installed, which is why one candidate covers both layouts.
3. The path RubyGems recorded for the loaded `magik` gem, for the cases where `lib/` was symlinked in.

The first candidate that actually contains a packaged page wins, so a layout with no docs is skipped rather than returned empty and confusing. Both layouts are tested in `test/magik/docs_test.rb`; the installed one against a throwaway tree built in `Dir.mktmpdir`.

## What this costs

Two real costs. Neither is hidden.

**Gem size.** Building the same gemspec with and without the documentation globs, `As of 2026-08-26`: **72 KB → 232 KB**, about **160 KB of compressed markdown**, roughly tripling the archive. The tree keeps growing, so re-derive rather than trusting the number:

```bash
gem build magik.gemspec && ls -l magik-*.gem
ruby -Ilib -e 'require "magik"; puts Magik::Docs.pages.size'
ruby -Ilib exe/magik docs list --json | ruby -rjson -e 'puts JSON.parse($stdin.read)["count"]'
```

It is worth it. That is one small image, downloaded once at install, in exchange for removing the failure mode that produces wrong code silently. The alternative is not "a smaller gem" — it is an agent inventing a DSL. `docs/architecture/**` is about a fifth of the raw doc bytes, which is what the close call above was actually worth.

**A doc change is now part of a release.** Editing `wiki/` on `main` does not reach anybody's installed gem. Every reader on `0.3` keeps reading the `0.3` manual until `0.4` ships. That is the trade, and it is the right way round: **a reader can never be shown a page that does not match the code they are running.** In practice it means [`PUBLISHING.md`](../../PUBLISHING.md)'s release checklist covers documentation, and a documentation fix is a patch release rather than a push to `main`.

## See also

- [`../idea/07-ai-first.md`](../idea/07-ai-first.md) — the argument this page implements, and the two-audience table the `:audience` field encodes.
- [`03-error-codes.md`](03-error-codes.md) — the `MAGIK_*` convention the four `MAGIK_DOCS_*` codes follow.
- [`../idea/09-app-scaffold.md`](../idea/09-app-scaffold.md) — the generated app harness, which points every subagent at `magik docs path`.
- [`../../wiki/CLI-Reference.md`](../../wiki/CLI-Reference.md) — the CLI surface as a whole.
