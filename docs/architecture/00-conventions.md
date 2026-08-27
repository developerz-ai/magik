# The coding contract

The rules every Ruby file in this repo obeys, and the design rules the framework asks its users to obey too.

**Status:** mostly planned. `lib/` holds `Magik::Error`, the CLI's implemented commands and one spec-only stub per subsystem; no DSL construct exists, and most checks named here are checks somebody still has to write. Re-derive what is a stub with `grep -rln NotImplementedError lib/magik`. Reviewed 2026-08-26.

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

### The same rules apply to app code — including code Magik generates

A generator emits code somebody will read, review and extend, so it obeys this contract exactly as `lib/` does. A generator that emits a 400-line god object, or a second write path, has shipped the smell rather than the shape. The DSL is designed so that a Magik app falls into SRP by default:

| App-level rule | How the framework makes it the default |
|---|---|
| One declaration per file | generators emit it that way; `App.define`'s `load` walks directories, so adding a file is the whole ceremony |
| One directory per concern | `app/models/`, `app/screens/`, `app/actions/`, `app/jobs/`, `app/ledgers/`, `domains/<name>/` |
| An action mutates; a job runs async; a ledger touches money | the grammar gives each its own construct, so mixing them requires going out of your way |
| A screen renders and holds nothing | the stateless guardrail refuses the alternative at boot ([`../idea/03-guardrails.md`](../idea/03-guardrails.md)) |
| A domain owns its models | boundary enforcement refuses the reach-across at boot ([`02-boundaries.md`](02-boundaries.md)) |

The app-side layout and a worked example live in [`../../wiki/Project-Layout.md`](../../wiki/Project-Layout.md) and the [`../../dummy/`](../../dummy/) reference app.

## DSL design rules: R1–R10

SOLID governs the objects inside a subsystem. **R1–R10 govern the construct those objects put in front of an app author**, and they are cited by number across the spec, so they are indexed here rather than restated: the rules are stated in full, with their reasoning, in [`../idea/11-dsl-as-tool-surface.md`](../idea/11-dsl-as-tool-surface.md) §4, and that page proposes exactly this pointer.

They exist because **the DSL is a tool surface**: an agent does not recall a grammar, it looks one up, so an option that cannot be looked up may as well not exist. And a DSL option is authored once and read forever — renaming one after release is a breaking change under semver — so the rules apply before the first construct ships, not after.

| # | Rule | The failure it prevents |
|---|---|---|
| [R1](../idea/11-dsl-as-tool-surface.md#r1--one-concept-one-spelling-everywhere) | One concept, one spelling, everywhere | an agent generalises from one construct to the next; an idea spelled two ways turns that generalisation into a plausible wrong guess. Sharing a stem while meaning different things is the worst of both |
| [R2](../idea/11-dsl-as-tool-surface.md#r2--enumerated-beats-free-form) | Enumerated beats free-form | a closed value set is a `Symbol` from that set, checkable at boot and completable. A free-form `String` is permitted only where the space is genuinely open — a URL, a cron expression, a regex — and then it carries a format check and a named error code |
| [R3](../idea/11-dsl-as-tool-surface.md#r3--every-option-has-a-default-the-minimal-declaration-is-valid) | Every option has a default; the minimal declaration is valid | a construct you cannot write a two-line version of. The exception is stated as a rule, not a loophole: an option with **no defensible default** is required *and* enumerated, so the failure names the choices |
| [R4](../idea/11-dsl-as-tool-surface.md#r4--verbose-is-acceptable-unreadable-is-not) | Verbose is acceptable; unreadable is not | a terse flag whose meaning must be looked up. Machine authorship makes length free at write time; it does nothing about legibility at review time. Corollary: do not rename what every ORM and SQL itself already uses — novelty has a review-time cost |
| [R5](../idea/11-dsl-as-tool-surface.md#r5--locality-is-non-negotiable) | Locality is non-negotiable | `config/` archaeology. A declaration's meaning must be visible without opening another file: routes derive from names, `use` seams are named once in `App.define`, everything else is in the block you are reading |
| [R6](../idea/11-dsl-as-tool-surface.md#r6--every-option-is-discoverable-through-the-schema-surface-or-it-is-a-defect) | Every option is describable by the schema, or it is a defect | an accepted-but-unlisted option, or a lambda in an option — invisible to `magik describe`, so neither the human nor the agent will use it correctly and both will invent something else |
| [R7](../idea/11-dsl-as-tool-surface.md#r7--errors-name-the-option-and-the-allowed-values) | An error names the specific cause | "invalid value". An option-level failure carries the construct, the declaration, the option, what was given, the `did_you_mean` and the allowed set ([`03-error-codes.md`](03-error-codes.md#option-level-errors-r7)) |
| [R8](../idea/11-dsl-as-tool-surface.md#r8--the-guardrails-are-the-schema-validation) | The option tables are the one representation | two tables drift; one cannot. The coercer, the guardrails, the docs anchors and `magik describe` all read the same rows — one artifact serialized four ways ([`01-module-map.md`](01-module-map.md#the-option-tables-and-magik-describe)) |
| [R9](../idea/11-dsl-as-tool-surface.md#r9--keyword-arguments-behaviour-in-blocks-no-positional-booleans) | Behaviour goes in blocks, options go in keyword arguments | a positional argument has no name, so it cannot appear in a schema, so it cannot be described — an R6 violation by construction. No positional booleans, ever |
| [R10](../idea/11-dsl-as-tool-surface.md#r10--adding-a-construct-is-a-budget-decision-adding-an-option-is-not) | Adding a construct is a budget decision; adding an option is not | the per-name option explosion — `retention_days:` beside `retention_hours:` — and its inverse, an option that changes what the construct *is*. A construct is paid by every agent in every session; an option is paid only where it is used. A new capability arrives as a **factory over an existing construct** |

### The four vocabulary decisions the rules produced

Settled before implementation, because a renamed option is free now and a semver break later. The full reasoning is in [`../idea/00-build-spec.md`](../idea/00-build-spec.md)'s *DSL vocabulary* section; this is the shape you write.

| # | Concept | The one spelling | From |
|---|---|---|---|
| **D1** | A duration | a **`:duration` type** everywhere — a unit-suffixed string coerced at boot: `session_ttl "14d"`, `schedule every: "10m"`, `trial: "14d"`, `throttle per: "1h"`. Never `15.minutes`, never a `*_days` integer | R2, R6, R10 |
| **D2** | A precondition | **`guard "reason" do … end`** on `ledger entry`, `action`, `job` and `flow step`. A flow step that simply does not apply uses **`skip_when do … end`** — *skip* and *abort* are different meanings | R9, R7 |
| **D3** | A field subset | **`fields`, `filterable`, `sortable`, `searchable`, `writable`** — five declarations, one vocabulary, identical on `api`, `admin_panel`, `data_table` and `screen`. `per_page:` stays an option: a scalar setting is not a field subset | R1, R9 |
| **D4** | Uniqueness | they stay apart. **`unique:`** on a `field` is a database constraint and nothing else; a job's dedupe key is **`idempotent_by`**, the same word `action` already uses | R1, R10 |

**Enforcement, not prose.** A `scripts/checks/` step over the option tables asserts that every option in [`../idea/02-dsl-surface.md`](../idea/02-dsl-surface.md) appears in `magik describe --json` and vice versa. It does not exist yet, and per this repo's own rule a convention with no check does not exist either.

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
| Subsystem names | exactly the twenty-one in [`01-module-map.md`](01-module-map.md), which are exactly the keys of `Magik::SUBSYSTEMS`. A new one is an architecture change, not a file. |
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
| Frozen state | constants holding collections are `.freeze`d. The declaration registry is frozen when boot completes — that is what makes the stateless guardrail checkable, and what keeps a thread-parallel test run honest ([`04-testing-strategy.md`](04-testing-strategy.md)). |
| Mutable globals | none after boot. No `$globals`, no class-level mutable accumulators outside the registry. |
| Comments | explain **why**. Never what. |
| Lint | RuboCop plus `rubocop-minitest`, `rubocop-rake`, `rubocop-performance`. The config in the repo root is the arbiter; disabling a cop inline needs a comment naming the reason. |

### Runtime

| Rule | Detail |
|---|---|
| Production target | TruffleRuby. |
| Development floor | CRuby ≥ 3.2 (`required_ruby_version = ">= 3.2"`). |
| TruffleRuby-specific behaviour | verified by `ruby scripts/probes/runtime.rb` and in CI, never asserted from a laptop ([`12-runtime-verification.md`](12-runtime-verification.md)). |
| Concurrency | real, parallel OS threads. TruffleRuby has no GVL, so **anything shared between threads must be frozen or synchronised**. Do not add mutable shared state to a subsystem without saying how the server and the test runner are meant to survive it. |

## YARD on every public method

Documentation is a shipping requirement, not a later pass. `.yardopts` at the root drives it; CI publishes to GitHub Pages.

```ruby
# Declares a background job.
#
# @param name [Symbol] the job's PascalCase name, e.g. +:SettleBatch+
# @param policy [Symbol, Array(Symbol, Symbol)] the verb this job runs under;
#   +:system+ is the declared opt-out
# @yield the job body — +retries+, +schedule+, +idempotent_by+ and +perform+ declarations
# @return [Magik::Jobs::Definition] the frozen definition, registered with the app
# @raise [Magik::Error] +MAGIK_JOBS_NO_PERFORM+ if the block declares no +perform+
# @raise [Magik::Error] +MAGIK_POLICY_UNDECLARED+ if +policy:+ is absent
# @example
#   job :SettleBatch, policy: :system do
#     retries times: 5, backoff: :exponential
#     schedule every: "10m"
#     idempotent_by :tenant_id
#     perform { |args| Payments.settle(tenant_id: args[:tenant_id]) }
#   end
# @see https://github.com/developerz-ai/magik/blob/main/docs/idea/02-dsl-surface.md
def job(name, policy:, &block)
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
