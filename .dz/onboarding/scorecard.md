# AI-first scorecard

> Written by the developerz.ai maintainer agent — established by dz-runner setup mode. Each onboarding run rewrites this file whole; the latest run wins, and the same card is stored on the platform.

- Run: `run_12df5555a15447b48ec1ae82d53dd0fd`
- Computed: 2026-10-30T07:29:27.798Z
- Proof: **proved** — every command ran green at head.
- Score: 13 of 15 items ok

## `policy` — ok

- .dz/maintainer/maintainer.yml established
- .dz/maintainer/reviewer.md established

## `brain` — ok

- CLAUDE.md already present, left alone

## `roster` — ok

- .claude/agents already present, left alone

## `skills` — ok

- .claude/skills/verify-change/SKILL.md established

## `scripts` — ok

- bin/setup already present, left alone
- bin/dev already present, left alone
- bin/check already present, left alone
- bin/stop established
- down: ./bin/stop (bin)
- ./bin/setup exited 0 at head (386.2s)

## `wiring` — ok

- .mcp.json established

## `commands` — ok

- .claude/commands already present, left alone

## `access` — gap

- landed 0 of 16 asked
- still missing (14): MAGIK_MASTER_KEY, SECRET_KEY_BASE, DATABASE_URL, REDIS_URL, MAGIK_REALTIME_BACKEND, MAGIK_CACHE_BACKEND, MAGIK_JOBS_BACKEND, MAGIK_SEARCH_BACKEND, MAGIK_ENV, MAGIK_LOG_FORMAT, MAGIK_LOG_LEVEL, PORT, GITHUB_TOKEN, GH_TOKEN
- unnecessary — do not provision (2 of the 16 asked): RUBYGEMS_API_KEY, GEM_HOST_API_KEY.
  Releases publish over OIDC trusted publishing and no long-lived RubyGems key is stored
  here or should be added (see [PUBLISHING.md](../../apps/magik/PUBLISHING.md), .github/workflows/release.yml),
  so there is no publishing credential in this gap

## `layout` — gap

- migration to the house layout filed as tasks
- apps/magik: 19 move(s) planned as one task

## `smoke_test` — ok

- test/magik/error_test.rb in the repository
- run by ./bin/check exited 0 at head (35.0s)

## `env_example` — ok

- .env.example already present, left alone

## `agents_md` — ok

- AGENTS.md already present, left alone

## `per_workspace_brains` — ok

- single-package repository: 0 workspaces
- CLAUDE.md already present, left alone

## `docs_readme` — ok

- docs/README.md already present, left alone

## `gate_proved` — ok

- ./bin/check exited 0 at head (35.0s)
