# Adding a feature

The loop a contributor or an agent follows to land one piece of the framework, start to finish, with the commands.

**Status:** partly runnable. `bin/check` and `rake test` exist and pass today; the DSL, the option tables, `magik describe` and the framework's own test runner do not, so the steps that touch them are the intended ones. Where a step cannot run today, the page says so. Reviewed 2026-08-26.

## The loop

| # | Step | Command | Lands in |
|---|---|---|---|
| 0 | Read the spec section | — | [`../idea/00-build-spec.md`](../idea/00-build-spec.md) |
| 1 | Document it here first | edit | `docs/idea/02-dsl-surface.md`, `docs/architecture/*` |
| 2 | Pick the subsystem and confirm the tier | — | [`01-module-map.md`](01-module-map.md), [`02-boundaries.md`](02-boundaries.md) |
| 3 | Write the failing Minitest | edit | `test/magik/<subsystem>/<concern>_test.rb` |
| 4 | Watch it fail | `bundle exec rake test TEST=test/magik/<subsystem>/<concern>_test.rb` | red, for the right reason |
| 5 | Implement | edit | `lib/magik/<subsystem>/<concern>.rb` |
| 6 | Add the option-table rows | edit | the construct's `Option` rows, which `magik describe` serializes |
| 7 | Register the error codes | edit | `lib/magik/<subsystem>/errors.rb` |
| 8 | Ship the guardrail | edit + test | the rule object in the same subsystem |
| 9 | YARD every public method | edit | the same files |
| 10 | Run the gate | `bin/check` | green |
| 11 | Changelog | edit | `CHANGELOG.md` |

Steps 1 and 3 are the two most often skipped and the two that make the difference: a construct with no doc is a construct nobody can call correctly, and an implementation written before its test is an implementation whose test is written to pass.

## 0. Read the spec section

The spec is the source of truth, and **no framework code ships that is not spec-backed** ([`00-conventions.md`](00-conventions.md)). Name the section in the commit message:

```
model: field :money refuses floats  (spec: Non-negotiable #10, Phase 1)
```

If the thing you want is not in the spec, the first commit edits the spec, on its own, with the argument. Inventing behaviour in `lib/` and back-filling a doc is how a framework acquires surface nobody chose.

## 1. Document it first

Write the intended shape before the implementation, so the design argument happens in prose where it is cheap:

| What you are adding | Document it in |
|---|---|
| a DSL construct or an option | [`../idea/02-dsl-surface.md`](../idea/02-dsl-surface.md) |
| a boot check | [`../idea/03-guardrails.md`](../idea/03-guardrails.md) + [`03-error-codes.md`](03-error-codes.md) |
| a backend behind a seam | [`../idea/04-swap-points.md`](../idea/04-swap-points.md) |
| a new subsystem | [`01-module-map.md`](01-module-map.md) + a tier in [`02-boundaries.md`](02-boundaries.md) |
| a refusal | [`../idea/05-limits.md`](../idea/05-limits.md) |

The doc is written in the same status vocabulary as everything else: it says `planned` until the code lands in the same PR, and then it does not.

## 2. Pick the subsystem

```bash
# which subsystem owns this, and what may it require?
sed -n '/^## Every subsystem/,/^## Where the guardrails live/p' docs/architecture/01-module-map.md
```

| Question | Answer in |
|---|---|
| Which subsystem owns the concept? | [`01-module-map.md`](01-module-map.md) — one reason to change each |
| What may it require? | [`02-boundaries.md`](02-boundaries.md) — strictly lower tiers, front doors only |
| Does it need something from a higher tier? | then the design is wrong. Move the shared vocabulary down into `core`, or pass the value in as a parameter |

## 3–4. Write the failing test

```ruby
# test/magik/model/money_field_test.rb
# frozen_string_literal: true

require "test_helper"

module Magik
  module Model
    class MoneyFieldTest < Magik::TestCase
      def test_float_assignment_raises_with_the_stable_code
        definition = Magik::Model::Definition.new(:Order) { field :total, :money, currency: :usd }

        error = assert_raises(Magik::Error) { definition.coerce(:total, 10.5) }

        assert_equal "MAGIK_MODEL_FLOAT_MONEY", error.code
      end
    end
  end
end
```

```bash
bundle exec rake test TEST=test/magik/model/money_field_test.rb
```

| Rule | Detail |
|---|---|
| Assert the **code**, not the message | messages get reworded; codes are permanent ([`03-error-codes.md`](03-error-codes.md)). |
| Red for the right reason | a `NameError` because the class does not exist yet is a valid first red; a typo is not. |
| One behaviour per test | the test name is the sentence the behaviour makes. |
| Determinism | frozen clock, seeded randomness, no network ([`04-testing-strategy.md`](04-testing-strategy.md)). |

## 5. Implement

```
lib/magik/<subsystem>/<concern>.rb
```

| Rule | Detail |
|---|---|
| SRP | one object, one reason to change. Under 150 lines, ≤ 7 public methods, ≤ 4 collaborators ([`00-conventions.md`](00-conventions.md)). |
| Requires | `require_relative` inside the subsystem, `require "magik/<other>"` across — front door only, strictly lower tier. |
| Frozen | freeze what is registered; no mutable state after boot, because the parallel test runner depends on it. |
| Stubs | anything you are not implementing raises `NotImplementedError` naming the spec phase. Never a fake that returns a plausible value. |

## 6. Add the option-table rows

Every option a construct accepts is a **row in the option table**, and that table is the one representation the coercer, the guardrails, the docs anchors and `magik describe` all read (R8, [`00-conventions.md`](00-conventions.md#dsl-design-rules-r1r10)). An option accepted by the coercer and missing from the table is not a shortcut; it is an option nobody can look up, which is an R6 defect.

| The row carries | Because |
|---|---|
| name, type, default | R3 — every option has a default, so the minimal declaration boots |
| the allowed set, where the space is closed | R2 — a closed set is a `Symbol` from that set, so a typo is refused at boot and the error can name the choices |
| applicability (`applies_when`, `required_when`) | so `describe` can say *`values:` applies to `:enum`* rather than listing everything unconditionally |
| the doc anchor | the join that lets an agent go schema → prose in one hop ([`09-shipped-docs.md`](09-shipped-docs.md)) |
| the `MAGIK_*` codes this option can raise | R7 — the error names the option, the allowed set, and a `fix:` pointing at `magik describe` |

And two shapes to refuse before writing the row: a **lambda in an option** (behaviour goes in a block — R9, and a schema cannot describe what an arbitrary `if:` decides), and a **per-name explosion** like `retention_days:` beside `retention_hours:` (R10 — that is one option taking a `:duration`, D1).

Neither the option tables nor `magik describe` exists yet; both land at build-order step 2, and retrofitting them onto constructs already implemented is the migration that ordering exists to avoid.

## 7. Register the error codes

```ruby
# lib/magik/model/errors.rb
register "MAGIK_MODEL_FLOAT_MONEY",
  summary: "A float reached a :money field.",
  why:     "Currency in binary floating point loses cents. :money is integer minor units plus a currency.",
  example: "field :total, :money, currency: :usd  # then: order.total = money(1050, :usd)",
  fix:     "Use money(cents, :currency) or an Integer of minor units.",
  doc:     "docs/idea/03-guardrails.md",
  stage:   :runtime,
  severity: :error
```

A raise with an unregistered code fails the catalogue test. A registered code is permanent from the moment it ships.

## 8. Ship the guardrail

**A construct is not done without its boot check** ([`../idea/06-phases.md`](../idea/06-phases.md)). The rule object lives in the same subsystem as the concept it guards; `core` runs it at boot and `check` runs the static ones without a server ([`01-module-map.md`](01-module-map.md)).

Two tests, always: one app declaration that violates the rule and fails with the code, one that satisfies it and boots.

**If what you added is a surface that reaches a model** — a screen, an action, an API resource, a channel, a job, an admin panel — it takes a `policy:` verb, and a declaration with neither a verb nor an explicit `policy: :public` / `policy: :system` fails the boot with `MAGIK_POLICY_UNDECLARED`. That is decision 13, *authorization is evaluated in exactly one place*, and it is the reason `policy` sits at tier 1 ([`01-module-map.md`](01-module-map.md#why-policy-is-tier-1)). The generated authorization test — one per verb, including a cross-tenant denial — comes with it ([`04-testing-strategy.md`](04-testing-strategy.md)).

## 9. YARD

```ruby
# Coerces a value into this field's declared type.
#
# @param field [Symbol] the field name
# @param value [Object] the incoming value
# @return [Object] the coerced value
# @raise [Magik::Error] +MAGIK_MODEL_FLOAT_MONEY+ when a Float reaches a +:money+ field
# @example
#   definition.coerce(:total, 1050)  #=> #<Magik::Money 1050 usd>
def coerce(field, value)
```

Every public method: summary, `@param`, `@return`, `@raise` for each code it can produce. Every DSL entry point additionally an `@example` matching [`../idea/02-dsl-surface.md`](../idea/02-dsl-surface.md).

```bash
bundle exec yard doc          # build
bundle exec yard stats --list-undoc   # what is missing
```

## 10. Run the gate

```bash
bin/check
```

`bin/check` exists and runs today. Re-derive its steps rather than trusting a list here:

```bash
bin/check --list          # the steps it actually runs
bin/check --only test     # one of them
bin/check --json          # the same run, as data
```

Two families of check, and only the first is wired into the gate so far:

| Family | Where it lives | Status |
|---|---|---|
| lint, tests, YARD coverage, gem build, the CLI's own surface, docs packaging | `bin/check` steps | **runs today** |
| boundaries, error-code catalogue, changelog, version consistency, doc commands, spec-only drift | one file each in [`../../scripts/checks/`](../../scripts/checks/), run directly — `ruby scripts/checks/<name>.rb` | **runs today, not yet a `bin/check` step** |
| conformance — swap-point suites, where the change touched a seam ([`../idea/04-swap-points.md`](../idea/04-swap-points.md)) | nowhere yet | planned; there is no seam to conform to |

The boundaries check is the one to run by hand after touching `lib/`: `ruby scripts/checks/boundaries.rb`.

## 11. Changelog

```markdown
### Added
- `model`: `:money` fields refuse Float assignment with `MAGIK_MODEL_FLOAT_MONEY` (spec: Non-negotiable #10).
```

| Rule | Detail |
|---|---|
| Same commit | the change and its changelog entry land together. |
| Honest verbs | "Added", "Changed", "Fixed". Never "improved" or "optimized" without a number and the command that produced it. |
| Status moves too | if this completes a phase item, update [`../idea/06-phases.md`](../idea/06-phases.md) and drop the `planned` marker on that row — only for the part that actually landed. |

## Definition of done

| # | |
|---|---|
| 1 | The spec section is named in the commit. |
| 2 | The docs describe the shape, and no longer say `planned` for what landed. |
| 3 | A test fails without the change and passes with it, asserting on codes rather than messages. |
| 4 | The guardrail exists and has both its tests. |
| 5 | Every public method has YARD, with `@example` on DSL entry points. |
| 6 | `bin/check` is green. |
| 7 | `CHANGELOG.md` says what changed. |
