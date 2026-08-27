# `scripts/` — this team's rules, as executable checks

## Why this directory exists

**When the developer is an agent, a convention that is not executable does not exist.**

A rule written in `CLAUDE.md` — *"always scope reports by `tenant_id`"*, *"never call the billing
API outside a job"*, *"every money column is integer cents"* — is advice. An agent may follow it on
feature #3, when the sentence is still near the top of the context, and quietly not on feature #40.
Nothing catches the difference. Nobody notices until the bug.

The same rule as a file in `scripts/checks/` is a **gate failure with a runnable `fix:` line**. It
holds on feature #40 exactly as well as on feature #3, it holds at 3am, and it holds for the
teammate who never read the document. It does not depend on anybody remembering anything.

That is the argument Magik already makes for its own boot-time guardrails — money, tenancy,
statelessness, domain boundaries, all refused at boot rather than in review. This directory hands
you the same mechanism for **your** rules, the ones the framework has no opinion about because they
are about your business and not about Ruby.

The loop it creates: **notice a convention → write the check → it is enforced from then on.**
`/feature` and `/check` run everything here on every change, so a rule you add today is a rule that
gates tomorrow's work without another conversation.

## The two directories

| Path | Is | Who owns it |
|---|---|---|
| `bin/` | the **verbs** a human or agent runs: `setup`, `check`, `dev`, `console`, `test`, `magik`. Stable, few, framework-provided | the framework — `magik generate agents --update` replaces them |
| `scripts/checks/` | **your rules**, one file each, discovered and run by `bin/check` | **you.** No magik command ever touches this directory |
| `scripts/lib/scripts.rb` | the base class, the result shape, discovery and the runner | the framework — replaced on update |

You extend the gate by **adding a check**, never by editing `bin/check`. That is what the discovery
glob is for, and it is why `bin/check` can be replaced wholesale without losing your work.

## Writing one

A check is a short file. Copy the nearest existing one and change the rule.

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# @check   tenant-scoping
# @summary Every report query narrows by tenant_id.
# @order   40
#
# Everything from here to the end of the comment block is the check's `--help`
# text. Say what it asserts, name the codes it raises, and say when it is not
# applicable.

require_relative "../lib/scripts"

module AppScripts
  module Checks
    class TenantScoping < Check
      # The PURE rule: data in, findings out. This is what a test exercises.
      def self.findings_for(sources)
        sources.filter_map do |path, body|
          next if body.include?("for_tenant")

          Finding.new(code: "APP_TENANT_SCOPE_MISSING", at: path,
                      cause: "#{path} queries without a tenant predicate",
                      fix: "add `.for_tenant` to the scope in #{path}")
        end
      end

      # The THIN half: read the real tree, hand it to the rule.
      def run
        paths = Root.glob("app/screens/*.rb")
        return not_applicable(because: "no screens yet", expected: expectation) if paths.empty?

        findings = self.class.findings_for(paths.to_h { |rel| [rel, Root.read(rel)] })
        return failure(reason: "unscoped_query", expected: expectation,
                       fix: "ruby scripts/checks/tenant_scoping.rb", findings: findings) if findings.any?

        ok(expected: expectation, got: "#{paths.size} screens scanned")
      end

      private

      def expectation = "every screen's state narrows by tenant_id"
    end
  end
end

exit AppScripts::Runner.main(__FILE__, AppScripts::Checks::TenantScoping) if $PROGRAM_NAME == __FILE__
```

### The five rules

1. **The header is the contract.** `@check`, `@summary`, `@order` are read by discovery without
   loading your Ruby, so `bin/check --list` works even when a check is syntactically broken. The
   name is lowercase-hyphenated and the file is the same name with underscores. A missing header is
   a hard error, never a skip — a check that quietly drops out of discovery is a check that stopped
   gating.
2. **Split the pure rule from the collector.** The class method that takes data and returns findings
   is what a test exercises with fixtures; `#run` is the thin half that reads the tree. **A rule that
   can only be tested by breaking the app has no negative case**, which means nobody ever proves it
   fires.
3. **Every finding carries a runnable `fix:`.** A command, never advice. An agent can run a command;
   it has to interpret a suggestion, and interpreting is where it guesses.
4. **`not_applicable` is for a precondition that is absent by design** — a flat app has no
   `domains/`, a new app has no migrations. It is a pass and it says why. A glob that *should* have
   matched and came back empty is a **failure**: the day somebody moves a directory, a check that
   says "pass, 0 files" goes quiet instead of red.
5. **Requiring the file must not run it.** Guard the entry point with
   `if $PROGRAM_NAME == __FILE__` so a test can load the class.

## Running them

```bash
ruby scripts/checks/i18n_coverage.rb          # one check, human output
ruby scripts/checks/i18n_coverage.rb --json   # one JSON object on stdout, nothing else
ruby scripts/checks/i18n_coverage.rb --help   # its header, verbatim
bin/check                                     # all of them, plus lint, tests and magik check
bin/check --list                              # what exists
bin/check --only i18n-coverage                # one step through the gate
```

Exit status is the same for a check run alone and the same check run through the gate, so a script
never has to parse words:

| Code | Means |
|---|---|
| `0` | satisfied |
| `1` | the app is wrong — the findings say where |
| `64` | bad usage (`EX_USAGE`): an unknown flag |
| `69` | a tool the check needs is not installed (`EX_UNAVAILABLE`). Nothing is broken; run the install command it printed |

## What ships here, and why these three

Three working examples, chosen because each catches a real bug class and each demonstrates a
different shape. Delete any you do not want — they are yours the moment they exist.

| Check | Catches | Demonstrates |
|---|---|---|
| `domain_boundaries` | a domain reaching into another's models with no `exposes` | a rule over a **declared graph**, and `not_applicable` for a flat app |
| `i18n_coverage` | a `t("…")` key that renders as a raw key on a customer's screen | a rule joining **two corpora** — code and locale files |
| `migration_safety` | a `drop_column` nobody decided on, and two migrations claiming one ordinal | a rule that accepts an **explicit acknowledgement**, rather than forbidding |

## The framework's own

The magik repository has the same directory with the same contract, checking the framework instead
of an app. If you have it checked out, read it — the shapes are identical, and its checks are
worked examples of harder rules:
<https://github.com/developerz-ai/magik/tree/main/scripts>

## Honest status

`bin/check` runs the checks in this directory **today**: they are plain Ruby over plain files and
need no framework. `magik check` and `magik test` are steps in the same gate and are **not
implemented** — `bin/check` reports them as `MISSING` and exits `69` rather than pretending. Run
`magik version --json` for which world you are in.
