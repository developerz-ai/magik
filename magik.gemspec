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

  # Packaged files — an allowlist, not a reject list. A new top-level directory
  # in this repo cannot reach a published gem until it is named here.
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
  # `magik docs list` reads, so the catalogue can never advertise a page that
  # `gem build` left out. test/magik/docs_test.rb asserts the two agree.
  #
  # ## What ships, and what deliberately does not
  #
  # SHIPS — docs/**/*.md, wiki/**/*.md, llms.txt:
  #
  #   * wiki/ is the app author's reference manual. It is the whole point.
  #   * docs/idea/ carries the DSL surface, the guardrails and the limits, and
  #     docs/idea/00-build-spec.md is named verbatim by Magik::Error::DEFAULT_FIX
  #     and by every spec-only stub's NotImplementedError message. A `fix:` line
  #     pointing at a file the installed gem does not contain is a broken
  #     `fix:` line, and this repo's error convention forbids advice nobody can
  #     follow.
  #   * docs/architecture/ is contributor-facing and was considered for
  #     exclusion. It ships anyway, for two reasons: docs/README.md and several
  #     idea/ pages link into it with relative paths, and a shipped index whose
  #     links dangle is worse for a reader than one extra directory; and
  #     03-error-codes.md is the design of the MAGIK_* catalogue, which is the
  #     first thing anyone reads after hitting a code. "Not for you" is carried
  #     by Magik::Docs.pages[:audience] — which reports these pages as
  #     `framework`, and `magik docs list` groups them apart — not by the
  #     packaging. The cost is roughly 25 KB compressed.
  #
  # DOES NOT SHIP:
  #
  #   * .claude/ — subagents and slash commands for implementing *this
  #     framework* (bin/check, lib/magik/<subsystem>/). Dropped into a user's
  #     app they are confidently wrong. An app gets its own .claude/ from
  #     lib/magik/cli/templates/app/.claude/, which does ship.
  #   * CONTRIBUTING.md, PUBLISHING.md, ROADMAP.md, SECURITY.md,
  #     CODE_OF_CONDUCT.md, CLAUDE.md/AGENTS.md — this repository's process, not
  #     the DSL. llms.txt links to them with absolute raw.githubusercontent.com
  #     URLs, so nothing dangles by leaving them out.
  #   * dummy/ — the demonstration app: large, and the rule it demonstrates is
  #     already written down in wiki/Project-Layout.md.
  #   * test/, bin/, scripts/, docker/, .github/ — development machinery.
  #
  # The cost of this decision: a documentation change is now part of a release.
  # Editing wiki/ without cutting a version leaves every installed gem reading
  # the old page, which is the trade for never reading a page that does not
  # match the code.
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
  # page is in spec.files.
  gemspec_dir = __dir__
  doc_globs = defined?(Magik::Docs) ? Magik::Docs::PACKAGED_GLOBS : []
  packaged_globs = %w[exe/** lib/**/* sig/**/* README.md LICENSE CHANGELOG.md] + doc_globs
  candidates = Dir.glob(packaged_globs, File::FNM_DOTMATCH, base: gemspec_dir)

  # `git ls-files` is authoritative when the gem is built from a checkout: it
  # keeps untracked scratch files out of a release. Without git — an unpacked
  # tarball, or a tree with nothing committed yet — the allowlist stands alone.
  tracked =
    if File.directory?(File.join(gemspec_dir, ".git"))
      Dir.chdir(gemspec_dir) { IO.popen(%w[git ls-files -z], &:read).split("\x0") }
    else
      []
    end
  candidates &= tracked unless tracked.empty?

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
