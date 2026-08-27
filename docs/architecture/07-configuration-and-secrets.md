# Configuration and secrets

How a Magik app is configured, where secrets live, and why a missing key fails at boot instead of at 3am.

**Status:** planned. There is no config layer, no credentials file, no `.env` loader and no `magik credentials` command. Rails' encrypted credentials are the prior art being assessed, not a shipped feature. Reviewed 2026-08-26.

## The layers, and what wins

Five layers, **most specific last**. A value from a later layer replaces the same key from an earlier one.

| # | Layer | Where | Contains | Environments |
|---|---|---|---|---|
| 1 | Framework defaults | `lib/magik/core/` | timeouts, pool sizes, log level | all |
| 2 | App declarations | `config/app.rb`, `config/<env>.rb` | non-secret app settings, seam selection (`use :cache, …`) | all |
| 3 | Encrypted credentials | `config/credentials/<env>.yml.enc` | secrets: API keys, provider tokens, signing keys | all |
| 4 | Environment variables | the process environment | anything, and the only production secret path in a twelve-factor deploy | all |
| 5 | `.env` files | `.env`, then `.env.local` | developer convenience | **development and test only** |

Precedence, stated once and unambiguously:

```
framework defaults  <  config/  <  credentials  <  ENV  <  .env (dev/test only)
```

| Why this order | |
|---|---|
| Credentials beat `config/` | a secret must never be readable in a committed plaintext file, so the encrypted layer overrides the declared one |
| `ENV` beats credentials | a container platform, a CI runner or a one-off `MAGIK_LOG_LEVEL=debug magik server` must win without editing an encrypted blob. This is also what makes the same image deployable to several environments |
| `.env` beats `ENV` in dev | a developer's local file is the most specific thing on their machine. In production `.env` is not loaded at all, so the question does not arise |

Reading a value is one call, and it never says where the value came from — that is the point of a layer stack:

```ruby
Magik.config.fetch(:stripe_secret_key)
```

## Encrypted credentials

Rails' model, assessed rather than copied.

```
config/credentials/production.yml.enc      committed
config/credentials/production.key          NEVER committed, gitignored
config/credentials/development.yml.enc     committed
config/credentials/development.key         NEVER committed
```

```bash
magik credentials edit --env production     # decrypt → $EDITOR → re-encrypt
magik credentials show --env production     # decrypt to stdout
magik credentials diff                      # readable diff of an encrypted file
magik credentials rotate --env production   # new key, re-encrypt, print the new key once
```

`edit` decrypts to a temp file with restrictive permissions, opens `$EDITOR`, re-encrypts on exit, and removes the temp file — including on a crash.

| Rails got right | Why it matters |
|---|---|
| Secrets versioned alongside the code that needs them | a rollback restores the secrets that release expected; a separate secret store rolls back separately or not at all |
| One key to deploy | the entire production secret payload reduces to a single environment variable |
| Per-environment files | staging cannot accidentally hold production's keys |

| Rails got wrong / awkward | What Magik intends |
|---|---|
| Key distribution to a team is unsolved — it happens over chat | the key is documented as a **deployment** secret, and the docs point at the platform's own secret store for team distribution. `magik credentials rotate` exists so a leaked key is a routine event, not an incident |
| An encrypted blob does not diff, so review is impossible | `magik credentials diff` decrypts both sides and prints a key-level diff — **key names and change status, values redacted by default**, `--show-values` for a local review |
| Losing the key loses the secrets, irrecoverably | `magik doctor` warns when a key is missing, when a `.enc` file has no key, and when a key is present but unused. The generated app README states plainly that the key has no recovery path |
| A merge conflict on a `.enc` file is unresolvable | `magik credentials edit` re-encrypts the whole file, so conflicts are file-level. The documented resolution is: take one side, re-run `edit`, re-add what the other side changed — using `diff` to see what that was |

## `.env` in development only

**`.env` is developer convenience and never a production mechanism.** Production reads real environment variables or credentials.

| Rule | Detail |
|---|---|
| Loaded in | `development` and `test` only. In any other environment the loader does not run, even if the file exists |
| A `.env` present in production | `magik doctor` reports it as a finding, and the boot logs a warning naming the file. Silently supporting it is how secrets end up on disk inside a container image |
| Load order | `.env` first, then `.env.local` overriding it. Neither is committed |
| `.env.example` | **is** committed, is complete — every key the app requires — and carries no real values. Placeholders only |
| Drift | `magik doctor` compares `.env.example` against the declared required config and reports keys missing from either side |

```
.env.example     committed, complete, no real values
.env             gitignored — shared team defaults for local work
.env.local       gitignored — one developer's overrides
```

## Declared configuration

Magik is boot-time-enforced everywhere else, and configuration is no exception. **An app declares the configuration it requires, and boot fails naming what is missing** — rather than a `nil` surfacing three layers down under load.

```ruby
App.define :Shop do
  config do
    require :database_url,      :string
    require :stripe_secret_key, :secret, if: -> { billing_enabled? }
    optional :log_level,        :enum, values: %i[debug info warn error], default: :info
    optional :worker_threads,   :integer, default: 4
  end
end
```

| Failure | Code | `fix:` |
|---|---|---|
| a required key with no value in any layer | `MAGIK_CONFIG_MISSING_KEY` | `magik credentials edit --env production` (or the `ENV` name, printed) |
| a value that does not match its declared type or enum | `MAGIK_CONFIG_INVALID_VALUE` | the expected shape, with the key name |
| `use :cache, :redis` with no `REDIS_URL` | `MAGIK_CONFIG_MISSING_KEY` | the exact key the backend needs |
| `use :cache, :nonexistent` | `MAGIK_CONFIG_UNKNOWN_BACKEND` | the list of shipped backends |

The last two rows are the tie to [`../idea/04-swap-points.md`](../idea/04-swap-points.md): **a seam selector is configuration**, so a bad selector or a backend missing its own required keys fails at boot with the rest, not at first use — which for a cache backend might be an hour into production traffic.

The intended failure:

```
MAGIK_CONFIG_MISSING_KEY  config/app.rb:12

  required config :stripe_secret_key was not found in credentials or ENV
  (billing is enabled, provider :stripe)

  fix: magik credentials edit --env production   # add stripe_secret_key
       or set STRIPE_SECRET_KEY in the environment

Boot aborted.
```

## Secrets hygiene, enforced

The spec already refuses `field :card_number` at the type level. The same principle applied to configuration — and these are mechanisms, not advice:

| Rule | Mechanism |
|---|---|
| Never logged | values of keys declared `:secret`, plus a name-pattern list (`*_key`, `*_secret`, `*_token`, `*_password`, `authorization`, `cookie`), are redacted before a log line is written. The redaction list is part of the logging contract ([`06-observability.md`](06-observability.md)) |
| Never rendered | a `:secret` value reaching a component raises rather than printing |
| Never in an error message | error `cause` and `details` are redacted through the same list before rendering, in all three renderings |
| Never in a job payload | a `:secret` value serialized into an enqueue argument raises. A job reads the secret from config at run time, where the value is not at rest in a queue table |
| Never in a trace | request traces and OTel attributes go through the same redaction |
| Redaction is visible | redacted output prints `[REDACTED:stripe_secret_key]`, not a blank — so nobody debugs a missing value that was only hidden |

## Deployment

| Concern | Intent |
|---|---|
| How the key reaches a container | one environment variable — `MAGIK_MASTER_KEY` — sourced from the platform's secret store. Never baked into an image, never in the repo |
| Alternative | skip credentials entirely and inject every value as an environment variable. Both paths are first-class; the layer order makes them compose |
| What is in the image | code only. No `.env`, no `.key`, no decrypted anything. The image is identical across environments |
| Rotation | `magik credentials rotate --env <env>` writes a new key, re-encrypts, and prints the key once. Deploy the new key, then the re-encrypted file, then revoke the old — the order matters and the command prints it |
| Verification | `magik doctor` on boot in a container reports which layer each required key resolved from, values redacted — so a misconfigured deploy is visible in the first log lines |

Deployment shape: [`../ops/README.md`](../ops/README.md).
