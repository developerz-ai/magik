# Guardrails

The rules Magik refuses to boot without. The spec says this is the product; this page is the list, with what fails, when it fails, and the error the failure raises.

**Status:** spec only — no guardrail is implemented, no error code is registered, and `magik check` does not exist. Every code below is a `planned` name reserved by design. Reviewed 2026-08-26.

## Why boot

A guardrail is worth building only if it catches the mistake **before** the mistake reaches a user. Three enforcement stages, in order of how early they catch:

| Stage | Runs | Catches | Cost |
|---|---|---|---|
| **boot** | every `magik server`, `magik console`, `magik worker`, `magik test` | anything derivable from the frozen declaration registry | the app does not start |
| **`magik check`** | on demand, in an editor loop, in CI | the same rules plus static analysis that needs no connection, plus `--scale` heuristics over query sites | exit 1 |
| **CI** | `bin/check` on every push | boot + check + tests + lint + docs | the build is red |

The rule: **if it can fail at boot, it fails at boot.** `magik check` exists so an agent can run the same rules in a tight loop without starting a server ([`07-ai-first.md`](07-ai-first.md)), not so a rule can be downgraded to a warning.

The one exception is `--scale`, which is a **warning** by design: an unscoped query is sometimes correct (a platform-wide admin report), so it reports rather than refuses.

## The catalogue

Every guardrail named in [`00-build-spec.md`](00-build-spec.md), plus the ones its architecture decisions imply. Format and field contract: [`../architecture/03-error-codes.md`](../architecture/03-error-codes.md).

### From the spec's guardrail list

| Guardrail | What fails | When | Code | `fix:` |
|---|---|---|---|---|
| Ledger entries must balance | an `entry` block whose debit lines do not sum to its credit lines | boot | `MAGIK_LEDGER_UNBALANCED` | `magik errors explain MAGIK_LEDGER_UNBALANCED` |
| No raw card numbers | a `field :card_number` — or any field matching the PAN name set — declared on any model | boot | `MAGIK_MODEL_FORBIDDEN_FIELD` | `magik generate model <Name> --tokenized-payment` |
| Domain boundaries | a domain referencing another domain's model constant without going through `exposes` or an event | boot | `MAGIK_DOMAIN_BOUNDARY` | `magik check --domains` |
| Stateless screens | a `screen` or `action` assigning an instance variable that outlives the request, or a mutable constant written after boot | boot | `MAGIK_RENDER_SCREEN_STATEFUL` · `MAGIK_ACTION_STATEFUL` | `magik errors explain MAGIK_ACTION_STATEFUL` |
| Timestamps need a zone | a `timestamp` rendered in a component with no `zone:` argument | boot | `MAGIK_RENDER_TIMESTAMP_NO_ZONE` | `magik check --render` |
| Tenant scoping at scale | a query site with no `tenant_id` in its `WHERE` clause | `magik check --scale` (warning) | `MAGIK_SCALE_UNSCOPED_QUERY` | `magik check --scale --json` |

### Authorization, layout and uploads

The three the spec adds beside the list above. Each is derivable from the frozen registry,
consequential, unambiguous and fixable — the four bars at the bottom of this page.

| Guardrail | What fails | When | Code | `fix:` |
|---|---|---|---|---|
| **Every surface reaching a model names a policy verb** | a `screen`, `action`, `api resource`, `channel`, `job` or `admin_panel` with no `policy:` and no explicit `policy: :public` / `policy: :system` | boot | `MAGIK_POLICY_UNDECLARED` | `magik describe policy --json` |
| A policy predicate performs no I/O | a `can` block issuing a query — `live` re-evaluates one per subscriber per change, so a query here is one round trip per row per open socket | boot | `MAGIK_POLICY_IO` | `magik errors explain MAGIK_POLICY_IO` |
| A named verb exists | `policy: %i[Invoice publish]` where `policy :Invoice` declares no `:publish` | boot | `MAGIK_POLICY_UNKNOWN_VERB` | `magik registry --kind policy --json` |
| Denial is the default | a `policy` block with no `default :deny` | boot | `MAGIK_POLICY_NO_DEFAULT` | `magik errors explain MAGIK_POLICY_NO_DEFAULT` |
| A rule receiving a `nil` record denies | a row-level rule that would pass on an absent record | boot (static) | `MAGIK_POLICY_NULL_PASSES` | `magik errors explain MAGIK_POLICY_NULL_PASSES` |
| Every screen has a layout | a `screen` with no `layout:` and no `layout: :None` | boot | `MAGIK_LAYOUT_MISSING` | `magik generate layout App` |
| Navigation cannot rot | a `nav_item` naming a screen that does not exist | boot | `MAGIK_LAYOUT_UNKNOWN_SCREEN` | `magik registry --kind screen --json` |
| Uploads are bounded | a `:file` field or an `attachment` with no `max_size` and no `content_types` — an unbounded upload field is an unbounded storage bill and a trivial DoS | boot | `MAGIK_MODEL_UNCONSTRAINED_UPLOAD` | `magik describe model.attachment --json` |

`MAGIK_POLICY_UNDECLARED` is the load-bearing one. It makes authorization non-optional the way
`tenant_id` is non-optional, which is the only mechanism that survives an agent in a hurry. An
`admin_panel` with no `policy:` is **not** a separate rule — it is this one, and the catalogue
deliberately carries one code rather than two, because the admin is a surface like any other and the
guardrail that protects it is the guardrail that protects all of them.

### Implied by the non-negotiable architecture decisions

| Guardrail | What fails | When | Code |
|---|---|---|---|
| Money is never a float | a `:money` field given a float default, or a float assigned at runtime | boot · runtime | `MAGIK_MODEL_FLOAT_MONEY` |
| Ledger is append-only | an `update`/`delete` reaching a posted ledger entry | runtime | `MAGIK_LEDGER_ENTRY_MUTATED` |
| Immutability holds | a write to a field covered by `immutable_after:` past its point | runtime | `MAGIK_MODEL_IMMUTABLE_VIOLATION` |
| Money mutations dedupe | an action that posts a ledger entry and declares no `idempotent_by:` | boot | `MAGIK_ACTION_IDEMPOTENCY_REQUIRED` |
| Every model is tenant-scoped | a model that opts out of `tenant_id` with no declared reason | boot | `MAGIK_MODEL_NO_TENANT` |
| Routes are unique | two actions or screens compiling to the same path | boot | `MAGIK_ROUTER_PATH_CONFLICT` |
| Inbound webhooks are verified | a `webhook :incoming` with no `verify_signature` | boot | `MAGIK_WEBHOOK_UNVERIFIED` |
| Migrations are reversible | a `migrate` with no `down` block | boot | `MAGIK_SCHEMA_IRREVERSIBLE` |
| Schema matches declarations | a model field with no applied migration behind it | boot | `MAGIK_SCHEMA_DRIFT` |
| Backends are known and proven | `use :cache, :something_unshipped` | boot | `MAGIK_CONFIG_UNKNOWN_BACKEND` |
| No offline | `pwa do offline … end`, or any request for a client-side data cache | boot | `MAGIK_PWA_OFFLINE_UNSUPPORTED` |
| Component contracts hold | a component replacing a kit one (`satisfies Magik::Kit::X`) missing a required prop, slot, htmx target or event ([`08-component-overrides.md`](08-component-overrides.md)) | boot | `MAGIK_COMPONENT_CONTRACT_VIOLATION` |
| Locale completeness | a `t()` key missing from a shipped locale | `magik check` | `MAGIK_I18N_MISSING_KEY` |
| App is defined once | a second `App.define` in one process | boot | `MAGIK_BOOT_REDEFINED` |

## What a failure looks like

Boot failure output is the same object rendered three ways — terminal, `--json`, and the dev error page ([`../architecture/03-error-codes.md`](../architecture/03-error-codes.md)). The intended terminal shape:

```
MAGIK_LEDGER_UNBALANCED  app/ledgers/payments.rb:14

  entry :refund debits 1 line (refunds) and credits 2 lines (cash, fees);
  debits total :amount, credits total :amount + :fee_amount

  fix: magik errors explain MAGIK_LEDGER_UNBALANCED

Boot aborted. 1 guardrail failed, 23 passed.
```

| Field | Rule |
|---|---|
| code | stable forever once shipped. Agents and log pipelines pattern-match on it. |
| location | the declaration site — `file:line` of the offending block, never a framework frame. |
| cause | the specific fact, with the real identifiers. Not a restatement of the code. |
| `fix:` | an executable command wherever one exists. Advice only where no command can help. |

## Adding a guardrail

The bar, so the list stays worth reading:

| Test | Question |
|---|---|
| Derivable | can the rule be decided from the frozen registry or from source, with no network and no guesswork? |
| Consequential | does violating it cause a production incident, a security hole, or a migration nobody survives? |
| Unambiguous | is there a legitimate app that breaks the rule on purpose? If yes, it is a `magik check` warning, not a boot failure. |
| Fixable | is there a command, a generator flag, or a one-line edit that resolves it? |

A rule that fails the last test ships as a warning with a documented rationale. A rule that fails the third one does not ship at all.

Implementation contract — where guardrail code lives, and why the boot runner is in `core` while the static rule set is in `check`: [`../architecture/02-boundaries.md`](../architecture/02-boundaries.md).
