# Security Policy

## Supported versions

**None.** `As of 2026-08-26` Magik is pre-alpha and spec only: there is no framework
implementation, so there is nothing running anywhere that a security fix could protect.

| Version | Supported |
|---|---|
| `0.0.x` | ❌ not supported — a RubyGems name reservation, not software. Do not depend on it |
| unreleased `main` | ❌ not supported — no release has been cut |

There is no supported release, no backport branch and no security branch. This table gets its first
`✅` when the first release that does something exists; until then, treat anything published under
the name `magik` as inert. Check what the registry actually serves rather than trusting this file:

```sh
gem list -r magik --all
gem info magik -r
```

## Reporting a vulnerability

**Do not open a public issue.** Report privately through GitHub Security Advisories:

→ **[Report a vulnerability](https://github.com/developerz-ai/magik/security/advisories/new)**
(repository → **Security** → **Report a vulnerability**)

Include: what you did, what happened, what you expected, the smallest input that reproduces it, and
the version or commit you tested. A failing test is worth more than a paragraph describing one.

If GitHub advisories are unavailable to you, email **admin@developerz.ai** with the same detail.

### What to expect

| Step | Expectation |
|---|---|
| Acknowledgement | within **3 business days** |
| Initial assessment and severity | within **7 days** |
| Progress | we tell you what we found, what we are doing about it, and when |
| Disclosure | coordinated. We agree a timeline with you, ship the fix, and do not publish before you have reviewed the advisory |
| Credit | in the advisory and in [`CHANGELOG.md`](CHANGELOG.md), unless you would rather stay anonymous |

These are the commitments of a pre-alpha project with no users. They are honest about the size of
the team, not a service-level agreement.

### Scope, today

The repository contains documentation, a gem skeleton, CI workflows and release plumbing. The
realistic reports against it are **supply-chain shaped**, and they are in scope:

- a workflow in [`.github/workflows/`](.github/workflows/) that could be made to publish, leak a
  token, or run untrusted code from a fork;
- anything that would let a third party publish a gem named `magik`, or attach a trusted publisher
  to it — see [`PUBLISHING.md`](PUBLISHING.md);
- a dependency or an action pinned in a way that lets it change under us.

Out of scope: the *absence* of a security control in a framework subsystem that does not exist yet.
Those are design commitments, listed below, and the right place to challenge one is a discussion
about the spec ([`CONTRIBUTING.md`](CONTRIBUTING.md)).

## Security-relevant design commitments — all planned

From [`docs/idea/00-build-spec.md`](docs/idea/00-build-spec.md). **Every row is planned. None is
implemented, none has been reviewed, and none should be relied on.** They are here so you know what
to audit when they do land, and so that shipping one of them without the guarantee is visibly a
regression against a written commitment.

| Commitment | What it means | Status |
|---|---|---|
| **Tokenized payment fields, enforced at the type level** | `field :card_number` is not a declarable type. The framework refuses at boot rather than trusting a code review to catch raw PAN storage | planned |
| **Append-only ledgers** | `ledger` entries are immutable once written; debits and credits must balance or the app does not boot | planned |
| **Audit trails** | `audited` and `immutable_after:` model annotations produce an automatic, tamper-evident record of who changed what | planned |
| **Tenant scoping by default** | every model auto-scoped by `tenant_id`; `magik check --scale` warns on a query with no `tenant_id` predicate. Cross-tenant reads are the failure mode this is designed against | planned |
| **Signed webhooks, both directions** | incoming: `verify_signature` before any handler runs. Outgoing: `sign_with`, so a receiver can verify us | planned |
| **Idempotent mutations** | `idempotent_by` on actions, so a retried or replayed mutation cannot double-charge | planned |
| **Domain boundaries enforced at boot** | a domain reaching into another domain's models fails the boot, not a review | planned |
| **Stateless app servers** | no in-process session or UI state across requests, so no cross-request state can leak between users | planned |
| **Auth via Rodauth** | wrapped, not reimplemented. Magik does not intend to write its own password hashing, session handling or MFA | planned |

**No third-party security audit has been done, and there is nothing to audit yet.** When there is,
this section will say who did it and when.

## Known gaps

`As of 2026-08-26`: the entire framework. That is the honest answer while the repository is spec
only, and this section will be replaced with a real list — not deleted — once code exists.
