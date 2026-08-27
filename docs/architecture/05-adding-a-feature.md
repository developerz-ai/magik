# Adding a feature

The loop a contributor or an agent follows to land one piece of the framework, start to finish, with the commands.

**Status:** planned. `bin/check`, `magik` and the test runner do not exist yet; the commands below are the intended ones. Where a step cannot run today, the page says so. Reviewed 2026-08-26.

## The loop

| # | Step | Command | Lands in |
|---|---|---|---|
| 0 | Read the spec section | — | [`../idea/00-build-spec.md`](../idea/00-build-spec.md) |
| 1 | Document it here first | edit | `docs/idea/02-dsl-surface.md`, `docs/architecture/*` |
| 2 | Pick the subsystem and confirm the tier | — | [`01-module-map.md`](01-module-map.md), [`02-boundaries.md`](02-boundaries.md) |
| 3 | Write the failing Minitest | edit | `test/magik/<subsystem>/<concern>_test.rb` |
| 4 | Watch it fail | `bundle exec rake test TEST=test/magik/<subsystem>/<concern>_test.rb` | red, for the right reason |
| 5 | Implement | edit | `lib/magik/<subsystem>/<concern>.rb` |
| 6 | Register the error codes | edit | `lib/magik/<subsystem>/errors.rb` |
| 7 | Ship the guardrail | edit + test | the rule object in the same subsystem |
| 8 | YARD every public method | edit | the same files |
| 9 | Run the gate | `bin/check` | green |
| 10 | Changelog | edit | `CHANGELOG.md` |

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

## 6. Register the error codes

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

## 7. Ship the guardrail

**A construct is not done without its boot check** ([`../idea/06-phases.md`](../idea/06-phases.md)). The rule object lives in the same subsystem as the concept it guards; `core` runs it at boot and `check` runs the static ones without a server ([`01-module-map.md`](01-module-map.md)).

Two tests, always: one app declaration that violates the rule and fails with the code, one that satisfies it and boots.

## 8. YARD

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

## 9. Run the gate

```bash
bin/check
```

Intended steps, in cost order — the cheapest failure first:

| # | Step | Command it wraps |
|---|---|---|
| 1 | lint | `bundle exec rubocop` |
| 2 | boundaries | tier + front-door scan over `lib/magik/` ([`02-boundaries.md`](02-boundaries.md)) |
| 3 | tests | `bundle exec rake test` |
| 4 | docs | `bundle exec yard stats --list-undoc` — undocumented public methods fail |
| 5 | catalogue | every raised code registered; every entry has a `fix` and a resolving `doc` |
| 6 | conformance | swap-point suites, where the change touched a seam ([`../idea/04-swap-points.md`](../idea/04-swap-points.md)) |

`bin/check` is owned by another part of the boilerplate and does not exist yet; until it does, run steps 1, 3 and 4 by hand.

## 10. Changelog

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
