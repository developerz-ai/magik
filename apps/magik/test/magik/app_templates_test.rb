# frozen_string_literal: true

require "erb"
require "json"
require "test_helper"

# Coverage for `lib/magik/cli/templates/app/` — the files `magik new` will copy
# into a generated application.
#
# `magik new` is **planned and not implemented**, so nothing here asserts that a
# generator works. What it asserts is everything that is true of the templates
# themselves today: the manifest matches the directory, every ERB parses and
# renders, the JSON parses, the frontmatter is present, the ownership markers
# are balanced, and no template ships a secret or a false claim.
#
# Runs on bare Ruby with no bundler.
class MagikAppTemplatesTest < Minitest::Test
  ROOT = File.expand_path("../../lib/magik/cli/templates/app", __dir__)

  # A manifest row. See lib/magik/cli/templates/app/MANIFEST.
  Row = Struct.new(:source, :mode, :destination, :on_update)

  # The context `magik new` will render each ERB template against. Its member
  # list is the documented variable set, and a template referencing anything
  # else raises NameError here rather than writing a blank into a user's repo.
  Context = Struct.new(
    :app_name, :app_class, :app_title, :magik_version,
    :generated_on, :layout, :ruby_version, :database_url, :declarations
  ) do
    def render_binding = binding
  end

  MODES = %w[erb copy copy-exec symlink none].freeze
  ON_UPDATE = %w[replace merge-blocks never -].freeze

  # Files whose emitted text must state plainly that the framework does not run.
  HONESTY_REQUIRED = %w[CLAUDE.md.erb README.md.erb llms.txt.erb docs/PLAN.md.erb].freeze

  # Files that carry the framework/project ownership split. The marker text is
  # the same everywhere; only the comment syntax around it changes.
  BLOCKED_FILES = %w[
    CLAUDE.md.erb llms.txt.erb docs/FEATURE.md.erb
    .gitignore.erb Gemfile.erb Rakefile.erb
  ].freeze

  # Templates that must be written executable, with a shebang.
  EXECUTABLE_MODE = "copy-exec"

  # The RuboCop base that ships inside the gem and is `inherit_gem`-ed by every
  # generated app, rather than copied into it.
  GEM_RUBOCOP = File.expand_path("../../lib/magik/cli/templates/rubocop.yml", __dir__)

  # Files that must carry the "not bootstrapped yet" sentinel and name the
  # command that clears it.
  SENTINEL_FILES = %w[CLAUDE.md.erb README.md.erb docs/PLAN.md.erb docs/ARCHITECTURE.md.erb llms.txt.erb].freeze

  SENTINEL = "<!-- magik:stage2-pending -->"
  STAGE_TWO_COMMAND = "/setup-project"

  # --- helpers -------------------------------------------------------------

  def manifest_rows
    @manifest_rows ||= File.readlines(File.join(ROOT, "MANIFEST")).filter_map do |line|
      next if line.strip.empty? || line.lstrip.start_with?("#")

      Row.new(*line.split)
    end
  end

  def on_disk
    Dir.glob("**/*", File::FNM_DOTMATCH, base: ROOT)
       .reject { |path| [".", ".."].include?(File.basename(path)) }
       .reject { |path| File.directory?(File.join(ROOT, path)) }
       .sort
  end

  def emitted_rows = manifest_rows.reject { |row| row.mode == "none" }

  def read(relative) = File.read(File.join(ROOT, relative))

  def context(layout: :flat, declarations: {})
    Context.new(
      "myapp", "Myapp", "Myapp", Magik::VERSION, "2026-08-26",
      layout, "3.2", "postgres://magik:magik@localhost:5432/myapp_development", declarations
    )
  end

  def render(relative, **)
    ERB.new(read(relative), trim_mode: "-").result(context(**).render_binding)
  end

  def frontmatter(relative)
    body = read(relative)
    return nil unless body.start_with?("---\n")

    closing = body.index("\n---\n", 3)
    return nil unless closing

    body[4...(closing + 1)].lines.each_with_object({}) do |line, fields|
      key, separator, value = line.partition(":")
      next if separator.empty?

      fields[key.strip] = value.strip
    end
  end

  def agent_sources = manifest_rows.map(&:source).grep(%r{\A\.claude/agents/.+\.md\z}).sort
  def command_sources = manifest_rows.map(&:source).grep(%r{\A\.claude/commands/.+\.md\z}).sort

  # --- the manifest is the contract ----------------------------------------

  def test_manifest_rows_are_well_formed
    refute_empty manifest_rows

    manifest_rows.each do |row|
      assert_equal 4, row.to_a.compact.size, "#{row.source}: expected 4 columns"
      mode = row.mode.split(":").first

      assert_includes MODES, mode, "#{row.source}: unknown mode #{row.mode.inspect}"
      assert_includes ON_UPDATE, row.on_update, "#{row.source}: unknown on-update #{row.on_update.inspect}"
    end
  end

  def test_every_template_on_disk_is_registered
    registered = manifest_rows.map(&:source).sort
    unregistered = on_disk - registered

    assert_empty unregistered,
                 "add these to lib/magik/cli/templates/app/MANIFEST: #{unregistered.join(", ")}"
  end

  def test_every_registered_source_exists
    missing = manifest_rows.map(&:source).reject { |source| File.file?(File.join(ROOT, source)) }

    assert_empty missing, "MANIFEST names files that do not exist: #{missing.join(", ")}"
  end

  def test_sources_and_destinations_are_unique
    sources = manifest_rows.map(&:source)

    assert_equal sources.uniq, sources

    destinations = emitted_rows.map(&:destination)

    assert_equal destinations.uniq, destinations
  end

  def test_developer_facing_files_are_never_emitted
    manifest_rows.select { |row| row.mode == "none" }.each do |row|
      assert_equal "-", row.destination, "#{row.source} is mode none and must have no destination"
      assert_equal "-", row.on_update, "#{row.source} is mode none and cannot be updated"
    end

    assert_includes manifest_rows.select { |row| row.mode == "none" }.map(&:source), "README.md"
  end

  def test_destinations_stay_inside_the_generated_app
    emitted_rows.each do |row|
      refute row.destination.start_with?("/"), "#{row.destination} is absolute"
      refute_includes row.destination.split("/"), "..", "#{row.destination} escapes the app root"
      refute_equal "-", row.on_update, "#{row.source} is emitted and needs an on-update rule"
    end
  end

  def test_only_marked_files_may_be_block_merged
    merged = emitted_rows.select { |row| row.on_update == "merge-blocks" }.map(&:source).sort

    assert_equal BLOCKED_FILES.sort, merged
  end

  # --- ERB ------------------------------------------------------------------

  def test_every_erb_template_parses
    sources = manifest_rows.map(&:source).select { |source| source.end_with?(".erb") }

    refute_empty sources

    sources.each do |source|
      ERB.new(read(source), trim_mode: "-").src # raises SyntaxError on a malformed template
    end
  end

  def test_every_erb_template_renders_for_both_layouts
    declarations = {
      domains: %w[Billing Identity], models: %w[Invoice Customer],
      screens: %w[Invoices], actions: %w[mark_paid], ledgers: %w[Receivables]
    }

    manifest_rows.map(&:source).select { |source| source.end_with?(".erb") }.each do |source|
      %i[flat domains].each do |layout|
        output = render(source, layout: layout, declarations: layout == :flat ? {} : declarations)

        refute_empty output.strip, "#{source} rendered empty for #{layout}"
        refute_includes output, "<%", "#{source} left an unrendered ERB tag for #{layout}"
      end
    end
  end

  def test_the_app_name_reaches_the_generated_files
    assert_includes render("CLAUDE.md.erb"), "App.define :Myapp"
    assert_includes render("README.md.erb"), "# Myapp"
    assert_includes render("llms.txt.erb"), "# Myapp"
  end

  def test_the_layout_flag_changes_what_is_written
    flat = render("CLAUDE.md.erb", layout: :flat)
    domained = render("CLAUDE.md.erb", layout: :domains)

    refute_equal flat, domained
    assert_includes flat, "This app is **flat**"
    assert_includes domained, "domains/<name>/domain.rb"
  end

  # --- JSON -----------------------------------------------------------------

  def test_settings_json_parses_and_has_both_lists
    settings = JSON.parse(read(".claude/settings.json"))
    permissions = settings.fetch("permissions")

    assert_kind_of Array, permissions.fetch("allow")
    assert_kind_of Array, permissions.fetch("deny")
    refute_empty permissions["allow"]
    refute_empty permissions["deny"]
    assert_equal "acceptEdits", permissions.fetch("defaultMode")
  end

  def test_the_allowlist_never_covers_a_destructive_command
    allow = JSON.parse(read(".claude/settings.json")).dig("permissions", "allow")

    ["db drop", "db reset", "git push", "git commit", "rm -rf", "gem push", "master.key"].each do |forbidden|
      offenders = allow.select { |rule| rule.include?(forbidden) }

      assert_empty offenders, "allowlist covers #{forbidden.inspect}: #{offenders.join(", ")}"
    end
  end

  def test_the_denylist_covers_the_destructive_and_the_secret
    deny = JSON.parse(read(".claude/settings.json")).dig("permissions", "deny")

    ["magik db drop", "magik db reset", "git push --force", "git reset --hard",
     "config/master.key", "credentials.yml.enc", "db/schema.rb"].each do |required|
      assert deny.any? { |rule| rule.include?(required) }, "denylist is missing #{required.inspect}"
    end

    %w[Read Write Edit].each do |tool|
      assert_includes deny, "#{tool}(**/.env)"
    end
  end

  def test_the_committed_env_example_stays_readable
    deny = JSON.parse(read(".claude/settings.json")).dig("permissions", "deny")

    # `.env.example` is committed, safe and something an agent needs. A blanket
    # `**/.env.*` deny would lock it away with the real secrets.
    offenders = deny.select { |rule| rule.include?(".env.*)") }

    assert_empty offenders, "these deny rules also block .env.example: #{offenders.join(", ")}"
  end

  def test_magik_docs_is_allowed_because_it_is_the_one_command_that_works
    allow = JSON.parse(read(".claude/settings.json")).dig("permissions", "allow")

    assert_includes allow, "Bash(magik docs:*)"
  end

  # --- markdown frontmatter -------------------------------------------------

  def test_every_agent_declares_name_description_and_tools
    refute_empty agent_sources

    agent_sources.each do |source|
      fields = frontmatter(source)

      refute_nil fields, "#{source} has no frontmatter"
      %w[name description tools].each do |key|
        refute_nil fields[key], "#{source} frontmatter is missing #{key}:"
        refute_empty fields[key], "#{source} frontmatter has an empty #{key}:"
      end
      assert_equal File.basename(source, ".md"), fields["name"],
                   "#{source}: the frontmatter name must match the filename"
    end
  end

  def test_every_command_declares_a_description_and_its_tools
    refute_empty command_sources

    command_sources.each do |source|
      fields = frontmatter(source)

      refute_nil fields, "#{source} has no frontmatter"
      refute_nil fields["description"], "#{source} frontmatter is missing description:"
      refute_nil fields["allowed-tools"], "#{source} frontmatter is missing allowed-tools:"
    end
  end

  def test_the_reviewer_cannot_write
    tools = frontmatter(".claude/agents/guardrail-reviewer.md")["tools"]

    # A reviewer that can fix what it finds stops reporting what it found.
    refute_includes tools, "Write"
    refute_includes tools, "Edit"
  end

  def test_the_roster_in_claude_md_matches_the_manifest
    rendered = render("CLAUDE.md.erb")

    agent_sources.each do |source|
      assert_includes rendered, File.basename(source, ".md")
    end

    command_sources.each do |source|
      assert_includes rendered, "/#{File.basename(source, ".md")}"
    end
  end

  # Agents are scoped by file set and must *tile* the app tree: every directory
  # a declaration can land in has exactly one owner, or two agents dispatched by
  # `/feature` collide on the same file. `policy` and `layout` are phase-2
  # constructs, so `app/policies/` and `app/layouts/` need owners like the rest.
  def test_every_app_directory_has_exactly_one_owning_agent
    owners = {
      "app/models/" => "data-modeler", "app/actions/" => "action-author",
      "app/screens/" => "screen-builder", "app/layouts/" => "screen-builder",
      "app/policies/" => "policy-author", "app/ledgers/" => "ledger-author",
      "test/" => "test-writer"
    }

    owners.each do |directory, agent|
      source = ".claude/agents/#{agent}.md"

      assert_includes agent_sources, source, "#{agent} is not in the MANIFEST"

      glob = "`#{directory}**`"
      claimants = agent_sources.select { |other| ownership_claim(other).include?(glob) }

      assert_equal [source], claimants,
                   "#{directory} must be claimed by #{agent} and by nobody else"
    end
  end

  # The "You own …" paragraph an agent opens with, which is its file set.
  # @param source [String] a `.claude/agents/*.md` template path
  # @return [String]
  def ownership_claim(source)
    read(source).split("\n## ", 2).first.to_s
  end

  # `.claude/README.md` is the roster an agent reads before dispatching, so it
  # goes stale the moment an agent file is added without it.
  def test_the_claude_readme_lists_every_agent_in_the_manifest
    roster = read(".claude/README.md")

    agent_sources.each do |source|
      assert_includes roster, "`#{File.basename(source, ".md")}`",
                      ".claude/README.md does not list #{source}"
    end
  end

  # TruffleRuby has no `fork` and its threads are genuinely parallel, so a test
  # worker is a thread and there is exactly one worker model. Ractors are not
  # it, and a template that says otherwise teaches the wrong invariant.
  def test_no_template_calls_the_concurrency_model_a_ractor
    offenders = manifest_rows.map(&:source).select { |source| read(source).include?("Ractor") }

    assert_empty offenders, "a test worker is a thread, not a Ractor: #{offenders.join(", ")}"
  end

  # --- ownership, staging and honesty --------------------------------------

  def test_the_ownership_markers_are_balanced
    BLOCKED_FILES.each do |source|
      body = read(source)

      %w[framework-block project-block].each do |block|
        assert_equal 1, body.scan("magik:#{block} BEGIN").size, "#{source}: #{block} BEGIN"
        assert_equal 1, body.scan("magik:#{block} END").size, "#{source}: #{block} END"
        assert_operator body.index("magik:#{block} BEGIN"), :<, body.index("magik:#{block} END"),
                        "#{source}: #{block} closes before it opens"
      end
    end
  end

  def test_the_blocks_never_nest
    # A nested pair cannot be rewritten by a line-based merge without eating the
    # other block, so the two regions must be disjoint.
    BLOCKED_FILES.each do |source|
      spans = %w[framework-block project-block].map do |block|
        body = read(source)
        (body.index("magik:#{block} BEGIN")..body.index("magik:#{block} END"))
      end

      refute spans[0].cover?(spans[1].first), "#{source}: project block opens inside the framework block"
      refute spans[1].cover?(spans[0].first), "#{source}: framework block opens inside the project block"
    end
  end

  def test_the_framework_block_is_stamped_with_the_version_that_wrote_it
    BLOCKED_FILES.each do |source|
      rendered = render(source)

      assert_includes rendered, "magik:framework-block BEGIN version=#{Magik::VERSION}",
                      "#{source}: the framework block must carry the gem version, so a stale " \
                      "harness is detectable rather than a matter of memory"
    end
  end

  def test_the_framework_block_stays_inside_its_budget
    # It shares a file with the project's own conventions. A framework half that
    # grows without limit is a project half nobody writes.
    rendered = render("CLAUDE.md.erb")
    block = rendered[/<!-- magik:framework-block BEGIN.*?<!-- magik:framework-block END -->/m]

    refute_nil block
    assert_operator block.bytesize, :<=, 11_000, "framework block: #{block.bytesize} bytes"
    assert_operator rendered.bytesize, :<=, 14_000, "whole CLAUDE.md: #{rendered.bytesize} bytes"
  end

  def test_a_fresh_app_says_it_has_not_been_set_up
    SENTINEL_FILES.each do |source|
      body = read(source)

      assert_includes body, SENTINEL, "#{source} must carry the stage-2 sentinel"
      assert_includes body, STAGE_TWO_COMMAND,
                      "#{source} must name #{STAGE_TWO_COMMAND}, or the sentinel tells nobody what to do"
    end
  end

  def test_the_stage_two_command_knows_how_to_detect_its_own_stage
    body = read(".claude/commands/setup-project.md")

    assert_includes body, "magik:stage2-pending"
    assert_includes body, "magik:framework-block"
    assert_includes body, "magik:project-block"
  end

  def test_no_template_claims_the_framework_works
    HONESTY_REQUIRED.each do |source|
      rendered = render(source)

      assert_match(/not implemented|spec only|name.reservation/i, rendered,
                   "#{source} must say plainly that the framework does not run yet")
    end
  end

  def test_every_agent_and_command_points_at_the_local_docs
    # The DSL is in no model's training data. An agent that writes it from memory
    # is the failure this framework has to design against.
    (agent_sources + command_sources).each do |source|
      body = read(source)

      assert_includes body, "magik docs", "#{source} must route the agent to the shipped docs"
    end
  end

  def test_the_docs_instruction_prefers_local_files_over_the_web
    %w[CLAUDE.md.erb llms.txt.erb docs/FEATURE.md.erb].each do |source|
      body = read(source)

      assert_includes body, "magik docs path",
                      "#{source}: `magik docs path` is what turns the shipped docs into files " \
                      "an agent's ordinary search already reaches"
    end
  end

  # --- what must never be generated ----------------------------------------

  def test_no_mcp_configuration_is_generated
    assert_empty on_disk.grep(/mcp/i),
                 "a generated app never carries an .mcp.json for a server the user did not ask for"
  end

  def test_no_template_ships_a_secret
    body = read(".env.example.erb")
    assignments = body.lines.grep(/\A[A-Z][A-Z0-9_]*=/)

    refute_empty assignments

    assignments.each do |line|
      key, _, value = line.strip.partition("=")
      next unless key.match?(/SECRET|KEY|TOKEN|PASSWORD|CREDENTIAL/)

      assert_empty value, "#{key} must ship blank — a secret written by a generator is a secret in git"
    end
  end

  def test_every_relative_link_in_an_emitted_file_stays_inside_the_generated_app
    # A generated app is a different repository, so a link out of it resolves to
    # nothing there — and `bin/check --only docs` scans these files from *this*
    # tree, where it resolves to nothing either. Framework references are
    # absolute URLs; in-app links must point at a file this template set emits.
    emitted_rows.map(&:source).select { |source| source.end_with?(".md") }.each do |source|
      links = read(source).scan(/\]\(([^)\s]+)\)/).flatten
      relative = links.reject { |target| target.start_with?("http://", "https://", "#", "mailto:") }

      relative.each do |target|
        resolved = File.expand_path(target.split("#").first, File.join(ROOT, File.dirname(source)))

        assert_path_exists resolved, "#{source} links to #{target}, which no template emits"
        refute resolved.start_with?("#{File.dirname(ROOT)}/") && !resolved.start_with?("#{ROOT}/"),
               "#{source} links outside the generated app: #{target}"
      end
    end
  end

  # --- the DSL in a template has to be Ruby --------------------------------

  def test_every_ruby_example_in_a_template_parses
    # The reference app found two spellings in the spec that are not valid Ruby.
    # A template is exactly as capable of shipping one.
    skip "RubyVM::InstructionSequence is unavailable on this engine" unless defined?(RubyVM::InstructionSequence)

    checked = 0
    manifest_rows.map(&:source).each do |source|
      body = source.end_with?(".erb") ? render(source) : read(source)
      body.scan(/^```ruby\n(.*?)^```/m).flatten.each do |snippet|
        RubyVM::InstructionSequence.compile(snippet.gsub(/^\s*#\s*…\s*$/, ""))
        checked += 1
      end
    end

    assert_operator checked, :>, 0, "no ruby examples found — did the fences lose their language tag?"
  end

  # --- budgets --------------------------------------------------------------

  def test_the_harness_files_stay_readable
    agent_sources.each do |source|
      assert_operator read(source).lines.size, :<=, 95, "#{source} is over the agent budget"
    end

    command_sources.each do |source|
      # Two stated exceptions: the interview script, and the loop command that is
      # the centre of the roster. Both are documented in the templates README.
      next if source.end_with?("setup-project.md", "feature.md")

      assert_operator read(source).lines.size, :<=, 80, "#{source} is over the command budget"
    end
  end

  def test_the_three_stage_journey_is_impossible_to_miss
    # magik new -> /setup-project -> /feature is the entire user journey. A user
    # who does not find stage 2 builds features into a scaffold with no domain
    # model, which is the most expensive failure this scaffold can produce.
    { "CLAUDE.md.erb" => render("CLAUDE.md.erb"),
      "README.md.erb" => render("README.md.erb"),
      ".claude/README.md" => read(".claude/README.md") }.each do |source, body|
      assert_includes body, "magik new", "#{source}: stage 1 is not named"
      assert_includes body, "/setup-project", "#{source}: stage 2 is not named"
      assert_includes body, "/feature", "#{source}: stage 3 is not named"
      assert_operator body.index("/setup-project"), :<, body.index("/feature"),
                      "#{source}: the stages must appear in the order they are run"
    end
  end

  def test_the_loop_command_reads_the_app_as_it_is
    # /feature must work as well on feature #40 as on feature #2, which means
    # reading current state every run rather than assuming a fresh scaffold.
    body = read(".claude/commands/feature.md")

    assert_includes body, "docs/PLAN.md", "the loop takes its `what` from the plan"
    assert_includes body, "docs/FEATURE.md", "the loop takes its `how` from the app's own loop doc"
    assert_includes body, "magik:stage2-pending", "the loop must refuse to run before stage 2"
    assert_includes body, "magik check", "done means the gate is green"
    assert_includes body, "magik docs", "step one is always the shipped docs"
    assert_match(%r{git log|ls app/models}, body, "the loop must read what already exists")
  end

  # --- project tooling ------------------------------------------------------

  def test_the_binstubs_are_executable_and_have_a_shebang
    rows = manifest_rows.select { |row| row.mode == EXECUTABLE_MODE }

    refute_empty rows

    rows.each do |row|
      assert row.destination.start_with?("bin/"), "#{row.source}: copy-exec is for bin/ only"
      assert File.executable?(File.join(ROOT, row.source)), "#{row.source} is not executable in the template tree"
      assert read(row.source).start_with?("#!"), "#{row.source} has no shebang"
    end
  end

  def test_the_gate_is_extended_by_adding_a_check_not_by_editing_bin_check
    body = read("bin/check")

    assert_includes body, "scripts/checks", "bin/check must discover the app's own rules"
    assert_includes body, "AppScripts::Registry.discover"
    assert_match(/ADD A RULE BY ADDING A CHECK/, body,
                 "bin/check must say how it is extended — it is `replace` on update")

    row = manifest_rows.find { |candidate| candidate.source == "bin/check" }

    assert_equal "replace", row.on_update
  end

  def test_bin_check_keeps_the_three_status_vocabulary_and_its_exit_codes
    body = read("bin/check")

    { "EXIT_OK = 0" => "success", "EXIT_FAILED = 1" => "the app is wrong",
      "EXIT_USAGE = 64" => "bad usage", "EXIT_NOT_INSTALLED = 69" => "a tool is missing" }.each_key do |constant|
      assert_includes body, constant
    end
    %w[pass FAIL MISSING].each { |status| assert_includes body, status }
  end

  def test_bin_check_runs_the_seeded_checks_green_on_a_fresh_app
    # The tooling half genuinely works with no framework behind it, and this is
    # the assertion that keeps that true.
    output = IO.popen(
      { "PATH" => ENV.fetch("PATH", "") },
      ["ruby", File.join(ROOT, "bin", "check"),
       *seeded_check_names.flat_map { |name| ["--only", name] }],
      err: %i[child out], &:read
    )

    assert_predicate $CHILD_STATUS || $?, :success?, "bin/check on a fresh app is not green:\n#{output}"
    assert_includes output, "ALL #{seeded_check_names.size} STEPS PASSED"
  end

  def test_every_seeded_check_is_discoverable_and_standalone
    seeded_checks.each do |source|
      body = read(source)

      assert_match(/^# @check\s+\S+/, body, "#{source} has no @check header")
      assert_match(/^# @summary\s+\S+/, body, "#{source} has no @summary header")
      assert_match(/^# @order\s+\d+/, body, "#{source} has no @order header")
      assert_includes body, "if $PROGRAM_NAME == __FILE__",
                      "#{source} must not run when it is required — a test has to be able to load it"
      assert_includes body, "def self.findings_for",
                      "#{source} must split the pure rule from the collector, or it has no negative case"
      assert_includes body, "not_applicable",
                      "#{source} must say when its precondition is absent by design"

      name = body[/^# @check\s+(\S+)/, 1]

      assert_equal File.basename(source, ".rb"), name.tr("-", "_"), "#{source}: @check name and filename disagree"
    end
  end

  def test_the_seeded_checks_are_the_teams_and_the_library_is_not
    seeded_checks.each do |source|
      row = manifest_rows.find { |candidate| candidate.source == source }

      assert_equal "never", row.on_update, "#{source} is the team's rule and must never be overwritten"
    end

    library = manifest_rows.find { |candidate| candidate.source == "scripts/lib/scripts.rb" }

    assert_equal "replace", library.on_update
  end

  def test_the_check_library_carries_the_same_contract_as_the_framework_repo
    body = read("scripts/lib/scripts.rb")

    %w[PASS FAIL MISSING].each { |status| assert_includes body, status }
    assert_includes body, "EXIT_CODES = { PASS => 0, FAIL => 1, MISSING => 69 }"
    assert_includes body, "EXIT_USAGE = 64"
    %w[Finding Result Check Registry Runner].each do |constant|
      assert_match(/(class|module) #{constant}\b|#{constant} = Struct\.new/, body,
                   "the library is missing #{constant}")
    end
  end

  def test_the_rubocop_rules_ship_in_the_gem_rather_than_in_every_app
    assert_path_exists GEM_RUBOCOP, "the gem-side RuboCop base is missing"

    require "yaml"
    base = YAML.load_file(GEM_RUBOCOP, aliases: true)

    assert_equal "3.2", base.dig("AllCops", "TargetRubyVersion").to_s
    assert_includes base.dig("AllCops", "Exclude"), "db/schema.rb"

    app_config = render(".rubocop.yml.erb")

    assert_includes app_config, "inherit_gem:"
    assert_includes app_config, "magik: lib/magik/cli/templates/rubocop.yml"
    # If the rules were copied instead of inherited, this file would be long and
    # every app would be pinned to the style of the magik it was generated with.
    assert_operator app_config.lines.size, :<=, 40, "the app's .rubocop.yml is copying rules instead of inheriting"
  end

  def test_the_gitignore_keeps_the_committed_example_and_drops_the_secrets
    rendered = render(".gitignore.erb")
    lines = rendered.lines.map(&:strip)

    %w[.env .env.local .env.* config/master.key].each { |pattern| assert_includes lines, pattern }
    # Load-bearing: `.env.*` above would otherwise swallow the committed template.
    assert_includes lines, "!.env.example"
    assert_operator lines.index("!.env.example"), :>, lines.index(".env.*"),
                    "the negation must come after the pattern it negates"
    # Generated AND committed — it is the reproducible truth about the schema.
    refute_includes lines, "db/schema.rb"
    assert_includes lines, ".claude/settings.local.json"
  end

  def test_the_generated_yaml_parses
    require "yaml"

    %w[.github/workflows/ci.yml.erb docker/compose.yml.erb lefthook.yml.erb].each do |source|
      rendered = render(source)

      YAML.load(rendered, aliases: true)
    rescue Psych::Exception => e
      flunk "#{source} does not render to valid YAML: #{e.message}"
    end
  end

  def test_the_gemfile_pins_magik_and_the_dev_group
    rendered = render("Gemfile.erb")

    assert_includes rendered, %(gem "magik", "~> #{Magik::VERSION}")
    %w[rake minitest rubocop rubocop-minitest rubocop-performance rubocop-rake simplecov].each do |gem_name|
      assert_includes rendered, %(gem "#{gem_name}")
    end
    refute_includes rendered, "rspec"
  end

  def test_the_rakefile_mirrors_this_repos_task_names
    rendered = render("Rakefile.erb")

    %w[:test :rubocop :check].each { |task| assert_includes rendered, task }
    assert_includes rendered, "rescue LoadError",
                    "a missing dev gem must abort with an install hint, never pass vacuously"
  end

  def test_the_tooling_says_which_half_actually_works
    rendered = render("README.md.erb")

    assert_match(/bundle install/, rendered)
    assert_match(%r{rake test|bin/check}, rendered)
    assert_match(/not implemented|planned|spec only/i, rendered)
  end

  def seeded_checks = manifest_rows.map(&:source).grep(%r{\Ascripts/checks/.+\.rb\z}).sort

  def seeded_check_names
    seeded_checks.map { |source| read(source)[/^# @check\s+(\S+)/, 1] }.sort
  end

  def test_agents_md_falls_back_to_pointing_at_claude_md
    row = manifest_rows.find { |candidate| candidate.destination == "AGENTS.md" }

    assert_equal "symlink:CLAUDE.md", row.mode
    assert_includes read(row.source), "CLAUDE.md"
  end
end
