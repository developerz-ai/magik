# `lib/magik/cli/templates/app/` — the app scaffold templates

**This file is developer-facing and is never emitted into a generated application.** It documents
the template set for whoever maintains it. `MANIFEST` marks it `none`, and
`test/magik/app_templates_test.rb` asserts that no `none` file has a destination.

**Status:** the templates are real files; `magik new` is **planned and not implemented**
(`ruby -Ilib exe/magik help` is the current answer). Nothing here has ever been rendered by the CLI.
`As of 2026-08-26`.

Design rationale: [`docs/idea/09-app-scaffold.md`](../../../../../docs/idea/09-app-scaffold.md).

## What this set is, and what it is not

This is **stage 1** of three — the deterministic, offline, model-free half of app creation. It emits
three things, and it emits them *generically but completely*, so the tree stands on its own if the
user never runs stage 2:

1. **the AI harness** — `CLAUDE.md`, `AGENTS.md`, `llms.txt`, `.claude/`
2. **the starter docs** — `docs/README|ARCHITECTURE|FEATURE|PLAN.md`
3. **the project tooling** — `Gemfile`, `Rakefile`, `.rubocop.yml`, `.editorconfig`,
   `.gitignore`, `.gitattributes`, `lefthook.yml`, `.github/workflows/ci.yml`,
   `docker/compose.yml`, `bin/*` and `scripts/*`

The third is not an afterthought. **A Magik user should never configure a linter, a formatter, a
task runner, a git hook or a CI workflow.** All of it is static configuration that is correct today,
which is exactly why it belongs in stage 1 while the code templates do not.

### The tooling actually runs

Unlike the framework, the tooling half works on a generated app **today**: `bundle install`,
`rake test`, `bundle exec rubocop`, `bin/setup`, `bin/check` and every file in `scripts/checks/` are
real operations that need no `App.define`. `bin/check` reports the magik steps as `MISSING` and
exits `69`, never `1` — "not built yet" and "your app is wrong" must never look the same to a
script. `README.md.erb` states the split in a table; keep it true.

### `bin/` and `scripts/` — the division that matters

| | Holds | Owner | On update |
|---|---|---|---|
| `bin/` | the **verbs**: `setup`, `check`, `dev`, `console`, `test`, `magik`. Stable and few | the framework | `replace` |
| `scripts/lib/scripts.rb` | the `Check` base class, `Result`, `Registry`, `Runner` — same contract as this repo's `scripts/lib/`, in one file | the framework | `replace` |
| `scripts/checks/*.rb` | **this team's own rules**, discovered by `bin/check`'s glob | the team | `never` |

The argument, written into the generated `scripts/README.md` and worth restating here: **when the
developer is an agent, a convention that is not executable does not exist.** A rule in `CLAUDE.md`
is advice that holds on feature #3 and quietly stops holding on feature #40. The same rule in
`scripts/checks/` is a gate failure with a runnable `fix:`. It is the boot-guardrail argument, handed
to the user for the rules the framework has no opinion about.

Three seeded checks ship as working examples, each demonstrating a different shape:
`domain_boundaries` (a rule over a declared graph), `i18n_coverage` (a rule joining two corpora) and
`migration_safety` (a rule that accepts an explicit acknowledgement). Each has a pure
`self.findings_for` a test can drive with a fixture — **a rule that can only be tested by breaking
the app has no negative case.**

**`not_applicable` is the one deliberate departure** from this repo's check library. There, an empty
corpus is always a failure. In an app, a flat layout with no `domains/` and a new app with no
migrations are ordinary states, and failing a fresh app's gate teaches its owner to ignore the gate.
Use it only where absence is legitimate; a glob that *should* have matched and did not is a failure.

### The updater only touches files it names

`magik generate agents --update` reads `MANIFEST` and nothing else. A helper you add at
`scripts/lib/<yours>.rb` is not in the table, so it is never read, let alone written — which is how
an app extends the library without giving up updates to the half the framework owns.

### Judgement calls made here, and why

| Question | Answer |
|---|---|
| Copy the RuboCop rules into every app, or `inherit_gem` them? | **`inherit_gem`.** The rules live at `lib/magik/cli/templates/rubocop.yml` inside the gem; the app's `.rubocop.yml` is a dozen lines that inherit them and hold the project's own overrides. Style improves with `gem update magik`, no app is pinned to the style of the magik that generated it, and **there is nothing to regenerate** — a strictly better answer than regeneration for the one file users most legitimately edit. (When Phase 1 gives the gem a proper `config/` directory, move the file and update the one `inherit_gem` line.) |
| Should `bin/*` be generated scripts or shims? | **Shims wherever there is no logic.** `bin/dev`, `bin/console`, `bin/test` and `bin/magik` delegate to the installed gem, so a fix arrives with `gem update` instead of being frozen into every app ever generated. `bin/setup` and `bin/check` are real scripts because they compose *other* commands and must work before, and independently of, a functioning framework — and their steps are subprocesses, so the parts that improve still improve outside the frozen shell. |
| Is `bin/check` therefore frozen? | **No, because it is `replace` and it is extended by data, not by edits.** You add a rule by adding a file to `scripts/checks/`, which the glob discovers. The script says so in its own header. That is what makes overwriting it safe. |
| `.devcontainer/`? | **Not generated.** Over-provisioning: it is an editor preference, it pins a base image that rots unattended, and the app already gets `docker/compose.yml` for the one service it needs. The framework repo needs one because contributors must reproduce a TruffleRuby toolchain; an app author needs Ruby and Postgres. Add it behind an explicit flag if it is ever asked for. |
| CI opt-in behind `magik new --ci`? | **Generated by default; `--no-ci` skips it.** A repo with no CI on day one is a repo where CI is added after the first regression. The cost of an unwanted file is one `git rm`; the cost of a missing gate is a bad merge. It is inert outside GitHub and says so in its own comments. |

It does **not** hold the code templates — `Gemfile`, `config/app.rb`, `config/database.yml`,
`config/environments/*.rb`, `app/**`, `db/**`, `bin/{setup,check,magik}`, `public/`. Those are a
separate, unwritten set that lands with Phase 1, because they must be generated against a
`model`/`screen`/`action` DSL that does not exist yet. A code template written before the DSL is a
template that ships wrong. They are exactly the rows in the *"What a generated app has that this
does not"* table in [`dummy/README.md`](../../../../../dummy/README.md) — the two lists are meant to
agree, and a row appearing in one and not the other is a defect in whichever is newer.

The three stages, in one line each:

| Stage | What | Who runs it | Owned by |
|---|---|---|---|
| 1 — static boilerplate | `magik new myapp` copies this directory | the CLI, deterministically | the framework |
| 2 — AI boilerplate | `/setup-project` in a Claude session, in the fresh app | an agent, interviewing the user | the project |
| 3 — real work | `/feature`, `/screen`, `/check`, `/next` | an agent, feature by feature | the project |

## The rendering contract

Every `erb` row in `MANIFEST` is rendered with the Ruby stdlib:

```ruby
ERB.new(File.read(source), trim_mode: "-").result(context.binding)
```

**No template engine, no dependency.** The context exposes exactly the variables below and nothing
else, so a typo raises `NameError` at generation time rather than writing a silent blank into a
user's repository.

| Variable | Type | Is | Example |
|---|---|---|---|
| `app_name` | `String` | the name as typed, `snake_case`, the directory name | `"myapp"` |
| `app_class` | `String` | the constant `App.define` declares | `"Myapp"` |
| `app_title` | `String` | human-readable, for prose and headings | `"Myapp"` |
| `magik_version` | `String` | the gem version that generated the tree — stamped into every framework block | `"0.0.1"` |
| `generated_on` | `String` | ISO-8601 date the tree was written | `"2026-08-26"` |
| `layout` | `Symbol` | `:flat` or `:domains` — `magik new --domains` selects the second | `:flat` |
| `ruby_version` | `String` | the `required_ruby_version` floor the app's `Gemfile` pins | `"3.2"` |
| `database_url` | `String` | `--database`, or the Postgres default from `.env.example` | `"postgres://…"` |
| `declarations` | `Hash{Symbol => Array<String>}` | what the scaffold actually created, keyed by kind — `{}` for a plain `magik new` | `{ models: ["Account"] }` |

`declarations` is read with `.fetch(kind, [])` in every template. It exists so `llms.txt` can list
the app's real inventory rather than a promise, and so `--domains` produces a non-empty domain list.

## Ownership markers — read this before editing `CLAUDE.md.erb` or `llms.txt.erb`

Two of the emitted files are jointly owned, and the boundary is written into the file:

```
<!-- magik:framework-block BEGIN version=0.0.1 -->   framework-owned, rewritten by
<!-- magik:framework-block END -->                   `magik generate agents --update`

<!-- magik:project-block BEGIN -->                   project-owned, never rewritten
<!-- magik:project-block END -->                     by any magik command
```

`.claude/agents/*.md` and `.claude/commands/*.md` deliberately carry **no project content at all** —
they are `copy` rows, byte-identical in every generated app. That is what makes `--update` a
whole-file replace for them instead of a merge. Keep it that way: if you find yourself wanting
`<%= app_name %>` in an agent file, the fact belongs in `CLAUDE.md` and the agent should read it
there.

The generated tree also carries a stage-2 sentinel, `<!-- magik:stage2-pending -->`, in
`README.md`, `CLAUDE.md` and `docs/PLAN.md`. `/setup-project` removes it on its first successful
run, and its presence or absence is how that command knows whether it is bootstrapping or updating.

## `AGENTS.md` is a symlink

The `symlink:CLAUDE.md` mode creates `AGENTS.md` as a **relative symlink to `CLAUDE.md`**, exactly
as this repository does — one file, two names, and no chance of the two drifting. `File.symlink`
raises `Errno::EPERM` on Windows without Developer Mode, so the fallback is `AGENTS.md.fallback`: a
one-line pointer file written in its place. The fallback is a degraded mode and says so in its own
text; it is not the preferred outcome.

## Rules for anything added here

- **Register it in `MANIFEST` in the same change.** An unregistered file fails the test suite.
- **Never claim the framework works.** Every emitted file states that Magik is spec only. The
  vocabulary is `planned`, `not implemented`, `spec only`.
- **No secrets, ever** — not a generated `SECRET_KEY_BASE`, not a token, not a `.mcp.json` pointing
  at a server nobody asked for. `.env.example` holds names and blanks.
- **Markdown links in `copy`-mode `.md` files must be absolute URLs.** A generated app is a
  different repository; `../docs/…` resolves to nothing there, and `bin/check --only docs` scans
  these files from *this* tree, where it resolves to nothing either. Paths inside the generated app
  are written as `` `code spans` ``, not links.
- **Keep the budgets**: an agent file ≤ 95 lines, a command ≤ 80 (`setup-project.md`, an interview
  script, and `feature.md`, the loop that is the centre of the roster, are the stated exceptions),
  the generated `CLAUDE.md`'s framework block
  ≤ 11,000 bytes and the whole template ≤ 14,000, this file ≤ 130. Each is read into an agent's
  context and pays for its length. The byte budget on the framework block exists so it can never
  crowd out the project block underneath it.
- **Any DSL you put in a template must parse.** `ruby -c` it. The reference app caught two spellings
  in the spec that are not valid Ruby — it is `retries`, not `retry` (a Ruby keyword), and
  `computed(:name, :type) { … }`, not `computed :name, :type { … }` (a brace block binds to the
  symbol, not the call). See [`dummy/README.md`](../../../../../dummy/README.md).

## Verify

```bash
rake test TEST=test/magik/app_templates_test.rb   # manifest, ERB, JSON, YAML, frontmatter, budgets
ruby -rerb -e 'ERB.new(File.read(ARGV[0]), trim_mode: "-").src' lib/magik/cli/templates/app/CLAUDE.md.erb
ruby -rjson -e 'JSON.parse(File.read(ARGV[0]))'   lib/magik/cli/templates/app/.claude/settings.json

# The tooling half runs in place — the template tree is a (very empty) app:
cd lib/magik/cli/templates/app && ./bin/check --list && ./bin/check --only i18n-coverage
```

There is no test that renders a template and boots the result, because there is nothing to boot.
Writing one is part of Phase 1's definition of done —
[`.claude/agents/cli-author.md`](../../../../../.claude/agents/cli-author.md) already requires that a
generator be tested by generating into a temp directory and booting the output.
