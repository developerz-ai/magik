# Error codes

The design of the `MAGIK_*` catalogue: the code format, the fields every error carries, how `magik errors explain` reads it, and the seed table implied by the guardrails.

**Status:** planned. No error class, no catalogue entry and no `magik errors` command exists. Every code below is a reserved name, not a shipped one. Reviewed 2026-08-26.

## Why codes

An error is the framework's only chance to be useful at the moment something is wrong, and its audience is usually an agent ([`../idea/07-ai-first.md`](../idea/07-ai-first.md)). A stable code is what makes an error searchable, matchable in a log pipeline, and answerable without reading framework source. A `fix:` line is what makes it actionable without a human.

**Errors are instructions.** Prose advice is something a reader has to interpret; a command is something it can run.

## Code format

```
MAGIK_<SUBSYSTEM>_<CONDITION>
```

| Rule | Detail |
|---|---|
| Prefix | `MAGIK_`, always. |
| Subsystem | the owning subsystem from [`01-module-map.md`](01-module-map.md), uppercased — `LEDGER`, `MODEL`, `RENDER`, `POLICY`, `DOMAIN`, `BOOT`, `CONFIG`, `SCALE`. |
| Condition | what is wrong, not what to do — `UNBALANCED`, `FORBIDDEN_FIELD`, `PATH_CONFLICT`. |
| Case | `SCREAMING_SNAKE`. |
| One code per condition | never one code for a family. `magik errors explain` should answer the specific mistake, not a category. |
| Stability | a shipped code is stable forever. Rewording the message is fine; renaming the code is a breaking change. |
| Registration | `lib/magik/<subsystem>/errors.rb`, one catalogue entry per code. A raise with an unregistered code fails the catalogue test. |

## Required fields

Every error is a `Magik::Error` subclass carrying:

| Field | Type | Rule |
|---|---|---|
| `code` | String | the stable identifier above |
| `cause` | String | the specific fact, with the real identifiers. Never a restatement of the code |
| `location` | String | `file:line` in **app** code — the declaration site, not a framework frame |
| `fix` | String | an executable command wherever one exists; advice only where none can |
| `stage` | Symbol | `:boot`, `:check`, `:runtime` — where this condition is detected |
| `severity` | Symbol | `:error` (refuses) or `:warning` (reports, e.g. `--scale`) |
| `doc` | String | the docs path that explains the rule |
| `details` | Hash | structured specifics for `--json` — the two totals, the two domains, the conflicting paths |

```ruby
raise Magik::Ledger::UnbalancedEntry.new(
  code:     "MAGIK_LEDGER_UNBALANCED",
  cause:    "entry :refund debits [:refunds] and credits [:cash, :fees]",
  location: "app/ledgers/payments.rb:14",
  fix:      "magik errors explain MAGIK_LEDGER_UNBALANCED",
  stage:    :boot,
  severity: :error,
  doc:      "docs/idea/03-guardrails.md",
  details:  { ledger: "Payments", entry: "refund", debits: ["refunds"], credits: %w[cash fees] }
)
```

## Three renderings, one object

| Rendering | Audience | Shape |
|---|---|---|
| Terminal | a human at a CLI | code, location, cause indented, `fix:` line, then the boot summary |
| `--json` | an agent, CI, a log pipeline | the full field set, one object per finding, stable schema |
| Dev error page | a human in a browser | the same code, cause and `fix:`, plus the app frame — never a raw 40-frame backtrace ([`06-observability.md`](06-observability.md)) |

The rule: **the same code and the same `fix:` string in all three.** A rendering that paraphrases is a rendering an agent cannot match on.

## `magik errors explain <CODE>`

The catalogue as a command. Planned shape:

```bash
magik errors explain MAGIK_LEDGER_UNBALANCED
magik errors explain MAGIK_LEDGER_UNBALANCED --json
magik errors list --subsystem ledger --json
```

Text output: what the rule is, why it exists, the shortest failing example, the fix, and the doc link.

`--json` output, one stable object:

```json
{
  "code": "MAGIK_LEDGER_UNBALANCED",
  "subsystem": "ledger",
  "stage": "boot",
  "severity": "error",
  "summary": "A ledger entry's debits do not equal its credits.",
  "why": "Double-entry only holds if every entry balances; an unbalanced entry corrupts every downstream total.",
  "fix": "Make the debit lines and credit lines of the entry sum to the same amount.",
  "example": "entry :refund do |amount:|\n  debit :refunds, amount\n  credit :cash, amount\nend",
  "doc": "docs/idea/03-guardrails.md",
  "since": "unreleased"
}
```

| Property | Rule |
|---|---|
| Source | the same registry the raise reads. There is no second copy of the catalogue to drift. |
| Offline | no network, no database, no app boot — an agent can call it mid-edit. |
| Schema stability | the `--json` field set is additive-only across versions. Removing or renaming a field is a breaking change. |
| Coverage | a catalogue test asserts every `Magik::Error` subclass has an entry, and every entry has a `fix` and a `doc` that resolves. |

## Seed catalogue

Every code implied by [`../idea/03-guardrails.md`](../idea/03-guardrails.md) and the spec's architecture decisions. **All planned** — none is registered.

| Code | Subsystem | Stage | Severity | Condition |
|---|---|---|---|---|
| `MAGIK_BOOT_REDEFINED` | core | boot | error | a second `App.define` in one process |
| `MAGIK_BOOT_GUARDRAIL_FAILED` | core | boot | error | the aggregate failure that aborts the boot after individual findings |
| `MAGIK_CONFIG_UNKNOWN_BACKEND` | core | boot | error | `use :seam, :name` naming a backend that does not ship |
| `MAGIK_CONFIG_MISSING_KEY` | core | boot | error | a declared-required config key with no value ([`07-configuration-and-secrets.md`](07-configuration-and-secrets.md)) |
| `MAGIK_MODEL_FORBIDDEN_FIELD` | model | boot | error | `field :card_number` or another PAN-shaped field |
| `MAGIK_MODEL_FLOAT_MONEY` | model | boot · runtime | error | a float reaching a `:money` field |
| `MAGIK_MODEL_NO_TENANT` | model | boot | error | a model with no `tenant_id` and no declared reason |
| `MAGIK_MODEL_IMMUTABLE_VIOLATION` | model | runtime | error | a write past `immutable_after:` |
| `MAGIK_MODEL_UNCONSTRAINED_UPLOAD` | model | boot | error | a `:file` field or `attachment` with no `max_size` and no `content_types` — an unbounded upload field is an unbounded storage bill and a trivial DoS |
| `MAGIK_SCHEMA_IRREVERSIBLE` | schema | boot | error | a `migrate` with no `down` |
| `MAGIK_SCHEMA_DRIFT` | schema | boot | error | a declared field with no applied migration behind it |
| `MAGIK_ROUTER_PATH_CONFLICT` | router | boot | error | two declarations compiling to one path |
| `MAGIK_POLICY_UNDECLARED` | policy | boot | error | a `screen`, `action`, `api resource`, `channel`, `job` or `admin_panel` with no `policy:` and no explicit `policy: :public` / `policy: :system` |
| `MAGIK_POLICY_IO` | policy | boot | error | a `can` block issuing a query — `live` re-evaluates one per subscriber per change, so a query here is one round trip per row per open socket |
| `MAGIK_POLICY_UNKNOWN_VERB` | policy | boot | error | `policy: %i[Invoice publish]` where `policy :Invoice` declares no `:publish` |
| `MAGIK_POLICY_NO_DEFAULT` | policy | boot | error | a `policy` block with no `default :deny` |
| `MAGIK_POLICY_NULL_PASSES` | policy | boot | error | a row-level rule that would pass on an absent record |
| `MAGIK_RENDER_SCREEN_STATEFUL` | render | boot | error | a screen holding state across requests |
| `MAGIK_RENDER_TIMESTAMP_NO_ZONE` | render | boot | error | a timestamp rendered with no explicit zone |
| `MAGIK_COMPONENT_CONTRACT_VIOLATION` | render | boot | error | a replacement component missing a contract prop, slot, target or event |
| `MAGIK_LAYOUT_MISSING` | render | boot | error | a `screen` with no layout and no `layout: :None` |
| `MAGIK_LAYOUT_UNKNOWN_SCREEN` | render | boot | error | a `nav_item` naming a screen that does not exist |
| `MAGIK_ACTION_STATEFUL` | action | boot | error | an action holding state across requests |
| `MAGIK_ACTION_IDEMPOTENCY_REQUIRED` | action | boot | error | a money-posting action with no `idempotent_by:` |
| `MAGIK_LEDGER_UNBALANCED` | ledger | boot | error | debits ≠ credits in an `entry` |
| `MAGIK_LEDGER_ENTRY_MUTATED` | ledger | runtime | error | an update or delete reaching a posted entry |
| `MAGIK_JOBS_NO_PERFORM` | jobs | boot | error | a `job` declaring no `perform` |
| `MAGIK_WEBHOOK_UNVERIFIED` | api | boot | error | an inbound webhook with no `verify_signature` |
| `MAGIK_ADMIN_INLINE_MUTATION` | admin | boot | error | an `admin_panel` declaring a write path that is not one of the app's own actions — a Magik admin cannot have a mutation the product does not have |
| `MAGIK_PWA_OFFLINE_UNSUPPORTED` | pwa | boot | error | an offline strategy or app-data cache requested |
| `MAGIK_I18N_MISSING_KEY` | i18n | check | error | a `t()` key missing from a shipped locale |
| `MAGIK_DOMAIN_BOUNDARY` | domains | boot | error | a direct cross-domain model reference |
| `MAGIK_DOMAIN_UNDECLARED_DEPENDENCY` | domains | boot | error | using a domain absent from `depends_on` |
| `MAGIK_DOMAIN_CYCLE` | domains | boot | error | a dependency cycle between domains |
| `MAGIK_DOMAIN_UNKNOWN_EVENT` | domains | boot | error | subscribing to an unpublished event |
| `MAGIK_DOMAIN_DUPLICATE_OWNER` | domains | boot | error | two domains claiming one model |
| `MAGIK_SCALE_UNSCOPED_QUERY` | check | check | warning | a query site with no `tenant_id` in `WHERE` |
| `MAGIK_BOUNDARY_TIER` | check | check | error | a sideways or upward require inside `lib/magik/` ([`02-boundaries.md`](02-boundaries.md)) |
| `MAGIK_BOUNDARY_INTERNAL_REQUIRE` | check | check | error | requiring past another subsystem's front door |
| `MAGIK_HARNESS_STALE` | cli | check | warning | a generated app's framework block was written by an older magik than the one installed — `fix: magik generate agents --update` |
| `MAGIK_HARNESS_MARKERS_MISSING` | cli | check | error | the `magik:framework-block` markers a regeneration needs were removed by hand, so an update refuses rather than guessing where the boundary was |

**One code, every surface.** `MAGIK_POLICY_UNDECLARED` is the load-bearing row, and it is deliberately owned by `policy` rather than by each surface that can trip it. There is no admin-specific "unprotected panel" code, no channel-specific one and no job-specific one: an `admin_panel` with no `policy:` fails the boot under the same code as a `screen` with no `policy:`, because it is the same mistake. A per-surface family would be exactly the "one code for a category" the format rules above refuse, in reverse — and the point of the guardrail is that authorization is non-optional the way `tenant_id` is, not that the admin panel is a special case.

The last two rows are **reserved and proposed, not implemented** — they are named by [`../idea/09-app-scaffold.md`](../idea/09-app-scaffold.md) so the names cannot be taken twice. Neither the `magik check` that would report a stale harness nor the `magik generate agents --update` that would fix one exists. Both also sit outside the `MAGIK_<SUBSYSTEM>_<CONDITION>` shape above — `HARNESS` is not a subsystem — which is a thing to settle before either is registered.

## Option-level errors (R7)

The contract above is **extended, not replaced**, for the largest class of errors a construct produces: a misspelled or illegal option. R7 ([`00-conventions.md`](00-conventions.md#dsl-design-rules-r1r10)) requires that such a failure carry the four facts that let an agent fix it without reading framework source — the option it was given, what it probably meant, the legal set, and where to look the rest up.

```json
{ "code": "MAGIK_MODEL_UNKNOWN_OPTION",
  "cause": "field :status, :enum was given `options:`; the option is spelled `values:`",
  "location": "app/models/order.rb:4",
  "stage": "boot",
  "severity": "error",
  "details": { "construct": "model", "declaration": "field", "option": "options",
               "given": "options", "did_you_mean": "values",
               "allowed": ["required","unique","default","values","currency","translatable"] },
  "fix": "magik describe model.field --json" }
```

| Rule | Detail |
|---|---|
| The `fix:` points at `magik describe` | not at prose, and not at this page. `magik describe` answers about the *grammar*, so it needs no app, no boot and no database and can be run mid-edit ([`01-module-map.md`](01-module-map.md#the-option-tables-and-magik-describe)) |
| `allowed` comes from the option table | the same rows the coercer just rejected the value against. There is no second list to drift (R8) |
| `did_you_mean` is best-effort | omitted rather than guessed when nothing is close. A wrong suggestion costs more than none |
| The error is what teaches the lookup | an agent that has seen one of these knows `magik describe` exists. That is the mechanism, and it is why the `fix:` line may not be softened into advice |

`magik describe` is a phase-1 command and **is not implemented**; neither is any option table. This section is the contract those errors will be written against.

## Adding a code

| # | Step |
|---|---|
| 1 | Confirm it is a distinct condition, not a variation of an existing one. |
| 2 | Register it in `lib/magik/<subsystem>/errors.rb` with `summary`, `why`, `example`, `fix`, `doc`. |
| 3 | Raise it from exactly one place, with real identifiers in `cause`. |
| 4 | Write the test that triggers it and asserts the code — not the message text. |
| 5 | Add the row to this page and to [`../idea/03-guardrails.md`](../idea/03-guardrails.md) if it is a guardrail. |
| 6 | Record it in `CHANGELOG.md`. It is now permanent. |
