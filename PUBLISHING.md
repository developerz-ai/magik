# Publishing

How a Magik release is cut and how it reaches RubyGems.

`As of 2026-08-26` **nothing has been published.** `0.0.1` is prepared and not pushed. Read the
registry rather than this sentence:

```sh
gem list -r magik --all     # every version RubyGems serves. Empty output means nothing is published
gem info magik -r           # version, homepage, licence and authors, as the registry has them
```

`bin/release` is the pre-flight for everything below. **It prints and never publishes** — it checks
the version, the changelog, the tag and the gate, then hands you the commands to paste:

```sh
bin/release          # the checks, then the commands
bin/release --json   # the same verdicts as data
```

## One gem, one version — nothing to keep in lockstep

Magik is **a single gem** with subsystem modules under `lib/magik/<subsystem>/`. No multi-package
lockstep, no per-package version, no publish ordering: one version, one commit, one tag, one `.gem`.

**The version is stamped in exactly one place** — [`lib/magik/version.rb`](lib/magik/version.rb):

```ruby
module Magik
  VERSION = "0.0.1"
end
```

`magik.gemspec` reads it. Nothing else states a version: a version written into a README, a doc page
or a workflow is a bug, and every one of them names a command instead.

| Fact | Read it yourself |
|---|---|
| what this tree is stamped at | `ruby -Ilib -e 'require "magik/version"; puts Magik::VERSION'` |
| what the CLI answers | `ruby -Ilib exe/magik version --json` |
| what RubyGems serves | `gem list -r magik --all` · `gem info magik -r` |
| who may push | `gem owner magik` |
| what a built gem actually contains | `gem contents magik --version <version>` after `rake build` |
| the tag is annotated **and on the remote** | `git ls-remote --tags origin 'refs/tags/v<version>*'` — you need both the ref and its peeled `^{}` line |
| the GitHub Release exists | `gh release view v<version> --json tagName,isDraft,publishedAt` |

## Cutting a release

1. **Write the notes as the change lands.** `## [Unreleased]` in [`CHANGELOG.md`](CHANGELOG.md) *is*
   the release notes. A release with an empty `[Unreleased]` should not be cut.
2. **Bump [`lib/magik/version.rb`](lib/magik/version.rb).** For a prerelease use RubyGems' dotted
   form — `0.1.0.rc1`, never `0.1.0-rc1`.
3. **Promote the changelog section**: rename `## [Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD`, open a
   fresh empty `## [Unreleased]` above it, and update the link definitions at the foot of the file.
   The heading must contain the version exactly — the release notes are lifted from it.
4. **`bin/release`** — it refuses on a dirty tree, a missing changelog section, a version that is
   already tagged, or a red gate, and prints the remaining commands when it passes.
5. **`bin/check`** — green, on the commit you are about to tag.
6. **Commit**: `release: X.Y.Z`.
7. **Tag, annotated**, and push:

   ```sh
   git tag -a vX.Y.Z -m "X.Y.Z"
   git push origin main
   git push origin vX.Y.Z
   ```

   **The tag must be annotated.** `git push --follow-tags` pushes annotated tags only — it will push
   your commit, say nothing, and leave a lightweight `git tag vX.Y.Z` on your machine, after which
   the GitHub Release cannot be created against a ref the remote does not have. `git tag -a` is the
   only form written in this file, for that reason.
8. **Publish a GitHub Release** for that tag, with the changelog section as the body. **Publishing
   the Release is what triggers the publish** — [`.github/workflows/release.yml`](.github/workflows/release.yml)
   runs on a published Release, not on a tag push and not on a branch.
9. **Verify the registry**, rather than trusting a green tick:

   ```sh
   gem list -r magik --all
   gem info magik -r
   ```

### The tag convention

`vX.Y.Z` — a leading `v`, **annotated**, one per release, never moved and never deleted. `v0.0.1` is
the first. A prerelease is dotted for RubyGems and hyphenated for git: version `0.1.0.rc1`, tag
`v0.1.0-rc1`.

## MFA is required, and the gemspec enforces it

`magik.gemspec` sets `spec.metadata["rubygems_mfa_required"] = "true"`. RubyGems then **refuses a
push from an account without MFA**, including a future compromised one. Set the account's MFA level
to *UI and API* on rubygems.org (Settings → Multifactor authentication) so an API key alone cannot
push.

Consequences worth knowing before you are mid-release:

- `gem signin` prompts for an OTP.
- `gem push` prompts for an OTP **at push time**, not at sign-in. Non-interactively:
  `gem push <file> --otp <code>`.
- An OTP is valid for about 30 seconds. Generate it when the prompt appears, not before.

## The automated path: trusted publishing (OIDC)

**The target state.** [`.github/workflows/release.yml`](.github/workflows/release.yml) authenticates
as the repository through GitHub's OIDC identity and RubyGems mints a short-lived credential for
that run. **No long-lived `GEM_HOST_API_KEY` is stored in this repository, and none should be
added** — a token in a secret is exactly what trusted publishing exists to remove. The workflow
needs `permissions: id-token: write` for the exchange.

**It cannot publish the first version.** A trusted publisher is attached to a gem that already
exists on RubyGems, so there is nothing to attach one to until `magik` is on the registry. Hence the
bootstrap below.

## One-time bootstrap: publishing 0.0.1 by hand

Once, by an owner. **Every release after it goes through the workflow.** This is the whole reason
`0.0.1` exists as a release: it reserves the name and creates the record a trusted publisher can
then be attached to.

The three steps are the ones wurk wraps as `bin/gem-build`, `bin/gem-login` and `bin/gem-push`;
Magik runs them directly until it needs the wrappers.

### 1. Sign in as an owner (once per machine)

```sh
gem signin        # rubygems.org email, password, and the OTP from your authenticator
chmod 600 ~/.gem/credentials
```

The cached key lives in `~/.gem/credentials`. Keep it out of the repository; it is not needed for
any later release.

### 2. Build, then push

```sh
bin/check                      # green, on the tagged commit
rake build                     # gem build magik.gemspec → magik-0.0.1.gem
gem push magik-0.0.1.gem       # prompts for an OTP; or: --otp <code>
```

Then confirm the registry has it. Propagation can lag the push by a minute or two, so an immediate
404 is not a failure:

```sh
gem list -r magik --all
gem info magik -r
gem owner magik
```

### 3. Attach the trusted publisher

On rubygems.org: **the gem's page → Trusted Publishers → add a GitHub Actions publisher**:

| Field | Value |
|---|---|
| Repository owner | `developerz-ai` |
| Repository name | `magik` |
| Workflow filename | `release.yml` |
| Environment | the environment name declared in `release.yml`, or blank if it declares none |

**Set the environment if the workflow declares one, and leave it blank if it does not** — the two
must match exactly or the OIDC exchange is refused. A blank field means RubyGems accepts a token
minted by *any* run of `release.yml`, whatever job produced it and whatever approval it did or did
not pass; a populated one is the registry refusing a token from outside the approval gate, which is
the half GitHub cannot enforce on its own.

### 4. Confirm nothing here is ever needed again

Steps 1–3 are **once per gem, ever**, and are not part of a normal release. Afterwards:

- no credential is needed on any machine to cut a release;
- nobody runs `gem push` by hand again;
- the flow is: bump → `bin/release` → tag → publish the GitHub Release → verify the registry.

**A hand push after this point is a mistake, not a shortcut**: it skips the gate, skips the
approval, and produces a version nobody reviewed. If a release genuinely cannot go through the
workflow, fix the workflow. The one legitimate exception is a `gem push` performed as an
out-of-band fallback while CI is unavailable — do it, then say so in the changelog entry.

## What is in the gem

[`magik.gemspec`](magik.gemspec) derives `files` from `git ls-files` and then rejects `test/`,
`bin/`, `dummy/`, `examples/`, `doc/`, `wiki/` and the dotfiles, adding back `README.md`, `LICENSE`
and `CHANGELOG.md`. A consumer's `bundle install` gets `lib/`, `exe/` and those three files, and
nothing else.

Verify what a build actually contains before pushing anything — the allowlist is only as good as
its last edit:

```sh
rake build
tar -xOf magik-<version>.gem data.tar.gz | tar -tzf - | sort
```

## Yanking

**Don't.** Yanking breaks every `Gemfile.lock` that already resolved the version, and the number can
never be reused — RubyGems refuses a re-push of a version that has existed. Ship a patch instead. If
a version is genuinely dangerous, yank it *and* publish the replacement in the same hour, say so in
[`CHANGELOG.md`](CHANGELOG.md), and if it is a vulnerability, file a
[security advisory](SECURITY.md).

```sh
gem yank magik -v X.Y.Z     # last resort, with MFA
```

## Checklist

Approving a release *is* the review. Check what a reviewer would:

| Check | Command | Answer that means go |
|---|---|---|
| the pre-flight is clean | `bin/release --json` | every check `ok` |
| the tree is stamped at the tag's version | `ruby -Ilib -e 'require "magik/version"; puts Magik::VERSION'` | equals the tag, minus the `v` |
| the gate is green on that commit | `bin/check` · `gh run list --branch main --limit 1` | `success` |
| the changelog section exists and is dated | `grep -n '^## ' CHANGELOG.md` | a section for this version |
| the tag is annotated and on the remote | `git ls-remote --tags origin 'refs/tags/vX.Y.Z*'` | the ref **and** its peeled `^{}` line |
| the Release is published, not a draft | `gh release view vX.Y.Z --json isDraft,publishedAt` | `isDraft: false` |
| the registry agrees, afterwards | `gem list -r magik --all` | the new version is listed |
