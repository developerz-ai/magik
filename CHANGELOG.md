# Changelog

All notable changes to Magik. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Magik is **one gem** with subsystem modules — there is no lockstep across packages and no
per-package version. The single version lives in
[`lib/magik/version.rb`](apps/magik/lib/magik/version.rb); [`PUBLISHING.md`](apps/magik/PUBLISHING.md) owns how it is
stamped and released.

**Semver does not apply below 0.1.0.** Anything in a `0.0.x` release may change or disappear
without notice, and `0.0.1` in particular ships no API at all.

`## [Unreleased]` is the release notes — write the entry as the change lands, not at release time.

## [Unreleased]

Documentation and planning only. **No framework behaviour changed, because there is none** — the
spec was amended from measurement and rewritten as a clean v1, and everything below is the rest of
the repository being brought back into agreement with it.

### Added

- **Architecture decision 13 — authorization is evaluated in exactly one place.** Every surface that
  reaches a model — screen, action, API resource, channel, job, admin panel — names a verb in a
  `policy` and the framework evaluates it. There is no second door to the data and no per-surface
  check. The evaluator sits at **tier 1**, below `model`, `render` and `realtime`, because tier 2 has
  to evaluate it and imports go strictly down; it takes the actor as an opaque value and `auth` at
  tier 3 supplies that value later. Authorization is deliberately **not** a swap point.
- **`policy` as the twenty-first subsystem** — `apps/magik/lib/magik/policy.rb`, a spec-only stub like the rest:
  `SPEC_PHASE`, `DSL_SURFACE`, `STATUS`, and a `.define` that raises `NotImplementedError`. Re-derive
  the list with `ruby -Iapps/magik/lib -e 'require "magik"; puts Magik::SUBSYSTEMS.keys.join(" ")'`.
- **Phase 4b — Media**, a new phase between jobs and money, delivered at build step 8. It exists
  because media spans four phases — the `:file` type is phase 1, the upload component phase 2,
  derivatives and transcoding are phase 4 jobs, and signed delivery is blocked on `policy` — and a
  capability whose value arrives only when all four have landed is a phase. It is not optional: the
  mission sentence names ecommerce and marketplaces and both are blocked on it.
- **`layout` and `magik describe`** in the plan — `layout` lands in phase 2 and build step 3 as the
  application shell, so a generated app has a sidebar on its first run; `magik describe` lands in
  phase 1 and build step 2 as the grammar-as-data, derived from the option tables the DSL validates
  against rather than hand-maintained.
- **A fourth executable proof for `1.0.0`** in [`ROADMAP.md`](apps/magik/ROADMAP.md): *a generated app is safe
  and usable on its first run*, proven by three tests rather than a document — a cross-tenant actor
  denied by every generated surface, the generated shell rendering correctly at 375px, and the
  generated signup form throttling without revealing whether an account exists. It exists because the
  three criteria above it can all be true of an application that is insecure and unusable.

- **`/planx` and `/feature`, two agent commands** ([`.claude/commands/`](.claude/README.md)).
  `/planx` writes a multi-file execution plan another agent runs cold — `overview.md`, one file per
  separable slice, and a `status.yml` tracker — into `.claude/plans/`, not `docs/`, because
  `Magik::Docs::PACKAGED_GLOBS` reads `docs/**/*.md` into the `magik docs` catalogue and a plan
  there would present itself as a page of the reference. `/feature` takes one request from plain language to merged, and carries the
  rules a parallel run goes wrong without: at most four live agents, one checkout and never a
  worktree, the file set as the only lock, and `bin/check` run by the coordinator alone. Both are
  adapted from the TypeScript sibling's harness; neither claims any framework behaviour.

- **Every checkout-root `docs/` page ships inside the gem as a generated mirror** — `apps/magik/docs/**`,
  rendered from the checkout's originals by `ruby apps/magik/scripts/checks/shipped_mirrors.rb`
  (`--write` regenerates; the check fails when a committed copy is stale). `Magik::Error::DEFAULT_FIX`
  and every spec-only stub's error message name the path `docs/idea/00-build-spec.md`, and the shipped
  manual links the other design pages — wiki pointing at `04-swap-points.md`, the build spec at the DSL
  surface — so an installed gem now serves the page its own links and fix lines point at instead of
  whatever `main` carries. Each mirror carries its original verbatim, with links to packaged pages
  rewritten gem-relative, other prose links as absolute repository URLs, and a provenance banner. The
  gemspec's file-list filter sees untracked-but-un-ignored files, so a first `--write` is visible to a
  gate run before the next commit. Re-derive: `ruby apps/magik/scripts/checks/shipped_mirrors.rb`,
  then `magik docs docs/idea/00-build-spec` and `gem build` + `tar -tf` for the packaged bytes.

- **A shipped-links guard — `apps/magik/scripts/checks/shipped_links.rb`** — every relative link in a
  packaged page (`Magik::Docs::PACKAGED_GLOBS`, minus the checkout-only `../` spellings) must resolve
  to another packaged file inside the gem root (`MAGIK_DEV_SHIPPED_LINK_ESCAPES` /
  `MAGIK_DEV_SHIPPED_LINK_UNPACKAGED`), no packaged page may link a packaged page through the
  repository's mutable `main` (`MAGIK_DEV_SHIPPED_LINK_MUTABLE_MAIN`), and a filesystem-absolute
  `/…` target — which resolves against the reader's filesystem root, never the gem root — is
  reported as escaping. 152 links across `wiki/` and `llms.txt` now point at the in-gem copies; only
  targets the gem does not carry (ROADMAP, CONTRIBUTING, `.claude/`) keep repository URLs. Re-derive:
  `ruby apps/magik/scripts/checks/shipped_links.rb`.

### Changed

- **`bin/stop` is the teardown half of the setup→dev→check cycle**, not a `true` stub. It runs
  `docker compose -f apps/magik/docker/compose.yml --profile swap stop` — the Postgres of the default profile
  that `bin/setup --services` started, plus any swap-profile Redis, which `--services` does not
  start: `stop` names the profile so that one stops too. It prints a note and
  exits 0 when docker or the compose plugin is absent, and exits 0 even if compose fails. It stops,
  never `down`, and never removes data: the named volumes survive for the next session.
  [`apps/magik/test/dev_scripts_test.rb`](apps/magik/test/dev_scripts_test.rb) pins the contract: every path exits 0, and
  the only docker argv the script may produce is the probe and that one `stop`.

- **The gem's app tree moved under `apps/magik/`.** `exe/`, `lib/`, `test/`, the `Gemfile`,
  `Rakefile`, `magik.gemspec`, `wiki/`, `llms.txt`, `dummy/`, `docker/` and `scripts/` now live
  inside `apps/magik/`, and the checkout root keeps only repository-level plumbing: `bin/`,
  `docs/`, `.claude/`, `.github/` and the top-level markdown. The root `Gemfile` became a
  bundler workspace entry pointing at the app gemspec, so `bin/setup`, `bin/check` and CI still
  resolve one bundle from the checkout root, and every command, workflow path and relative link
  was re-pointed with it — `rake -C apps/magik test`,
  `ruby -Iapps/magik/lib apps/magik/exe/magik version --json`. The package shrank to match:
  `spec.files` stays inside `apps/magik/` — README, LICENSE, CHANGELOG and the repo-root `docs/`
  trees leave the gem, with one later exception under Added above: the generated build-spec mirror —
  while a checkout `magik docs` still serves `docs/idea` and `docs/architecture` by
  resolving `../../docs/**` against `Magik.root`. `magik.manifest.json` moved verbatim and
  `ruby apps/magik/scripts/checks/manifest.rb` passes against it unchanged. Re-derive the
  layout with `bin/check` — every step runs the app-prefixed spelling.

- **Dependabot now tracks the checkout-root bundle too.** CI resolves TWO Bundler definitions — the
  root `Gemfile` (the workspace entry `bin/check`'s `bundle exec` and CI's bundler-cache resolve
  against) and `apps/magik/Gemfile` — but Dependabot only watched the app one, so a constraint
  update it proposed for the app bundle did not reach the bundle CI actually resolves, and the
  duplicated development constraints in the two files could drift apart in silence. The root entry
  uses the same fortnightly cron schedule and cooldown as the app bundle, so both bundles update in
  one morning, not two.

- **`.coderabbit.yml` is back at the checkout root.** CodeRabbit discovers `.coderabbit.yml` only at
  the repository root; while it sat under `apps/magik/`, every review fell back to defaults and
  dropped the path instructions. The file moves back with its globs already repo-root-relative, a
  header note on why the location is load-bearing, and the gemspec and docs instructions updated for
  the generated build-spec mirror and the shipped-links guard.
- **`.claude/settings.json` is no longer committed**, and is now ignored. It is a permission
  allowlist and a post-edit hook — one operator's tolerance for what runs unprompted and one
  machine's tooling — so committing it handed every contributor those choices silently. Nothing in
  the repo depended on it: the lint runs because `bin/check` runs `rake -C apps/magik rubocop`, and publishing is
  guarded by [`PUBLISHING.md`](apps/magik/PUBLISHING.md) and `bin/release`, not by a deny rule. The template
  `magik new` will render into a generated app, `apps/magik/lib/magik/cli/templates/app/.claude/settings.json`,
  is unaffected — that one is a product artifact and stays.

- **The server is Rack + Puma, thread-per-request — not Falcon.** TruffleRuby's threads are genuinely
  parallel and it implements no fiber scheduler and no `fork`, which makes thread-per-request the
  correct model, Puma the correct server, and clustered workers impossible. Re-derive with
  `ruby apps/magik/scripts/probes/runtime.rb --json`; the provenance is
  [`docs/architecture/12-runtime-verification.md`](docs/architecture/12-runtime-verification.md).
  Corrected in [`.env.example`](apps/magik/.env.example), [`magik.gemspec`](apps/magik/magik.gemspec)'s wrap-target list,
  [`.github/dependabot.yml`](.github/dependabot.yml),
  [`.github/workflows/ci.yml`](.github/workflows/ci.yml) and
  [`CONTRIBUTING.md`](CONTRIBUTING.md).
- **Every count now reads ten phases, thirteen build steps and thirteen non-negotiable decisions.**
  [`ROADMAP.md`](apps/magik/ROADMAP.md), [`llms.txt`](apps/magik/llms.txt) and [`CONTRIBUTING.md`](CONTRIBUTING.md) said
  nine, twelve and twelve.
- **[`ROADMAP.md`](apps/magik/ROADMAP.md) is now ordered by delivery and numbered by phase identity**, and says
  so. It previously renumbered the phases silently, so its "Phase 3" was the spec's phase 9. The
  spec settles the relationship — *where the build order and the phase list disagree, build order
  wins* — and the page now states it instead of hiding it. Domains is labelled spec item 12 rather
  than a phase, matching [`docs/idea/06-phases.md`](docs/idea/06-phases.md).
- **`retries times: 5, backoff: :exponential`, never `retry`.** `retry` is a Ruby keyword and a
  declaration named after it does not parse; `computed(:name, :type) { … }` keeps its parentheses
  because a brace block binds to the last call. Both were found by running a parser over the drafted
  DSL, which is the spec's rule: *a drafted DSL spelling is not designed until it has been parsed.*
- **The TruffleRuby pin in [`.devcontainer/Dockerfile`](.devcontainer/Dockerfile) is `34.0.1`**, and
  its header no longer describes the runtime's concurrency as "Ractors and Fibers" — it is real
  parallel OS threads, verified on both 24.2.1 and 34.0.1. The devcontainer's `build.args` in
  [`.devcontainer/devcontainer.json`](.devcontainer/devcontainer.json) now passes that same default
  instead of overriding it with `24.2.1`.
- **[`llms.txt`](apps/magik/llms.txt) and [`docs/README.md`](docs/README.md) map the pages that exist** —
  `docs/idea/10`–`12` and `docs/architecture/09`–`12` were missing from both, and `apps/magik/llms.txt` still
  described the spec as "kept verbatim", listed two working CLI commands where three run, and named
  twenty subsystems where twenty-one are registered.
- **The `MAGIK_*` catalogue is one catalogue again, and the format is a closed set.**
  [`wiki/Error-Codes.md`](apps/magik/wiki/Error-Codes.md) had drifted to 82 codes in a looser
  `MAGIK_<CONDITION>` shape, sixteen of them a second name for a guardrail
  [`docs/idea/03-guardrails.md`](docs/idea/03-guardrails.md) had already named — `MAGIK_STATEFUL_ACTION`
  beside `MAGIK_ACTION_STATEFUL`, `MAGIK_ROUTE_COLLISION` beside `MAGIK_ROUTER_PATH_CONFLICT`,
  `MAGIK_OFFLINE_UNSUPPORTED` beside `MAGIK_PWA_OFFLINE_UNSUPPORTED`. The spec page won every
  disagreement; the sixteen collapsed onto its spelling and the rest were renamed into
  `MAGIK_<SUBSYSTEM>_<CONDITION>`. `MAGIK_WEBHOOK_UNVERIFIED` (no `verify_signature` declared, boot)
  and `MAGIK_WEBHOOK_SIGNATURE_INVALID` (the signature did not match, runtime) are two conditions and
  both stay.
- **Breaking, error surface: three shipped CLI codes were renamed** — `MAGIK_UNKNOWN_COMMAND` →
  `MAGIK_CLI_UNKNOWN_COMMAND`, `MAGIK_COMMAND_NOT_IMPLEMENTED` → `MAGIK_CLI_COMMAND_NOT_IMPLEMENTED`,
  `MAGIK_INVALID_OPTION` → `MAGIK_CLI_INVALID_OPTION`. The stability rule protects consumers, and
  `0.0.1` is a name reservation with none; the window to fix a convention is before there is anyone to
  break. The four `MAGIK_DOCS_*` codes already fit and are unchanged, and `MAGIK_ERROR` is kept as the
  root code by a rule rather than an exception — the reasoning is in
  [`docs/architecture/03-error-codes.md`](docs/architecture/03-error-codes.md#the-shipped-codes-and-the-format-a-decision-record).
- **The allowed `<SUBSYSTEM>` tokens are written down** — a closed set of 30 in
  [`docs/architecture/03-error-codes.md`](docs/architecture/03-error-codes.md#the-allowed-subsystem-tokens),
  replacing an open-ended example list that ended in a dash, which is what let the catalogue drift.
- **[`scripts/checks/error_codes.rb`](apps/magik/scripts/checks/error_codes.rb) now validates the reserved
  catalogue too**, not only the eight implemented classes: every code in the `Code` column of
  `apps/magik/wiki/Error-Codes.md` and `docs/idea/03-guardrails.md` must use a token from the closed set
  (`MAGIK_DEV_ERROR_CODE_UNKNOWN_SUBSYSTEM`), carry a condition
  (`MAGIK_DEV_ERROR_CODE_MALFORMED`), not restate a condition another code already names
  (`MAGIK_DEV_ERROR_CODE_NEAR_DUPLICATE`), not revive a retired spelling
  (`MAGIK_DEV_ERROR_CODE_RETIRED_SPELLING`), and — for every guardrail on the spec page — appear in
  the manual (`MAGIK_DEV_ERROR_CODE_UNCATALOGUED`). `MAGIK_DEV_ERROR_CODE_ROOT_MISCLAIMED` holds the
  root-code rule over `apps/magik/lib`.
- **`MAGIK_HARNESS_STALE` and `MAGIK_HARNESS_MARKERS_MISSING` are now `MAGIK_CLI_HARNESS_STALE` and
  `MAGIK_CLI_HARNESS_MARKERS_MISSING`.** `HARNESS` was never a subsystem, and both names were
  reserved rather than shipped, so they moved into `MAGIK_<SUBSYSTEM>_<CONDITION>` rather than
  carving an exception into it — the same reasoning as the three CLI renames above, applied one step
  earlier. The old spellings are in `RETIRED` and cannot come back.
- **The five `MAGIK_*` codes the developer scripts in `bin/` print now carry a `DEV` token** —
  `MAGIK_DEV_NO_RUBY`, `MAGIK_DEV_RUBY_TOO_OLD`, `MAGIK_DEV_NO_RAKE`, `MAGIK_DEV_NO_WATCHER`,
  `MAGIK_DEV_NO_VERSION`. They were a fourth namespace using the project's prefix under no rule and
  no check. `bin/` ships to nobody, so they are deliberately absent from `apps/magik/wiki/Error-Codes.md`; they
  are documented in
  [`docs/architecture/03-error-codes.md`](docs/architecture/03-error-codes.md#the-dev-namespace-codes-that-never-reach-an-app),
  and `apps/magik/scripts/checks/error_codes.rb` now scans `bin/` as a third corpus —
  `MAGIK_DEV_ERROR_CODE_BIN_MALFORMED` for a code outside the token,
  `MAGIK_DEV_ERROR_CODE_BIN_UNFIXABLE` for one printed with no `fix:`. It matches the `CODE: cause`
  rendering rather than the prefix, so the `MAGIK_YARD_MIN_COVERAGE` and `MAGIK_DOCS_ROOT`
  environment variables stay what they are.
- **Every finding the repository's own checks emit is now `MAGIK_DEV_*` too, and one rule covers the
  whole prefix.** The check findings were a *fourth* `MAGIK_` namespace that nothing validated,
  spelled with seven tokens nothing had blessed — `MANIFEST`, `CHANGELOG`, `VERSION`, `SPEC`,
  `DUMMY`, `DOC`, `ERROR_CODE`. All 40 were renamed: `MAGIK_MANIFEST_DRIFT` →
  `MAGIK_DEV_MANIFEST_DRIFT`, `MAGIK_CHANGELOG_HEADING` → `MAGIK_DEV_CHANGELOG_HEADING`,
  `MAGIK_BOUNDARY_TIER` → `MAGIK_DEV_BOUNDARY_TIER`, `MAGIK_ERROR_CODE_MALFORMED` →
  `MAGIK_DEV_ERROR_CODE_MALFORMED`, and so on through
  [`scripts/checks/`](apps/magik/scripts/checks) and `Check#nothing_scanned`. The alternative — blessing seven
  more tokens — dilutes a closed set of *framework* tokens with repository-internal concerns and
  leaves four namespaces under three rules. Folding them in leaves one, statable in a line: **a
  `MAGIK_` code is either a framework code, whose token comes from the closed set and which an app
  author can hit, or a repo-internal code under `MAGIK_DEV_*`, emitted by this repository's own
  scripts and checks, which ships to nobody. There is no third kind.** Nobody outside this
  repository could ever have matched on one, so nothing breaks; on a red gate the `DEV_` is signal,
  because it says *this is about the repository, not about your app*.
  `MAGIK_BOUNDARY_TIER` and `MAGIK_BOUNDARY_INTERNAL_REQUIRE` stay in the seed catalogue as the
  **framework** codes `magik check` will raise inside an application — one name each, neither
  borrowing the other's.
- **[`scripts/checks/error_codes.rb`](apps/magik/scripts/checks/error_codes.rb) gained a fourth corpus** so the
  new rule is enforced rather than promised: it reads every `Finding.new(code: ...)` under
  `apps/magik/scripts/`, resolving a `NAME = "MAGIK_DEV_..."` constant against the file that declares it, and
  raises `MAGIK_DEV_ERROR_CODE_FINDING_MALFORMED` for a code outside `MAGIK_DEV_<CONDITION>`,
  `MAGIK_DEV_ERROR_CODE_FINDING_FRAMEWORK_TOKEN` for one claiming a closed-set token — the mistake
  that reads as correct — `MAGIK_DEV_ERROR_CODE_FINDING_UNFIXABLE` for a finding built with no
  `fix:`, `MAGIK_DEV_ERROR_CODE_FINDING_UNRESOLVED` for a `code:` argument it cannot read rather
  than a silent skip, and `MAGIK_DEV_ERROR_FIX_ADVICE` from the one shared phrase list, so the four
  corpora cannot disagree about what counts as advice. A fifth rule runs from the catalogue side:
  `MAGIK_DEV_ERROR_CODE_PUBLISHED` refuses a repo-internal code written into
  [`wiki/Error-Codes.md`](apps/magik/wiki/Error-Codes.md) or `docs/idea/03-guardrails.md`, which an app author
  reads and can never reach.

### Fixed

- **A PR touching only `apps/magik/Gemfile` or the root `.rubocop.yml` can no longer skip CI's Ruby
  jobs.** Neither path matched the `ruby` paths-filter, so a dependency bump or a lint-rule change
  reached `main` with the affected jobs never run. Both are in the filter now, beside the workspace
  `Gemfile` and the app `.rubocop.yml` that were already listed.
- **`apps/magik/scripts/README.md`'s check-authoring sequence runs the suite the way the repo
  spells it** — `bundle exec rake -C apps/magik test`, not `bundle exec rake test`, which stopped
  working when the Rakefile moved into `apps/magik`.
- **The mirror check's and the shipped-links check's failure branches hand the reader a runnable
  recovery** — `git checkout -- docs` (then the regenerating `--write`) when rendering the mirrors
  raises, and concrete `in apps/magik/<page>:<line>, replace <target> with <replacement>` edits for
  a dangling, unpackaged, filesystem-absolute or mutable-`main` link — where both checks used to
  print advice such as "restore the source and check its links".
- **`apps/magik/PUBLISHING.md`'s inventory tells release reviewers the truth about `docs/`**: the gem
  ships the generated mirror tree, the checkout-root originals stay out — not "docs/ is not
  packaged".
- **`bin/stop`'s two missing-tool messages now print a command instead of advising one.** They said
  *"install Docker before `bin/setup --services`"* and *"install docker-compose-plugin"* — an
  instruction and a package name, neither of them something a reader can paste, against the repo's
  own rule that a `fix:` is a runnable command. They now print
  `sudo apt-get install -y docker.io docker-compose-v2` (Debian/Ubuntu) or
  `brew install --cask docker` (macOS), and `sudo apt-get install -y docker-compose-v2` or
  `brew install docker-compose` when only the compose plugin is missing.
  [`apps/magik/test/dev_scripts_test.rb`](apps/magik/test/dev_scripts_test.rb) pins both.
- **`bin/dev --once` and the no-watcher refusal are exercised at last.** Every dev-script case
  stubbed a watcher, so the two paths a coding box actually takes — one pass with no watcher
  installed, and the refusal that says one is missing — were never run. `run_script` now forwards
  arguments, and the suite asserts that `--once` runs the check exactly once and never asks for a
  watcher, and that the refusal exits 69 with `MAGIK_DEV_NO_WATCHER` and a `fix:` that is a command.
  That `fix:` is now `sudo apt-get install -y entr`; the message used to say `apt install entr`,
  which needs root and does not work as pasted.

- **The command tables no longer call `bin/dev` "the CLI against the demo app" or "a running
  stack".** [`README.md`](README.md), [`CONTRIBUTING.md`](CONTRIBUTING.md), [`CLAUDE.md`](CLAUDE.md)
  and [`.claude/skills/verify-change/SKILL.md`](.claude/skills/verify-change/SKILL.md) now say what
  it is: the test watch loop — rerun `bin/check --only test` on every change, `--once` for a single
  pass — which never touches [`apps/magik/dummy/`](apps/magik/dummy/) and, Magik being spec only, boots no stack.
- **`bin/dev`'s watchexec branch now watches everything the script announces.** It hardcoded
  `--exts rb,rake,gemspec --watch lib --watch exe --watch test`, but `--exts` is a whitelist filter
  that drops extension-less files — `Rakefile` and `Gemfile` never triggered a rerun — and
  `magik.gemspec` sits outside the watched directories. The branch derives its `--watch` arguments
  from the same `WATCH_PATHS`/`WATCH_FILES` arrays the entr, fswatch and inotifywait branches use.
  [`apps/magik/test/dev_scripts_test.rb`](apps/magik/test/dev_scripts_test.rb) runs the script against a stub watchexec
  and asserts the exact argument list — one `--watch` per watched path and file, and no `--exts`.
- **`bin/dev`'s entr branch now actually watches.** The old form piped an
  endless `while` loop into `entr`, which reads its file list from stdin only
  up to EOF and then starts watching — the loop never ended, so `entr` never
  started. [`bin/dev`](bin/dev) now runs the regenerate-and-restart loop
  entr's own manual prescribes, and the entr and fswatch branches hold
  `exit 0` when their watcher ends instead of falling through to the
  no-watcher refusal.

- **`apps/magik/magik.gemspec` evaluates when its `require` lines are stripped.** Dependabot's Bundler
  sanitizer rewrites `require` calls to `nil` before evaluating a gemspec, so `Magik::Docs` was
  undefined and every dependency update failed with `dependency_file_not_evaluatable`. The
  documentation globs are now read through `defined?(Magik::Docs)`, keeping their single home in
  [`lib/magik/docs.rb`](apps/magik/lib/magik/docs.rb); a real build still packages the pages the globs match inside the gem, and
  [`test/magik/docs_test.rb`](apps/magik/test/magik/docs_test.rb) fails if it ever stops.
- **GitHub Pages is enabled**, so [`.github/workflows/docs.yml`](.github/workflows/docs.yml) no
  longer fails at `actions/configure-pages` with a 404. That was the one-time human setup step the
  workflow's own comment names, and the URL it serves is the `documentation_uri` the gemspec has
  advertised since `0.0.1`.

### Notes

- **Nothing in this release is a measurement of Magik.** The only numbers anywhere in the repository
  are engine measurements from `apps/magik/scripts/probes/`, and they belong to Ruby, not to this framework.
- **No `MAGIK_*` code named in the spec is implemented.** Eight codes can be raised by a running
  command — three `MAGIK_CLI_*`, four `MAGIK_DOCS_*` and the root `MAGIK_ERROR` — and everything in
  the guardrail catalogue is seeded and raised by nothing. Re-derive the real list with
  `jq -r '.error_codes[].code' apps/magik/magik.manifest.json`, or the count with
  `ruby apps/magik/scripts/checks/error_codes.rb`. **Do not** grep `apps/magik/lib` for the pattern: it returns eleven,
  because it also matches the `MAGIK_DOCS_ROOT` environment variable and two code names that appear
  only inside YARD examples. That over-count is the reason the manifest exists.


## [0.0.1] - 2026-08-26

**A name reservation and the repository's ground work. No framework functionality.**

This release exists so the gem name `magik` is held on RubyGems and so the release path is proven
end to end before there is anything worth releasing. Installing it gives you a version constant and
a CLI that can print it. Nothing else.

What is explicitly **not** in this release: `App.define`, `model`, `migrate`, `component`, `screen`,
`action`, `channel`, `job`, `ledger`, `api`, `auth`, `billing`, `admin_panel`, the router, the
server, the test DSL, and every generator. Every one of them is
[specified](docs/idea/00-build-spec.md) and unimplemented. See the status callout in
[`README.md`](README.md).

### Added

- **The gem skeleton**, with **zero runtime dependencies** — [`magik.gemspec`](apps/magik/magik.gemspec),
  `apps/magik/Gemfile`, [`Rakefile`](apps/magik/Rakefile), `apps/magik/lib/magik.rb`, [`lib/magik/version.rb`](apps/magik/lib/magik/version.rb)
  and `apps/magik/exe/magik`. `required_ruby_version` is `">= 3.2"`; TruffleRuby is the production runtime
  target and CRuby is supported for tooling and development. `apps/magik/lib/magik.rb` is plain `autoload` over
  a `Magik::SUBSYSTEMS` map, so requiring the gem reads one file. The gems Magik intends to wrap are
  listed in the gemspec as comments, to be added by the phase that needs each one.
- **`Magik::Error`** — the `MAGIK_*` error-code convention, implemented and tested rather than
  described: a stable code, a one-sentence cause, a runnable `fix:` line, a deterministic rendered
  message, and `#to_h` for `--json`. Three subclasses cover the CLI's own failures.
- **`magik version` and `magik help`** — a working CLI, both with `--json`. `help` lists every
  command the spec names and marks each `ready` or `planned`, because "not built yet" and "not a
  command" are different facts.
- **19 spec-only subsystem stubs** under `apps/magik/lib/magik/`, one per planned subsystem: `core`, `model`,
  `schema`, `render`, `action`, `router`, `realtime`, `jobs`, `ledger`, `api`, `auth`, `billing`,
  `admin`, `i18n`, `pwa`, `notify`, `testing`, `domains`, `check`. Each documents its `SPEC_PHASE`,
  its `DSL_SURFACE` verbatim from the spec, and a `STATUS`; every `.define` raises
  `NotImplementedError` naming the spec rather than returning a plausible empty answer. `cli` is the
  twentieth subsystem and the only one with real behaviour.
- **The build spec**, [`docs/idea/00-build-spec.md`](docs/idea/00-build-spec.md), as the source of
  truth, plus the `docs/idea/`, [`docs/architecture/`](docs/architecture/) and
  [`docs/ops/README.md`](docs/ops/README.md) documentation sets, the [`wiki/`](apps/magik/wiki/) reference
  manual, [`ROADMAP.md`](apps/magik/ROADMAP.md) and [`llms.txt`](apps/magik/llms.txt).
- **The agent workflow** — [`CLAUDE.md`](CLAUDE.md) (with `AGENTS.md` symlinked to it) and
  [`.claude/`](.claude/README.md) with its agents and slash commands.
- **The developer environment** — `bin/setup`, `bin/check` (the gate, with `--only`, `--json` and
  `--list`), `bin/dev`, `bin/console`, `bin/release` (a release pre-flight that prints and never
  publishes), `apps/magik/docker/compose.yml`, [`.devcontainer/`](.devcontainer/) and
  [`lefthook.yml`](lefthook.yml).
- **Minitest** as the test framework, under `test/` as `*_test.rb`, run by `rake test` — and passing
  on bare Ruby, with no bundle installed. Never RSpec: a spec decision.
- **`rake -T`** — `build`, `check`, `docs:coverage`, `rubocop`, `test`, `yard`. The RuboCop and YARD
  tasks are defined even when their gem is absent, and abort with an install hint rather than
  passing vacuously.
- **RuboCop** (with `rubocop-minitest`, `rubocop-rake`, `rubocop-performance`) via
  [`.rubocop.yml`](apps/magik/.rubocop.yml), and **YARD** via [`.yardopts`](apps/magik/.yardopts).
- **CI and release plumbing** — [`.github/workflows/ci.yml`](.github/workflows/ci.yml),
  [`release.yml`](.github/workflows/release.yml) and
  [`docs.yml`](.github/workflows/docs.yml), which publishes the YARD docs to
  <https://developerz-ai.github.io/magik/api/>. Releases publish to RubyGems over trusted publishing
  (OIDC), with `rubygems_mfa_required` set on the gem; [`PUBLISHING.md`](apps/magik/PUBLISHING.md) documents
  the one-time manual bootstrap that 0.0.1 itself requires.
- **Project governance** — [`CONTRIBUTING.md`](CONTRIBUTING.md), [`SECURITY.md`](SECURITY.md),
  [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) and [`LICENSE`](LICENSE) (MIT).

### Notes

- **Nothing here has been benchmarked, deployed, or run against a real database.** No number in
  this repository is a measurement.
- `0.0.1` is published **by hand**: RubyGems cannot attach a trusted publisher to a gem that does
  not exist yet, so the first push is manual and every release after it goes through the workflow.
  [`PUBLISHING.md`](apps/magik/PUBLISHING.md) has the exact steps.

[Unreleased]: https://github.com/developerz-ai/magik/compare/v0.0.1...HEAD
[0.0.1]: https://github.com/developerz-ai/magik/releases/tag/v0.0.1
