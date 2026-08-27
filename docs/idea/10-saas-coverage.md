# SaaS coverage audit

An adversarial test of one sentence in [`00-build-spec.md`](00-build-spec.md): that Magik covers *"99% of SaaS use cases (CRUD apps, dashboards, fintech, ecommerce, marketplaces) without the user needing to 'graduate' to another stack."*

**Status:** spec only. This page audits a specification, not an implementation. Nothing described as present is *built* — "covered" throughout means *the grammar has a construct for it and the docs specify its behaviour*, and every such construct is `planned` ([`../../wiki/Known-Gaps.md`](../../wiki/Known-Gaps.md)). Nothing on this page has been measured, run, or tested. Reviewed 2026-08-26.

## Verdict

**As a claim about where the grammar stands, "99% of SaaS use cases" is not defensible. As a target the phases are sequenced to reach, it is.** That is how [`00-build-spec.md`](00-build-spec.md) states it, and this page is the measurement it names.

The precise form of the failure matters, because it is not "the spec is thin". The spec is unusually complete about **the transaction shapes of a SaaS** — a row, a mutation, a page, an async job, a double-entry posting, a signed webhook, a versioned API — and it is more rigorous about several of them (money, tenancy, idempotency, N+1) than the frameworks it is competing with. What it does not cover is **the surfaces a SaaS presents to people**: who may do what, what the application looks like around the data, what a support engineer does at 2am, what the signup form does when a bot finds it, and what the email actually looks like when it arrives.

Counted by surface rather than by sentiment, the table below is **68 rows**: the specced grammar fully covers **12**, partially covers **15**, is silent on **40**, and contains **1** surface (admin access control) that is specified as a boot guardrail the DSL cannot satisfy. That is **under a fifth covered**, not 99%.

**What this count is a measurement of.** It was taken on 2026-08-26 against the grammar as the spec then stood, and it is what produced the three closures the spec now carries — `policy` and `layout` in phase 2, and media as phase 4b. **The count has not been re-taken since**, so read every row below as the finding that motivated the design rather than as the state of the current grammar. Re-taking it is owed, and the command is right here.

Re-derive it rather than trusting the sentence — the table is the source, and it is machine-countable:

```bash
awk '/^## The coverage table/,/^## Gap analysis/' docs/idea/10-saas-coverage.md \
  | grep -E '^\| *[0-9]+[a-d]? *\|' | awk -F'|' '{gsub(/\*| /,"",$4); print $4}' | sort | uniq -c
```

Three qualifications keep that number honest in the spec's favour:

| The fair reading | Why it still is not 99% |
|---|---|
| Weighted by *lines of app code*, the covered part is the majority — a SaaS is mostly models, screens, actions and jobs, and those are covered well | the absent items are disproportionately the ones you cannot skip and cannot retrofit. An app with no authorization is not 80% of an app |
| Several absences are one declaration away and belong to a phase that has not been written yet | that is true of about half of them, and this page classifies which. It is not true of authorization or the app shell |
| "99%" is rhetoric, not arithmetic | it is rhetoric in the **mission statement of the spec**, which is the sentence a user believes when choosing the framework. It sets the bar this page measures against |

### What would force a user to graduate to another stack

The claim under test is specifically about *graduation*, so it is worth separating "you must hand-write this" (annoying) from "you must leave" (fatal). Only three items are genuinely fatal, and one is fatal for a different reason than the other two:

| # | Gap | Why it forces an exit |
|---|---|---|
| 1 | **Authorization** | Magik's core value is that one declaration projects to many surfaces — a `model` becomes a screen, an API resource, an admin panel, a realtime channel and a job. **Those surfaces are generated, so the app cannot reach inside them to add a check.** An app can hand-write an authz check in its own `action`; it cannot hand-write one into `api :V1 do resource :invoices do index end end` or into `admin_panel :Invoice`. The app's only remaining move is to stop using the generated surfaces, which is graduating from the framework one construct at a time |
| 2 | **Media — files, images, video, audio** | there is no `:file` field type, no attachment declaration, no derivative pipeline and no transcoding seam. An ecommerce product with no images and a marketplace with no listing photos are not products. Two of the four verticals the mission sentence names are blocked on constructs that do not exist |
| 3 | **The application shell** | this one does not block capability, it **voids the headline success criterion**. "Zero HTML/JS/CSS written" is false on the first afternoon if the sidebar, the topbar and the mobile collapse are `raw` markup. The audience the thesis names — people who specifically do not want a frontend toolchain ([`01-thesis.md`](01-thesis.md)) — leaves over exactly this, and they leave quietly |

Everything else on this page is a real gap that a determined user works around inside Magik.

### What the audit confirms as strong

Being adversarial about a spec means saying where the adversarial reading fails. Three areas hold up under pressure:

| Area | Why it holds |
|---|---|
| **N+1 and debugging** | this is the best-designed part of the spec and the owner's instinct to check it was already answered. Prevention over detection: there is no lazy loading at all, so `MAGIK_LAZY_ASSOCIATION` raises where other frameworks issue a silent query ([`../../wiki/Models.md`](../../wiki/Models.md)). On top of that, [`../architecture/06-observability.md`](../architecture/06-observability.md) specifies same-shape-N-times detection in the dev trace, `magik check --scale` in CI, `magik explain query` showing the injected tenant predicate, and a per-request trace tree that most frameworks structurally cannot assemble. **No gap is manufactured here** |
| **Money and compliance** | `:money` as integer minor units refused at the type system, boot-time ledger balance analysis, `audited`, `immutable_after:`, `idempotent_by:`. The fintech claim in the mission sentence is the one the spec earns most convincingly |
| **Tenancy** | injected rather than remembered, plus `--scale` warnings for query sites that escape it. Retrofitted tenancy is the migration nobody survives, and the spec does not defer it |

### The organising principle this audit recommends

Most of the UI-side findings below collapse into one sentence, and it is a design axiom rather than a feature list:

> **Ship the shape, not the parts.** Nobody's SaaS is a novel interface. It is a sidebar with nav sections, a topbar with search and an account menu, a stat row, a filterable table, a detail view, a settings area, a members page, a billing page, and an empty state before the first record exists. The framework knows that. It should hand it over, not ship twelve components and let ten thousand teams reassemble the same thing.

This is axiom 13 in [`01-thesis.md`](01-thesis.md). It is also, in this audit's judgement, **the sharpest practical differentiator Magik has against Rails** — a bigger one than the DSL — and it compounds with the AI-first thesis, because an agent generates whatever the framework makes easiest. If the conventional shell, the empty state and the responsive collapse are defaults, every generated screen inherits them. If they are documentation, every generated screen is a bare table.

The tension it must respect is the one the thesis already names: opinionated defaults with no escape hatch is the Meteor failure mode. Every piece of shipped shape needs its documented override, on the existing ladder in [`08-component-overrides.md`](08-component-overrides.md) — not a second, special system.

---

## The coverage table

Sixty-eight surfaces a real SaaS needs across its whole life. **Covered** = a construct exists in the grammar and its behaviour is specified. **Partial** = named somewhere but with a hole a first app hits. **Absent** = nothing in `docs/` or `wiki/` addresses it.

Classification column uses the four categories from the gap analysis below: **(a)** in scope, existing phase; **(b)** in scope, needs a new primitive or phase; **(c)** out of scope, belongs in [`05-limits.md`](05-limits.md); **(d)** not the framework's job.

**This table is a dated snapshot, taken before the spec adopted this audit's proposals, and it is deliberately left as counted.** Every **(b)** row below — authorization, the application shell, media — has since become a construct in [`00-build-spec.md`](00-build-spec.md): `policy` and `layout` in phase 2, `attachment` in phase 4b. Rewriting the rows without re-running the count would replace a measurement with an assertion, which is the failure this page exists to prevent. **The re-count is owed**; run it rather than reading the old rows as current.

### Identity and access

| # | Surface | Status | Where | Class |
|---|---|---|---|---|
| 1 | Signup, login, password reset, email verification, OAuth, 2FA | Covered | `auth`, phase 7 | — |
| 2 | Teams, memberships, seats, invitations | Absent | `billing` declares `seats:` in the reference app; nothing models a member | (a) phase 7 |
| 3 | Roles and permission sets | Absent | — | (b) |
| 4 | **Authorization evaluated in every surface** | **Absent** | `auth` explicitly disclaims it ([`../architecture/01-module-map.md`](../architecture/01-module-map.md)) | **(b)** |
| 5 | Support impersonation, "log in as" | Absent | — | (a) phase 7 |
| 6 | Session security defaults — CSRF, secure/`SameSite` cookies, fixation | Absent from docs | — | (a) phase 2 |
| 7 | Enumeration resistance on login and reset | Absent | — | (a) phase 7 |

### The product surface

| # | Surface | Status | Where | Class |
|---|---|---|---|---|
| 8 | Screens, routing by convention, actions | Covered | phase 2 | — |
| 9 | Component kit (12 components) | Covered | phase 2 | — |
| 10 | **Application shell — sidebar, topbar, nav, breadcrumbs** | **Absent** | when counted, `sidebar`, `app shell` and `breadcrumb` occurred zero times in `docs/` or `wiki/` | **(b)** |
| 11 | **Responsiveness, mobile navigation, breakpoints, touch targets** | **Absent** | one occurrence of `responsive` in the whole tree, describing `grid` | **(b)** with 10 |
| 12 | Dashboard composition | Partial | `grid`, `stat`, `chart`, `card` exist as parts; nothing composes them | (a) phase 2 |
| 13 | Empty, loading and error states | Partial | `empty:` on `data_table`, nothing else | (a) phase 2 |
| 14 | Theme tokens, light/dark | Partial | colour, radius, font. No spacing scale, type scale, elevation, motion, icon set | (a) phase 2 |
| 15 | Accessibility | Absent | one incidental `role="dialog"` inside an example override | (a) phase 2 |
| 16 | A `data_table` on a narrow screen | Absent | the hardest single responsive problem in the kit, unaddressed | (a) phase 2 |
| 17 | In-app search and filtering on a screen | Partial | `filterable`/`searchable` exist on `api` and `admin_panel`, not on `screen` | (a) phase 2 |
| 18 | Printable documents and PDF | Partial | Prawn is on the wrap list; the reference app invents `render_pdf` | (a) phase 8 |

### Admin and support tooling

| # | Surface | Status | Where | Class |
|---|---|---|---|---|
| 19 | Admin CRUD list view | Covered | `admin_panel`, phase 7 | — |
| 20 | Admin: bulk actions, inline edit, nested resources, saved filters, admin dashboards | Absent | — | (a) phase 7 |
| 21 | **Admin access control** | **Contradictory** | `MAGIK_ADMIN_UNPROTECTED` requires "a declared access rule" that the DSL cannot express | **(b)** with 4 |
| 22 | Audit of staff actions specifically | Partial | `audited` is per-model and per-actor; nothing separates staff from customer | (a) phase 5 |
| 23 | Support views of a tenant's data | Absent | — | (a) phase 7 |

### Money and account lifecycle

| # | Surface | Status | Where | Class |
|---|---|---|---|---|
| 24 | Ledger, `:money`, `audited`, `immutable_after`, `idempotent_by` | Covered | phase 5 — the strongest area | — |
| 25 | Plans, trials, subscriptions, metered usage | Covered | `billing`, phase 7 | — |
| 26 | Upgrade, downgrade, proration, cancellation | Partial | asserted in the wiki, no construct or state machine specified | (a) phase 7 |
| 27 | Dunning | Partial | `on_payment_failed` plus an app-written job — which is the right answer | — |
| 28 | Tax and VAT | Absent | the reference app already had to invent `tax_rate_bp` in basis points | (a) phase 5 |
| 29 | Account deletion and closure | Absent | — | (a) with 33 |

### Data lifecycle

| # | Surface | Status | Where | Class |
|---|---|---|---|---|
| 30 | Soft delete, archive, restore | Absent | the reference app invents an `archived` boolean per model | (a) phase 1 |
| 31 | GDPR subject data export | Absent | — | (a) phase 5 |
| 32 | GDPR erasure / right to be forgotten | Absent | and it collides with `audited` + append-only ledgers, which is why it needs designing rather than adding | (a) phase 5 |
| 33 | Retention policies and scheduled purge | Absent | — | (a) phase 5 |
| 34 | CSV / spreadsheet import | Absent | — | (a) phase 4 |
| 35 | CSV / data export and report download | Absent | — | (a) phase 4 |
| 36 | Scheduled reports and digests | Covered by composition | `job` + `schedule` + `notification` | — |
| 37 | Backups, restore, point-in-time recovery | Absent | — | (d) |

### Files

| # | Surface | Status | Where | Class |
|---|---|---|---|---|
| 38 | **File uploads and attachments** | **Absent** | Shrine is on the wrap list, storage is a listed seam, and there is **no field type, no declaration and no component** | **(b) phase 4b** |
| 39 | Image derivatives, `srcset`, format conversion, EXIF stripping | Absent | — | (b) phase 4b |
| 40 | Direct-to-storage presigned upload, multipart, resumable, progress | Absent | — | (b) phase 4b |
| 40a | **Video and audio — transcoding, packaging, playback, waveforms** | **Absent** | — | (b) phase 4b, wrapped not built |
| 40b | Signed expiring URLs, private files, per-tenant file authorization | Absent | and a private file served without a policy check is a cached cross-tenant leak | (b) phase 4b + b1 |
| 40c | Blob lifecycle — orphan cleanup, retention, erasure of blobs not just rows | Absent | — | (b) phase 4b |
| 40d | Upload type/size limits, magic-byte sniffing, malware scanning | Absent | — | (b) phase 4b, (d) for the scanner |

### Integration

| # | Surface | Status | Where | Class |
|---|---|---|---|---|
| 41 | REST API with pagination, filtering, sorting | Covered | `api`, phase 6 | — |
| 42 | Inbound and outbound webhooks, signed | Covered | `webhook`, phase 6 | — |
| 43 | API versioning, deprecation and sunset | Partial | `api :V1` implies versions; nothing specifies deprecating one | (a) phase 6 |
| 44 | Webhook delivery log, replay, customer-facing endpoint management | Partial | the wiki asserts deliveries are "inspectable"; no construct backs it | (a) phase 6 |
| 45 | **Search as an app-facing construct** | **Absent** | search is a **listed seam** with no way to declare what is searchable or to query it | (a) phase 1 |
| 46 | **Caching as an app-facing construct** | **Absent** | same shape: `use :cache` exists, `cache.fetch` is mentioned once in passing, nothing specifies keys, TTLs or invalidation | (a) phase 2 |

### Communication

| # | Surface | Status | Where | Class |
|---|---|---|---|---|
| 47 | One notification, several channels, delivered via jobs | Covered | `notification`, phase 8 — a good declaration | — |
| 48 | **Email dev preview without sending** | **Absent** | and it matters doubly here: an agent cannot open a mail client, so rendering to a file is its only way to see an email | (a) phase 8 |
| 49 | Email building — CSS inlining, plain-text alternative, email layout | Absent | screen layouts and mail layouts are not the same artifact | (a) phase 8 |
| 50 | Deliverability — bounces, complaints, suppression list, unsubscribe | Absent | — | (a) phase 8 |
| 51 | Email assertions beyond `assert_notified` | Partial | delivery is assertable; content, recipient headers and links are not | (a) phase 9 |
| 52 | In-app notification centre | Partial | `channel :in_app` writes a row; no screen or component reads it | (a) phase 8 |

### The admin panel, benchmarked against Avo

[Avo](https://avohq.io) is the Ruby admin framework people actually reach for, so it is the right bar rather than an abstract one. Its documented surface, as of 2026-08-26 ([docs.avohq.io](https://docs.avohq.io/3.0/)):

> resources and array resources; **40+ field types** including money, badge, select, boolean, date/time, file and files, code, markdown, Trix/TipTap/Rhino rich text, key-value, progress bar, radio, stars, status, tags, country, gravatar, location, external image, preview, record link, heading; **associations** — `belongs_to`, `has_one`, `has_many`, `has_and_belongs_to_many`, polymorphic; field discovery and per-view field options; **scopes**; **records reordering**; cover and profile photos; record previews; **four view types** — table, grid, map, custom; **panels, clusters, sidebars and tabs** on a resource page; **actions** with argument forms, confirmations and bulk execution; **dashboards and cards**; **kanban board**; **basic and dynamic filters**; **search**; pagination and sorting with per-column control; ejectable views, custom fields, resource tools, custom tools; **authorization**, **audit logging**, **multitenancy**, **impersonation**; **localisation**; **branding** and a **menu editor**; a **media library**; caching and view-performance tuning; testing support.

Magik's specced surface, in full:

```ruby
admin_panel :Order do
  list_display :reference, :status, :total, :placed_at
  filterable   :status
  searchable   :reference
  read_only    :total
  actions      :refund_order
end
```

**It does not reach the bar, and the shortfall is not "fewer field types" — it is that only one of Avo's four view types exists.** `list_display` produces a list. There is no specification of a detail view, no form, no association browsing, and no way to arrange a record page. An admin who can list orders and cannot open one is not an admin.

Ranked by what an operator hits first:

| Avo capability | Magik as specced | Verdict |
|---|---|---|
| Resource **detail view** with panels, tabs and a sidebar | unspecified — `list_display` implies a list and nothing describes a show page | **the blocking gap** |
| **Association fields** — browse a customer's invoices, an invoice's lines, inline | absent. Most of what an admin does is follow a relationship | **blocking** |
| **Create / edit forms**, per-view field visibility | `read_only`/`editable` imply editability; no form is specified | blocking |
| **Bulk actions** over a selection, with an argument form and a confirmation | absent — `actions :refund_order` is per-row and unconditional | high |
| **Authorization**, delegated to policies | **absent entirely.** Avo delegates to Pundit; Magik has no policy primitive | **blocking, and coupled to b1** |
| **Impersonation** | absent | high |
| **Audit logging** of admin activity | partial — `audited` records an actor; nothing separates or surfaces staff activity | high |
| **Dashboards and cards** inside admin | absent | medium |
| **Filters** — boolean, select, text, date range; saved and shared | `filterable :status` only. No filter *types*, no saved views | medium |
| **Global search** across resources | `searchable` is per-resource only | medium |
| **Sorting** with per-column control, **pagination** | unspecified for admin | medium |
| Field library — money, badge, status, progress, key-value, rich text, file | none declared for admin; the app's field types are the only vocabulary | medium |
| Records reordering (drag) | absent | low |
| **Menu editor**, groups, dividers | absent — and it is the same problem as the missing `layout`; admin navigation is navigation | medium, solved by b2 |
| Grid, map and kanban views | absent | low — deliberately, see below |
| Branding, theming | inherited from `theme`, which is a genuine Magik advantage | **better** |
| Localisation | inherited from `locales`, same advantage | **better** |
| Custom tools / resource tools | inherited — an admin screen *is* a `screen` | **better** |

**Where Magik should deliberately differ, and it is worth arguing rather than copying.** Avo is a separate admin language layered on Rails: its own field DSL, its own view types, its own authorization delegation, its own asset pipeline (Stimulus, TailwindCSS, an ejectable view layer). Magik's structural claim is that **the admin is a projection of declarations the app already has**, in the same grammar. That buys four things Avo cannot:

| Magik's difference | Consequence |
|---|---|
| One grammar | an `admin_panel` field type *is* the `model` field type. There is no second field library to learn or keep in sync, and adding a field to a model adds it to the admin |
| Admin actions **are** the app's actions | `MAGIK_ADMIN_INLINE_MUTATION` forbids a second write path. Avo actions are admin-only code; a Magik admin cannot have a mutation the product does not have. **This is the single best property of the specced design and everything else should be built on it** |
| One authorization system | once `policy` exists. Avo delegating to Pundit is the right shape; Magik can go further and make it a boot failure to have an admin surface with no policy |
| No separate asset pipeline | Avo needs Stimulus, Tailwind and an ejectable view layer. Magik's admin renders through the same kit and themes from the same tokens, so an admin that matches the product is free |

And where Magik should deliberately **not** follow: kanban, map view and a media-library browser are product surfaces, not admin primitives. Grid view is worth having only because a media-heavy resource is unusable as a table.

**The minimum surface that reaches the bar** — drafted in [`02-dsl-surface.md`](02-dsl-surface.md) under [`admin_panel`](02-dsl-surface.md#admin_panel):

| Must add | Shape |
|---|---|
| A detail view | `show do panel … tab … sidebar … end` |
| Association browsing | `has_many :line_items, display: :table, actions: %i[…]` |
| Forms with per-view visibility | `form do field :status, only: %i[edit] end` |
| Bulk actions with arguments | `bulk_action :refund, args: { reason: :string }, confirm: true` |
| Typed filters, saved views | `filter :status, :select`, `filter :placed_at, :date_range`, `saved_view :overdue` |
| Global search | `admin do search :Order, :Customer end` on the app |
| Impersonation | `impersonation policy: %i[Account impersonate], banner: true, audited: true` |
| Admin dashboard cards | `admin_dashboard do metric … chart … end` — the same `stat`/`chart` kit |
| A policy on every panel | `admin_panel :Order, policy: %i[Order administer]` — b1, and the reason the two recommendations are inseparable |

**The two recommendations are coupled and must ship together.** An admin panel without policies is a security hole with a nice table on top: it is by construction the surface with the broadest data access in the application, it is the one a support engineer opens against a customer's records, and Magik's own guardrail catalogue already says an unprotected one must not boot. Building the admin depth first and adding authorization later would mean shipping the most dangerous surface in the framework in its least guarded form.

### `data_table`, the most-used component in any SaaS

The spec gives it one word in the kit list. The wiki gives it one line — *"rows, columns, sorting, pagination, per-row actions"* — and one worked example. **This is the component every screen in every SaaS uses, and it is specified in less detail than `pwa`.**

It is not only an admin concern: the customer-facing list of invoices, orders, listings or transactions is the same component, and under-speccing it means every app builds the same thing twice.

What it needs, and — this is the part worth stating — **every item has an htmx-shaped answer, which demonstrates that "no SPA framework" is not a limitation here**:

| Capability | The htmx-shaped answer | Note |
|---|---|---|
| **Server-side pagination** | a partial swap: the pager is `hx-get` at the table's target, and the page token is in the URL | **cursor-based, and UUIDv7 makes it free.** Sortable primary keys mean a cursor is `(sort_key, id)` with no offset scan, so page 900 costs what page 1 costs. This is a real design advantage falling out of decision 8 and the spec should claim it |
| **Sorting** | column headers are `hx-get` links carrying the sort key; the server re-renders the rows | `sortable :placed_at, :total` declares the allowed set; an undeclared sort is a 400, matching `MAGIK_FILTER_UNDECLARED` on the API |
| **Per-column and global search** | a debounced `hx-get` from one input into the rows target | the same `searchable` declaration the API and admin use — one spelling, three surfaces |
| **Filters with URL-encoded state** | filters write to the query string; the swap re-reads it | **so a filtered view is shareable and bookmarkable**, which is the property people actually want and the one client-side state destroys. This is the strongest single argument for server-rendered tables |
| **Row actions** | already specified — `row_action` compiles to `hx-post` at the action | keep |
| **Bulk actions with selection across pages** | the honest hard case. Selection is client state, which the guardrails forbid holding *server*-side per session. The answer is a **selection encoded in the URL or the form** — explicit ids, or a "select all matching this filter" predicate that the server re-evaluates. Never an opaque server-side selection object | needs stating, because the naive implementation violates decision 9 |
| **Column visibility and ordering** | a per-actor preference row, applied server-side at render | a preference is data, not session state |
| **CSV export of the current view** | a `job` producing a file plus a notification, over the same filter predicate | reuses the (a) export item; the table declares `exportable` |
| **Empty, loading, error states** | `empty:` exists. Loading is `hx-indicator` on the target — **compilable from the table's own shape, so it should be automatic**. Error is an inline state with a retry re-issuing the same request | see the states section above |
| **Narrow-screen behaviour** | the table becomes a **card list**, not a horizontal scroll | the one place responsiveness costs the author a line: `compact primary: :reference, secondary: %i[status total], action: :issue_invoice` |

So `data_table` gets a full subsection of [`02-dsl-surface.md`](02-dsl-surface.md) rather than a row in a kit table, and a phase-2 exit criterion of its own.

### `chart`

Specified as one kit component: *"a rendered chart. **Server-rendered**"*. Three questions the spec does not answer, and each has a wrong answer that is easy to reach:

| Question | Recommendation |
|---|---|
| **Which types ship?** | line, bar, stacked bar, area, pie/donut, and sparkline. That is the set a SaaS dashboard uses; anything beyond it is a BI product ([`05-limits.md`](05-limits.md)) |
| **Where does the data come from?** | a `state` declaration, exactly like every other component — a model scope returning a series. **Never a query in the chart call**, or `chart` becomes the one component that may query and `MAGIK_COMPONENT_DIRECT_QUERY` acquires an exception. The reference app's `Invoice.where(status: :paid).group_by_month(…)` in a `state` block is the right shape; `group_by_month` is a grouping helper the `model` DSL owes it and does not have |
| **Server-rendered SVG or a client library?** | **server-rendered inline SVG, by default and in the kit.** Chartkick — the Ruby precedent — wraps Chart.js and needs a JavaScript payload and a client render pass; that is a build-step-adjacent dependency and a per-page cost for a picture that does not change between requests. Inline SVG themes from the same CSS variables as everything else, works with `live` (a re-broadcast fragment *is* the new chart), degrades to a table for screen readers, and prints. It is also the only option that keeps "no heavy client-side compute" unambiguous |

The cost of that choice, stated rather than discovered: **an SVG chart has no hover tooltips, no zoom, no pan and no client-side legend toggling** without JavaScript. The honest position is that tooltips are reachable with CSS and `<title>` elements, and anything richer is rung 4 of the override ladder — attach your own charting library to a server-rendered element, which [`08-component-overrides.md`](08-component-overrides.md) already permits explicitly. Ship the simple thing, document the hatch.

Theming: a chart takes its series colours from the token set (`color_series_1..n`), not from a hard-coded palette, or it is the one thing on the page that does not change in dark mode.

### Media — images, video and audio

**There is no media construct at all.** Shrine appears on the wrap list, `Storage` is a listed seam in [`04-swap-points.md`](04-swap-points.md) — that much is already there and correct — and between the two there is **no field type, no declaration, no component and no job**. For ecommerce (product images), marketplaces (listing photos) and any app with avatars or document attachments, that is blocking rather than inconvenient, and it is the clearest single reason the 99% sentence cannot stand as written.

The upload is not the hard part. The path is:

#### Ingest

| Concern | Recommendation |
|---|---|
| **Direct-to-storage** | presigned uploads, as the **default and not an option**. A request server proxying a 2GB file collides head-on with decision 9 — it occupies a thread for minutes and makes "add another server" a lie about memory. `attachment :video, direct: true` should be the shape, and proxied upload the explicitly-chosen exception for small files |
| **Multipart and resumable** | required for anything above a few hundred MB. This is a wrapped concern, not a built one — the storage backend's own multipart API, exposed through the seam |
| **Progress and drag-and-drop with no build step** | the honest answer, stated plainly: **an upload component is the one place the "zero JavaScript" claim needs a footnote.** htmx alone cannot show byte-level progress on a direct-to-storage PUT. The framework ships a small, versioned, non-bundled `magik-upload.js` in `public/` alongside htmx — the same deal htmx itself gets: a fixed asset, no toolchain, no `node_modules`, no build. **The app author still writes no JavaScript**, which is the claim that actually matters; the framework author writes some, once. Saying this is better than either pretending it is free or dropping the feature |

#### Validation — security-critical

| Rule | Why |
|---|---|
| **Content type sniffed from magic bytes**, never from the extension and never from the client-supplied header | a `.png` that is a `.svg` is stored XSS; a `.pdf` that is an executable is a distribution channel. This is a framework default, not an option |
| **Size and dimension limits are required declarations** | `MAGIK_MODEL_UNCONSTRAINED_UPLOAD` at boot for an `attachment` with no `max_size` and no `content_types`. An unbounded upload field is an unbounded storage bill and a trivial DoS |
| **Malware scanning is a seam** | the framework owns the seam and the `:quarantined` state on the record; the scanner is somebody else's service (d). A file in `:quarantined` is not servable, and that is enforced by the delivery layer rather than remembered by the app |

#### Images

| Concern | Recommendation |
|---|---|
| Derivatives and `srcset` | `derivative :thumb, resize: [200, 200]` plus a `responsive_image` kit component emitting `srcset`/`sizes`. Without it, a product grid ships full-resolution originals to phones |
| Format conversion | WebP and AVIF with a fallback, negotiated from `Accept` server-side |
| **On-the-fly vs. pre-generated** | **pre-generated in a job, by default.** On-the-fly needs a cache to be viable and is a **DoS vector when the URL is unsigned** — an attacker requests ten thousand distinct sizes and pays for none of it. If on-the-fly is offered, the transform must be signed. Say so at the point of choosing |
| **EXIF stripping by default** | **GPS coordinates in a user's photo are a privacy incident waiting to happen**, and orientation is the only EXIF field most apps need. Strip on ingest, extract what is declared (`exif :taken_at, :orientation`), keep nothing else. This is exactly the shape of opinionated safe default the irreversible layer calls for: unstripped EXIF that reached storage is already leaked, and no later fix recovers it |

#### Video and audio — scope, ruthlessly

**Magik must wrap, not build.** Transcoding, HLS/DASH packaging, poster frames, waveforms and adaptive bitrate ladders are a specialist product; a framework that builds one has become a media company. Two viable answers, and the spec must pick a default:

| Option | Assessment |
|---|---|
| A job shelling out to `ffmpeg` | works, costs nothing in vendor fees, and puts a CPU-bound multi-minute process on the app's own worker fleet — where it starves every other job, needs its own queue and its own machine shape, and where a malformed input is a remote code execution surface with a long CVE history |
| **A seam pointing at a media service** — Mux, Cloudflare Stream, Bunny | **this is the default.** `use :media, :mux` with `attachment :lesson_video, media: :video` producing a playback id, a poster and a duration. The provider ingests directly, transcodes, packages and serves; the app stores an id |
| Both | the seam has an `:ffmpeg` backend for teams that want no vendor, documented with its costs (a dedicated queue, a machine shape, and the input-validation burden) |

Audio is the same seam with a waveform derivative. Playback is a `<video>`/`<audio>` element and an optional player script at rung 4 — no client compute, no build step.

#### Delivery and access control

| Concern | Recommendation |
|---|---|
| Public vs. private | declared on the attachment, not inferred. `attachment :avatar, visibility: :public` / `attachment :contract, visibility: :private` |
| Signed, expiring URLs | the default for `:private`. A URL that never expires is a permanent grant to anyone it was ever forwarded to |
| **Per-tenant authorization on every file** | **this couples straight back to b1.** An attachment served without evaluating a policy is a cross-tenant data leak with a CDN in front of it — the worst version, because it is cached. A private attachment's URL must be issued only after the same `policy` verb that guards the record it hangs off |
| CDN and cache headers | public files get long-lived immutable URLs keyed by content hash; private files get `private, no-store` and are never CDN-cached |

#### Lifecycle

| Concern | Recommendation |
|---|---|
| Orphan cleanup | deleting a record enqueues blob deletion. Without it, storage grows monotonically and nobody notices until the bill |
| Retention and **GDPR erasure** | erasure must cover the **blobs**, not only the rows. An erased user whose profile photo is still in a bucket has not been erased. This is why the erasure item under (a) is designed rather than bolted on |
| Soft delete interaction | an archived record's blobs are retained until the archive window closes, which is a decision the retention policy has to state |

#### Where it goes in the plan

**Media gets its own phase line rather than being tucked into an existing phase**, and the reasoning is that it spans four of them: the field type is phase 1, the upload component is phase 2, derivative generation and transcoding are phase 4 jobs, and delivery authorization is blocked on `policy`. A capability whose pieces land in four phases and whose value arrives only when all four have landed is a phase, not a line item — otherwise each phase ships its quarter and the app still cannot store a photo. It is added to [`06-phases.md`](06-phases.md) as **Phase 4b — Media**, sequenced after jobs and after `policy`.

### Abuse resistance

| # | Surface | Status | Where | Class |
|---|---|---|---|---|
| 53 | Rate limiting by plan on the API | Covered | `api`, phase 6 | — |
| 54 | Rate limiting per IP, per account, per action; login throttling and lockout | Absent | — | (a) phase 2 + a new seam |
| 55 | CAPTCHA / bot challenge | Absent | — | (a) phase 7 + a new seam |
| 56 | Honeypot and timing checks on forms | Absent | — | (a) phase 2, **as a default** |
| 57 | CSRF, CSP, HSTS, frame options, secure cookies | Absent from docs | — | (a) phase 2, **as defaults** |
| 58 | Output escaping guarantee | Partial | implied by "you never write HTML"; never stated as a guarantee with a named escape hatch | (a) phase 2 |
| 59 | Disposable-domain blocking and signup abuse | Absent | — | (a) phase 7 |
| 60 | Content moderation of user-generated content | Absent | — | (d) |

### Operations, environments and release

| # | Surface | Status | Where | Class |
|---|---|---|---|---|
| 61 | Environments, per-environment credentials, one image | Partial | real but thin: no first-class environment concept, no staging story, no per-environment seam selection | (a) phase 1 |
| 62 | Health, readiness, migration gating, drain, rollback | Partial | intent stated in [`../ops/README.md`](../ops/README.md); no command, no construct | (a) phase 1 |
| 63 | Observability, structured logs, request trace, N+1, slow query | **Covered** | [`../architecture/06-observability.md`](../architecture/06-observability.md) — a strength | — |
| 64 | Feature flags and gradual rollout | Absent | — | (a) phase 7 |

Plus, below the numbered set and classified in the analysis: analytics and product events (d/a), SEO metadata for indexable screens (a), marketing-site authoring (c), status pages and incident response (d), i18n beyond strings — currency, number, address, RTL, pluralisation (partial/a), multi-region data residency (c).

---

## Gap analysis

### (b) — needs a new primitive

The bar is deliberately high. The spec's design rule is that new capability arrives as a **factory over an existing construct**, not a new kind of thing, and axiom 5 of [`07-ai-first.md`](07-ai-first.md) prices every added construct against a finite context window. **Two proposals clear that bar. Several obvious candidates do not, and are rejected below by name.**

#### b1 — `policy`: authorization as a primitive

**This is the most serious gap in the specification.** Not the largest, not the most visible: the most serious, because it is the only one that is simultaneously (i) absent, (ii) unretrofittable, (iii) a security property rather than a convenience, and (iv) already being invented by the first app that tried.

**The evidence that it is already being invented.** [`../../dummy/`](../../dummy/README.md) is the reference app, written against the spec before the framework. It reaches for authorization four times and has to make the DSL up each time:

```ruby
# dummy/app/actions/issue_invoice.rb
authorize { |user, params| user.can?(:issue, Invoice.find(params[:invoice_id])) }

# dummy/app/actions/record_payment.rb
authorize { |user, _| user.can?(:record_payment) }

# dummy/app/channels/invoices.rb
authorize { |user| user.can?(:read, Invoice) }
```

`authorize` appears nowhere in [`02-dsl-surface.md`](02-dsl-surface.md). `can?` appears nowhere. The role `:owner` appears in `dummy/config/app.rb` as `two_factor :totp, required_for: [:owner]` with nothing anywhere that declares a role set. **This is the predicted failure happening in the reference app: the first real app invented an authorization system, and the second will invent a different one.** It also invented three different arities for the same block.

**The guardrail catalogue was already reaching for the construct.** [`../../wiki/Auth-Billing-Admin.md`](../../wiki/Auth-Billing-Admin.md) specifies a boot guardrail, `MAGIK_ADMIN_UNPROTECTED`, on the rule that *"an admin panel with no declared access rule is a boot failure"* — written when there was no way to declare an access rule, so it could only ever fail or be quietly dropped. **A guardrail catalogue containing a rule no app can satisfy is the strongest possible internal evidence that a primitive is missing.** `policy` is what makes the rule satisfiable, and `MAGIK_POLICY_UNDECLARED` is what it becomes — one code covering every surface rather than a special case for the admin.

**Why nothing existing can absorb it.** Taking each candidate seriously:

| Candidate home | Why it fails |
|---|---|
| A block on `action` | authorization for mutations only, which is the smaller half. `api resource index` reads with no action. `screen state` reads with no action. `channel`/`live` pushes with no action. `admin_panel` renders with no action. Four unguarded surfaces remain |
| `model`, as a scope | [`../architecture/01-module-map.md`](../architecture/01-module-map.md) forbids the model from authorizing, and correctly: a scope cannot express "this actor may see this row in the admin panel but not through the API", because a scope has no idea which surface asked |
| `auth` | the module map is explicit — `auth` *identifies*, and must never "decide authorization for a *resource*". That separation is right. Collapsing it makes `auth` a god-subsystem, and creates the tier problem below anyway |
| Application code, per app | this is the status quo, and it is exactly the two-authz-systems failure. The generated surfaces (`api`, `admin_panel`, `channel`) are framework-rendered; app code cannot reach into them to add a check |
| Left out entirely | see Ultimate, which reached the same conclusion from the opposite end of the language spectrum: **"Two authz systems is how every Meteor-like framework died"** ([`ultimate/docs/idea/02-primitives.md`](https://github.com/developerz-ai/ultimate)). It makes `policy` one of eight primitives — the same count Magik would be adding one to |

**The architectural claim, with its tier consequence.** A policy must be evaluated identically by `render` (tier 2), `realtime` (tier 2), `action` (tier 3), `api` (tier 3) and `admin` (tier 4). A subsystem may require **strictly lower** tiers only. So the policy evaluator cannot live at tier 3 beside `auth` — `render` and `realtime` sit below it and could not call it. This forces a specific placement, and it is the same split the guardrail runner already uses:

| Piece | Lives in | Tier |
|---|---|---|
| The rule interface, the registry and the evaluator | a new `policy` subsystem | **1** — below `model`, `render` and `realtime`, so every surface can call it |
| The actor a request resolves to | `auth`, unchanged | 3 — `auth` supplies the value; `policy` never knows how it was authenticated |
| Each surface's enforcement point | the surface's own subsystem | its existing tier |

`policy` at tier 1 takes the actor as an **opaque value**, exactly as `router` at tier 1 takes a path without knowing what a screen is. That is what makes the tier legal rather than a special case.

**The Ruby**, in the house grammar — keyword, name, block of declarations:

```ruby
# app/policies/invoice.rb  <->  policy :Invoice

policy :Invoice do
  default :deny                       # required. There is no implicit allow

  can :read do |actor, invoice|
    actor.role?(:viewer, :member, :admin, :owner)
  end

  can :issue do |actor, invoice|
    actor.role?(:admin, :owner) && invoice.status == :draft
  end

  can :record_payment do |actor, _invoice|
    actor.role?(:admin, :owner)
  end

  can :administer do |actor, _invoice|
    actor.staff? && actor.role?(:support_lead)
  end
end
```

The role set is declared once, app-wide, beside the actor:

```ruby
App.define :Ledgerline do
  roles :owner, :admin, :member, :viewer, default: :member
  staff_roles :support, :support_lead          # separate axis: staff are not tenant members
end
```

And every surface **names a verb** instead of writing a check:

```ruby
screen  :Invoices,       policy: %i[Invoice read]
action  :issue_invoice,  policy: %i[Invoice issue]
channel :invoices,       policy: %i[Invoice read]
job     :DunningSweep,   policy: :system            # explicit, not implicit
admin_panel :Invoice,    policy: %i[Invoice administer]

api :V1 do
  resource :invoices, model: :Invoice   # index/show -> :read, create -> :create, update -> :update
end
```

**The guardrails are why this is worth a primitive rather than a convention.** Each passes all four bars in [`03-guardrails.md`](03-guardrails.md) — derivable from the frozen registry, consequential, unambiguous, fixable:

| Guardrail | What fails | When | Code |
|---|---|---|---|
| Every surface reaching a model names a policy verb | a `screen`, `action`, `api resource`, `channel` or `admin_panel` with no `policy:` and no `policy: :public` | boot | `MAGIK_POLICY_UNDECLARED` |
| A predicate performs no I/O | a `can` block issuing a query — `live` re-evaluates one per subscriber per change, so a query here is one round trip per row per open socket | boot | `MAGIK_POLICY_IO` |
| A named verb exists | `policy: %i[Invoice publish]` where `policy :Invoice` declares no `:publish` | boot | `MAGIK_POLICY_UNKNOWN_VERB` |
| Denial is the default | a `policy` block with no `default :deny` | boot | `MAGIK_POLICY_NO_DEFAULT` |
| A rule receiving a `nil` record denies | a row-level rule that would pass on an absent record | boot (static) | `MAGIK_POLICY_NULL_PASSES` |

`MAGIK_POLICY_UNDECLARED` is the load-bearing one. It makes authorization non-optional the way `tenant_id` is non-optional, which is the only mechanism that survives an agent in a hurry — and the AI-first thesis says plainly that an agent ships a plausible-looking mistake, so the boot has to be where it is caught.

The admin's protection is then `MAGIK_POLICY_UNDECLARED` like every other surface's — **one code rather than two**, and a rule an app can actually satisfy.

**Where it sits in the plan.** `policy` must land **with phase 2**, not with `auth` in phase 7. A `screen` and an `action` are the first two surfaces that need it, and adding an authorization argument to five surfaces after all five exist is the retrofit the spec itself calls "a migration nobody survives" when it is talking about tenancy. Before `auth` ships, the actor is whatever the app's `actor_from` resolves; after it, `Magik::Auth.actor` supplies it. Nothing in the policy layer changes at that handover, which is the test that the tier split is right.

**Cost, stated honestly.** One construct, one subsystem, one tier, five error codes, and a `policy:` argument on six existing constructs. That is a real spend against the context-window budget in [`07-ai-first.md`](07-ai-first.md). The counter-argument is that the alternative is not zero — the alternative is every app inventing `authorize`, which is more surface to learn, not less, and none of it checkable.

#### b2 — `layout`: the application shell as a primitive

**The component kit was a list of components with no layout primitives at all.** `button, form, field, data_table, modal, toast, card, list, grid, tabs, stat, chart` — twelve things that go *inside* a page, and nothing that *is* a page. When this was counted, `sidebar`, `app shell`, `breakpoint` and `breadcrumb` occurred zero times across `docs/` and `wiki/`, and `responsive` occurred once, describing `grid`. Grepping for them now finds the construct this section argued for, which is the only reason the count moved.

**The evidence, again from the reference app.** `dummy/app/screens/dashboard.rb` and `dummy/app/screens/invoices.rb` both open their `body` directly with content — a `grid` in one, a `tabs` in the other. Neither has a sidebar, a header, a nav or a link to the other. **There is no way to navigate Ledgerline.** The reference application for a framework that claims to cover 99% of SaaS has no navigation, because the grammar has no way to declare any. Nobody noticed, which is the point: an absence in a grammar is invisible until someone tries to use the product.

**Why nothing existing can absorb it.**

| Candidate home | Why it fails |
|---|---|
| A `component` | a component is a pure function of props and is **forbidden from querying** (`MAGIK_COMPONENT_DIRECT_QUERY`). A sidebar needs the nav derived from the screen registry, a badge count from the database, and the account menu from the current actor and tenant — all ambient request context a component is defined not to have |
| A `screen` | a screen is auto-routed from its name. A layout has no route, and the wrapping direction is inverted: a screen does not *call* its layout, it is *selected into* one |
| Composition — "just put the sidebar in every screen's body" | that is the hand-assembly this audit exists to reject, it duplicates the nav in every file, and it makes "which screens exist in the nav" unanswerable at boot |
| Convention with no construct — a magic `app/layouts/application.html` | there is no template language, by design ([`05-limits.md`](05-limits.md)). The UI is Ruby. A layout that is not a declaration is not in the registry, so `magik routes` cannot say which layout serves a path and no guardrail can check it |

**The Ruby:**

```ruby
# app/layouts/app.rb  <->  layout :App

layout :App do
  sidebar do
    brand { text app_name }

    section t("nav.work") do
      nav_item :Dashboard, icon: :home
      nav_item :Invoices,  icon: :receipt, badge: -> { Invoice.overdue.count }
      nav_item :Customers, icon: :users
    end

    section t("nav.settings"), collapsed: true do
      nav_item :Members, icon: :users, policy: %i[Member administer]
      nav_item :Billing, icon: :card,  policy: %i[Subscription administer]
    end
  end

  topbar do
    breadcrumbs                                   # derived from each screen's `parent:`
    search action: :global_search, placeholder: t("nav.search")
    account_menu items: %i[profile theme sign_out]
  end

  content { slot :screen }

  responsive do
    sidebar collapses_below: :md, into: :drawer   # CSS + one htmx target. No build step
  end
end
```

A screen names its layout and its place in the hierarchy; opting out is explicit:

```ruby
screen :Invoices, layout: :App, parent: :Dashboard do … end
screen :SignIn,   layout: :None do … end            # auth screens want no shell
screen :Pricing,  layout: :Marketing do … end       # a second layout, not a special case
```

**Five properties that make this a framework feature rather than a snippet:**

| Property | Why it needs the registry |
|---|---|
| A default that exists | `magik new` generates a working `:App` layout with the conventional furniture already in it. **A generated app has a sidebar on its first run.** That is "ship the shape" made concrete, and it is what makes "under 30 lines, zero HTML/CSS/JS" true for a product rather than for one form |
| Nav items cannot rot | `nav_item :Invoices` names a screen constant. A link to a screen that does not exist fails at boot (`MAGIK_LAYOUT_UNKNOWN_SCREEN`), the same derivation the router already performs for actions |
| Nav respects authorization | `nav_item ... policy:` hides an item the actor cannot reach. **Showing a link to a 403 is the most common authorization bug in a SaaS**, and it costs nothing when the nav and the policy are both declarations. This is the join between b1 and b2 and is an argument for landing them together |
| Breadcrumbs are derived | from `parent:` on the screen, not typed per page. A breadcrumb trail maintained by hand is a breadcrumb trail that is wrong |
| Every screen has one | the default is `:App`; opting out is `layout: :None`, written down. A screen with no layout and no opt-out is `MAGIK_LAYOUT_MISSING` at boot |

**It rides the existing override ladder, and must not invent a second one.** `sidebar`, `topbar`, `nav_item`, `breadcrumbs` and `account_menu` are kit components with published contracts, so all four rungs of [`08-component-overrides.md`](08-component-overrides.md) apply unchanged: retheme with tokens (rung 1), `extends:` for different markup (rung 2), `component :Sidebar do satisfies Magik::Kit::Sidebar … end` to replace it app-wide (rung 3), `raw` at one call site (rung 4). `layout` itself is a new *declaration*, not a new *override system*.

**It respects both permanent limits.** A collapsing sidebar is a CSS media query plus one toggle target; a mobile drawer is a class swap. No SPA framework, no client router, no client-owned state, no build step, no heavy client compute. The one honest caveat is stated in the responsiveness section below.

#### Rejected as primitives — factories over existing constructs

Holding the bar means naming what does **not** clear it, and why:

| Proposal | Rejected because it is |
|---|---|
| `upload` / `attachment` | a **field type plus options on `model`**: `field :logo, :file, max_size: "5MB", content_types: %w[image/png image/jpeg]`. Same shape as `:money`, same guardrail style (`MAGIK_MODEL_UNCONSTRAINED_UPLOAD` — a `:file` field with no size and type bounds fails boot). Storage is already a listed seam. Urgent, but not new |
| `search` | **declarations on `model`** — `searchable :name, :number, using: :full_text` — plus `Model.search("…")` returning a dataset. The seam already exists; the app-facing half was never written |
| `cache` | **an option on `state` and `component`**, plus a `cache.fetch` surface. Not a construct |
| `flag` (feature flags) | a **factory over `policy`** once `policy` exists: a flag is an authorization rule whose subject is a cohort rather than a role. Building it as a separate system creates the second decision point the AI-first thesis forbids |
| `rate_limit` / `throttle` | **an option on `action` and `api`** plus a new **seam** for the counter store. Item 9 (stateless app servers) means the counter cannot live in process, so it needs a backend — which makes it a swap point by construction, not a primitive |
| `challenge` (CAPTCHA) | **an option on `form` and `action`** plus a new seam for the provider |
| `environment` | **a block inside `App.define`**, selecting seams per environment. `App.define` is already the only place a backend is named; a second namer would break that rule |
| `report` / `export` | a **factory over `job` + `notification`**: produce a file in a job, deliver a link. The reference app's `DunningSweep` already shows the shape works |
| `dashboard` | a **screen with a layout and a grid preset**. Once `layout` exists, a dashboard is `screen :Dashboard, layout: :App` plus a `dashboard_grid` kit component — no new kind of thing |
| `team` / `membership` | **models the framework generates**, the way `auth` already generates an account model. A generator, not a primitive |

### (a) — in scope, belongs to an existing phase

Each of these extends a construct that already exists. Grouped by phase, with the construct each one touches. These are added to [`06-phases.md`](06-phases.md) as one line per phase.

| Phase | Gap | Extends |
|---|---|---|
| 1 | `:file` field type, attachment declarations, size/type limits, image derivatives | `model` `field` |
| 1 | `searchable` declarations and `Model.search` over the existing search seam | `model` |
| 1 | Soft delete / archive / restore as a model annotation, with scopes excluding archived rows by default | `model` |
| 1 | An `environment` block in `App.define` selecting seams per environment; `magik doctor --env` | `App.define` |
| 1 | Health and readiness endpoints, `magik migrate --gate`, drain semantics | CLI + `App.define` |
| 2 | The application shell — but see b2; only the kit components are phase-2 *work*, the construct is new | component kit |
| 2 | Responsive behaviour as a **kit property**, breakpoint tokens, a narrow-screen `data_table` mode | component kit |
| 2 | Empty, loading, error and skeleton states as first-class slots on every collection component | component kit |
| 2 | Spacing scale, type scale, elevation, motion and an icon set as tokens | `theme` |
| 2 | Accessibility as a kit contract element — roles, labels, focus order, keyboard paths, contrast pairs | component contract |
| 2 | Screen-level `search` and `filter` declarations feeding `state` | `screen` |
| 2 | Fragment caching as an option on `state` and `component` | `screen`, `component` |
| 2 | CSRF, CSP, HSTS, frame options and cookie flags as **framework defaults** with a documented override | the Rack stack |
| 2 | A honeypot and a submission-timing check on every generated `form`, **on by default** | `form` |
| 2 | Per-IP / per-actor / per-action throttling as an option on `action` | `action` |
| 2 | Output escaping stated as a guarantee, with `raw` as the single named escape hatch | `render` |
| 4 | CSV/spreadsheet import and export as job factories with a progress surface | `job` |
| 5 | Tax and rate arithmetic in basis points, as `:money`'s sibling — the reference app already needed it | `core` value types |
| 5 | GDPR subject export and erasure, including the interaction with `audited` and append-only ledgers | `audited` |
| 5 | Retention policies and scheduled purge | `model` + `job` |
| 6 | API deprecation and sunset headers on a version | `api` |
| 6 | Webhook delivery log, replay and a customer-facing endpoint surface | `webhook` |
| 7 | Teams, memberships, seats and invitations, generated the way `auth` generates accounts | `auth` |
| 7 | Support impersonation with a mandatory audit record and a visible banner | `auth` + `admin_panel` |
| 7 | Admin depth — bulk actions, inline edit, nested resources, saved filters, per-row custom actions, export | `admin_panel` |
| 7 | Bot challenge as an option on public forms, over a new provider seam | `auth`, `form` |
| 7 | Enumeration-resistant login and reset responses, and constant-time comparisons, **by default** | `auth` |
| 7 | Disposable-domain policy on signup | `auth` |
| 7 | Feature flags as a `policy` factory once `policy` exists | `policy` |
| 8 | Email preview rendered to a file — `magik mail preview` — plus a dev-only preview route | `notification` |
| 8 | Email build: CSS inlining, plain-text alternative, mail layouts distinct from screen layouts | `notification` |
| 8 | Suppression list, unsubscribe tokens, and inbound bounce/complaint events over the webhook DSL | `notification` |
| 8 | An in-app notification centre screen and component reading what `channel :in_app` writes | `notification` |
| 8 | Currency, number, address and pluralisation formatting; RTL as a theme direction | `i18n` |
| 8 | Per-screen `meta`, canonical URL and Open Graph tags — server-rendered HTML is indexable, so this is cheap | `screen` |
| 8 | PDF and print rendering as a declared output of a `notification` or a `job` | `notification` |
| 9 | Email content assertions — recipient, subject, body text, links, plain-text presence | `testing` |
| 9 | An authorization test generated per policy verb, including a cross-tenant denial | `testing` |
| 9 | A responsive render assertion — `render_screen … at: :mobile` | `testing` |

### (c) — out of scope, and the docs should say so

Added to [`05-limits.md`](05-limits.md) with reasoning. Each passes that page's four tests: permanent, structural, statable loudly, and honest about the alternative.

| Limit | Reasoning |
|---|---|
| **No email marketing or campaign sending** | `notification` is transactional email. Bulk campaigns, list management, drip sequences and engagement tracking are a different product with a different deliverability model — a shared sending reputation between transactional and marketing mail is how a password-reset email ends up in spam. Use a campaign provider; the app's job is to sync the list |
| **No native mobile application** | `pwa` makes an app installable. There is no native shell, no App Store artifact, and `channel :push` means **web push** — not APNs or FCM through a native SDK. The spec's `:push` channel is ambiguous today and should be narrowed rather than quietly implying a native path |
| **No CMS, blog engine or marketing-site authoring** | Magik renders application screens for known actors. Per-screen SEO metadata is cheap and in scope (a); an editorial workflow, a page builder and a content model for marketing pages are a second product. Put a static site in front |
| **No ad-hoc BI or end-user report builder** | `stat` and `chart` render declared queries. A pivot table, a drill-down, a saved-query builder and a semantic layer are an analytics product. Export to one |
| **No workflow or BPM engine** | `flow` is a linear, resumable wizard. Parallel branches, human task assignment, compensating transactions and a visual designer are not what it is, and stretching it into one produces a second, worse execution model beside `job` |
| **No multi-region or data-residency partitioning** | one Postgres, one region, tenancy by column. Sharding, regional pinning and cross-region replication are a deployment topology the framework does not model. `magik check --scale` exists to keep the option open, not to deliver it |

### (d) — not the framework's job

| Concern | Who owns it |
|---|---|
| Backups, restore, point-in-time recovery | the database platform. Magik's contribution is that migrations are reversible and the schema is reproducible |
| Status page, incident response, on-call | the operations team and a status-page vendor. [`../ops/README.md`](../ops/README.md) already says there are no runbooks because there have been no incidents |
| Uptime monitoring, alerting, log aggregation | the platform. Magik's contribution is stable `MAGIK_*` codes an alert rule can match and OTel as an export path |
| SPF, DKIM, DMARC records, sending-domain warm-up, IP reputation | DNS and the email provider. The framework can *check* them in `magik doctor` and should; it cannot own them |
| Virus and malware scanning of uploads | a scanning service. The framework owns the seam that calls it and the quarantine state on the record |
| Content moderation of user-generated text and images | a moderation vendor or the product team. Not a framework decision |
| CDN, WAF, DDoS mitigation, TLS termination | the load balancer and edge. The topology in [`../ops/README.md`](../ops/README.md) assumes one in front |
| SOC 2, PCI and ISO evidence collection | a compliance programme. Magik contributes `audited`, the PAN-field refusal and the ledger guarantees as controls, not as certification |
| The analytics product itself | a product analytics vendor. Emitting the events is (a); storing, querying and charting them for a growth team is not |

---

## The four dimensions in detail

### Email

`notification` is a **good declaration and an incomplete pipeline**. What it specifies is genuinely right: one event, several channels, one file, recipient-locale rendering, delivery through the job queue, attachments, and mail transport as a listed swap point. The reference app's `invoice_issued.rb` reads well and puts the per-channel decision in exactly one place.

Everything after "hand it to the transport" is missing, and everything before "render it" is missing too:

| Gap | Why it bites the first app |
|---|---|
| **No dev preview** | you cannot see an email without sending one. Rails has mailer previews and `letter_opener` for a reason. **This one is doubly severe here**: the AI-first thesis says the framework's output is an agent's entire diagnostic surface, and an agent has no inbox. `magik mail preview :invoice_issued --locale es --out tmp/` rendering to a file is the agent-shaped answer, and it does not exist |
| **No email build step** | HTML email needs inlined CSS, table-safe layout and a `text/plain` alternative or it lands in spam and renders broken in Outlook. `body { render :OrderPlacedEmail }` renders a **screen** component; screen layouts and mail layouts are not the same artifact and cannot be |
| **No deliverability loop** | no bounce or complaint webhook, no suppression list. Sending to an address that hard-bounced is how a sending reputation dies. The suppression list must be **framework-owned and consulted by `notify` before delivery** — an app-level suppression table that `notify` does not read is a suppression list that does nothing |
| **No unsubscribe** | required by law for anything non-transactional, and it needs a signed token, a preference record and a `List-Unsubscribe` header |
| **Thin assertions** | `assert_notified` proves delivery was attempted. It does not assert the subject, the recipient, the body text, the links, or that a plain-text part exists |

**Verdict on the question asked: yes, email warrants its own section in [`02-dsl-surface.md`](02-dsl-surface.md).** Not because it is a new primitive — every item above is a factory over `notification`, `webhook` and the CLI — but because nine lines is a fair description of a declaration and a wholly unfair description of a subsystem that has to render, inline, degrade, suppress, sign, deliver, retry and record. That section is *Email production*, in phase 8.

### Environments, staging and release

`MAGIK_ENV`, per-environment encrypted credentials, `config/environments/` in the layout, and one image across environments are real and correctly reasoned in [`../architecture/07-configuration-and-secrets.md`](../architecture/07-configuration-and-secrets.md). They are also the whole story, and the story has holes:

| Gap | Consequence |
|---|---|
| No first-class environment concept in the DSL | `config/environments/development.rb` appears in the layout tree and is never specified. What may it contain? Can it call `use`? Nothing says |
| **No statement of how a seam is selected per environment** | this is the sharp one. The obvious deployment — Postgres `LISTEN`/`NOTIFY` in dev, Redis in production; memory cache in dev, Redis in production — is the thing the swap-point page most obviously implies and never states. `use` is documented as living in `App.define`, of which there is exactly one |
| No verification that a per-environment swap is safe | [`04-swap-points.md`](04-swap-points.md) requires a conformance suite green on every backend. If dev and production run **different** backends, the conformance suite is not an optimisation, it is the only thing standing between "works on my machine" and a production-only failure mode. That link is never drawn |
| No staging story | staging is named once, in a sentence about credentials. Nothing says what staging is *for* — a production-shaped environment with production-shaped backends and non-production data — or how to keep it honest |
| Seeds are dev-only and undefined | `db/seeds.rb` is "hand-written, idempotent, NOT fixtures" and that is all. Nothing about per-environment seeds, or a demo dataset a support engineer can reset |

The recommendation is (a): an `environment` block inside `App.define`, because `App.define` is already documented as *the only place a backend is named* and a second namer would break the rule that makes the seam analysable:

```ruby
App.define :Shop do
  use :cache,    :memory
  use :realtime, :postgres

  environment :production do
    use :cache,    :redis, url: config.fetch(:redis_url)
    use :realtime, :redis, url: config.fetch(:redis_url)
  end

  environment :test do
    use :jobs, :inline          # a test runs its jobs, it does not queue them
  end
end
```

With one guardrail worth its weight: **a seam whose backend differs between environments emits a boot warning naming both, unless its conformance suite is recorded green on both.** Silent dev/production divergence is the thing that turns a swap point from a feature into a trap, and the spec's own honesty rule ("a swap ships proven, not promised") already implies it.

Plus, on the release half: `magik doctor --env production` reporting which layer each key resolved from is specified; health and readiness endpoints, `magik migrate` as a gate, drain semantics and rollback are stated as *intent* in [`../ops/README.md`](../ops/README.md) with no command behind them. That is honest and it is also the first thing a first deploy needs.

### N+1 and debugging — confirmed, not a gap

Stated plainly because the audit was asked to check it and the answer is favourable:

| Design choice | Why it is stronger than detection |
|---|---|
| **No lazy loading at all** | `invoice.customer` on a record loaded without `.eager(:customer)` raises `MAGIK_LAZY_ASSOCIATION`. There is no code path that silently issues the query, so there is no N+1 to detect — the class of bug is prevented rather than reported. This is the single best decision in the data layer, and it is downstream of choosing Sequel over ActiveRecord |
| Components cannot query | `MAGIK_COMPONENT_DIRECT_QUERY` at boot. The classic N+1 — a query inside a row template — is not expressible |
| Screens cannot query | `MAGIK_SCREEN_DIRECT_QUERY`; a screen names a `state`, and a state is a model scope. The query is where it can be read and eager-loaded |
| Detection anyway, in layers | dev trace warns on same-shape-N-times with **both sites**; `magik check --scale` reports it in CI; slow queries log with SQL, plan and the issuing declaration; missing indexes are reported with a suggested migration |
| A request trace most frameworks cannot build | screen → state → query → render → job → broadcast with per-node timings and the dominant node marked, because everything descends from one declaration. `--json` on all of it |
| `magik explain query` | shows the SQL including the framework-injected tenant predicate — the framework writes part of the query, so it is obliged to show it |

The only gaps worth naming here are small and belong to (a): there is no specified way to **assert** the absence of N+1 in a test (`assert_queries(3) { … }`), and the eager-loading spelling is inconsistent across the docs (`eager(:customer)` in [`02-dsl-surface.md`](02-dsl-surface.md) and the wiki, `includes(:customer)` in `dummy/app/screens/invoices.rb`) — one of the two is wrong and the reference app is the place that will teach whichever survives.

### Layout, responsiveness, dashboards, admin, theming, accessibility

The construct is b2 above. This section holds the parts of the UI question that are **not** solved by adding `layout`.

#### Responsiveness: is it a kit property or an app-author job?

**It has to be a kit property, and the spec should say so as a claim it can be held to.** The weaker answer — the author configures breakpoints — fails for a specific reason: with no build step and no SPA, the app author has no CSS pipeline to configure *with*. Telling them responsiveness is their job while also telling them they write no CSS is telling them it is nobody's job.

So the claim to commit to: **every kit component is responsive by construction, and no app-authored declaration is required to make a screen work on a phone.** That is a strong claim and it has to be tested rather than asserted — `render_screen :Invoices, at: :mobile` as a test helper, and a phase-2 exit criterion that the generated app renders correctly at 375px.

Two honest caveats to write down rather than discover:

| Caveat | Detail |
|---|---|
| **`data_table` on a narrow screen is genuinely hard** | it cannot merely scroll horizontally — that is the thing every framework does and every user hates. The real answer is that a table becomes a **card list** below a breakpoint, with `column` declarations mapping to a per-row summary, which means `data_table` needs a `compact:` or `on_narrow:` declaration naming the primary, secondary and action fields. It is the one place responsiveness costs the app author a line, and the spec should say which line rather than pretending |
| **A drawer needs a toggle** | CSS alone can do a checkbox-hack drawer, which is accessible if done carefully and awful if not. htmx can swap a class. Either is within the limits; the spec should pick one and state it, because "it is just CSS" is the sentence that precedes a build step |

Touch targets, focus-visible styling, and reduced-motion are token-level and belong with the theme work.

#### Dashboards

`stat`, `chart`, `grid` and `card` are the parts; nothing composes them, so every author rebuilds the same grid-of-stats-above-a-chart. Under "ship the shape" this is a preset, not a primitive: a `dashboard_grid` kit component with a responsive reflow (four stats across on desktop, two on tablet, one on mobile) and a documented default arrangement, plus the empty/loading states below. The reference app's `screen :Dashboard` writing `grid columns: 3` by hand is the symptom — `columns: 3` is a desktop number typed into a file that has no idea what a phone is.

#### Empty, loading and error states

`empty:` on `data_table` is the whole current specification. This is a "ship the shape" item with unusually high leverage, because these three states are what separate an application that looks finished from one that looks like a framework, and they are exactly what a generated screen omits:

- **Empty** — every collection component takes an empty slot with a default that is already decent: an icon, a sentence, and the primary action that creates the first record. A new SaaS account sees empty states before it sees anything else.
- **Loading** — htmx has request-in-flight indicators natively (`hx-indicator`), so a skeleton is compilable from the component's own shape with no JavaScript authored. It should be automatic, not opt-in.
- **Error** — an action failure currently produces a `toast`. A failed *fragment* needs an inline error state with a retry that re-issues the same htmx request.

#### The admin panel, pressure-tested

The owner's requirement is "easy to create". The specced surface is:

```ruby
admin_panel :Order do
  list_display :reference, :status, :total, :placed_at
  filterable   :status
  searchable   :reference
  read_only    :total
  actions      :refund_order
end
```

That produces **a good list view**. Measured against what an admin actually does, it is roughly a third of one:

| An admin needs | Specced? | Class |
|---|---|---|
| List with filters and search | yes | — |
| Detail view of one record | not specified — `list_display` implies a list; nothing describes the show page | (a) |
| Related records — a customer's invoices, an invoice's lines | no. Nested resources are unaddressed and are most of what an admin browses | (a) |
| Inline edit and a create form | `read_only`/`editable` imply editability; no form is specified | (a) |
| Bulk actions over a selection | no | (a) |
| Per-row custom actions beyond `actions :name` | partial — `actions` names app actions, which is the **right** design (`MAGIK_ADMIN_INLINE_MUTATION` forbids a second write path) but says nothing about per-row conditionality | (a) |
| Export the current filtered view | no | (a) |
| Saved filters / shared views | no | (a) |
| A dashboard inside admin | no | (a) |
| Staff roles distinct from tenant roles | no — and it is a **different axis**: a support engineer is not a member of the tenant they are helping | (b1) |
| Impersonation with an audit record and a visible banner | no | (a) |
| An audit of staff actions, queryable | partial — `audited` records the actor; nothing distinguishes or surfaces staff activity | (a) |

The `admin_panel` design has one genuinely excellent property worth defending: **admin actions are the app's actions**, so there is no admin-only write path that skips the guards. Keep that and build the rest on it. And note that the whole surface is blocked on b1: an admin panel with no policy verb must not boot, and `policy` is what makes that rule satisfiable rather than decorative.

#### Theming, and "looks good by default"

One `theme` block with colour, radius and font tokens is enough to make an app **consistent**. It is not enough to make it **look designed**. What is missing is what a design system consists of beyond colour:

| Missing token family | Why it matters |
|---|---|
| Spacing scale | the difference between "styled" and "designed" is mostly rhythm. Without a scale, every component picks its own padding |
| Type scale and line height | one `font_body` string does not tell a `heading` what size it is at each level |
| Elevation and border tokens | a `card` and a `modal` need a defined surface hierarchy or the page reads flat |
| Motion tokens | present in one wiki example (`motion :modal_enter`), absent from the DSL surface |
| **An icon set** | `nav_item icon: :home` needs an icon to exist. No SPA and no build step means icons must be inlined SVG shipped with the kit, which is a real decision the spec has not made |
| Density | admin tables and marketing pages want different row heights from one token set |

The recommendation is not "add more tokens" — it is that the kit ships **one finished-looking default theme** that a generated app uses without declaring anything, and the tokens are how you change it. Ship the shape.

#### Accessibility

Effectively unaddressed: one incidental `role="dialog"` in an override example. Accessibility is the canonical thing nobody adds later, and Magik has a structural advantage it is not using — **every component is framework-authored**, so accessibility can be a property of the kit rather than a discipline of the app author.

The proposal is to make it a **contract element**. [`08-component-overrides.md`](08-component-overrides.md) already defines a component contract as "props in, slots, htmx targets, events out". Add a fifth: **the accessibility obligations** — required roles, the labelled-by relationship, focus management, the keyboard path. Then a rung-3 replacement that drops the focus trap fails at boot with `MAGIK_COMPONENT_CONTRACT_VIOLATION` naming what is missing, exactly as a missing slot does today. That turns accessibility from advice into a guardrail, which is the only form the spec believes in.

Colour-contrast pairs belong in the token set and are checkable by `magik check`.

### Abuse resistance

The spec names exactly one mechanism — `rate_limit by: :plan` for the API in phase 6. Everything else is absent. The organising question is the right one, so here is the answer per item:

| Concern | Recommendation | Why |
|---|---|---|
| CSRF, CSP, HSTS, frame options, `Secure`/`HttpOnly`/`SameSite` cookies, session fixation on privilege change | **framework default, never typed** | there is no app in the target audience that wants these off. Each has a documented per-app override and a `magik check` finding when overridden. An agent will not remember any of them |
| Output escaping | **framework guarantee, with `raw` as the single named hatch** | already true in spirit — the app writes no HTML — but it must be *stated* as a guarantee and `raw` must be the one auditable exception, which `magik check` already counts |
| **Honeypot + submission timing on every `form`** | **framework default, on** | this is the recommendation to argue for hardest. It is zero-dependency, needs no third party, sends nothing to a vendor, has **no accessibility cost** when the field is properly hidden from assistive technology, and catches most naive bots. It is precisely a Magik-shaped opinionated default: invisible, free, and off only by explicit declaration |
| Login throttling and lockout | **framework default on the generated `auth` flow** | a signup and login flow generated by `auth` with no throttling is a credential-stuffing target the moment it is public |
| Per-IP / per-actor / per-action throttling generally | **one declaration, over a new seam** | `action :export_all, throttle: { by: :actor, max: 3, per: "1h" }`. **Item 9 (stateless app servers) means the counter cannot live in process**, so it needs a backend — which makes it a swap point by construction. Postgres default, Redis alternative. Note that [`../../wiki/API-And-Webhooks.md`](../../wiki/API-And-Webhooks.md) already names a "rate-limit store" seam that [`04-swap-points.md`](04-swap-points.md) does not list; that inconsistency is fixed by adding the row |
| **Enumeration resistance** | **framework default, not a setting** | identical response and identical timing for "no such account" and "wrong password", and for a reset request whether or not the address exists. This is always got wrong when it is not a default, and there is no legitimate app that wants the other behaviour |
| Email verification | already generated by `auth` — keep | — |
| Disposable-domain blocking | **one declaration, off by default** | `auth do signup_domains block: :disposable end`. Off by default because it is a product decision with false positives, and a framework that silently rejects a real user's address is worse than one that does nothing |
| **CAPTCHA / bot challenge** | **one declaration, off by default, over a new seam** | `form action: :sign_up, challenge: :required` with `use :challenge, :turnstile`. **A vendor must not be hardcoded** — that is precisely what spec item 11 exists to prevent, and this vendor space (Turnstile, hCaptcha, reCAPTCHA) is unusually volatile on both privacy and pricing. Off by default because a CAPTCHA has a real accessibility cost and a real privacy cost, and imposing one on every app is the wrong opinion |
| Upload type/size limits | **required declaration — boot fails without it** | a `:file` field with no bounds is an unbounded write to your storage bill. `MAGIK_MODEL_UNCONSTRAINED_UPLOAD` |
| Virus scanning, content moderation | **a seam the framework calls, a service someone else owns** | (d) for the scanner, (a) for the quarantine state on the record |

**The AI-first argument, stated because it is decisive here.** An agent asked to build a signup flow will produce a signup flow. It will not add throttling, it will not equalise the timing of a failed login, it will not set `SameSite`, and it will not add a honeypot — not because it cannot, but because nothing in the task prompted it to. This is the same argument the spec already makes for boot guardrails, applied to security defaults: *a human reviewer catches those sometimes; a default catches them every time.* **Anything security-relevant that is documentation rather than default will not exist in agent-written Magik apps.** That is the strongest available reason to put this in phase 2 and phase 7 as defaults rather than in a "security best practices" wiki page nobody reads.

---

## Ranking

Ordered by what would hurt the first real Magik app most. The first three are the ones that decide whether the 99% sentence is true.

| # | Gap | Class | Hurts because | Graduation risk |
|---|---|---|---|---|
| 1 | **Authorization (`policy`)** | b1 | the framework's generated surfaces cannot be guarded from outside; a boot guardrail already depends on it; the reference app already invented three incompatible spellings of it | **Yes** |
| 2 | **Application shell and responsiveness (`layout`)** | b2 | voids "zero HTML/JS/CSS" on day one; the reference app has no navigation at all; it is the sharpest differentiator against Rails and it is missing | **Yes — quietly** |
| 3 | **Media — attachments, images, video, audio** | b (phase 4b) | blocks ecommerce and marketplaces, two of the four verticals the mission sentence names. A product with no photo is not a product | **Yes** |
| 4 | Teams, roles, seats, invitations | a (phase 7) | every B2B SaaS needs it in week one, and it is the data model `policy` needs to decide anything | No, but painful |
| 5 | Abuse defaults — CSRF/headers/cookies, throttling, enumeration, honeypot | a (phase 2/7) | an agent will not add any of them; the first public signup form is the incident | No — worse |
| 6 | Email production — preview, inlining, plain text, suppression, bounces | a (phase 8) | email is the second-most-used surface of a SaaS after the screen, and the pipeline stops at "hand it to SMTP". An agent cannot even see one | No |
| 7 | Admin depth — detail views, association browsing, forms, bulk actions, filters, impersonation, staff audit | a (phase 7) + b1 | the 2am screen is a list view. Benchmarked against Avo, only one of four view types existed; and the surface cannot be protected at all until `policy` exists | No |
| 8 | Environments, per-environment seams, staging, release gating | a (phase 1) | the first deploy hits all of it at once, and a dev/production seam difference is untested by construction | No |
| 9 | Data lifecycle — soft delete, GDPR export and erasure, retention | a (phase 1/5) | the first support ticket and the first subject request; erasure vs. append-only ledgers needs designing, not adding | No |
| 10 | Search and cache as app-facing constructs | a (phase 1/2) | two seams listed on the swap-points page with no way for an app to use them is a strange thing to specify |  No |
| 7a | **`data_table` depth** — cursor pagination, sorting, filters with URL state, bulk selection, column control, export, narrow-screen mode | a (phase 2) | the single most-used component in any SaaS, specified in less detail than `pwa`, and used by both the product and the admin | No |
| 11 | Empty/loading/error states, dashboard composition, `chart` specification, token depth, icons, accessibility | a (phase 2) | the "looks like a framework" tax, paid on every screen an agent generates | No |
| 12 | Exports and imports, feature flags, API deprecation, webhook delivery log, tax arithmetic, i18n depth, SEO metadata, analytics events | a (various) | each is a month-three annoyance rather than a week-one blocker | No |

---

## Recommended sequencing before 1.0

The ordering principle: **anything that wraps every surface must land before the surfaces multiply.** Both b-items are wrapping concerns, and both get exponentially more expensive per phase that ships without them.

| Before | Land | Why not later |
|---|---|---|
| **`0.2.0`** (phase 2, rendering) | **`policy`** and **`layout`** | a screen and an action are the first two surfaces needing authorization and the first thing needing a shell. Adding a `policy:` argument to six constructs after six constructs exist is the retrofit the spec calls unsurvivable when it says it about tenancy. Landing `layout` after phase 2 means every screen written in between has no home for its navigation |
| **`0.2.0`** | responsive kit behaviour, empty/loading/error states, the finished default theme, accessibility in the component contract | all of these are properties of kit components. Adding them after the kit ships means changing twelve components and every app that overrode one |
| **`0.2.0`** | security defaults — CSRF, headers, cookie flags, escaping guarantee, form honeypot | they are Rack-stack and `form` defaults. Retrofitting a default that changes behaviour is a breaking change; shipping it first is free |
| **`0.1.0`** | the `:file` field type and the `attachment` declaration | it is a field type, and field types are phase 1. Adding one later is a migration for every app that worked around its absence. The rest of media follows in phase 4b |
| **`0.2.0`** | the full `data_table` and `chart` specifications | they are kit components; changing them after apps have overridden them breaks the override contract |
| **after `0.5.0`** (jobs) and after `policy` | **phase 4b — media**: derivatives, transcoding seam, direct upload, signed delivery, blob lifecycle | derivative generation is job work, and signed delivery is blocked on `policy`. Landing media before either produces an upload feature with no processing and no access control |
| **`0.1.0`** | `environment` in `App.define`, soft delete, `searchable` | all are `App.define` and `model` surface, and all three are worked around badly if they arrive late |
| **`0.7.0`** (auth/billing/admin) | teams and memberships, impersonation, admin depth, throttling, enumeration resistance, challenge seam | they sit on `auth` and `admin_panel` and cannot precede them |
| **`0.9.0`** (i18n/PWA/notifications) | the whole email production set | it sits on `notification` |
| **`1.0.0`** | the added claim below | — |

### What this changes about 1.0

[`../../ROADMAP.md`](../../ROADMAP.md) defines `1.0.0` as all phases green plus three executable proofs. This audit argued for a **fourth**, because the first three can all be true of an application that is insecure and unusable, and it is now the spec's sixth success criterion:

> **A generated app is safe and usable on its first run**, proven by: a cross-tenant actor is denied by every generated surface in a test; the generated shell renders correctly at 375px in a test; the generated signup form throttles and does not reveal whether an account exists.

Each clause is a test, not a document — which is the standard the other three already meet.

### Where this audit landed in the spec

Every finding above is now part of the design rather than a recommendation about it. The map, so a
reader of this page knows where to go for the decision rather than the argument:

| This page's finding | Where it lives in [`00-build-spec.md`](00-build-spec.md) |
|---|---|
| The mission sentence is a target, not a description | Mission — and this page is the measurement it names |
| Authorization is a primitive, in phase 2, evaluated in one place | `policy` in phase 2, and architecture decision 13 |
| The application shell is a primitive | `layout` in phase 2, with the layout primitives in the kit list |
| Media is its own phase, wrapped and not built | Phase 4b, plus a media service in Libraries to Wrap |
| `:file` is a field type and phase-1 work | Phase 1's type list, with `MAGIK_MODEL_UNCONSTRAINED_UPLOAD` |
| Security is defaults, not documentation | phase 2 and phase 7, one line each |
| `admin_panel` needs four view types and a policy | Phase 7 |
| A generated app must be safe and usable on its first run | the sixth success criterion |
| Anything wrapping every surface lands before the surfaces multiply | the build order — `describe` at step 2, `policy` and `layout` at step 3, media at step 8 |

## Next

| Want | Read |
|---|---|
| The spec being audited | [`00-build-spec.md`](00-build-spec.md) |
| The axioms, including "ship the shape" | [`01-thesis.md`](01-thesis.md) |
| Where the constructs are drafted | [`02-dsl-surface.md`](02-dsl-surface.md) |
| The guardrail bar every proposal here was tested against | [`03-guardrails.md`](03-guardrails.md) |
| The seams, including the ones this audit adds | [`04-swap-points.md`](04-swap-points.md) |
| The limits, including the ones this audit adds | [`05-limits.md`](05-limits.md) |
| Where the (a) items landed | [`06-phases.md`](06-phases.md) |
| The (b) items as tracked gaps | [`../../wiki/Known-Gaps.md`](../../wiki/Known-Gaps.md) |
