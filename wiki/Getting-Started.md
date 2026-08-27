# Getting started

**Status:** `Planned — not implemented`. Every command and every output on this page is the **target**
developer experience described by [`docs/idea/00-build-spec.md`](../docs/idea/00-build-spec.md). None
of it runs. `magik new` does not exist. `As of 2026-08-26`.

Read this as the acceptance test for Phase 1 and Phase 2, written before the code — because "what
should the first five minutes feel like" is a design decision, and deciding it after the
implementation is how frameworks end up with a first five minutes nobody chose.

What actually runs today: `magik version` and `magik help`. See [Installation](Installation.md).

## The intended first run

```bash
gem install magik
magik new myapp
cd myapp
bin/setup
magik server
```

Five commands, no Docker, no Node, no `config/` archaeology. Open `http://localhost:3000`.

| Step | What it is intended to do |
|---|---|
| `gem install magik` | installs the CLI globally so `magik new` is reachable before there is a bundle |
| `magik new myapp` | writes the app skeleton — see [Project layout](Project-Layout.md). Installs nothing |
| `bin/setup` | the app's **own** script: `bundle install`, create the database, run migrations, seed. Idempotent — safe to re-run |
| `magik server` | boots the app server, mounts the router, watches for changes |

`magik server` straight after `cd` is intended to **fail loudly**, not mysteriously: `magik new`
installs no gems, so there is no bundle and no database. The boot is meant to stop on
`MAGIK_SETUP_INCOMPLETE` with `fix: run bin/setup`. An error that names the next command is the
design; a stack trace is a bug. See [Error codes](Error-Codes.md).

## Your first feature, intended

The spec's success criterion is: **a new CRUD SaaS screen is a model, a screen and an action in under
30 lines, with zero HTML, JavaScript or CSS written.** Here is what that is meant to look like.

### 1. A model

```ruby
# app/models/invoice.rb
model :Invoice do
  field :number,   :string, required: true, unique_per_tenant: true
  field :amount,   :money,  required: true
  field :status,   :enum, values: %i[draft sent paid], default: :draft
  field :due_on,   :date

  belongs_to :customer
  has_many   :line_items

  validate :amount, positive: true
  scope :outstanding, -> { where(status: %i[draft sent]) }
end
```

You did not declare an `id`, a `tenant_id`, `created_at` or `updated_at`. UUIDv7 primary keys and
tenant scoping are injected — see [Models](Models.md).

### 2. A migration

```bash
magik generate model Invoice
```

is intended to write both the model above and its migration. Written by hand it is:

```ruby
# db/migrations/001_create_invoices.rb
migrate :CreateInvoices do
  up   { create_table_for :Invoice }
  down { drop_table :invoices }
end
```

### 3. A policy

Every surface that reaches a model names a verb, and the verbs live in one file per model. There is
no implicit allow, and a surface that names nothing fails at boot.

```ruby
# app/policies/invoice.rb
policy :Invoice do
  default :deny

  can :read do |actor, _invoice|
    actor.role?(:viewer, :member, :admin, :owner)
  end

  can :record_payment do |actor, _invoice|
    actor.role?(:admin, :owner)
  end
end
```

### 4. A screen

```ruby
# app/screens/invoices.rb
screen :Invoices, policy: %i[Invoice read], layout: :App do
  state :invoices, -> { Invoice.outstanding.order(:due_on) }

  body do
    card title: "Outstanding" do
      data_table :invoices,
                 columns: %i[number customer amount due_on status],
                 row_action: :mark_paid
    end
  end
end
```

Auto-routed to `/invoices`. No route file, no template, no CSS. `layout: :App` names the shell
`magik new` is specified to generate — so the screen arrives inside a working sidebar rather than on a
blank page.

### 5. An action

```ruby
# app/actions/mark_paid.rb
action :mark_paid, policy: %i[Invoice record_payment] do |params|
  invoice = Invoice.find!(params[:id])
  invoice.update(status: :paid, paid_at: Time.now)
  refresh :Invoices
end
```

`row_action: :mark_paid` in the screen emits the htmx attributes that POST to this action and swap the
table in place. You wrote no JavaScript, and there is no client-side router to explain.

### 6. A test

```ruby
# test/invoices_test.rb
test :Invoices do
  it "marks an invoice paid" do
    invoice = create(:invoice, status: :sent)
    perform_action :mark_paid, id: invoice.id
    expect(invoice.reload.status).to eq(:paid)
  end
end
```

`create(:invoice)` needs no factory file — factories are inferred from the field types. See
[Testing](Testing.md).

```bash
magik test
magik test --watch      # re-runs on save
magik test --changed    # only what your diff can have broken
```

## The loop

Intended day-to-day:

```bash
magik server            # terminal 1 — reloads on change
magik test --watch      # terminal 2 — reruns on save
magik check             # before you push: guardrails, tenancy, ledgers, domain boundaries
```

What reloads instantly, what needs a restart, and what an error page looks like when reloaded code
raises: [Development loop](Development-Loop.md).

`magik check --scale` additionally warns on queries missing `tenant_id` in their `WHERE` clause —
sharding pain, pre-empted. See [CLI reference](CLI-Reference.md).

## What this page deliberately does not show

| Not shown | Because |
|---|---|
| A screenshot | there is nothing to screenshot |
| A timing | no benchmark has been run. The spec's "1,000 tests under 10s" is a **target**, and it stays one until a committed result says otherwise |
| A "it just works" claim | nothing works. Every code block above is a design artefact |

## Next

| Want | Read |
|---|---|
| The day-to-day loop, hot reload included | [Development loop](Development-Loop.md) |
| The full model DSL | [Models](Models.md) |
| The full screen and component DSL | [Screens and components](Screens-And-Components.md) |
| Every CLI command | [CLI reference](CLI-Reference.md) |
| What order this gets built in | [`ROADMAP.md`](../ROADMAP.md) |
| What is missing | [Known gaps](Known-Gaps.md) |
