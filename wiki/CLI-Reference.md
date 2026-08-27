# CLI reference

**Status:** `Mostly planned`. **Two commands exist today: `version` and `help`.** Everything else in
this reference is specified and not implemented — calling it exits `1` with
`MAGIK_COMMAND_NOT_IMPLEMENTED`. `As of 2026-08-26`.

The binary is `magik`. There is one command registry; a command that is not in it does not exist.

Resolve what this build actually ships rather than trusting the table below:

```bash
magik help --json
magik version --json
```

---

## Conventions

| Convention | Detail |
|---|---|
| `--json` | every command accepts it and prints one machine-readable object on stdout |
| Exit codes | `0` success · `1` the command failed, printing a typed `MAGIK_*` error · `2` usage error |
| Errors | always `code` + `cause` + `fix`. Same three fields in the terminal, the error page and `--json`. See [Error codes](Error-Codes.md) |
| Flags | long form, `--flag value` or `--flag=value`. Booleans negate as `--no-<flag>` |
| Global flags | `--json`, `--help`, `--version`, `--cwd <dir>`, `--verbose` |
| App detection | most commands walk up for `config/app.rb` and fail with `MAGIK_NOT_IN_APP` if there is none. Exceptions: `new`, `version`, `help` |
| Not built vs not a command | a **planned** command exits `MAGIK_COMMAND_NOT_IMPLEMENTED`; an **unknown** one exits `MAGIK_UNKNOWN_COMMAND`. "Not built yet" and "not a command" are different facts and get different codes |
| Bad flags | `MAGIK_INVALID_OPTION`, exit `2` |

### `--json` shape

```json
{ "ok": true, "command": "version", "summary": "magik 0.0.1", "data": { "version": "0.0.1" } }
```

A failure adds the error triple:

```json
{
  "ok": false,
  "command": "new",
  "summary": "not implemented",
  "error": {
    "code": "MAGIK_COMMAND_NOT_IMPLEMENTED",
    "cause": "`magik new` is specified in docs/idea/00-build-spec.md and not implemented",
    "fix": "run `magik help` for the commands that work today"
  }
}
```

That triple is `Magik::Error#to_h` — one object, three renderings.

---

## Command index

`As of 2026-08-26`. **shipped** = it runs. **planned** = specified, registered, and exits
`MAGIK_COMMAND_NOT_IMPLEMENTED`.

| Command | Does | Status |
|---|---|---|
| `magik version` | print the version | **shipped** |
| `magik help [command]` | the catalogue, or usage for one command | **shipped** |
| `magik new <name>` | scaffold an app | planned |
| `magik generate model\|screen\|component\|action\|job\|migration <name>` | scaffold one declaration plus its test | planned |
| `magik generate agents --update` | rewrite the framework-owned half of a generated app's AI harness | planned |
| `magik console` | a REPL with the app loaded | planned |
| `magik server` | boot the app server with hot reload | planned |
| `magik worker` | run background jobs | planned |
| `magik test [paths]` | the test suite | planned |
| `magik check` | the guardrails, as a linter | planned |
| `magik db <sub>` | create, migrate, rollback, seed, reset | planned |
| `magik domains` | the domain graph | planned |
| `magik routes` | the routes convention produced | planned |
| `magik errors explain <CODE>` | code → cause, fix, docs | planned |

---

## Shipped today

### `magik version`

```bash
magik version
magik version --json
```

```json
{ "ok": true, "command": "version", "summary": "magik 0.0.1", "data": { "version": "0.0.1" } }
```

Exit `0`.

### `magik help`

```bash
magik help
magik help new
magik help --json
```

Lists every registered command with its status, so `magik help --json` is the authoritative answer to
"what works" — this page is a copy of it and copies go stale.

Exit `0`.

---

## Planned

Everything below is the intended contract. None of it runs.

### `magik new <name>`

```bash
magik new myapp
magik new myapp --domains          # start with the domained layout
magik new myapp --dry-run --json   # the file list, without writing
```

| Flag | Does |
|---|---|
| `--domains` | emit `domains/` rather than a flat `app/` |
| `--database <url>` | write the connection into `config/database.yml` |
| `--dry-run` | print the files, write nothing |

Installs nothing. `bin/setup` is the next step. Exit `0`, or `2` if the directory is non-empty.

### `magik generate <kind> <name>`

```bash
magik generate model Invoice
magik generate screen Invoices
magik generate component MoneyCell
magik generate action mark_paid
magik generate job SendInvoiceEmail
magik generate migration AddPaidAtToInvoices
```

Kinds: `model`, `screen`, `component`, `action`, `job`, `channel`, `ledger`, `migration`, `domain`.
Plus `agents`, which takes no `<name>` — see below.

| Flag | Does |
|---|---|
| `--dry-run` | print the files, write nothing |
| `--force` | overwrite. Without it, an existing file is `MAGIK_GENERATE_WOULD_OVERWRITE` |
| `--no-test` | skip the test file. Discouraged, and it says so |

Every generator writes a **real test**, never a `# TODO` stub. Exit `0`, or `1` on a collision.

### `magik generate agents`

```bash
magik generate agents --update
```

Refreshes, in place, the AI harness `magik new` emitted into the app. Takes no `<name>`.

| Flag | Does |
|---|---|
| `--update` | rewrite the framework-owned harness: `.claude/agents/`, `.claude/commands/` and `.claude/settings.json` whole, since they carry no project content; and in `CLAUDE.md`, `llms.txt` and `docs/FEATURE.md` **only** the marked framework block, leaving the project block untouched. Missing ownership markers is a refusal — `MAGIK_HARNESS_MARKERS_MISSING` — never a guess at where the boundary was |

It is the `fix:` line a stale harness prints. The ownership rule it implements is
[`docs/idea/09-app-scaffold.md`](../docs/idea/09-app-scaffold.md).

### `magik console`

```bash
magik console
magik console --env production --sandbox
```

| Flag | Does |
|---|---|
| `--env <name>` | which environment to load |
| `--sandbox` | wrap the session in a transaction rolled back on exit |

### `magik server`

```bash
magik server
magik server --port 4000 --host 0.0.0.0
magik server --no-reload
```

| Flag | Does |
|---|---|
| `--port` / `--host` | bind address. Defaults `3000` / `127.0.0.1` |
| `--env <name>` | environment |
| `--no-reload` | disable hot reload |
| `--workers <n>` | worker threads in the server's pool |

Boots on `MAGIK_SETUP_INCOMPLETE` with `fix: run bin/setup` if there is no bundle or database — an
error naming the next command, not a stack trace. See [Development loop](Development-Loop.md).

### `magik worker`

```bash
magik worker
magik worker --queue mailers --concurrency 8
magik worker --once
```

| Flag | Does |
|---|---|
| `--queue <name>` | one queue. Repeatable |
| `--concurrency <n>` | in-process concurrency |
| `--once` | drain what is queued, then exit. For CI |

### `magik test [paths]`

```bash
magik test
magik test --watch
magik test --changed
magik test test/actions/mark_paid_test.rb:12
magik test --workers 1 --seed 12345
magik test --json
```

| Flag | Does |
|---|---|
| `--watch` | re-run affected tests on save |
| `--changed` | only what the diff against the merge base can have broken |
| `--workers <n>` / `--workers auto` | parallelism. `auto` (all cores) is the default |
| `--seed <n>` | reproduce an ordering |
| `--name <pattern>` | filter by test name |
| `--generated` | only the auto-generated tests |
| `--json` | the result object — shape in [Testing](Testing.md#json-output-shape) |

Exit `0` all green, `1` any failure or error.

### `magik check`

The guardrails as a command. What fails at boot, reported all at once instead of one at a time.

```bash
magik check
magik check --scale
magik check --domains
magik check --contract Modal
magik check --components
magik check --json
```

| Flag | Reports |
|---|---|
| *(none)* | every boot-time guardrail: ledgers, PAN fields, statefulness, timezones, component contracts |
| `--scale` | queries with no `tenant_id` in their `WHERE` clause — sharding pain, pre-empted |
| `--domains` | boundary violations, dependency cycles, unpublished events |
| `--contract <Component>` | the contract a kit component publishes |
| `--components` | what shadows what, across `app/`, domains, the kit gem and the built-ins |
| `--json` | findings as data |

```json
{
  "ok": false,
  "command": "check",
  "summary": "2 findings",
  "findings": [
    {
      "code": "MAGIK_TENANT_SCOPE_MISSING",
      "cause": "app/screens/revenue.rb:14 queries :Invoice with no tenant_id predicate",
      "fix": "add `.for_tenant` to the scope, or declare the query tenant-exempt with `global_scope!`",
      "at": "app/screens/revenue.rb:14"
    }
  ]
}
```

Exit `0` clean, `1` any finding. This is the command CI gates on.

### `magik db <sub>`

```bash
magik db create
magik db migrate
magik db rollback --step 1
magik db seed
magik db reset
magik db schema           # regenerate db/schema.rb
```

### `magik domains` / `magik routes` / `magik errors explain`

```bash
magik domains --json          # nodes, edges, exposures, events
magik domains --graph
magik routes                  # every route the convention produced
magik errors explain MAGIK_LEDGER_UNBALANCED --json
```

---

## Exit codes

| Code | Means |
|---|---|
| `0` | success |
| `1` | the command ran and failed. A typed `MAGIK_*` error is printed |
| `2` | usage error: `MAGIK_UNKNOWN_COMMAND`, `MAGIK_INVALID_OPTION` |

## Next

- [Error codes](Error-Codes.md) — every code a command can print.
- [Development loop](Development-Loop.md) — the commands in daily use.
- [Testing](Testing.md) — `magik test` in full.
- [Known gaps](Known-Gaps.md) — what does not exist, stated plainly.
