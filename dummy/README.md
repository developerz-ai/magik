# `dummy/` — Ledgerline, the reference application

Ledgerline is a small invoicing and billing SaaS, written in the Magik DSL that
[`docs/idea/00-build-spec.md`](../docs/idea/00-build-spec.md) specifies.

**It does not run. It cannot run. Nothing here has ever executed.**

That is not a defect — it is the point.

## What this is for

Two things, and it is worth being precise about both.

**1. It is the spec, made executable-shaped.** A specification written as prose
can describe a DSL that is unpleasant to write, and nobody notices until the
framework is built and the first real app is attempted. Ledgerline is that first
app, written *first*: before the parser, before the compiler, before any of it.
Every declaration here is a claim about what the framework must accept, made in
a form you can read as code rather than as a paragraph about code.

Writing it has already changed the design. See
[What writing this taught us](#what-writing-this-taught-us) below.

**2. It is the layout, made concrete.** `dummy/` is the canonical answer to
"where does this file go in a Magik app", and people will copy this tree. So the
separation of concerns is meant to be visible on sight, and the rules in
[Separation of concerns](#separation-of-concerns) are enforced by where files
are, not by a document you have to remember.

## Status: not implemented

As of **2026-08-26**, Magik is spec only. There is no `App.define`, no `model`,
no `screen`, no compiler and no server. Loading any file in this directory
raises `NoMethodError` on its first line, and every file says so in its header.

| Question | Answer |
| --- | --- |
| Does it run? | No. |
| Has it ever run? | No. |
| Is it tested? | No. It is excluded from `rake test` and from RuboCop. |
| Does it parse as Ruby? | Yes — `ruby -c` is clean on every file. Nothing more. |
| When will it run? | See below. |

`ruby -c` passing is a deliberately low bar, and it is the *only* claim made
here. It means the DSL is spelled in syntax Ruby will accept, so an editor can
highlight it and a reader is not tripping over parse errors. It does not mean
any of it works.

### What "running" will mean

Not one switch — five, in the order the build spec's phases land:

| Milestone | What becomes true |
| --- | --- |
| **Phase 1** — foundation | `config/app.rb`, `app/models/*` and `db/migrations/*` load. `magik console` opens against a real schema; `Invoice.overdue` returns rows. |
| **Phase 2** — rendering | `app/screens/*`, `app/components/*`, `app/layouts/*`, `app/policies/*` and `app/actions/*` compile. `magik server` serves `/invoices` inside the `:App` shell, every surface's `policy:` verb is evaluated, and clicking a row action writes to the database. **This is the first point at which Ledgerline is a usable application.** |
| **Phase 3** — realtime | `app/channels/invoices.rb` and the `live` lines in `app/screens/dashboard.rb` update without a refresh. |
| **Phase 4** — jobs | `app/jobs/*` run under `magik worker`; the nightly sweep fires. |
| **Phase 5** — money | `app/ledgers/receivables.rb` posts double-entry records and refuses to boot if they do not balance. |
| **Phases 6–9** | `app/api/*`, auth, billing, admin, i18n, and `dummy/test/invoicing_test.rb` executing as a real Minitest suite. |

Until Phase 2, "running" is not a partial state — it is a `NoMethodError`.

## The product

One coherent SaaS, chosen because it exercises the hard parts of the spec at
once rather than one at a time: money as integer cents, a double-entry ledger,
multi-tenancy, opt-in realtime, background jobs, webhooks in both directions and
an admin panel.

Ledgerline's users are small businesses. They add customers, issue invoices,
get paid, and chase the ones who have not paid. Ledgerline itself charges them
a subscription — which is a *second*, separate money flow, and the two are
deliberately kept apart:

| Flow | Whose money | Where it lives |
| --- | --- | --- |
| A tenant invoices their customer | The tenant's revenue | [`app/ledgers/receivables.rb`](app/ledgers/receivables.rb) |
| Ledgerline charges the tenant | Ledgerline's revenue | [`domains/billing/`](domains/billing/domain.rb) |

They sound identical in English and must never share a model. Putting them in
different places is the cheapest way to keep them apart.

## The tree

This is [`wiki/Project-Layout.md`](../wiki/Project-Layout.md)'s canonical app
layout, populated. Directory names and their meanings match that page exactly;
the file names inside them are Ledgerline's.

```text
dummy/
├── config/
│   ├── app.rb                     App.define :Ledgerline — the composition root
│   ├── backends.rb                the swap points: db, cache, jobs, realtime, search
│   └── theme.rb                   design tokens, light/dark, as CSS variables
├── app/
│   ├── models/                    data + invariants          (the only things that persist)
│   │   ├── account.rb             model :Account — the tenant root
│   │   ├── customer.rb            model :Customer
│   │   ├── invoice.rb             model :Invoice
│   │   ├── invoice_line.rb        model :InvoiceLine
│   │   └── payment.rb             model :Payment
│   ├── policies/                  authorization             (the ONLY rules)
│   │   ├── customer.rb            policy :Customer
│   │   └── invoice.rb             policy :Invoice
│   ├── components/                reusable UI                (pure; never queries)
│   │   └── money_badge.rb         component :MoneyBadge
│   ├── layouts/                   the application shell      (nav lives here)
│   │   └── app.rb                 layout :App
│   ├── screens/                   pages, auto-routed         (read + render; never write)
│   │   ├── dashboard.rb           screen :Dashboard
│   │   ├── invoices.rb            screen :Invoices
│   │   └── sign_in.rb             screen :SignIn — policy: :public, layout: :None
│   ├── flows/                     multi-step wizards
│   │   └── onboarding.rb          flow :Onboarding
│   ├── actions/                   mutations                  (the ONLY writes)
│   │   ├── issue_invoice.rb       action :issue_invoice
│   │   └── record_payment.rb      action :record_payment
│   ├── channels/                  realtime subscriptions     (opt-in, per screen)
│   │   └── invoices.rb            channel :invoices
│   ├── jobs/                      async work                 (the ONLY async)
│   │   ├── send_invoice_email.rb  job :SendInvoiceEmail
│   │   └── dunning_sweep.rb       job :DunningSweep
│   ├── ledgers/                   money movement             (the ONLY money)
│   │   └── receivables.rb         ledger :Receivables
│   ├── api/                       the REST surface
│   │   └── v1.rb                  api :V1
│   ├── webhooks/                  events crossing the boundary, both directions
│   │   ├── stripe_incoming.rb     webhook :incoming, :stripe
│   │   └── invoice_events_outgoing.rb  webhook :outgoing, :invoice_events
│   └── notifications/             one file per notification, every channel it rides
│       └── invoice_issued.rb      notification :invoice_issued
├── domains/                       the large-app shape (see below)
│   ├── billing/
│   │   ├── domain.rb              domain :Billing
│   │   └── app/models/
│   │       └── subscription.rb    model :Subscription — private to :Billing
│   └── invoicing/
│       └── domain.rb              domain :Invoicing
├── locales/
│   └── en.yml                     one file per locale, named by its code
├── db/
│   ├── migrations/                hand-written, ordered, append-only
│   │   ├── 20260826120000_create_customers_and_invoices.rb
│   │   └── 20260826120100_create_payments_and_ledger.rb
│   └── seeds.rb                   hand-written, idempotent, NOT fixtures
└── test/                          mirrors app/ exactly, one file per declaration
    ├── models/invoice_test.rb
    └── actions/record_payment_test.rb
```

There is **no routes file**, and that is not an omission. Routing is by
convention: a screen's file name is its path, and an action is reachable at its
own name (spec, Build Order 4). A file you would have to keep in sync with
another file is a file the framework should be deriving.

### What a generated app has that this does not

`magik new` will emit more than this. `dummy/` holds the *declarative* surface —
the part that teaches the DSL — and deliberately omits the scaffolding, because
a second `Gemfile` and a second `bin/` inside the framework's own repository
would be actively confusing.

| In a generated app | Why not here |
| --- | --- |
| `Gemfile`, `bin/setup`, `bin/check`, `bin/magik` | The framework repo has its own, at the root. Two would collide. |
| `config/database.yml`, `config/environments/*.rb` | Environment wiring, not DSL. Nothing to demonstrate. |
| `public/` (htmx, favicon) | Static assets. Nothing to read. |
| `db/schema.rb` | Generated by the migrations. Committed in a real app; nothing generates one yet. |
| `tmp/`, `log/` | Generated, and gitignored — see the repo root `.gitignore`. |
| `README.md`, `AGENTS.md` | This file is the app's README. |

## Separation of concerns

Each concern has exactly one directory, and the rule for each is one sentence.
The directory *is* the enforcement: you cannot accidentally write to the
database from a screen if writes only exist in `app/actions/`.

| Directory | May | May not |
| --- | --- | --- |
| `app/models/` | Declare fields, associations, validations, scopes, invariants. | Render, mutate other models, enqueue, send anything. |
| `app/policies/` | Decide, in pure predicates over an actor and a record, who may do what. | Query, or do I/O of any kind. A `live` screen re-evaluates a predicate per subscriber per change. |
| `app/components/` | Display the props it is given. | Query the database. A component that queries is an N+1 waiting for the list to grow. |
| `app/layouts/` | Wrap a screen: navigation, header, breadcrumbs, responsive collapse. | Fetch what the screen shows. The one read it makes is a nav badge, and it names a scope the model owns. |
| `app/screens/` | Read (in `state`), render (in `body`), link to actions. | Write. Every button names an action. |
| `app/actions/` | Write. Exactly one transaction, then broadcast, then redirect. | Render HTML, or do slow work inline. |
| `app/channels/` | Subscribe to model changes and fan them out. | Mutate anything. |
| `app/jobs/` | Anything slow, retryable or third-party. | Be called synchronously from a request. |
| `app/ledgers/` | Move money, in balanced double-entry records. | Be bypassed. There is no `balance` column to update instead. |
| `app/flows/` | Order screens into a wizard, with guards and resumable progress. | Hold progress in the process. It is a row, never a session object. |
| `app/api/` | Expose and delegate. | Reimplement a mutation. `create:` and `member:` name existing actions. |
| `app/webhooks/` | Verify a signature, then call an existing action. | Hold business rules. An incoming webhook is just another caller. |
| `app/notifications/` | Say how one event reaches a person, on every channel. | Decide *when*. That is the action's or the job's call. |
| `config/` | Declare what the app is made of, what it swaps, how it looks. | Hold anything specific to one model, screen or job. |

Two consequences worth stating out loud, because they are what the layout buys:

- **`grep -rl . app/actions/` is a complete list of every mutation in the
  product.** Not most of them.
- **Nothing outside `app/ledgers/` adds up money.** A balance is derived from
  entries, so it cannot drift from them.

## Naming: filename ↔ declaration

One rule, applied everywhere, in both directions:

> The file's basename is the `snake_case` of the declaration's name.

```text
app/models/invoice.rb          <->  model :Invoice
app/policies/invoice.rb        <->  policy :Invoice
app/layouts/app.rb             <->  layout :App
app/screens/dashboard.rb       <->  screen :Dashboard
app/actions/issue_invoice.rb   <->  action :issue_invoice
app/jobs/send_invoice_email.rb <->  job :SendInvoiceEmail
app/ledgers/receivables.rb     <->  ledger :Receivables
app/flows/onboarding.rb        <->  flow :Onboarding
domains/billing/domain.rb      <->  domain :Billing
```

Given a name in an error message you can open the file without searching, and
given a file you know what it declares without reading it. Migrations add a
sortable UTC timestamp prefix, and only that:
`20260826120000_create_customers_and_invoices.rb` ↔
`migrate :CreateCustomersAndInvoices`.

One file, one declaration. `has_many :lines` has to resolve to a file whose name
you can guess, which is why `invoice_line.rb` exists as its own six-field file
rather than living inside `invoice.rb`.

## Small app or domains?

`app/` is the small-app shape: one flat set of directories, every model visible
to every other. `domains/` is the large-app shape: the same directories, nested
one level down, with a boundary the framework enforces at boot (spec decision
12).

Ledgerline shows both at once — `app/` is the whole invoicing product, and
`domains/billing/` is one slice pulled out — because that is what the migration
path actually looks like. Note the paths: a domain repeats the *identical*
`app/<concern>/` layout inside itself, so moving a slice out is a `git mv` and a
`domain.rb`, not a rewrite.

**Start in `app/`.** Every app should. Move a slice into `domains/` when at least
two of these are true:

- Two people or two teams keep editing the same models for unrelated reasons.
- A model is being read from code that has no business knowing it exists —
  `Subscription` read from an invoicing screen is the example here.
- The words mean different things in different parts of the app. Ledgerline has
  two "payments" and two "plans"; that ambiguity is the signal.
- You cannot answer "what would break if I changed this model" by reading.
- Boot time or test time is dominated by loading things one change does not touch.

**Do not move a slice because the app got big.** Size is not the trigger;
*entanglement* is. A 200-model app with one team and one vocabulary is fine flat.
A 20-model app where billing and invoicing are quietly reaching into each other
is not, and `depends_on` failing at boot is how you find out before it is
expensive.

What the boundary actually costs: `domains/invoicing/domain.rb` cannot read
`Billing::Subscription`. It subscribes to `Billing.payment_failed` instead. That
is more code and one more indirection, and it is only worth paying for when the
alternative is a direct read nobody can safely delete.

## Spec coverage

Every area of the build spec appears at least once. This table is how to find
the example for a phase you are about to implement.

| Spec area | Where |
| --- | --- |
| `App.define`, tenancy, auth, billing, admin | [`config/app.rb`](config/app.rb) |
| Swap points (spec decision 11) | [`config/backends.rb`](config/backends.rb) |
| Theme, design tokens, light/dark | [`config/theme.rb`](config/theme.rb) |
| `model`, fields, associations, scopes | [`app/models/`](app/models/invoice.rb) |
| `:money` (integer cents, no floats) | [`app/models/invoice_line.rb`](app/models/invoice_line.rb) |
| `migrate`, UUIDv7, injected `tenant_id` | [`db/migrations/`](db/migrations/20260826120000_create_customers_and_invoices.rb) |
| `component` | [`app/components/money_badge.rb`](app/components/money_badge.rb) |
| `screen`, `state`, component kit | [`app/screens/invoices.rb`](app/screens/invoices.rb) |
| `policy`, `default :deny`, `can` | [`app/policies/invoice.rb`](app/policies/invoice.rb) |
| `roles` / `staff_roles`, declared once | [`config/app.rb`](config/app.rb) |
| `policy: :public` and `layout: :None` | [`app/screens/sign_in.rb`](app/screens/sign_in.rb) |
| `layout`, `sidebar`, `nav_item`, `breadcrumbs` | [`app/layouts/app.rb`](app/layouts/app.rb) |
| `action`, `idempotent_by` | [`app/actions/record_payment.rb`](app/actions/record_payment.rb) |
| `live`, `channel`, `broadcast`, `presence` | [`app/screens/dashboard.rb`](app/screens/dashboard.rb), [`app/channels/invoices.rb`](app/channels/invoices.rb) |
| `job`, `schedule :cron` | [`app/jobs/`](app/jobs/dunning_sweep.rb) |
| `ledger`, `debit`/`credit`/`guard` | [`app/ledgers/receivables.rb`](app/ledgers/receivables.rb) |
| `audited`, `immutable_after` | [`app/models/invoice.rb`](app/models/invoice.rb) |
| `flow` (multi-step wizard) | [`app/flows/onboarding.rb`](app/flows/onboarding.rb) |
| `api`, rate limiting, representations | [`app/api/v1.rb`](app/api/v1.rb) |
| `webhook :incoming` / `:outgoing` | [`app/webhooks/`](app/webhooks/stripe_incoming.rb) |
| `auth`, `billing`, `admin_panel` | [`config/app.rb`](config/app.rb) |
| `notification`, per-channel delivery | [`app/notifications/invoice_issued.rb`](app/notifications/invoice_issued.rb) |
| `locales`, `translatable`, `pwa` | [`locales/en.yml`](locales/en.yml), [`app/models/customer.rb`](app/models/customer.rb) |
| Test DSL, factories, `concurrently` | [`test/actions/record_payment_test.rb`](test/actions/record_payment_test.rb) |
| `audited` trail, `travel_to` | [`test/models/invoice_test.rb`](test/models/invoice_test.rb) |
| Idempotent seeds | [`db/seeds.rb`](db/seeds.rb) |
| Domain module system | [`domains/`](domains/billing/domain.rb) |
| Guardrails (no `card_number`, no float money) | [`app/models/payment.rb`](app/models/payment.rb) |

## What writing this taught us

The reason to write the app before the framework is that some of the spec does
not survive contact with a keyboard. Findings so far, each one a change to the
design rather than a note about this app:

- **`retry` cannot be a DSL method.** The spec writes
  `job :Name do retry; ... end`. `retry` is a Ruby keyword; `retry times: 5`
  is a `SyntaxError`, not a method call. The DSL spells it `retries`. Found by
  running `ruby -c` on [`app/jobs/send_invoice_email.rb`](app/jobs/send_invoice_email.rb).
- **`computed :name, :type { ... }` does not parse either.** A brace block binds
  to a method call, and `:money` is a symbol literal. It has to be
  `computed(:name, :type) { ... }`, or the DSL must take the block differently.
- **"Billing" is ambiguous in an invoicing product**, and the ambiguity is
  load-bearing rather than cosmetic: a tenant's receivables and Ledgerline's own
  subscriptions are both "billing", both money, both auditable. They are split
  across a domain boundary here for exactly that reason.
- **A tax rate cannot be a float**, and the spec only forbids floats for
  *currency*. `tax_rate_bp` is an integer in basis points, because `0.21` in a
  multiplication against cents reintroduces the rounding error `:money` exists
  to remove.
- **An app with no `policy` construct invents one, badly.** Before `policy`
  landed in phase 2, this app had written its own authorization three times, in
  three incompatible spellings with three different arities:
  `authorize do |user, params| user.can?(:issue, Invoice.find(...)) end` in one
  action, `authorize { |user, _| user.can?(:record_payment) }` in another — that
  one had quietly dropped the record — and
  `authorize { |user| user.can?(:read, Invoice) }` in the channel. Nothing
  defined `can?`. Three surfaces that must agree cannot be trusted to agree when
  each one writes its own check, and an `admin_panel` — generated, with no block
  to put a check in — could not have written one at all. That is the argument
  for a verb named as an ARGUMENT and refused at boot
  (`MAGIK_POLICY_UNDECLARED`), rather than a block offered inside the construct.
- **The reference application had no navigation.** Two screens, both opening
  their `body` with content, neither carrying a sidebar, a header or a link to
  the other — and nothing in the DSL to put one in. A framework claiming to
  cover most of SaaS cannot leave the shell to the app, because every app then
  writes a different one and none of them is checkable. `layout` is the answer,
  and `nav_item :Invoices` naming a screen *constant* rather than a URL is what
  makes a dead link a boot failure instead of a 404.
- **An incoming webhook has no actor.** `action :record_payment` names
  `policy: %i[Invoice record_payment]`, and its two callers are a modal and
  Stripe. A policy predicate takes an actor; a verified signature is not one.
  `webhook :incoming` is not among the surfaces `MAGIK_POLICY_UNDECLARED`
  lists, so nothing fails to boot — which means the spec has a gap rather than
  a rule. Recorded in [`app/webhooks/stripe_incoming.rb`](app/webhooks/stripe_incoming.rb).
- **A ledger is not a model, so an API over it has no policy to name.**
  `resource :ledger_entries` in [`app/api/v1.rb`](app/api/v1.rb) is the one
  place naming a verb was awkward: `policy :Model` presumes a model, and
  `ledger :Receivables` is not one. It borrows `%i[Invoice read]`, on the
  grounds that an actor who may read the invoice may read the postings that
  explain it — but "what is a policy's subject when the surface is not a model"
  is unanswered.
- **There is no ActiveSupport in a Magik app**, and this file set was full of
  `12.hours`, `30.seconds` and `1.minute` — each of which is a `NoMethodError`
  on an Integer in plain Ruby. Every one is now a `:duration`: a unit-suffixed
  string coerced at boot, which is also why `trial_days 14` became
  `trial "14d"` and `payment_terms_days` was never written.

## Rules for editing this directory

1. **Every file carries the aspirational header.** Four lines, at the top,
   before anything else. A file here without one reads as working code.
2. **Every file must pass `ruby -c`.** Not because it runs, but because a parse
   error hides the design under a syntax complaint.
3. **No file may claim a feature works.** Comments describe intent and design
   rationale in the present tense of the *spec*, never of the implementation.
4. **Keep it small.** Around thirty-five files, and the ceiling is the directory
   set in [`wiki/Project-Layout.md`](../wiki/Project-Layout.md) — one or two
   files per directory, each a clear illustration. The moment a file is here to
   make the app more *realistic* rather than to demonstrate something, delete
   it.
5. **Nothing here is linted or tested.** `dummy/` is excluded from RuboCop and
   is not on `rake test`'s path. When the framework can execute it, that
   changes — and that change is the milestone.
