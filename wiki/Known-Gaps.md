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
| **The entire framework is unimplemented** | `docs/idea/00-build-spec.md` describes nine phases. Zero are built. There is no `App.define`, no `model`, no `screen`, no `action`, no router, no renderer, no job queue, no ledger, no `magik new`. Every DSL block on this wiki is a design artefact that has never been parsed | there is no workaround. Use Rails, or use [Ultimate](https://github.com/developerz-ai/ultimate), and watch [`ROADMAP.md`](../ROADMAP.md) |
| `magik new` does not exist | the command is registered and exits `1` with `MAGIK_COMMAND_NOT_IMPLEMENTED` | none. It is build step 1 |
| Ten of the twelve CLI commands are `MAGIK_COMMAND_NOT_IMPLEMENTED` | only `version` and `help` run | `magik help --json` is the authoritative list, and it is short |
| The error catalogue is four codes, not the ~60 on [Error codes](Error-Codes.md) | `MAGIK_ERROR`, `MAGIK_UNKNOWN_COMMAND`, `MAGIK_COMMAND_NOT_IMPLEMENTED`, `MAGIK_INVALID_OPTION`. Everything else is written down and raised by nothing | treat that page's [Live today](Error-Codes.md#live-today) table as the real one |
| The error catalogue is hand-written, not generated | it will be generated from the subsystem declarations once `magik check` exists, with drift failing the gate. Until then a code can be on the page and nowhere in the code, and nothing catches it | check `lib/magik/` before depending on a code |
| Every subsystem module is a documented stub | referencing one loads a module that raises `NotImplementedError` naming the spec section it will implement | `ruby -Ilib -e 'require "magik"; puts Magik::SUBSYSTEMS.keys.inspect'` lists all twenty |
| `dummy/` and `examples/` are empty | there is no reference app to read, because there is no framework to write one against | the DSL examples on this wiki are the closest thing, and none of them has been executed |
| No benchmark exists | the spec targets 1,000 tests in under 10s. Nothing has been measured, because there is no test runner | do not quote a performance number for Magik. There is none to quote |
| TruffleRuby is untested locally | the production runtime is TruffleRuby; the development machine has CRuby 3.2.3. Anything TruffleRuby-specific runs in CI | assume nothing about Ractor behaviour until CI has run it |
| No swap point has been proven | every swap on this wiki — DB, cache, jobs, search, realtime — is a design commitment with no implementation and no test on either side | the spec requires a **passing test** before a swap is claimed. None exists |

---

## Design gaps — capability the spec does not describe

A different kind of gap from the one above. Everything in "Not built yet" is **specified and unbuilt**. Everything here is **unspecified**: there is no construct, no phase and no page, so building the framework exactly as written would still not produce it. Found by the coverage audit,
[`docs/idea/10-saas-coverage.md`](../docs/idea/10-saas-coverage.md), which pressure-tested the spec's claim to cover "99% of SaaS use cases". `As of 2026-08-26` none of these has been accepted into the spec — they are tracked proposals, drafted in
[`docs/idea/02-dsl-surface.md`](../docs/idea/02-dsl-surface.md) under "Proposed — not in the build spec".

| Gap | Symptom | Status |
|---|---|---|
| **No authorization primitive** | `auth` identifies and explicitly does not authorize; nothing else owns it. There is no `policy`, no roles, no permissions in the grammar. The reference app already invented `authorize { \|user\| user.can?(…) }` in three incompatible spellings, and `MAGIK_ADMIN_UNPROTECTED` names a "declared access rule" the DSL cannot express — a guardrail no app can satisfy. **Ranked the most serious gap in the spec**, because the framework's generated surfaces (`api`, `admin_panel`, `channel`, `live`) cannot be guarded from application code | proposed as a new primitive, `policy`, landing with phase 2 |
| **No application shell** | the component kit is twelve components that go *inside* a page and nothing that *is* a page. `sidebar`, `app shell`, `breadcrumb` and `breakpoint` appear zero times in `docs/` or `wiki/`. The reference app has two screens and **no way to navigate between them**. It also voids the spec's "zero HTML, CSS or JavaScript" success criterion the first time somebody needs a sidebar | proposed as a new primitive, `layout`, landing with phase 2 |
| **Responsiveness is undefined** | one occurrence of the word in the whole tree, describing `grid`. With no build step and no SPA, nothing states what makes a Magik app work on a phone — and `data_table` on a narrow screen is a genuinely hard problem the spec has not named | proposed as a kit property with a 375px render test, phase 2 |
| **No media construct** | Shrine is on the wrap list and `Storage` is a listed seam; between them there is no field type, no declaration, no derivative pipeline and no transcoding answer. Blocks ecommerce and marketplaces outright | proposed as `attachment` plus a media seam, in a new phase 4b |
| **`admin_panel` is a list view** | benchmarked against [Avo](https://avohq.io): no detail view, no association browsing, no forms, no bulk actions, no typed filters, no impersonation. Only one of Avo's four view types exists. And it cannot boot at all until the authorization gap closes | proposed as an expanded `admin_panel`, phase 7 |
| **`data_table` and `chart` are under-specced** | the most-used component in any SaaS is documented in one line; `chart` in one word. Both are used by the product *and* the admin, so under-speccing them means every app builds them twice | proposed as full sections of the DSL surface, phase 2 |
| **Email stops at the transport** | the `notification` declaration is good and the pipeline around it is missing: no dev preview (which an agent needs more than a human — it has no inbox), no CSS inlining, no plain-text alternative, no mail layout, no suppression list, no bounce handling, no unsubscribe | proposed as extensions to `notification`, phase 8 |
| **Security defaults are undocumented** | CSRF, CSP, HSTS, frame options, cookie flags, login throttling, enumeration resistance and form honeypots appear nowhere. **An agent building a signup flow will not add any of them unless they are defaults** | proposed as framework defaults in phases 2 and 7 |
| **Environments are thin** | `MAGIK_ENV`, per-environment credentials and `config/environments/` exist; there is no first-class environment concept in the DSL, no staging story, and **no statement of how a seam is selected per environment** — the obvious deployment the swap-point page implies and never describes | proposed as an `environment` block in `App.define`, phase 1 |
| **Two listed seams have no app-facing construct** | `use :search` and `use :cache` resolve backends an app has no way to declare against or query | proposed as `searchable`/`Model.search` and caching options on `state`, phases 1–2 |
| **Data lifecycle is unaddressed** | no soft delete, no archive, no retention, no GDPR export, no erasure. Erasure also collides with `audited` and append-only ledgers, so it needs designing rather than adding | proposed across phases 1 and 5 |

Two things this table is **not**: it is not a promise that any of these will ship, and it is not a criticism of what is written. The spec is unusually complete about the transaction shapes of a SaaS — models, mutations, money, jobs, realtime, APIs — and notably strong on N+1 prevention, tenancy and money handling. What the audit found is that the shapes a SaaS presents to *people* were the ones nobody had written down yet.

---

## Not built yet, by phase

This is unfinished work, not a defect list. Order and definitions of done are in
[`ROADMAP.md`](../ROADMAP.md).

| Phase | Not built | Target |
|---|---|---|
| 1 — Foundation | `App.define`, `model`, `migrate`, `:money`, UUIDv7, tenant injection, `new`/`generate`/`console`/`server` | `0.1.0` |
| 2 — Rendering and actions | `component`, `screen`, `action`, the component kit, theming, the router, hot reload | `0.2.0` |
| 3 — Testing | the `test` DSL, inferred factories, the helpers, the parallel runner | `0.3.0` |
| 4 — Realtime | `live`, `channel`, `broadcast`, `presence` | `0.4.0` |
| 5 — Jobs | `job`, the transactional queue, `magik worker` | `0.5.0` |
| 6 — Money and compliance | `ledger`, `audited`, `immutable_after:`, `idempotent_by`, `flow` | `0.6.0` |
| 7 — Auth, billing, admin | `auth`, `billing`, `admin_panel`, `tenant_by` | `0.7.0` |
| 8 — API and webhooks | `api`, `resource`, `webhook` | `0.8.0` |
| 9 — i18n, PWA, notifications | `locales`, `translatable:`, `pwa`, `notification` | `0.9.0` |
| 10 — Domains and check | `domain`, boot-time enforcement, `magik check`, `--scale` | `0.10.0` |

---

## Open by decision — these will not be fixed

Each is a real limitation somebody has already argued about, and the reasoning is why it stays. They
are **not** on the roadmap, at any version.

| Limit | Why it stays |
|---|---|
| **No offline support** | the server is the single source of truth. Offline means a local write log, conflict resolution, and a second definition of "what is true" — which is most of the complexity in the frameworks that tried. A PWA ships; an offline cache does not. `MAGIK_OFFLINE_UNSUPPORTED` refuses loudly rather than half-working |
| **No heavy client-side compute** | canvas editors, games, in-browser media editing, spreadsheet engines. Server-rendered HTML plus htmx is the wrong architecture for these and saying so is more useful than a degraded version. `MAGIK_CLIENT_COMPUTE_UNSUPPORTED` |
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
- [Error codes](Error-Codes.md) — the four codes that are real.
- [Contributing](Contributing.md) — the fastest way to make this page shorter.
