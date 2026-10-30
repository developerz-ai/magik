# frozen_string_literal: true

# `lib/` on the load path, so `Magik::Docs` resolves through the same autoload
# the gem itself uses. spec.files below is derived from Magik::Docs::PACKAGED_GLOBS.
$LOAD_PATH.unshift(File.expand_path("lib", __dir__))

require "magik/version"
require "magik/docs"

Gem::Specification.new do |spec|
  spec.name = "magik"
  spec.version = Magik::VERSION
  spec.authors = ["developerz.ai"]
  spec.email = ["admin@developerz.ai"]

  spec.summary = "An opinionated, full-stack Ruby framework for TruffleRuby — one DSL for the whole app."
  spec.description = <<~DESC
    Magik is a full-stack Ruby framework designed for TruffleRuby: one DSL for models,
    screens, actions, realtime channels, background jobs, ledgers, APIs and admin panels.
    The server renders HTML and htmx handles interactivity — there is no separate frontend
    framework, no offline mode, and no heavy client-side compute.

    Status as of 2026-08-26: this is a name-reservation release. The specification lives in
    docs/idea/00-build-spec.md and is entirely unimplemented. What ships today is the gem
    skeleton, the MAGIK_* error-code convention, a `magik version` / `magik help` CLI, and
    one documented, spec-only stub module per planned subsystem. Nothing renders a page,
    connects to a database, or runs a job yet.
  DESC

  spec.homepage = "https://github.com/developerz-ai/magik"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/developerz-ai/magik",
    "changelog_uri" => "https://github.com/developerz-ai/magik/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://developerz-ai.github.io/magik/api/",
    "bug_tracker_uri" => "https://github.com/developerz-ai/magik/issues",
    "rubygems_mfa_required" => "true"
  }

  # Packaged files — an allowlist, not a reject list, and bounded to the gem's
  # own directory (apps/magik): a new file here cannot reach a published gem
  # until it is named below, and any candidate that would resolve outside the
  # gem dir is dropped outright, so a glob aimed at the repository root can
  # never leak into the package. README.md, LICENSE, CHANGELOG.md and the
  # repo-root docs/ trees stay out — they live at the checkout root, two
  # levels above this file — with one deliberate exception: the generated
  # build-spec mirror, docs/idea/00-build-spec.md, named below.
  #
  # ## Why the documentation ships inside the gem
  #
  # Magik invents a DSL — `model`, `screen`, `action`, `ledger`, `channel`,
  # `flow` — that no language model has in its training data. An agent asked to
  # write Magik code without the reference in front of it reconstructs a
  # Rails-shaped API from memory, confidently and wrongly, every time. Fetching
  # the reference over the network instead is slow, rate-limited, and
  # **version-blind**: it returns whatever is on `main`, not what this gem does.
  # An installed gem carrying its own manual is version-matched by construction,
  # and `magik docs path` hands an agent a directory its ordinary grep and glob
  # tools can read. See docs/architecture/09-shipped-docs.md.
  #
  # The glob list lives in Magik::Docs::PACKAGED_GLOBS, which is also what
  # `magik docs list` reads, so an INSTALLED gem's catalogue can never offer
  # a page that `gem build` left out. A checkout catalogue is wider by
  # design: the ../../ spelling also serves the repo-root trees, which the
  # package excludes. test/magik/docs_test.rb asserts the packaging split.
  #
  # ## What ships, and what deliberately does not
  #
  # SHIPS — exe/**, lib/**/*, sig/**/*, llms.txt, wiki/**/*.md, and the
  # generated build-spec mirror docs/idea/00-build-spec.md:
  #
  #   * wiki/ is the app author's reference manual. It is the whole point of
  #     shipping docs at all: an installed gem that carries its own manual is
  #     version-matched by construction, and `magik docs path` hands an agent
  #     a directory its ordinary grep and glob tools can read.
  #   * llms.txt is the machine-readable page map the catalogue routes from.
  #   * docs/idea/00-build-spec.md is a GENERATED mirror of the checkout's
  #     docs/idea/00-build-spec.md — scripts/checks/build_spec_mirror.rb
  #     renders it from the original and fails the gate when stale. The path
  #     is not a nice-to-have: Magik::Error::DEFAULT_FIX and every spec-only
  #     stub's NotImplementedError message name it, and an installed gem has
  #     no repository two levels up for that path to resolve against, so
  #     without the mirror the recovery instruction in every error is
  #     unusable exactly where errors are handled. The mirror carries the
  #     original verbatim, with links rewritten to absolute repository URLs
  #     so they resolve from an installed gem's filesystem.
  #
  # STAYS AT THE REPOSITORY ROOT — never packaged:
  #
  #   * the REST of docs/idea/ and docs/architecture/, and docs/ops/ — the
  #     DSL surface, the guardrails, the architecture notes. They are the
  #     design record of *this repository* and live two levels above this
  #     gemspec, outside the gem dir. A checkout catalogue still serves them:
  #     PACKAGED_GLOBS carries the ../../docs/**/*.md spelling, which
  #     resolves in a checkout and is dropped here by the "../" reject below
  #     — so an installed gem neither ships nor advertises those pages.
  #     docs_test asserts the split.
  #   * CONTRIBUTING.md, PUBLISHING.md, ROADMAP.md, SECURITY.md,
  #     CODE_OF_CONDUCT.md, CLAUDE.md/AGENTS.md — this repository's process,
  #     not the DSL.
  #
  # Shipped pages never carry a relative link that leaves the gem dir: links
  # to repository-only pages are absolute repository URLs (the mechanism
  # llms.txt already used), and scripts/checks/shipped_links.rb fails the
  # gate on any relative link in a packaged page that resolves outside the
  # gem dir or to an unpackaged file — "nothing dangles" is an assertion, not
  # a claim.
  #   * .claude/ — subagents and slash commands for implementing *this
  #     framework* (bin/check, lib/magik/<subsystem>/). Dropped into a user's
  #     app they are confidently wrong. An app gets its own .claude/ from
  #     lib/magik/cli/templates/app/.claude/, which does ship.
  #   * dummy/ — the demonstration app: large, and the rule it demonstrates is
  #     already written down in wiki/Project-Layout.md, which ships.
  #   * test/, bin/, scripts/, docker/, .github/ — development machinery.
  #
  # The cost of this decision: a documentation change is now part of a release.
  # Editing wiki/ without cutting a version leaves every installed gem reading
  # the old page, which is the trade for never reading a page that does not
  # match the code. The build-spec mirror carries the same cost with a guard:
  # editing the original without rerunning
  # `ruby apps/magik/scripts/checks/build_spec_mirror.rb --write` fails the
  # checks step. The repo-root docs/ trees do not carry that cost — from a
  # checkout they are one ../../ step away, and MAGIK_DOCS_ROOT can point a
  # catalogue at any checkout.
  #
  # `defined?` rather than a bare constant, and this is not defensive noise:
  # Dependabot evaluates this gemspec with every `require` REWRITTEN AWAY. Its
  # Bundler sanitizer replaces `require` and `require_relative` calls with `nil`
  # before it evals the file, so `require "magik/docs"` above never runs there
  # and the reference below raised `uninitialized constant Magik` — which is
  # what turned every Dependabot update on this repo into
  # `dependency_file_not_evaluatable`. Guarded rather than inlined: the glob
  # list has exactly one home, lib/magik/docs.rb, and a second copy here is a
  # second thing to keep in sync. The fallback packages no documentation, which
  # is only ever reached by a dependency resolver reading spec.files it will
  # never install — and a real build that somehow took this branch goes red in
  # test/magik/docs_test.rb, which loads THIS file and asserts every catalogued
  # page inside the gem dir is in spec.files.
  gemspec_dir = __dir__
  doc_globs = defined?(Magik::Docs) ? Magik::Docs::PACKAGED_GLOBS : []
  packaged_globs = %w[exe/** lib/**/* sig/**/*] + doc_globs
  candidates = Dir.glob(packaged_globs, File::FNM_DOTMATCH, base: gemspec_dir)

  # PACKAGED_GLOBS carries "../../docs/**/*.md" for a checkout's catalogue. An
  # installed gem has no repository above it — drop every candidate that would
  # resolve outside the gem dir, so spec.files can never carry a "../" path.
  candidates = candidates.reject { |path| path.start_with?("../") }

  # `git ls-files` is authoritative when the gem is built from a checkout (the
  # repository's .git lives at the checkout root, two levels above this
  # gemspec): it keeps ignored scratch files out of a release.
  # `--cached --others --exclude-standard` — tracked files plus untracked,
  # un-ignored ones — because a packaged page can be NEW in the working tree:
  # the build-spec mirror is generated in place, and a gate run on the dirty
  # tree must see it in spec.files or the packaging tests would read a file
  # list the built gem will not have. Without git — an unpacked tarball, or a
  # tree with nothing committed yet — the allowlist stands alone.
  checkout_root = File.expand_path("../..", gemspec_dir)
  git_files =
    if File.directory?(File.join(checkout_root, ".git"))
      Dir.chdir(gemspec_dir) do
        IO.popen(%w[git ls-files --cached --others --exclude-standard -z], &:read).split("\x0")
      end
    else
      []
    end
  candidates &= git_files unless git_files.empty?

  spec.files = candidates.reject do |path|
    path.empty? || File.directory?(File.join(gemspec_dir, path))
  end.uniq.sort

  spec.bindir = "exe"
  spec.executables = ["magik"]
  spec.require_paths = ["lib"]

  # Runtime dependencies: none, deliberately.
  #
  # The boilerplate loads nothing but the Ruby standard library (json, optparse,
  # pathname). Declaring a dependency the code does not require would be a lie
  # about what is wired up.
  #
  # Intended wrap-targets, per docs/idea/00-build-spec.md ("Libraries to Wrap"),
  # to be added one at a time as the phase that needs them lands:
  #
  #   sequel      — DB layer                      (Phase 1: model, schema)
  #   puma        — Rack server, thread/request   (Phase 1: core, router)
  #   money       — currency support              (Phase 1: :money type)
  #   que         — Postgres-backed job queue     (Phase 4: jobs)
  #   shrine      — uploads, S3                   (Phase 4b: media)
  #   mux et al.  — video/audio, behind use :media (Phase 4b: media)
  #   prawn       — PDF generation                (Phase 8: notify)
  #   pgvector    — vector search                 (Phase 6: api)
  #   rodauth     — authentication                (Phase 7: auth)
  #   stripe/paddle SDKs — billing                (Phase 7: billing)
  #   anthropic/openai SDKs — AI actions          (no phase assigned yet)
  #   opentelemetry-* — observability             (cross-cutting)
  #   minitest    — test core                     (Phase 9: testing)
  #
  # JSON is a seam rather than a fixed dependency (`use :json, :auto | :oj |
  # :stdlib`): the fast path is engine-dependent, and the C-extension
  # alternatives do not name TruffleRuby as a supported platform. See
  # docs/architecture/10-performance-defaults.md.
  #
  # htmx (~14kb) is vendored as a static asset, not a gem.
  #
  # Runtime target is TruffleRuby; CRuby >= 3.2 is supported for tooling and
  # development. TruffleRuby-specific checks run in CI, not on dev machines.
end
