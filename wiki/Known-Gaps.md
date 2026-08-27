# Known gaps

**Status:** this is the honest page. `As of 2026-08-26` **the gap is the entire framework.**

A reference manual that hides this is lying to the reader. Every other page on this wiki documents
intended behaviour; this one documents reality, and reality is that `magik 0.0.1` is a name
reservation on RubyGems with a two-command CLI attached.

Resolve it rather than believing this sentence:

```bash
gem list magik --remote --all                          # what RubyGems serves
ruby -Ilib -e 'require "magik"; puts Magik::VERSION'   # what a checkout is stamped at
magik help                                             # every command that runs
```

---

## The gap

| Gap | Symptom | Work around it by |
|---|---|---|
| **The entire framework is unimplemented** | `docs/idea/00-build-spec.md` describes ten phases — 1, 2, 3, 4, 4b, 5, 6, 7, 8, 9 — over thirteen build steps. Zero are built. There is no `App.define`, no `model`, no `screen`, no `action`, no router, no renderer, no job queue, no ledger, no `magik new`. Every DSL block on this wiki is a design artefact that has never been parsed | there is no workaround. Use Rails, or use [Ultimate](https://github.com/developerz-ai/ultimate), and watch [`ROADMAP.md`](../ROADMAP.md) |
| `magik new` does not exist | the command is registered and exits `1` with `MAGIK_CLI_COMMAND_NOT_IMPLEMENTED` | none. It is build step 1 |
| Twelve of the fifteen CLI commands are `MAGIK_CLI_COMMAND_NOT_IMPLEMENTED` | only `version`, `help` and `docs` run | `magik help --json` is the authoritative list, and it marks every command `ready` or `planned`. Re-derive it rather than trusting this row |
| The error catalogue is eight codes, not the ~80 on [Error codes](Error-Codes.md) | four CLI codes and four `MAGIK_DOCS_*` codes. Everything else is written down and raised by nothing | treat that page's [Live today](Error-Codes.md#live-today) table as the real one |
| The error catalogue is hand-written, not generated | it will be generated from the subsystem declarations once `magik check` exists, with drift failing the gate. Until then a code can be on the page and nowhere in the code, and nothing catches it | check `lib/magik/` before depending on a code |
| Every subsystem module is a documented stub | referencing one loads a module that raises `NotImplementedError` naming the spec section it will implement | `ruby -Ilib -e 'require "magik"; puts Magik::SUBSYSTEMS.keys.inspect'` lists all twenty-one |
| `dummy/` is a reference app that has never executed | Ledgerline, an invoicing SaaS, is written out in full — but there is no framework to run it against, so **every declaration in it is a claim, not a behaviour**. It is parse-checked and nothing more: `ruby scripts/checks/dummy_parses.rb` | read it as the spec made executable-shaped. `examples/` is still empty |
| No benchmark exists | the spec targets 1,000 tests in under 10s. Nothing has been measured, because there is no test runner | do not quote a performance number for Magik. There is none to quote |
| TruffleRuby is barely exercised | the production runtime is TruffleRuby and the development default is CRuby. The only TruffleRuby behaviour anyone has measured is `scripts/probes/runtime.rb` ([results](../docs/architecture/12-runtime-verification.md)); everything else runs in CI | assume nothing beyond what that page records |
| No swap point has been proven | every swap on this wiki — DB, cache, jobs, search, realtime — is a design commitment with no implementation and no test on either side | the spec requires a **passing test** before a swap is claimed. None exists |

---

## Design gaps — closed in the spec, unbuilt like everything else

These were once a different kind of gap: capability the spec did not describe at all, so building the
framework exactly as written would still not have produced it. They were found by the coverage audit,
[`docs/idea/10-saas-coverage.md`](../docs/idea/10-saas-coverage.md), which pressure-tested the spec's
claim to cover "99% of SaaS use cases".

**`As of 2026-08-26` every row below has been accepted into the spec.** That closes a *design* gap
and nothing else — the constructs are in [`docs/idea/00-build-spec.md`](../docs/idea/00-build-spec.md)
and drafted in [`docs/idea/02-dsl-surface.md`](../docs/idea/02-dsl-surface.md), and **not one line of
any of them is implemented**, exactly like the rest of the framework. The table is kept because a
reader deciding whether to trust the spec should be able to see what it was missing and when it
stopped missing it.

| Was missing | Symptom at the time | Closed by |
|---|---|---|
| **No authorization primitive** | `auth` identified and explicitly did not authorize; nothing else owned it. There was no `policy`, no roles, no permissions in the grammar. The reference app had already invented `authorize { \|user\| user.can?(…) }` in three incompatible spellings, and the admin guardrail named a "declared access rule" the DSL could not express. **Ranked the most serious gap in the spec**, because the generated surfaces (`api`, `admin_panel`, `channel`, `live`) cannot be guarded from application code | `policy` — a phase 2 construct with its evaluator at tier 1, five `MAGIK_POLICY_*` guardrails, and a `policy:` verb named by every surface. Architecture decision 13. The unsatisfiable admin guardrail was retired in favour of `MAGIK_POLICY_UNDECLARED` |
| **No application shell** | the component kit was twelve components that go *inside* a page and nothing that *is* a page. The reference app had two screens and **no way to navigate between them**. It voided the "zero HTML, CSS or JavaScript" success criterion the first time somebody needed a sidebar | `layout` — a phase 2 construct, plus six kit components (`sidebar`, `topbar`, `nav_item`, `breadcrumbs`, `account_menu`, `dashboard_grid`), `MAGIK_LAYOUT_MISSING` and `MAGIK_LAYOUT_UNKNOWN_SCREEN`. `magik new` is specified to generate a working `:App` layout |
| **Responsiveness is undefined** | one occurrence of the word in the whole tree, describing `grid`. Nothing stated what makes a Magik app work on a phone — and `data_table` on a narrow screen is a genuinely hard problem | a kit property: every component responsive by construction, `render_screen … at: :mobile` as the test, and a phase 2 exit criterion at 375px. `data_table` becomes a card list, never a horizontal scroll |
| **No media construct** | Shrine was on the wrap list and `Storage` was a listed seam; between them there was no field type, no declaration, no derivative pipeline and no transcoding answer. Blocked ecommerce and marketplaces outright | a `:file` field type in phase 1, `attachment` and the media seam in a new **phase 4b**, and `MAGIK_MODEL_UNCONSTRAINED_UPLOAD` |
| **`admin_panel` is a list view** | benchmarked against [Avo](https://avohq.io): no detail view, no association browsing, no forms, no bulk actions, no typed filters, no impersonation. One of Avo's four view types | an expanded `admin_panel` with `list`, `show` and `form`, the shared five-word field vocabulary, and a **required** `policy:` — see [Auth, billing, admin](Auth-Billing-Admin.md#admin-panel) |
| **`data_table` and `chart` are under-specced** | the most-used component in any SaaS documented in one line; `chart` in one word. Both are used by the product *and* the admin, so under-speccing them meant every app built them twice | full DSL-surface sections for both, phase 2 |
| **Email stops at the transport** | no dev preview (which an agent needs more than a human — it has no inbox), no CSS inlining, no plain-text alternative, no mail layout, no suppression list, no bounce handling, no unsubscribe | phase 8 email production, including `magik mail preview` and a framework-owned suppression list |
| **Security defaults are undocumented** | CSRF, CSP, HSTS, frame options, cookie flags, login throttling, enumeration resistance and form honeypots appeared nowhere. **An agent building a signup flow will not add any of them unless they are defaults** | framework defaults in phases 2 and 7, on by default, with a documented override |
| **Environments are thin** | `MAGIK_ENV`, per-environment credentials and `config/environments/` existed; there was no first-class environment concept in the DSL, no staging story, and **no statement of how a seam is selected per environment** | an `environment` block inside `App.define`, phase 1 — the only place a backend is named stays the only place |
| **Two listed seams have no app-facing construct** | `use :search` and `use :cache` resolved backends an app had no way to declare against or query | `searchable` on `model` and `Model.search` in phase 1; fragment caching as an option on `state` and `component` in phase 2 |
| **Data lifecycle is unaddressed** | no soft delete, no archive, no retention, no GDPR export, no erasure. Erasure also collides with `audited` and append-only ledgers | soft delete and archive as a model annotation in phase 1; retention, subject export and erasure — *including* the append-only collision — in phase 5 |

Two things this table is **not**: it is not a claim that any of it works, and it is not a criticism of
what is written. The spec was unusually complete about the transaction shapes of a SaaS — models,
mutations, money, jobs, realtime, APIs — and notably strong on N+1 prevention, tenancy and money
handling. What the audit found is that the shapes a SaaS presents to *people* were the ones nobody
had written down yet. They are written down now. None of them is built.

The coverage count that produced this table is itself owed a re-run: its last full count put full
coverage at under a fifth, and it predates the rows above closing. Re-run it rather than quoting it.

---

## Not built yet, by phase

This is unfinished work, not a defect list. Order and definitions of done are in
[`ROADMAP.md`](../ROADMAP.md); this table is that page reduced to "what is missing".

**Two orderings, and this table carries both.** A phase is an *identity* — which capability a
construct belongs to. A build step is a *position* — when it actually gets written. The spec's ten
phases and its thirteen build steps are deliberately not the same sequence, and where they disagree
**build order wins** ([`docs/idea/06-phases.md`](../docs/idea/06-phases.md)). The rows below are in
delivery order and keep their spec phase number, exactly as `ROADMAP.md` presents them — **nothing
here renumbers a phase.** That is why phase 9 appears third, phase 7 before phase 6, and phase 4b
between 4 and 5.

| Phase | Not built | Build step | Target |
|---|---|---|---|
| **1** — Foundation | `App.define`, `model`, `migrate`, `:money`, `:duration`, `:file`, `computed(:name, :type)`, UUIDv7, tenant injection, `searchable`, soft delete, the option tables and `magik describe`, `new`/`generate`/`console`/`server` | 1–2 | `0.1.0` |
| **2** — Rendering, actions, authorization and the shell | `component`, `screen`, `action`, **`policy`**, **`layout`**, the component kit, `data_table`, `chart`, theming, the security defaults, the router, hot reload | 3–4 | `0.2.0` |
| **9** — Testing, delivered third | the `test` DSL, inferred factories, the helpers, `render_screen … at: :mobile`, the parallel runner | 5 | `0.3.0` |
| **3** — Realtime | `live`, `channel`, `broadcast`, `presence` | 6 | `0.4.0` |
| **4** — Jobs and async | `job`, `retries`, `schedule`, the transactional queue, `magik worker`, CSV import/export | 7 | `0.5.0` |
| **4b** — Media | `attachment`, derivatives, direct upload, magic-byte sniffing, signed delivery, the media seam, blob lifecycle | 8 | `0.6.0` |
| **5** — Money and compliance | `ledger`, `audited`, `immutable_after:`, `idempotent_by`, `flow`, basis-point rates | 9 | `0.7.0` |
| **7** — Auth, billing, admin | `auth`, `billing`, `admin_panel`, `tenant_by`, teams and seats, the abuse defaults | 10 | `0.8.0` |
| **6** — API and webhooks | `api`, `resource`, `webhook`, plan-based rate limits, the delivery log | 11 | `0.9.0` |
| **8** — i18n, PWA, notifications | `locales`, `translatable:`, `pwa`, `notification`, email production | 12 | `0.10.0` |
| **Spec item 12** — Domains and `magik check` | `domain`, boot-time enforcement, `magik check`, `--scale` | 13 | `0.11.0` |

The last row is **not a numbered phase**: domains are architecture decision 12 of the spec, delivered
last because they enforce boundaries across everything that exists by then.

`1.0.0` is not "every row above is green". It is that **plus** four claims proven by something
executable — every swap point tested on both sides, a CRUD screen under 30 lines with its line count
asserted by a test, no `fintech: true` mode anywhere, and a generated app that is safe and usable on
its first run. [`ROADMAP.md`](../ROADMAP.md) carries the proofs each one needs.

---

## Open by decision — these will not be fixed

Each is a real limitation somebody has already argued about, and the reasoning is why it stays. They
are **not** on the roadmap, at any version.

| Limit | Why it stays |
|---|---|
| **No offline support** | the server is the single source of truth. Offline means a local write log, conflict resolution, and a second definition of "what is true" — which is most of the complexity in the frameworks that tried. A PWA ships; an offline cache does not. `MAGIK_PWA_OFFLINE_UNSUPPORTED` refuses loudly rather than half-working |
| **No heavy client-side compute** | canvas editors, games, in-browser media editing, spreadsheet engines. Server-rendered HTML plus htmx is the wrong architecture for these and saying so is more useful than a degraded version. `MAGIK_RENDER_CLIENT_COMPUTE_UNSUPPORTED` |
| **No SPA framework, ever** | React, Vue, Svelte owning rendering — architecture decision 4, and the one that gets challenged most. You *may* attach your own JavaScript behaviour to server-rendered markup; you may not hand rendering to a client framework. See [Screens and components](Screens-And-Components.md#what-no-spa-framework-does-and-does-not-forbid) |
| **No GraphQL** | the API surface is REST, generated from `resource` declarations. A second query language is a second authorization surface |
| **CRuby is not the target** | it is supported for tooling. Where CRuby and TruffleRuby diverge, TruffleRuby is the documented behaviour |
| **Not a multi-gem monorepo** | one gem, subsystem modules. Extraction stays possible; it is not promised, and no page should imply a package boundary that does not exist |
| **No `magik upgrade`** | while the major version is `0`, minor bumps may break the public API and the upgrade path is reading the changelog. A codemod for a DSL that is still being discovered would be a codemod for a moving target |

---

## Is this page allowed to be shorter later?

Yes, and that is the measure of progress. The row that says *the entire framework is unimplemented*
comes off when the entire framework is implemented, and not one phase before it. Every other row
comes off when the thing exists **and has a test**.

Nothing on this page is removed because it became inconvenient to state.

---

## Next

- [`ROADMAP.md`](../ROADMAP.md) — what gets built, in what order, and what "done" means.
- [FAQ](FAQ.md) — including "is this production ready" (no).
- [Error codes](Error-Codes.md) — the eight codes that are real.
- [Contributing](Contributing.md) — the fastest way to make this page shorter.
