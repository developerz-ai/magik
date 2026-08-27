# Local services

Postgres for development, and a Redis you only start when you are testing a swap
point. One file: [`compose.yml`](compose.yml).

> **Nothing in Magik connects to these yet.** As of 2026-08-26 the framework is
> spec only — there is no config loader, no boot process and no database code.
> This stack exists so the topology the spec assumes is runnable and reviewable
> from day one, and so `bin/setup --services` has something to start. Starting it
> gives you a working Postgres; it does not give you a working Magik app.

## Start it

```bash
docker compose -f docker/compose.yml up -d          # Postgres (the default)
docker compose -f docker/compose.yml ps             # what is running, and its health
docker compose -f docker/compose.yml logs -f postgres
docker compose -f docker/compose.yml down           # stop, keep the data
docker compose -f docker/compose.yml down -v        # stop and DELETE the data
```

`bin/setup --services` runs the first of those for you, and degrades to a
printed note if Docker is not installed.

## The two profiles

| Profile | Services | When |
| --- | --- | --- |
| *(default)* | `postgres` | Always. It is the database, the realtime transport and the job queue. |
| `swap` | `postgres` + `redis` | Only when you are exercising a swap point. |

```bash
docker compose -f docker/compose.yml --profile swap up -d
```

Postgres is alone in the default profile because the build spec makes it three
things at once: the database (Sequel, UUIDv7 keys), the realtime backend
(`LISTEN`/`NOTIFY`, Phase 3) and the job queue (a transactional Que-style queue,
Phase 4). So the one-container stack is the *whole* default stack, not a
cut-down one.

Redis is the documented **alternative** for the cache, jobs and realtime
backends — never the default — so it costs nothing until you ask for it. See
`MAGIK_CACHE_BACKEND`, `MAGIK_JOBS_BACKEND` and `MAGIK_REALTIME_BACKEND` in
[`../.env.example`](../.env.example).

## Pointing `DATABASE_URL` at it

The defaults in `compose.yml` and in `.env.example` are the same string, so if
you changed neither, this already matches:

```dotenv
DATABASE_URL=postgres://magik:magik@localhost:5432/magik_development
REDIS_URL=redis://localhost:6379/0
```

If you overrode the compose variables, build the URL from what you set:

```text
postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:${POSTGRES_PORT}/${POSTGRES_DB}
```

`compose.yml` reads `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`,
`POSTGRES_PORT` and `REDIS_PORT` from your environment, each with the default
above. Changing the credentials means changing `DATABASE_URL` to match — they
are two copies of the same fact and nothing checks that they agree.

Both ports are published to `127.0.0.1` only. Publishing `5432:5432` instead
would expose a Postgres whose password is `magik` to every machine on whatever
network your laptop is on.

A `psql` without installing one:

```bash
docker compose -f docker/compose.yml exec postgres psql -U magik -d magik_development
```

## When Postgres will not come up

Work down this list. Each step is a command, and each one rules something out.

**1. Ask what state it is actually in.** `up -d` returns as soon as the
container is *created*, which is not the same as *healthy*.

```bash
docker compose -f docker/compose.yml ps
```

`Up (healthy)` means the healthcheck is passing. `Up (health: starting)` means
wait — first boot runs `initdb` and takes a few seconds. `Restarting` means it
is crash-looping, and step 2 will say why. `Exit 1` means it died.

**2. Read the logs. The reason is nearly always in the last 30 lines.**

```bash
docker compose -f docker/compose.yml logs --tail=50 postgres
```

**3. Match the message.**

| What the logs or the CLI say | What it means | Fix |
| --- | --- | --- |
| `bind: address already in use` | Something else already owns 5432 — usually a Postgres installed on the host, or an older container. | `sudo lsof -i :5432` (or `ss -ltnp \| grep 5432`) to find it. Stop it, or run this one elsewhere: `POSTGRES_PORT=5433 docker compose -f docker/compose.yml up -d` and change the port in `DATABASE_URL`. |
| `database files are incompatible with server` | The named volume holds data from a different major version of Postgres. | You are choosing between the data and the upgrade. To discard it: `docker compose -f docker/compose.yml down -v`. To keep it, `pg_dump` from the old image first. |
| `password authentication failed for user "magik"` | The volume was initialised with different credentials. `POSTGRES_PASSWORD` is only read on **first** boot — changing it later changes nothing. | Either use the original password, or re-initialise: `docker compose -f docker/compose.yml down -v && docker compose -f docker/compose.yml up -d`. |
| `Cannot connect to the Docker daemon` | Docker itself is not running. | Start Docker Desktop, or `sudo systemctl start docker`. |
| `permission denied while trying to connect to the Docker daemon socket` | Your user is not in the `docker` group. | `sudo usermod -aG docker $USER`, then log out and back in. |
| `no space left on device` | Docker's disk is full — usually old volumes and images. | `docker system df`, then `docker system prune` (this does not touch named volumes) or `docker volume prune`. |
| Health stuck at `starting`, logs quiet | First-boot `initdb` on a slow disk. | Give it 30 seconds. `docker compose -f docker/compose.yml logs -f postgres` and wait for `database system is ready to accept connections`. |

**4. Confirm the server is really answering**, rather than trusting the
healthcheck:

```bash
docker compose -f docker/compose.yml exec postgres pg_isready -U magik -d magik_development
# -> /var/run/postgresql:5432 - accepting connections
```

**5. Confirm it is reachable from *outside* the container** — a healthy
container with an unreachable published port is a firewall or port-mapping
problem, not a Postgres problem:

```bash
docker compose -f docker/compose.yml port postgres 5432   # what it is published on
nc -z 127.0.0.1 5432 && echo reachable
```

**6. Start from scratch.** This deletes all local data and is the correct move
far more often than it feels like it should be:

```bash
docker compose -f docker/compose.yml down -v
docker compose -f docker/compose.yml up -d
```

## Data, and how to lose it

Data lives in the named volumes `magik-postgres-data` and `magik-redis-data`,
not in this repository. Named rather than bind-mounted so that a `git clean -xdf`
cannot delete your database and macOS file sharing cannot make it slow.

```bash
docker volume ls | grep magik
docker compose -f docker/compose.yml down -v   # the only command that deletes it
```

Nothing here is a backup. It is a development database; treat every byte in it
as disposable.

## What this is not

This is a **development** stack. It is not a production deployment, not a
reference for one, and not tuned like one: the password is `magik`, TLS is off,
and there are no resource limits. Production deployment is out of scope while
Magik is spec only, and there is no `compose.prod.yml` here on purpose — an
untested production compose file is worse than none.
