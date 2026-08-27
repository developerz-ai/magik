# `.claude/` — the harness in this app

Everything here is read by an agent, so every file pays its token cost on activation. Keep them
short.

## The whole user journey, in three lines

```
magik new myapp     stage 1 — static boilerplate. Deterministic, offline, run once by the CLI
/setup-project      stage 2 — AI boilerplate. An interview, run once, makes this app YOURS
/feature            stage 3 — real work. Run forever, one slice at a time
```

**`/feature` is the loop.** After `/setup-project`, it is the only command most people ever need:
`/feature` after `/feature`, each one ending with the gate green. The rest of this directory exists
to make that one command work well.

If `CLAUDE.md` still shows the stage-2 banner, stage 2 has not happened. **Run `/setup-project`
before anything else** — building a feature into a scaffold with no domain model means inventing
one, badly, as a side effect.

## Commands — what you type

| Command | Does | Reads |
|---|---|---|
| `/setup-project` | the interview, then this app's architecture, plan and feature loop. **Once** | the stage-2 sentinel, then you |
| **`/feature`** | one slice end to end, gate green. With an argument it builds that; with none it takes the next item from `docs/PLAN.md` and confirms | `docs/FEATURE.md`, `docs/PLAN.md`, and the app as it currently is |
| `/screen` | one screen or component, at the right rung of the override ladder | `magik docs Screens-And-Components` |
| `/check` | the gate, with every finding triaged to a file, a rule, a fix and an owner | the error catalogue |
| `/next` | the single next task, and nothing else | `docs/PLAN.md` |

## Agents — what `/feature` dispatches

**Scoped by file set, not by role.** A researcher/coder/reviewer trio has no file set, so it cannot
be told what it may not touch, and two of them running at once collide. These six tile the app tree
with no overlap, which is what lets a feature's units run in parallel once the names are fixed.

| Agent | Owns | Never touches |
|---|---|---|
| `data-modeler` | `app/models/`, `db/migrations/`, `db/seeds.rb` | anything that acts |
| `action-author` | `app/actions/`, `jobs/`, `channels/`, `flows/`, `webhooks/`, `api/` | money movement, rendering |
| `screen-builder` | `app/screens/`, `app/components/`, `config/theme.rb`, `locales/` | the database |
| `ledger-author` | `app/ledgers/` | everything else. One directory, deliberately |
| `test-writer` | `test/` | `app/` — a test that needs a source change is a finding, not a fix |
| `guardrail-reviewer` | **nothing — read-only, no `Write` or `Edit`** | a reviewer that fixes what it finds stops reporting what it found |

## Where your own rules go

Not here. `scripts/checks/` holds this team's conventions as **executable checks**, discovered and
run by `bin/check` on every change — so `/feature` and `/check` enforce them without anybody
remembering to. **When the developer is an agent, a convention that is not executable does not
exist.** [`scripts/README.md`](../scripts/README.md) has the argument and the shape; a check is a
short file.

## `settings.json`

The allowlist: `magik` commands, read-only git, read-only shell. Denied: destructive database
commands, force pushes, `git reset --hard`, and anything touching `.env`, `config/master.key` or
`config/credentials.yml.enc`. `db/schema.rb` is denied because it is generated — change a migration
and run `magik db schema`.

`settings.local.json` is per-developer. Never commit one.

**There are no hooks.** A `PostToolUse` hook running `magik check` would be useful the day that
command exists; today it would fail on every edit and be swallowed, which is worse than no hook
because it looks like coverage.

## Who owns these files

| Path | Owner | On `magik generate agents --update` |
|---|---|---|
| `agents/*.md`, `commands/*.md`, `settings.json`, this file | the framework — no project content by construction | **replaced whole** |
| `CLAUDE.md`, `llms.txt`, `docs/FEATURE.md` | shared, split by marker | only the `magik:framework-block` is rewritten |
| `docs/ARCHITECTURE.md`, `docs/PLAN.md`, `README.md`, `.env.example` | you, from the moment they are written | **never touched** |

Put your own rules in `CLAUDE.md`'s project block, not here — edits to a `replace` file are lost on
the next update. Why it works this way:
<https://github.com/developerz-ai/magik/blob/main/docs/idea/09-app-scaffold.md>

## One rule every agent here inherits

**The Magik DSL is not in your training data.** `magik docs path` gives you the shipped
documentation as ordinary files, matched to this app's gem version. Read it before writing a
declaration — every agent file says so, because an agent activated with only its own file in context
never reads this one.
