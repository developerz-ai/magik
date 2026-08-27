# Testing

**Status:** `Planned — not implemented`. Spec Phase 9, delivered **third** (build step 5) so that
everything after it is test-driven. Nothing on this page runs. `As of 2026-08-26`.

Testing is not a chapter at the end of this manual. It is the third thing built, before realtime,
before jobs, before ledgers — because a framework that adds its test harness last ends up with a
suite that documents its bugs rather than one that prevented them.

Two commitments shape the design:

1. **Fast enough that you leave it running.** All cores, by default, with no configuration.
2. **The same DSL grammar as everything else.** A test declaration reads like a model declaration,
   because there is one grammar in this framework and tests are not an exception to it.

Magik wraps **Minitest**, never RSpec — fast boot, simple object model, no `let` graph to reverse
engineer. Prior art for the *runner mechanics* comes from Rails' parallel test runner and from
`parallel_tests` / `parallel_rspec`: process-per-core, database per worker, a clean split of work.
That is where the borrowing stops — the framework choice is Minitest and it is not revisited.

How it works underneath — worker threads, template-database cloning, the honest risks in each — is [`docs/architecture/04-testing-strategy.md`](../docs/architecture/04-testing-strategy.md).
This page is what you type.

---

## Writing a test

The running example is the invoicing SaaS in [`dummy/`](../dummy/).

```ruby
# test/actions/mark_paid_test.rb
test :MarkPaid do
  it "settles the receivable and notifies the customer" do
    invoice = create(:invoice, status: :sent, amount: 149_99)

    perform_action :mark_paid, id: invoice.id

    expect(invoice.reload.status).to eq(:paid)
    expect(Receivables.balance(:accounts_receivable)).to eq(0)
    assert_enqueued :SendReceiptEmail, invoice_id: invoice.id
  end

  it "refuses to mark a draft invoice paid" do
    invoice = create(:invoice, status: :draft)

    result = perform_action :mark_paid, id: invoice.id

    expect(result).to be_guard_failure
    expect(result.message).to include("only a sent invoice")
    expect(invoice.reload.status).to eq(:draft)
  end
end
```

`test :Name do it "…" do expect(…) end end` compiles to Minitest. `expect` is a thin matcher surface
over Minitest assertions — the failure output is Minitest's, the backtrace is Minitest's, and
`minitest/pride` still works. Nothing is hidden behind a runner you cannot reason about.

| Piece | Is |
|---|---|
| `test :Name` | a Minitest class, named after the declaration under test |
| `it "…"` | a test method |
| `expect(x).to eq(y)` | `assert_equal y, x` with a better failure message |
| `create(:invoice)` | an inferred factory — no fixture file, no factory file |

---

## Every helper, in use

The spec names seven. Each one exists because it covers something that is otherwise slow, flaky, or
written wrong. `assert_queries(n) { … }` joins them for the one thing the others cannot express — the
*absence* of an N+1.

### `perform_action`

Runs an action exactly as a request would: params coerced, guards evaluated, tenant scoped.

```ruby
result = perform_action :create_invoice, customer_id: customer.id, amount: 50_00, due_on: Date.today + 30

expect(result).to be_success
expect(Invoice.count).to eq(1)
```

You are testing the real path. There is no "call the service object directly" shortcut that skips
half of what production does, because there is no service object — the action *is* the unit.

### `render_screen`

Renders a screen server-side and gives you something you can assert against.

```ruby
create(:invoice, number: "INV-001", status: :sent, due_on: Date.today - 5)

page = render_screen :Invoices

expect(page).to have_text("INV-001")
expect(page).to have_component(:data_table, rows: 1)
expect(page).to have_htmx_post(:mark_paid)
```

No browser, no driver, no headless anything. The output is HTML the server produced, so a test that
passes here is testing what the user receives.

`at:` renders the screen at a named breakpoint, which is **what makes the responsiveness claim
testable rather than asserted**. Every kit component is meant to be responsive by construction; this
is how you find out whether it was:

```ruby
page = render_screen :Invoices, at: :mobile      # 375px

expect(page).to have_component(:card_list)       # data_table becomes a card list
expect(page).not_to overflow_horizontally
```

### `concurrently(n)`

Runs a block `n` ways at once and waits for all of them. For the races you would otherwise find in
production.

```ruby
it "charges once under concurrent submission" do
  invoice = create(:invoice, status: :sent)

  results = concurrently(10) { perform_action :charge_invoice, invoice_id: invoice.id }

  expect(results.count(&:success?)).to eq(10)          # every caller gets a result
  expect(Receivables.entries(:invoice_settled).count).to eq(1)   # exactly one settlement
end
```

That is the `idempotent_by` contract, asserted rather than assumed. See
[Money and ledgers](Money-And-Ledgers.md).

### `travel_to`

Freezes the clock for the block. Every timestamp, schedule and window sees the frozen time.

```ruby
it "marks an invoice overdue the day after it is due" do
  invoice = create(:invoice, status: :sent, due_on: Date.new(2026, 3, 1))

  travel_to Time.utc(2026, 3, 1, 23, 59) { expect(Invoice.overdue).to be_empty }
  travel_to Time.utc(2026, 3, 2, 0,  1)  { expect(Invoice.overdue).to include(invoice) }
end
```

No `sleep`, ever. A test that sleeps is a test that is both slow and still flaky.

### `assert_enqueued`

```ruby
perform_action :send_invoice, id: invoice.id

assert_enqueued :SendInvoiceEmail, invoice_id: invoice.id
assert_enqueued :SendInvoiceEmail, count: 1
refute_enqueued :SweepOverdue
```

Jobs do not run during a test unless you ask. To run them:

```ruby
perform_enqueued_jobs { perform_action :send_invoice, id: invoice.id }
```

### `assert_broadcast`

```ruby
assert_broadcast "invoices:tenant", :changed do
  perform_action :mark_paid, id: invoice.id
end
```

Asserts the realtime event a live screen depends on, without opening a socket. See
[Realtime](Realtime.md).

### `assert_notified`

```ruby
assert_notified :invoice_overdue, to: customer, via: %i[email in_app] do
  perform_enqueued_jobs { SweepOverdue.perform_now }
end
```

Asserts the notification and its channels, without an SMTP server or a push provider.

---

## Factories are inferred

There is no `factories/` directory and no fixture files. A factory is derived from the model's own
field types — the model already declares what a valid `Invoice` looks like, so declaring it a second
time is a second thing to keep in step.

```ruby
model :Invoice do
  field :number, :string, required: true, unique_per_tenant: true
  field :amount, :money,  required: true
  field :status, :enum,   values: %i[draft sent paid void], default: :draft
  field :due_on, :date
  belongs_to :customer
end
```

gives you, for free:

```ruby
create(:invoice)                      # every required field filled, associations built
build(:invoice)                       # not saved
create_list(:invoice, 5)
create(:invoice, status: :paid)       # override anything
```

| Field type | Inferred value |
|---|---|
| `:string` with `unique_per_tenant: true` | a unique, readable value — `"INV-0001"`, not `"MyString1"` |
| `:money` | a positive amount in the declared currency |
| `:enum` | the `default:`, or the first value |
| `:date` / `:timestamp` | a time near the frozen clock |
| `belongs_to` | the associated record is built, tenant-consistent |
| `has_many` | **empty by default.** Pass `line_items: 3` to build them |

### Overriding the inference

When a type-derived value is not good enough, override it once on the model rather than everywhere in
the suite:

```ruby
model :Invoice do
  field :number, :string, required: true, unique_per_tenant: true

  factory do
    number { |n| format("INV-%04d", n) }
    trait :overdue,  { status: :sent, due_on: Date.today - 30 }
    trait :settled,  { status: :paid, paid_at: Time.now.utc }
  end
end
```

```ruby
create(:invoice, :overdue)
create(:invoice, :settled, amount: 1_000_00)
```

The `factory` block lives on the model on purpose: the definition of "a plausible invoice" belongs
next to the definition of an invoice.

---

## Tests you did not write

Some tests are mechanical. Magik generates them from declarations you have already made, so the
obvious coverage is present without anyone typing it.

| Generated from | Test asserted |
|---|---|
| `required: true` | creating without the field fails, with the field named in the error |
| `unique_per_tenant: true` | a duplicate inside one tenant is refused at the database, and the same value in another tenant is allowed |
| `validate :amount, positive: true` | a zero and a negative are both refused |
| `field :status, :enum, values:` | a value outside the set is refused |
| `belongs_to` | the foreign key is enforced, and the association is tenant-consistent |
| `ledger` | every declared `entry` balances; the ledger's accounts sum to zero |
| `immutable_after :paid` | a write past the state is refused |
| `idempotent_by` | a replayed call performs once — the `concurrently` assertion above, generated |
| `policy :Model` | **one authorization test per declared verb**, including a cross-tenant denial — the actor from another tenant is refused by every surface that names the verb |
| `attachment` / `:file` | an oversized upload and a disallowed content type are both refused |

```bash
magik test --generated          # only the generated tests
magik test --generated --list   # what would run, without running it
```

**Generated tests are not a substitute for yours.** They cover what a declaration *claims*; they
cannot cover what your business means. They exist so that the boring half is never the half that was
skipped.

---

## Running it

```bash
magik test                            # the whole suite, all cores
magik test --watch                    # re-run affected tests on save
magik test --changed                  # only what your diff can have broken
magik test test/actions/              # a directory
magik test test/actions/mark_paid_test.rb
magik test test/actions/mark_paid_test.rb:12    # one test, by line
magik test --name "settles the receivable"      # by name
magik test --workers 4                # override the default
magik test --workers 1                # serial, for debugging
magik test --seed 12345               # reproduce an ordering
magik test --generated                # only the generated tests
magik test --json                     # machine-readable
```

`--watch` is the one you leave running. It re-runs the tests a saved file can have affected, not the
whole suite, and it does not restart the process between runs.

`--changed` is the one CI uses on a pull request, and the one you run before pushing. It resolves the
diff against the merge base and runs the transitive set.

### JSON output shape

```json
{
  "ok": false,
  "command": "test",
  "summary": "142 tests, 1 failure, 0 errors, 3 skipped",
  "seed": 12345,
  "workers": 8,
  "duration_ms": 4213,
  "counts": { "tests": 142, "assertions": 388, "failures": 1, "errors": 0, "skips": 3 },
  "failures": [
    {
      "test": "MarkPaid#settles the receivable and notifies the customer",
      "file": "test/actions/mark_paid_test.rb",
      "line": 12,
      "message": "expected :paid, got :sent",
      "code": "MAGIK_TEST_FAILED",
      "fix": "magik test test/actions/mark_paid_test.rb:12 --workers 1"
    }
  ]
}
```

Every failure carries the command that re-runs **that one test serially**, because "reproduce it in
isolation" is the first thing you do and the framework already knows the command. Failures follow the
same code / cause / `fix:` contract as every other Magik error — see [Error codes](Error-Codes.md).

---

## The parallel model, in user-facing terms

| Behaviour | Detail |
|---|---|
| **All cores by default** | `workers: :auto` means every core. You do not configure this to get it |
| **One worker per test file group** | files are grouped and each group runs on its own worker thread. Tests within a file run in order |
| **A database per worker** | each worker gets its own database, cloned from a template. Workers never see each other's rows |
| **Transactional rollback per test** | each test runs inside a transaction that is rolled back at the end. **No truncation** — that is where the speed comes from |
| **Frozen clock per test** | time does not advance under you between two assertions |
| **Randomised order, reported seed** | order dependence is found rather than tolerated. `--seed` reproduces a run |

### What rollback-not-truncation means for you

This is the part that surprises people, so it is stated plainly.

Your test runs inside a transaction that never commits. Ninety-nine times out of a hundred that is
invisible and it is why the suite is fast. The exceptions:

| Situation | What happens | What to do |
|---|---|---|
| You assert on data from **another connection** | it cannot see your uncommitted rows | mark the test `committed: true` — it runs outside the transaction and truncates afterwards, and it is slower. Use it sparingly |
| You test something that depends on `COMMIT` firing | after-commit behaviour never fires | `committed: true`, same trade |
| You test `LISTEN`/`NOTIFY` realtime end to end | notifications are delivered on commit | `committed: true` — or use `assert_broadcast`, which does not need a commit |
| You use `concurrently(n)` | each concurrent call needs its own connection, so the block runs `committed: true` automatically | nothing. It is handled |

```ruby
test :InvoiceUpdates do
  it "delivers a notify on commit", committed: true do
    # runs outside the transaction; the database is truncated after
  end
end
```

**Nested transactions still work.** Code under test that opens its own transaction gets a savepoint,
so a rollback in your application code behaves the way it does in production.

---

## Speed

The spec's target is **1,000 tests, parallel, all cores, under 10 seconds.**

That is a target. **No benchmark has been run, because there is no runner to run one with.** No
number on this page is a result, and none will be until a committed benchmark exists with the command
that reproduces it.

When there is something to measure, this is how you will measure it — and this is how you should
measure your own suite rather than trusting a framework's number about a different machine:

```bash
magik test --json | jq '.duration_ms, .counts.tests, .workers'
nproc                                  # what "all cores" means on this box
magik test --workers 1 --json | jq .duration_ms    # the serial baseline the parallel run is beating
```

The honest risks in the parallel design — chiefly that thread-parallel tests demand genuinely
shared-nothing tests — are named in
[`docs/architecture/04-testing-strategy.md`](../docs/architecture/04-testing-strategy.md) rather than
smoothed over here.

---

## Guardrails

| Guardrail | Fails with | When |
|---|---|---|
| A test file declares one `test` block | `MAGIK_TEST_MULTIPLE_DECLARATIONS` | load |
| The test tree mirrors `app/` | `MAGIK_TEST_MISPLACED` | load |
| A test that sleeps is refused | `MAGIK_TEST_SLEEPS` | run — use `travel_to` |
| A test that reaches the real network is refused | `MAGIK_TEST_NETWORK` | run |
| A declaration with no test file is reported | `MAGIK_TEST_MISSING` | `magik check` |

The sealed network is not optional. A suite that quietly talks to a real API is a suite that is green
because someone else's server was up.

---

## Next

- [Actions](Actions.md) · [Screens and components](Screens-And-Components.md) · [Jobs](Jobs.md) — what you are testing.
- [Development loop](Development-Loop.md) — `magik test --watch` alongside a reloading server.
- [CLI reference](CLI-Reference.md) — every flag on `magik test`.
- [`docs/architecture/04-testing-strategy.md`](../docs/architecture/04-testing-strategy.md) — how the runner works, and its risks.
