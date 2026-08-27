# scripts/

The executable checks that make this repository self-verifying.

Every rule this repo states in prose — the tier table, the `MAGIK_*` code format, the "never claim
unimplemented behaviour" vocabulary, the documented commands — is a convention until something
fails when it is broken. `docs/architecture/00-conventions.md` puts it plainly: a convention with no
check does not really exist. This directory is where the checks live.

**One check is one program.** It answers one question about this repository, it runs on its own, it
exits `0` or `1`, it speaks `--json`, and when it fails it prints a runnable `fix:`. `bin/check`
discovers them by globbing this directory — it does not list them — so adding a check is adding a
file.

```bash
ruby scripts/checks/boundaries.rb          # one check, human output
ruby scripts/checks/boundaries.rb --json   # one JSON object on stdout, nothing else
ruby scripts/checks/boundaries.rb --help   # what it asserts and why
```

## The checks

Run them, do not read this table for a verdict:

```bash
for check in scripts/checks/*.rb; do ruby "$check"; done
```

| Check | What it catches |
|---|---|
| [`boundaries`](checks/boundaries.rb) | a `require` or constant reference inside `lib/magik/` that goes sideways or up a tier, one that reaches past another subsystem's front door, and a document whose `tier N` block no longer matches [`lib/tiers.rb`](lib/tiers.rb) |
| [`error-codes`](checks/error_codes.rb) | a `Magik::Error` subclass with a malformed code, an inherited code, a duplicate code or a `fix:` that is advice; drift in **both** directions between the shipped codes and [`../wiki/Error-Codes.md`](../wiki/Error-Codes.md)'s "Live today" table; a reserved name in either catalogue outside `MAGIK_<SUBSYSTEM>_<CONDITION>`; and a `MAGIK_DEV_*` code in `bin/` that is misspelled or printed with no `fix:` |
| [`spec-only-drift`](checks/spec_only_drift.rb) | a subsystem in `Magik::SPEC_ONLY_SUBSYSTEMS` whose `.define` no longer raises `NotImplementedError`, one outside the list that still does, and a `STATUS` constant that disagrees with either |
| [`doc-commands`](checks/doc_commands.rb) | a shell command in a fenced block in `README.md`, `CLAUDE.md`, `CONTRIBUTING.md` or `wiki/` that this repo does not provide — a missing `bin/` script, an undefined rake task, a `magik` subcommand absent from `Magik::CLI::COMMANDS`, or a `/slash-command` with no file behind it |
| [`changelog`](checks/changelog.rb) | `CHANGELOG.md` losing its `[Unreleased]` section, never gaining one for `Magik::VERSION`, an undated or unlinked release heading, releases out of order, or a `###` that is not a Keep a Changelog change type |
| [`version-consistency`](checks/version_consistency.rb) | the gemspec, the newest changelog release, or any doc that names a `magik` version disagreeing with `lib/magik/version.rb` — and a corpus in which nothing states the version at all |
| [`dummy-parses`](checks/dummy_parses.rb) | a syntax error under `dummy/`. That is the only property the reference app has while the framework is spec only, and this check asserts exactly it |
| [`manifest`](checks/manifest.rb) | `../magik.manifest.json` no longer describing the tree — a subsystem, an error code or a check added, removed or renamed without regenerating it |

Two checks that were considered and deliberately **not** written:

- **`yard-coverage`** — `bin/check`'s `yard` step already asserts the documentation floor, reading
  `MAGIK_YARD_MIN_COVERAGE` and defaulting to 100. A second copy of one rule is exactly the drift
  the rest of this directory exists to prevent. If the gate is ever refactored so that every rule
  lives here, that step's body moves into `scripts/checks/yard_coverage.rb` verbatim — it does not
  get rewritten.
- **`markdown-links`** — likewise already the `docs` step of `bin/check`.

## The discovery contract

`bin/check` reads a check's name, description and cost order from a **comment header**, not from
Ruby. One `File.foreach` per file: no gem is loaded, no check is executed, and `bin/check --list`
still works when a check is syntactically broken. It is also the only copy of that metadata — the
`Check` subclass does not restate its name — so the two cannot drift apart.

Every file in `scripts/checks/` must begin like this:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# @check   boundaries
# @summary Requires and constant references inside lib/magik/ go down a tier only.
# @order   10
#
# Everything from here to the end of the comment block is the check's --help
# text. Say what the rule is, why it exists, which finding codes it can raise,
# and what it deliberately cannot see.
```

| Tag | Rule |
|---|---|
| `@check` | lowercase, hyphen-separated. Must equal the file's basename with `_` for `-`, so `--only error-codes` and `scripts/checks/error_codes.rb` are the same thing. Unique across the directory |
| `@summary` | one line. It becomes the step title in `bin/check` and the first line of `--help` |
| `@order` | a positive integer, cheapest first, unique across the directory so the run order is total |

A file here with no readable header raises `MagikScripts::Registry::HeaderError` — loudly, never a
skip. A check that quietly drops out of discovery is a check that has quietly stopped gating.

## The result contract

| Exit | Meaning |
|---|---|
| `0` | the check is satisfied |
| `1` | the repository is wrong — the findings say where |
| `64` | bad usage (`EX_USAGE`): an unknown flag |
| `69` | a tool the check needs is not installed (`EX_UNAVAILABLE`). Nothing is broken; the fix is the install command it prints |

These are `bin/check`'s own codes, so a check run by hand and the same check run through the gate
are machine-indistinguishable.

`--json` is one object on stdout and nothing else:

```json
{
  "check": "boundaries",
  "summary": "...",
  "order": 10,
  "path": "scripts/checks/boundaries.rb",
  "duration_ms": 71,
  "ok": true,
  "status": "pass",
  "exit_code": 0,
  "reason": null,
  "expected": "...",
  "got": "24 files scanned (21 inside a subsystem), 20 subsystems tiered, 2 documents agree",
  "fix": null,
  "findings": []
}
```

A finding is the shape [`../docs/architecture/03-error-codes.md`](../docs/architecture/03-error-codes.md)
prescribes — `code`, `cause`, `fix`, `at`:

```text
  MAGIK_BOUNDARY_TIER (lib/magik/model.rb:4)
    cause: model (tier 2) requires action (tier 3); dependencies go down a tier only
    fix:   delete the dependency at lib/magik/model.rb:4 — model may use: core, i18n, router, schema
```

`code` is a `MAGIK_*` name in the format the framework uses. These are **check-stage** codes: they
are not `Magik::Error` subclasses and they are not in `wiki/Error-Codes.md`'s live table, because
nothing in `lib/` raises them. They belong to the `check` subsystem, which is spec only. They use
the framework's format so that when `lib/magik/check/errors.rb` is written, the catalogue entries
already exist under the names people have been reading.

`cause` names real identifiers and says what the consequence is. `fix` is a command to run or an
edit naming a file — never advice, and never with an angle-bracket placeholder in it, because a fix
line is something somebody pastes.

## `lib/`

Small on purpose. This is a helper library, not a framework.

| File | What it provides |
|---|---|
| [`scripts.rb`](lib/scripts.rb) | the front door. Requires the rest and does nothing else |
| [`repo.rb`](lib/repo.rb) | `Repo.root`, `Repo.read`, and `Repo.glob`, which honours `.rubocop.yml`'s exclusions and skips `dummy/` unless a check opts in |
| [`check.rb`](lib/check.rb) | the `Check` base class: the `#run` contract, and `#nothing_scanned` for the empty-corpus case |
| [`result.rb`](lib/result.rb) | `Result` — three statuses (`pass`, `fail`, `missing`), their exit codes, and the JSON body |
| [`finding.rb`](lib/finding.rb) | `Finding` — `code`, `cause`, `fix`, `at`, and the two renderings |
| [`registry.rb`](lib/registry.rb) | header parsing and discovery: the contract above, enforced |
| [`runner.rb`](lib/runner.rb) | the shared command line — `--json`, `--help`, exit codes |
| [`gate.rb`](lib/gate.rb) | the adapter `bin/check` wires in. Not loaded by checks |
| [`markdown.rb`](lib/markdown.rb) | fenced blocks, links, sections and table rows, all with line numbers |
| [`shell.rb`](lib/shell.rb) | a quote-aware reader for the shell snippets documentation shows |
| [`ruby_source.rb`](lib/ruby_source.rb) | requires and constant references, via `Ripper` rather than a regex |
| [`tiers.rb`](lib/tiers.rb) | the executable copy of the tier table, and a parser for the prose one |
| [`library.rb`](lib/library.rb) | loads the gem from `lib/` and answers questions about it |
| [`manifest.rb`](lib/manifest.rb) | builds `magik.manifest.json` and reports drift section by section |

Requiring any of them has no side effects: nothing reads a file, starts a subprocess or mutates a
constant at load time.

## Adding a check

1. **Name the question.** One question, answerable yes or no about this repository. If it takes two
   sentences it is two checks.
2. **Write the header** — `@check`, `@summary`, `@order`, then prose saying what the rule is, why it
   exists, which finding codes it raises, and what it deliberately cannot see. That prose is the
   `--help` output; there is no second copy.
3. **Split the rule from the collector.** A class method that takes plain data and returns findings,
   and a `#run` that reads the real tree and calls it. A rule that can only be exercised by editing
   the repository has no negative case.
4. **Make zero inputs a failure.** Call `nothing_scanned` when the corpus is empty. A glob that
   matches nothing reads exactly like a clean tree, and that is the failure mode that survives every
   refactor: somebody moves a directory and the check goes quiet instead of red.
5. **Give every finding a `code`, a `cause`, a `fix` and an `at`.** The `fix` is runnable.
6. **End the file** with `exit MagikScripts::Runner.main(__FILE__, TheCheck) if $PROGRAM_NAME == __FILE__`,
   so requiring it defines the class and runs nothing.
7. **`chmod +x`** the file — RuboCop's `Lint/ScriptPermission` asks for it, and so does the shebang.
8. **Write `test/scripts/<name>_test.rb`**, including the failing case. See below.
9. **Regenerate the manifest**: `ruby scripts/checks/manifest.rb --write`.
10. **Run it**: `ruby scripts/checks/<name>.rb`, then `--json`, then `--help`, then
    `bundle exec rake test` and `bundle exec rubocop`.

Nothing in `bin/check` changes. That is the point of the header.

## A check ships with a failing-case test

**A check that cannot fail is not a check.** Every check has a test in
[`../test/scripts/`](../test/scripts/) that proves it detects the thing it is for, using a fixture
rather than a mutilated repository — that is what the pure/collector split in step 3 is for.

Each test file covers four things:

| Section | Why |
|---|---|
| **Detection** | one test per finding code, asserting the code, the `at`, and that the `fix` names the right file |
| **Silence** | the correct inputs it must *not* report. One false positive on a page that is right is how a check gets switched off rather than fixed |
| **Vacuity** | zero inputs is a failure, never a pass |
| **The real tree** | where the check is green today, the test asserts it stays green, so `rake test` is the build error |

Two shared tests hold every check to the directory's contract, so a new check inherits them:
[`registry_test.rb`](../test/scripts/registry_test.rb) proves every file here is discoverable, and
[`runner_test.rb`](../test/scripts/runner_test.rb) proves every check speaks `--json`, answers
`--help`, exits a known code, and — when it fails — names findings that all carry a `MAGIK_*` code
and a non-empty `fix`.

The tests run on bare Ruby with no bundle, like the rest of the suite. Dev gems stay behind
`rescue LoadError` in `test/test_helper.rb`.

## `magik.manifest.json`

Generated at the repo root by `ruby scripts/checks/manifest.rb --write`, and checked for staleness
by the `manifest` check. Everything in it is derived from the tree — the subsystems and their
tier, phase and status; the error codes and the file that owns each; the checks and their cost
order — so a field nobody can derive does not belong in it.

`build_id` is the full SHA-256 of the canonical body, never truncated: a shortened digest is a
collision the drift check would read as fresh. Drift is reported section by section rather than as
a byte diff, so the message says *what* went stale, and a body that matches under a hand-edited
digest is still drift.

It is a repository artefact and is not packaged into the gem — `magik.gemspec`'s file list is an
allowlist, and neither `scripts/` nor the manifest is on it.

## Not to be confused with

`lib/magik/cli/templates/app/scripts/` is a **different** directory: the checks `magik new` writes
into a generated application, which check that application's code. This directory checks the
framework repository. They share a shape, not a code path.
