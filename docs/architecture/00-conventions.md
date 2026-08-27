# The coding contract

The rules every Ruby file in this repo obeys, and the design rules the framework asks its users to obey too.

**Status:** planned. The repo currently contains `lib/magik/version.rb` and nothing else; every check named here is a check somebody still has to write. Reviewed 2026-08-26.

Rationale lives in [`../idea/01-thesis.md`](../idea/01-thesis.md). This file is the rules.

## Axioms, applied to code

| Axiom | What it means while you are typing |
|---|---|
| The primary developer is an agent | one obvious way to do the thing, and a check that says whether you did it |
| One DSL grammar | a new construct that does not read like the existing ones is a rejected design, not a style nit |
| Guardrails are the product | shipping a construct means shipping its boot check |
| Errors are instructions | every raise carries a `MAGIK_*` code, a cause with real identifiers, and a runnable `fix:` |
| Cost is opt-in | a feature nobody declared costs zero queries, zero sockets, zero rows |
| Swaps ship proven | a backend is listed only when its conformance suite is green in CI |

## No framework code that is not spec-backed

The single most important rule in this repo while it is empty.

| Rule | Detail |
|---|---|
| Every construct traces to the spec | a PR adding DSL, a CLI command or a guardrail names the [`../idea/00-build-spec.md`](../idea/00-build-spec.md) section it implements. |
| The spec wins | where a doc and the spec disagree, the doc is wrong and gets fixed. |
| Extending the spec is a spec change | a genuinely new idea edits the spec first, in its own commit, with the argument. Inventing behaviour in `lib/` and documenting it afterwards is how a framework acquires surface nobody chose. |
| Stubs over fakes | an unimplemented method raises `NotImplementedError` naming the spec section and the phase. A plausible-looking fake is worse than an empty file. |

```ruby
# @raise [NotImplementedError] always — spec Phase 3, not implemented
def broadcast(channel, event, payload)
  raise NotImplementedError, "Magik::Realtime#broadcast — spec Phase 3, not implemented"
end
```

## SOLID, and single responsibility above all

SOLID is a written contract here, in **two** places: the framework's internals, and the app code Magik's users (and their agents) write. The second is the harder claim, and it is the one the DSL is shaped around — following SRP in a Magik app should be the path of least resistance, not an act of discipline.

### SRP, concretely for Ruby

**One class, one reason to change.** In this repo that means many small objects under `lib/magik/<subsystem>/`, each with a name that says what it does and a public surface you can hold in your head.

The smell, and the split:

| Smell | Why it happens | The split |
|---|---|---|
| A 400-line `Magik::Model` that validates, queries, serializes and renders | the DSL entry point becomes the dumping ground for everything the DSL touches | `Model::Definition` (the declaration), `Model::Validator`, `Model::Dataset`, `Model::Serializer` — the DSL method is a thin front door that builds a `Definition` |
| A `Compiler` that parses, plans and emits | three reasons to change wearing one name | `Compiler::Parser` → `Compiler::Plan` → `Compiler::Emitter`, one direction, values between |
| A class whose name contains `Manager`, `Handler`, `Service`, `Util` or `Helper` | nobody could name the single responsibility, so they named the absence of one | rename it after what it does; if you cannot, it is two objects |
| A method taking a `mode:`, `kind:` or `type:` flag that selects a branch | a second responsibility smuggled in as an argument | one object per mode, chosen at the seam |
| `private` methods outnumbering public ones three to one | a smaller object is hiding inside | extract it, give it a name, test it directly |

**Measurable form**, so `bin/check` can enforce it later. These are the intended thresholds, and the enforcement is **planned, not built** — today they are review guidance:

| Metric | Target | Hard ceiling | Intended enforcement |
|---|---|---|---|
| File length | < 150 lines | 300 | `bin/check` (planned) |
| Public methods per class | ≤ 7 | 12 | `bin/check` (planned) |
| Collaborators (distinct types a class instantiates or calls) | ≤ 4 | 6 | `bin/check` (planned) |
| Method length | < 15 lines | 25 | RuboCop `Metrics/MethodLength` |
| Cyclomatic complexity | — | RuboCop default | RuboCop `Metrics/CyclomaticComplexity` |

A ceiling is not a budget to spend. Crossing one means the split was due earlier.

### The other four, in Ruby idiom

| Letter | In Magik | Consequence you can check |
|---|---|---|
| **Open/closed** | the swap points are the extension seams ([`../idea/04-swap-points.md`](../idea/04-swap-points.md)). New behaviour arrives as a new object registered with the framework — never as a new branch in a `case` inside an existing one. | a `case` statement over backend names in `lib/` is a defect. The registry does the dispatch. |
| **Liskov** | a backend must satisfy the seam's contract test — which is the spec's "a swap ships proven, not promised" rule stated as a type property. | one conformance suite per seam, run against every backend in CI. A backend that needs its own special-cased test has broken the seam. |
| **Interface segregation** | a subsystem depends on the narrow role it uses, not on the whole neighbouring module. `render` needs a channel *name*, not the realtime subsystem — so the channel-name vocabulary lives in `core` and `render` never requires `realtime`. | the tier rules in [`02-boundaries.md`](02-boundaries.md). A `require` that exists to reach one method is a role that belongs lower down. |
| **Dependency inversion** | subsystems depend on an abstraction the app configures at boot — the DB adapter, the job backend, the realtime backend, the cache. `jobs` knows a queue role; it does not know Postgres. | this is *why* swap points can exist at all. A subsystem naming a concrete product outside its `backends/` directory is a defect. |

### The same rules apply to app code

The DSL is designed so that a Magik app falls into SRP by default:

| App-level rule | How the framework makes it the default |
|---|---|
| One declaration per file | generators emit it that way; `App.define`'s `load` walks directories, so adding a file is the whole ceremony |
| One directory per concern | `app/models/`, `app/screens/`, `app/actions/`, `app/jobs/`, `app/ledgers/`, `domains/<name>/` |
| An action mutates; a job runs async; a ledger touches money | the grammar gives each its own construct, so mixing them requires going out of your way |
| A screen renders and holds nothing | the stateless guardrail refuses the alternative at boot ([`../idea/03-guardrails.md`](../idea/03-guardrails.md)) |
| A domain owns its models | boundary enforcement refuses the reach-across at boot ([`02-boundaries.md`](02-boundaries.md)) |

The app-side layout and a worked example live in `wiki/Project-Layout.md` and the `dummy/` reference app.

## File layout

One gem, subsystems under `lib/magik/<subsystem>/`. Not a multi-gem monorepo — extraction stays possible, and is not promised.

```
lib/magik.rb                          # requires core, defines Magik::VERSION entry point
lib/magik/version.rb
lib/magik/<subsystem>.rb              # the subsystem's front door: requires its files, defines its namespace
lib/magik/<subsystem>/errors.rb       # this subsystem's MAGIK_* codes
lib/magik/<subsystem>/<concern>.rb    # one responsibility each
lib/magik/<subsystem>/backends/<name>.rb   # only where the subsystem owns a swap point
exe/magik                             # the CLI binary
test/magik/<subsystem>/<concern>_test.rb
```

| Rule | Detail |
|---|---|
| Subsystem names | exactly the twenty in [`01-module-map.md`](01-module-map.md). A new one is an architecture change, not a file. |
| File names | `snake_case.rb`, matching the class or module they define. |
| One class per file | except a tiny value object used only by its neighbour. |
| Front door | `lib/magik/<subsystem>.rb` is the only file another subsystem may require. Reaching into `lib/magik/model/dataset.rb` from `lib/magik/api/` is a boundary violation even when the tier allows the subsystem ([`02-boundaries.md`](02-boundaries.md)). |
| `require_relative` inside a subsystem, `require` across | so the dependency direction is visible in the first ten lines of every file. |

## Ruby style

| Rule | Detail |
|---|---|
| Magic comment | `# frozen_string_literal: true` on every file, first line. |
| Indentation | two spaces, no tabs. |
| Module nesting | nested, not compact — `module Magik; module Model; class Definition` — so constant lookup is unambiguous. |
| Naming | `CamelCase` classes and modules, `snake_case` methods and variables, `SCREAMING_SNAKE` constants, `?`/`!` used for their conventional meanings only. |
| Keyword arguments | for anything with two or more parameters, and always for booleans. No positional flags. |
| Frozen state | constants holding collections are `.freeze`d. The declaration registry is frozen when boot completes — that is what makes the stateless guardrail checkable, and what keeps a Ractor-parallel test run honest ([`04-testing-strategy.md`](04-testing-strategy.md)). |
| Mutable globals | none after boot. No `$globals`, no class-level mutable accumulators outside the registry. |
| Comments | explain **why**. Never what. |
| Lint | RuboCop plus `rubocop-minitest`, `rubocop-rake`, `rubocop-performance`. The config in the repo root is the arbiter; disabling a cop inline needs a comment naming the reason. |

### Runtime

| Rule | Detail |
|---|---|
| Production target | TruffleRuby. |
| Development floor | CRuby ≥ 3.2 (`required_ruby_version = ">= 3.2"`). |
| TruffleRuby-specific behaviour | verified in CI, never in a local hook — no TruffleRuby is assumed on a developer machine, `As of 2026-08-26`. |
| Ractor discipline | anything intended to cross a Ractor boundary must be frozen or shareable. Do not add mutable shared state to a subsystem without saying how the test runner is meant to survive it. |

## YARD on every public method

Documentation is a shipping requirement, not a later pass. `.yardopts` at the root drives it; CI publishes to GitHub Pages.

```ruby
# Declares a background job.
#
# @param name [Symbol] the job's PascalCase name, e.g. +:SettleBatch+
# @yield the job body — +retry+, +schedule+, +unique_by+ and +perform+ declarations
# @return [Magik::Jobs::Definition] the frozen definition, registered with the app
# @raise [Magik::Error] +MAGIK_JOBS_NO_PERFORM+ if the block declares no +perform+
# @example
#   job :SettleBatch do
#     retries times: 5, backoff: :exponential
#     perform { |args| Payments.settle(tenant_id: args[:tenant_id]) }
#   end
# @see https://github.com/developerz-ai/magik/blob/main/docs/idea/02-dsl-surface.md
def job(name, &block)
```

| Rule | Detail |
|---|---|
| Every public method | a summary line, `@param` for each parameter, `@return`, and `@raise` for every error code it can produce. |
| Every DSL entry point | additionally an `@example` showing the canonical shape from [`../idea/02-dsl-surface.md`](../idea/02-dsl-surface.md). |
| Private methods | documented where the *why* is not obvious. Not required. |
| Unimplemented | say so, with the phase: `@note Not implemented — spec Phase 4.` |
| Enforcement | a YARD coverage step in `bin/check` (planned). Undocumented public methods fail it. |

## Errors

**Never raise a bare `RuntimeError`, `ArgumentError` or `StandardError`.** Every raise is a `Magik::Error` subclass carrying a code, a cause and a fix.

```ruby
raise Magik::Ledger::UnbalancedEntry.new(
  code:     "MAGIK_LEDGER_UNBALANCED",
  cause:    "entry :refund debits #{debits.inspect} and credits #{credits.inspect}",
  location: "#{file}:#{line}",
  fix:      "magik errors explain MAGIK_LEDGER_UNBALANCED"
)
```

| Rule | Detail |
|---|---|
| Code format | `MAGIK_` + `SUBSYSTEM` + `_CONDITION`, screaming snake. |
| Stability | a shipped code is stable forever. Agents and log pipelines match on it. |
| Registration | in `lib/magik/<subsystem>/errors.rb`, one catalogue entry per code. |
| Renderings | one object, three outputs: terminal, `--json`, dev error page. |

Full design: [`03-error-codes.md`](03-error-codes.md). Diagnostics around it: [`06-observability.md`](06-observability.md).

## Tests

Minitest and Rake. Never RSpec — a spec decision, and the reasoning is in [`../idea/05-limits.md`](../idea/05-limits.md).

| Rule | Detail |
|---|---|
| Location | `test/magik/<subsystem>/<concern>_test.rb`, mirroring `lib/`. |
| Naming | `class DefinitionTest < Magik::TestCase`, methods `test_<what_it_proves>`. |
| Bar | every test must be able to fail for a real reason. `assert true` is worse than no test. |
| Determinism | frozen clock, seeded randomness, no network. An unmocked socket fails the test. |
| Order | tests run in a randomized order and in parallel; a test that depends on another is broken. |

Strategy, the runner, and the parallelism design: [`04-testing-strategy.md`](04-testing-strategy.md).

## Commits and changelog

| Rule | Detail |
|---|---|
| Changelog | every user-visible change adds a `CHANGELOG.md` entry in the same commit. |
| Status vocabulary | `planned`, `not implemented`, `spec only`. Never a benchmark number or a passing-test count for behaviour that does not exist. |
| Dates | any claim that can go stale is stamped `As of YYYY-MM-DD`. |
| The gate | `bin/check` (planned) — lint, tests, YARD coverage, boundaries, docs. Green means the change is landable. |
