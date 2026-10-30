# Reviewer instructions — developerz-ai/magik

> Read by the developerz.ai reviewer at EVERY review of this repository, at the reviewed
> commit, as this repo's own layer of the reviewer's prompt — established by dz-runner setup mode.
> It refines the platform rules (a finding is cited or withheld; the bot always discloses)
> and never overrides them. Edit freely; keep it under 12,000 characters — past that it is cut.

## Stack

Ruby + Bundler. The gate is `bin/check` (`PARALLEL_PROCESSOR_COUNT=2 bin/check`): a change that does not pass it is not proven, whatever its description says.

## Review conventions
- Require a concrete build-spec section for each change; reject invented framework surfaces without a spec amendment.
- Distinguish implemented CLI/documentation/error behavior from planned subsystem DSL; do not accept unsupported runtime claims.
- Require Minitest coverage and each specified boot guardrail in the same change as its feature.
- Enforce strictly downward subsystem imports using `apps/magik/scripts/lib/tiers.rb`; keep architecture tier tables consistent.
- Keep policy evaluation at tier 1, actor provisioning in auth at tier 3, and policy predicates free of queries and I/O.
- Preserve TruffleRuby production constraints, Sequel, stateless servers, tenant scoping, UUIDv7 and integer-cent money.
- Require stable MAGIK_* errors with concrete causes and runnable fixes, and YARD documentation for public APIs.
- Require tests proving backend swap points and preserve authorization as a single non-swappable evaluator.
- Follow the prescribed generated-app file layout and keep framework development tooling distinct from app templates.
- Require dependency rationale, an Unreleased changelog entry and corrections to status claims affected by implementation.
## Gates that matter
- Require `bin/check` as local proof; its seven steps cover RuboCop, Minitest, YARD and 100% documentation coverage, gem build, CLI JSON smoke, relative Markdown links and apps/magik/scripts/checks assertions.
- Treat focused `bin/check --only STEP` runs as debugging aids, not replacements for the full gate.
- Respect CI’s Ruby-engine matrix and installed-gem smoke test; do not infer TruffleRuby correctness from a local CRuby pass.
- Require the unconditional CI aggregator named `ci`; accept intentionally skipped area jobs but not failed or cancelled dependencies.
- Treat pre-commit as fast changed-file checks and pre-push as the complete gate.
- Keep external-link checks advisory while enforcing relative links locally.
## Never flag
- Do not demand RSpec, ActiveRecord, SPA frameworks, a client build step, offline support or forked workers.
- Do not flag explicit NotImplementedError subsystem stubs as accidental omissions or pretend the aspirational dummy app should boot.
- Do not apply this repository’s RuboCop rules to `apps/magik/dummy/` or generated-app templates excluded by `apps/magik/.rubocop.yml`.
- Do not require local TruffleRuby installation to run the supported CRuby tooling lane.
- Do not demand database services or dormant environment credentials for the current framework gate.
- Do not strip Markdown hard-line-break spaces or override formatter-owned style with personal preferences.
