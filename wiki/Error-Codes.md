# Error codes

**Status:** `Format contract real, catalogue almost entirely planned`. **Eight codes exist today.**
Every other code on this page is seeded from the guardrails in
[`docs/idea/00-build-spec.md`](../docs/idea/00-build-spec.md) and is raised by nothing.
`As of 2026-08-26`.

Every failure Magik raises is a `Magik::Error` carrying three things, and all three are required:

1. a **stable code** matching `MAGIK_[A-Z0-9_]+` — greppable, linkable, safe to match on in a test;
2. a **cause** — one sentence about what actually went wrong;
3. a **fix** — a runnable command or a concrete edit. Never "check your configuration".

---

## The format contract

```text
MAGIK_LEDGER_UNBALANCED: entry :invoice_issued debits 14999, credits 14900
  fix: correct the amounts in app/ledgers/receivables.rb — debits must equal credits
```

```json
{
  "code": "MAGIK_LEDGER_UNBALANCED",
  "cause": "entry :invoice_issued debits 14999, credits 14900",
  "fix": "correct the amounts in app/ledgers/receivables.rb — debits must equal credits"
}
```

The JSON is `Magik::Error#to_h`. One object, three renderings — the terminal, the development error
page, and `--json` — and they never disagree, because there is one source.

```ruby
raise Magik::Error.new(
  "the app has no `App.define` block",
  code: "MAGIK_NO_APP",
  fix:  "run `magik new myapp` to generate one"
)
```

Reusable errors declare their defaults once:

```ruby
class MissingTenant < Magik::Error
  code "MAGIK_MISSING_TENANT"
  fix  "add `tenant_by :subdomain` to your App.define block"
end

raise MissingTenant, "query on :Invoice has no tenant_id in WHERE"
```

| Rule | Detail |
|---|---|
| Lookup | `magik errors explain <CODE> --json` — *planned*; today, this page |
| Uniqueness | one code is owned by exactly one subsystem |
| Stability | a shipped code never changes meaning and is never reused. A renamed concept gets a new code and the old one stays documented |
| `fix` is executable | a command, a call to paste, or an edit naming a file. A `fix:` reading "do the right thing" is a bug — [file it](https://github.com/developerz-ai/magik/issues) |
| Bare `Error` | never raised by the framework for a framework condition. A code, a cause and a fix, or it is not a Magik error |
| Enforced format | `Magik::Error` validates the code against `CODE_FORMAT` and refuses a blank `fix` at construction. A malformed code is an `ArgumentError` before it ever reaches a user |

---

## The catalogue is generated once the checker exists

**This page is hand-written today and that is a temporary state.** Codes are declared by the
subsystem that owns them; the intent is that `magik check` reads those declarations and the catalogue
is generated from them, with drift between the code and this page failing the gate — the same
mechanism used for the module map.

Until then, a code on this page is a code somebody wrote down. Treat the eight in
[Live today](#live-today) as real and everything else as a design artefact.

---

## Live today

Eight codes, all in the CLI, all raised by code you can run. Re-derive the list rather than trusting
it: `ruby scripts/checks/error_codes.rb` fails the build if this table and `lib/` disagree, in either
direction.

| Code | Means | Typical cause | Fix |
|---|---|---|---|
| `MAGIK_ERROR` | the base code | a one-off `Magik::Error` raised with no more specific class | read the cause; it names the condition |
| `MAGIK_UNKNOWN_COMMAND` | not a Magik command | a typo, or a command from another tool | `magik help` lists every command |
| `MAGIK_COMMAND_NOT_IMPLEMENTED` | a specified command that is not built | every command except `version`, `help` and `docs` | `magik help` for what runs today; [`ROADMAP.md`](../ROADMAP.md) for when the rest lands |
| `MAGIK_INVALID_OPTION` | a flag this command does not take | a typo, or a flag from a different command | `magik help <command>` for its flags |
| `MAGIK_DOCS_UNAVAILABLE` | no shipped documentation tree was found at all | a damaged install, or a `MAGIK_DOCS_ROOT` pointing at nothing | reinstall the gem with `gem install magik`, or set `MAGIK_DOCS_ROOT` to a checkout of <https://github.com/developerz-ai/magik> |
| `MAGIK_DOCS_PAGE_NOT_FOUND` | a slug or path names no shipped page | a typo, or a page from a different version of the gem | `magik docs list` shows every page that ships with this gem |
| `MAGIK_DOCS_AMBIGUOUS_PAGE` | a shorthand slug matches more than one page | `magik docs models`, where two trees carry that name | `magik docs list`, then use the full slug — `magik docs wiki/models` |
| `MAGIK_DOCS_MISSING_TERM` | a search with nothing to search for | `magik docs search` with no argument | `magik docs search <term>`, e.g. `magik docs search ledger` |

`MAGIK_UNKNOWN_COMMAND` and `MAGIK_INVALID_OPTION` exit `2`; `MAGIK_COMMAND_NOT_IMPLEMENTED` exits
`1`. "Not built yet" and "not a command" are different facts and get different codes and different
exits.

---

## Planned — seeded from the guardrails

The spec's [Guardrails to Enforce at Boot](../docs/idea/00-build-spec.md) section is the seed, and
each rule in it has a code. It names six original rules, and a further table covering authorization,
the application shell and uploads.

### The six original spec guardrails

| Code | Means | Cause | Fix |
|---|---|---|---|
| `MAGIK_LEDGER_UNBALANCED` | a ledger entry's debits and credits disagree | an `entry` block whose sides do not sum to zero | correct the amounts in the ledger declaration. Boot, not runtime |
| `MAGIK_PAN_FIELD_FORBIDDEN` | a field would store a card number | `field :card_number`, or any PAN-shaped field name, under any type | store a provider token: `field :payment_method_token, :string` |
| `MAGIK_DOMAIN_BOUNDARY_VIOLATION` | a domain reached another domain's model directly | a reference to a constant the owning domain does not `expose` | add `exposes :X` to the owner, or subscribe to a published event |
| `MAGIK_STATEFUL_SCREEN` | a screen holds state across requests | an instance variable assigned outside a render pass | put it in the URL, or in a `state` declaration that recomputes |
| `MAGIK_TIMEZONE_UNSPECIFIED` | a timestamp renders with no timezone | a `:timestamp` field rendered without `zone:` | add `zone: :tenant`, or an explicit IANA zone name |
| `MAGIK_TENANT_SCOPE_MISSING` | a query has no `tenant_id` in its `WHERE` | a scope or raw dataset built outside the tenant scope | add `.for_tenant`, or declare it exempt with `global_scope!`. Reported by `magik check --scale` |

### Authorization, layout and uploads

Added to the guardrail set by the same spec section, for the same reason the six above are guardrails:
each is a rule the frozen registry can decide at boot, each is consequential, and each is fixable by
an edit the error can name. `policy` and `layout` are phase 2 constructs — see
[Screens and components](Screens-And-Components.md) and
[Auth, billing, admin](Auth-Billing-Admin.md).

| Code | Means | Cause | Fix |
|---|---|---|---|
| `MAGIK_POLICY_UNDECLARED` | a surface that reaches a model names no verb | a `screen`, `action`, `api resource`, `channel`, `job` or `admin_panel` with no `policy:` and no explicit `policy: :public` / `policy: :system` | name one — `screen :Invoices, policy: %i[Invoice read]`. `magik describe policy --json` prints the grammar |
| `MAGIK_POLICY_IO` | a policy predicate performs I/O | a `can` block issuing a query. A `live` screen re-evaluates one per subscriber per change, so a query here is a round trip per row per open socket | load the record in the surface's `state` and let the predicate read it. `magik errors explain MAGIK_POLICY_IO` |
| `MAGIK_POLICY_UNKNOWN_VERB` | `policy:` names a verb nothing declares | `policy: %i[Invoice publish]` where `policy :Invoice` declares no `:publish` | add `can :publish` to `app/policies/invoice.rb`, or correct the verb. `magik registry --kind policy --json` lists every declared verb |
| `MAGIK_POLICY_NO_DEFAULT` | a policy does not state its default | a `policy` block with no `default :deny` | add `default :deny` as the block's first line. There is no implicit allow |
| `MAGIK_POLICY_NULL_PASSES` | a row rule would pass on an absent record | a `can` block whose predicate returns truthy when the record is `nil` | deny the `nil` — `can :read do \|actor, invoice\| invoice && … end` |
| `MAGIK_LAYOUT_MISSING` | a screen has no application shell | a `screen` with no `layout:` and no `layout: :None` | `magik generate layout App`, then declare `layout: :App` on the screen |
| `MAGIK_LAYOUT_UNKNOWN_SCREEN` | navigation points at nothing | a `nav_item` naming a screen that does not exist | `magik registry --kind screen --json` lists every screen; correct the name, or declare the screen |
| `MAGIK_MODEL_UNCONSTRAINED_UPLOAD` | an upload field is unbounded | a `:file` field or an `attachment` with no `max_size` and no `content_types` — an unbounded upload is an unbounded storage bill and a trivial DoS | declare both — `attachment :hero, :image, max_size: "10MB", content_types: %w[image/png image/jpeg]`. `magik describe model.attachment --json` prints the options |

`MAGIK_POLICY_UNDECLARED` is the load-bearing one. It makes authorization non-optional the way
`tenant_id` is non-optional, and it is what makes an unprotected `admin_panel` a boot failure rather
than a documented risk — one code covering every surface rather than a special case per surface.

### Core and CLI

| Code | Means | Fix |
|---|---|---|
| `MAGIK_NOT_IN_APP` | the command needs an app and found none | run it inside a Magik app, or `magik new <name>` |
| `MAGIK_NO_APP` | no `App.define` block was found | add one to `config/app.rb` |
| `MAGIK_SETUP_INCOMPLETE` | no bundle or no database | `bin/setup` |
| `MAGIK_RESTART_REQUIRED` | a changed file cannot be hot-reloaded | restart `magik server`. See [Development loop](Development-Loop.md) |
| `MAGIK_CONFIG_INVALID` | a config key is missing or malformed | the cause names the key; `.env.example` lists them all |
| `MAGIK_GENERATE_WOULD_OVERWRITE` | a generator would clobber hand-written code | rename, or pass `--force` deliberately |

### Models and schema

| Code | Means | Fix |
|---|---|---|
| `MAGIK_RECORD_NOT_FOUND` | `find!` matched nothing | check the id, or use `find` and handle `nil` |
| `MAGIK_LAZY_ASSOCIATION` | an association was accessed without being eagerly loaded | add `.eager(:name)` to the query that loaded the record |
| `MAGIK_MONEY_FLOAT` | a `Float` reached a `:money` field | pass integer cents, or `Money.usd("149.99")` |
| `MAGIK_CURRENCY_MISMATCH` | arithmetic across two currencies | convert explicitly, with an explicit rate |
| `MAGIK_IMMUTABLE_RECORD` | a write past `immutable_after:` | issue a correcting record instead of editing a settled one |
| `MAGIK_MIGRATION_IRREVERSIBLE` | a migration has no `down` | add one, or declare `irreversible!` deliberately |
| `MAGIK_SCHEMA_DRIFT` | the database does not match the migrations | `magik db migrate`, then `magik db schema` |

### Render, screens and components

| Code | Means | Fix |
|---|---|---|
| `MAGIK_SCREEN_DIRECT_QUERY` | a screen built a query in its `body` | move it to a model `scope` and declare it as `state` |
| `MAGIK_COMPONENT_DIRECT_QUERY` | a component read the database | pass the data in as a prop |
| `MAGIK_PROP_UNDECLARED` | a prop was passed that the component does not declare | declare it, or remove it from the call |
| `MAGIK_COMPONENT_CONTRACT_VIOLATION` | a component shadowing a kit name does not satisfy its contract | the cause names the missing prop, slot or htmx hook. Add it — or stop shadowing the kit name and declare your own. `magik check --contract <Name>` prints the contract |
| `MAGIK_ROUTE_COLLISION` | two screens or actions claim one path | rename one declaration |

### Actions

| Code | Means | Fix |
|---|---|---|
| `MAGIK_MUTATION_OUTSIDE_ACTION` | a write happened outside an `action` | move it into an action |
| `MAGIK_STATEFUL_ACTION` | an action holds state across requests | everything comes from `params`, the tenant, and the database |
| `MAGIK_ASYNC_OUTSIDE_JOB` | a fiber or thread was spawned outside a `job` | declare a job and enqueue it |
| `MAGIK_PARAM_MISSING` | a `required:` param was absent | the cause names it |
| `MAGIK_PARAM_TYPE` | a param did not coerce to its declared type | the cause names the param and both types |
| `MAGIK_GUARD_FAILED` | a `guard` precondition failed | user-facing by design. The message is yours |
| `MAGIK_IDEMPOTENCY_REQUIRED` | a money-moving action has no `idempotent_by` | add `idempotent_by :key` |

### Realtime

| Code | Means | Fix |
|---|---|---|
| `MAGIK_CHANNEL_UNDECLARED` | `live` names a channel nothing declares | declare the channel, or fix the name |
| `MAGIK_CHANNEL_CROSSES_TENANT` | a channel name would span tenants | scope the name to the tenant |
| `MAGIK_REALTIME_BACKEND_UNAVAILABLE` | the configured backend could not be reached | the cause names the backend and the endpoint |

### Jobs

| Code | Means | Fix |
|---|---|---|
| `MAGIK_SCHEDULE_ZONE_MISSING` | a `cron:` schedule has no `zone:` | add one. A cron with no zone shifts twice a year |
| `MAGIK_JOB_ARGS_UNSERIALISABLE` | a job argument cannot be serialised | pass ids, not objects |
| `MAGIK_JOB_TIMEOUT` | an attempt exceeded its `timeout:` | raise the timeout, or split the work |
| `MAGIK_JOB_DEAD` | retries are exhausted | the cause carries the last error. Fix it and re-enqueue |

### Money and ledgers

| Code | Means | Fix |
|---|---|---|
| `MAGIK_LEDGER_APPEND_ONLY` | a ledger entry was updated or deleted | write a reversing entry |
| `MAGIK_MONEY_OUTSIDE_LEDGER` | a `:money` field was written outside a ledger entry | move the movement into the ledger |
| `MAGIK_FLOW_STEP_UNKNOWN` | a flow was resumed at a step that does not exist | the cause names the flow and the step |

### API and webhooks

| Code | Means | Fix |
|---|---|---|
| `MAGIK_WEBHOOK_UNVERIFIED` | an incoming webhook declares no signature verification | add `verify_signature` |
| `MAGIK_WEBHOOK_SIGNATURE_INVALID` | the signature did not match | check the secret. Returns `401`; the body never reaches your handler |
| `MAGIK_API_INLINE_MUTATION` | an API resource wrote directly instead of calling an action | delegate: `create action: :create_invoice` |
| `MAGIK_FILTER_UNDECLARED` | a filter named an undeclared column | add it to `filterable`, or drop the parameter |
| `MAGIK_PAGINATION_UNBOUNDED` | an `index` has no page ceiling | add `per_page:` |
| `MAGIK_SERIALIZER_UNDECLARED` | a resource does not declare which fields leave the building | add a `fields` declaration to the resource block |
| `MAGIK_RATE_LIMITED` | over the plan's limit | returns `429` with `Retry-After` |

### Auth, billing, admin

| Code | Means | Fix |
|---|---|---|
| `MAGIK_TENANT_STRATEGY_MISSING` | no `tenant_by` was declared | add one to `App.define` |
| `MAGIK_ADMIN_INLINE_MUTATION` | an admin action wrote directly | name a real action |

An `admin_panel` with no `policy:` is `MAGIK_POLICY_UNDECLARED`, not a code of its own — see
[Authorization, layout and uploads](#authorization-layout-and-uploads).

### Domains

| Code | Means | Fix |
|---|---|---|
| `MAGIK_DOMAIN_CYCLE` | the `depends_on` graph has a cycle | the cause prints the cycle. Break it with an event |
| `MAGIK_DOMAIN_UNKNOWN` | `depends_on` names a domain that does not exist | check the name |
| `MAGIK_EVENT_UNPUBLISHED` | a subscription names an event nobody publishes | add it to the publisher's `publishes_events` |
| `MAGIK_DECLARATION_MISPLACED` | a declaration is in the wrong directory or domain | move the file — see [Project layout](Project-Layout.md) |
| `MAGIK_FILE_MULTIPLE_DECLARATIONS` | one file declares more than one thing | split it. One declaration per file |

### Testing

| Code | Means | Fix |
|---|---|---|
| `MAGIK_TEST_FAILED` | an assertion failed | the `fix:` is the command that re-runs that one test serially |
| `MAGIK_TEST_SLEEPS` | a test called `sleep` | use `travel_to` |
| `MAGIK_TEST_NETWORK` | a test reached the real network | stub it. The sealed network is not optional |
| `MAGIK_TEST_MISSING` | a declaration has no test file | `magik generate` writes one. Reported by `magik check` |
| `MAGIK_TEST_MISPLACED` | a test file does not mirror `app/` | move it |
| `MAGIK_TEST_MULTIPLE_DECLARATIONS` | one test file declares more than one `test` block | split it |

### Limits — refusals, not failures

These are the permanent exclusions. They are codes rather than silent no-ops **because a limit that
fails quietly is worse than one that refuses loudly.**

| Code | Means | Fix |
|---|---|---|
| `MAGIK_OFFLINE_UNSUPPORTED` | something asked for offline behaviour | there is no offline mode, at any phase. The server is the single source of truth |
| `MAGIK_CLIENT_COMPUTE_UNSUPPORTED` | something asked for heavy client-side compute | out of scope. See [`docs/idea/05-limits.md`](../docs/idea/05-limits.md) |
| `MAGIK_BACKEND_UNKNOWN` | a swap point was pointed at a backend that does not exist | the cause lists the backends that seam accepts |

---

## Next

- [CLI reference](CLI-Reference.md) — the commands the `fix:` lines name.
- [Known gaps](Known-Gaps.md) — what is not built.
- [`docs/idea/03-guardrails.md`](../docs/idea/03-guardrails.md) — why each guardrail exists.
- [`docs/architecture/03-error-codes.md`](../docs/architecture/03-error-codes.md) — how codes are declared and owned.
