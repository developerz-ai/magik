# frozen_string_literal: true

require_relative "helper"

# One development Ruby, named in five places that have to agree.
#
# The pin is `apps/magik/.ruby-version`; the toolchain reference is `mise.toml`;
# the two fix lines are `bin/setup`'s `MAGIK_DEV_NO_RUBY` and
# `MAGIK_DEV_RUBY_TOO_OLD`; and the `MAGIK_DEV_RUBY_TOO_OLD` guidance is
# written down twice — `docs/architecture/03-error-codes.md` and its generated
# mirror under `apps/magik/docs/`. Nothing in the gate ties those five
# together, so a release moved in one of them and not the others leaves a
# checkout whose fix lines install a Ruby the pin does not name. This file is
# that tie.
#
# The rule it holds: **the pin names a release the ruby-lang.org advisory for
# CVE-2024-27282 does not mark affected**, and every other copy names the same
# release. The advisory's URL and its affected and fixed lists are recorded in
# the tree — in `apps/magik/.ruby-version` — so the claim is checkable without
# the network, and this test reads that record rather than keeping a second
# copy of it.
class MagikScriptsRubyPinTest < Minitest::Test
  # The checkout root: this file lives under apps/magik/test/scripts/, four
  # levels down, but `bin/setup` and `mise.toml` are at the root and the two
  # document copies are under docs/ and apps/magik/docs/.
  REPO = File.expand_path("../../../..", __dir__).freeze

  # The development pin.
  PIN = File.join(REPO, "apps", "magik", ".ruby-version").freeze

  # The toolchain reference. It is the one file here that bin/setup does not
  # read, and it is the file a reader believes about the box.
  MISE = File.join(REPO, "mise.toml").freeze

  # The developer script whose two fix lines name the release.
  SETUP = File.join(REPO, "bin", "setup").freeze

  # The two copies of the error-code page: the source and its packaged mirror.
  # The mirror is GENERATED — `apps/magik/scripts/checks/shipped_mirrors.rb`
  # renders it — so it is read, never edited, and a drift between the two is
  # exactly what this test has to see.
  ERROR_CODES_SOURCE = File.join(REPO, "docs", "architecture", "03-error-codes.md").freeze
  ERROR_CODES_MIRROR = File.join(REPO, "apps", "magik", "docs", "architecture", "03-error-codes.md").freeze

  # The gemspec's own floor, read from the gemspec — never restated here.
  GEMSPEC = File.join(REPO, "apps", "magik", "magik.gemspec").freeze

  # The advisory this pin is checked against. Its URL and its affected and
  # fixed version lists live in the tree; this constant names the URL the
  # record has to carry, so the claim is checkable without the network.
  ADVISORY_URL = "https://www.ruby-lang.org/en/news/2024/04/23/arbitrary-memory-address-read-regexp-cve-2024-27282/"

  # The advisory's own subject: the CVE this pin is checked against.
  CVE = "CVE-2024-27282"

  # The two codes bin/setup raises about the Ruby it finds.
  RUBY_CODES = %w[MAGIK_DEV_NO_RUBY MAGIK_DEV_RUBY_TOO_OLD].freeze

  # --- the parsers, against fixtures -------------------------------------------

  # A pin names the FIRST WORD of the FIRST non-empty line: rbenv reads the
  # first word, mise reads the first line, and every comment in the file sits
  # below the version for exactly that reason. A version on the second line
  # would be read by neither.
  def test_the_pin_is_the_first_word_of_the_first_line
    assert_equal "3.4.10", pin_version_of(<<~PIN)
      3.4.10
      # a comment below the version
    PIN
  end

  def test_a_pin_whose_comment_sits_above_the_version_is_read_as_the_comment
    assert_equal "#", pin_version_of(<<~PIN)
      # 3.2.3 is the version
      3.4.10
    PIN
  end

  # The toolchain reference is the `ruby = "..."` under [tools]. A commented
  # mention of a release is prose, not the value — the same discipline the
  # version-consistency check applies to a stamp.
  def test_the_mise_value_is_the_one_under_the_tools_table
    assert_equal "3.4.10", mise_ruby_of(<<~TOML)
      # `ruby = "9.9.9"` is only a mention in this comment.
      [tools]
      ruby = "3.4.10"
    TOML
  end

  # The fix line under a code: the first `fix:` within the block below it.
  # The text is trimmed the way the gate's own {MagikScripts::Checks::DevCodes}
  # trims it, so the fix this test reads is the fix the gate reads.
  def test_the_fix_line_under_a_code_is_the_one_below_it
    source = <<~SH
      echo "MAGIK_DEV_NO_RUBY: ruby is not on PATH" >&2
      echo "  fix: mise install ruby@3.4.10 && mise exec ruby@3.4.10 -- bin/setup" >&2
      echo "MAGIK_DEV_OTHER: something else" >&2
      echo "  fix: gem install rake" >&2
    SH

    assert_equal "mise install ruby@3.4.10 && mise exec ruby@3.4.10 -- bin/setup",
                 fix_line_for(source, "MAGIK_DEV_NO_RUBY")
  end

  # A code with no fix: below it has no fix at all — the guard has to notice
  # the absence, not only a wrong fix.
  def test_a_code_with_no_fix_line_below_it_has_none
    source = "echo \"MAGIK_DEV_NO_RUBY: ruby is not on PATH\" >&2\necho \"  note: nothing\" >&2\n"

    assert_nil fix_line_for(source, "MAGIK_DEV_NO_RUBY")
  end

  # A fix line is advice when it says what to think about rather than what to
  # run. The gate's own list of advice phrases is the one that counts; this
  # test uses it so the two cannot disagree.
  def test_a_fix_line_that_is_advice_is_not_a_command
    assert advice?("make sure Ruby >= 3.2 is installed, then re-run bin/setup")
    refute advice?("mise install ruby@3.4.10 && mise exec ruby@3.4.10 -- bin/setup")
  end

  # --- the real tree ------------------------------------------------------------

  def test_the_pin_names_a_release_the_advisory_does_not_mark_affected
    pin = pin_version

    refute_empty pin, "apps/magik/.ruby-version must name a release"
    affected = affected_versions

    refute_empty affected, "the tree must record the advisory's affected versions"
    refute_includes affected, pin,
                    "the pin names #{pin}, which the recorded advisory marks affected"
  end

  def test_the_pin_is_above_every_release_the_advisory_marks_affected
    pin = pin_version

    affected_versions.each do |version|
      assert_operator Gem::Version.new(pin), :>, Gem::Version.new(version),
                      "the pin #{pin} must be above the affected release #{version}"
    end
  end

  def test_the_pin_is_above_every_release_the_advisory_records_as_fixed
    pin = pin_version

    fixed = fixed_versions

    refute_empty fixed, "the tree must record the advisory's fixed versions"
    fixed.each do |version|
      assert_operator Gem::Version.new(pin), :>, Gem::Version.new(version),
                      "the pin #{pin} must be above the fixed release #{version}"
    end
  end

  # The recorded lists are read out of the tree, so a list that lost a release
  # would quietly narrow what this file holds the pin to. The advisory names
  # four affected releases and four fixed ones; the record has to carry all of
  # them, on one line or on four.
  def test_the_recorded_advisory_lists_are_read_in_full
    assert_equal %w[3.0.6 3.1.4 3.2.3 3.3.0], affected_versions
    assert_equal %w[3.0.7 3.1.5 3.2.4 3.3.1], fixed_versions
  end

  def test_the_pin_satisfies_the_gemspecs_required_ruby_version_floor
    floor = gemspec_floor

    refute_nil floor, "the gemspec must state a required_ruby_version"
    assert_operator Gem::Version.new(pin_version), :>=, Gem::Version.new(floor),
                    "the pin must not sit below the floor the gem itself states"
  end

  def test_the_pin_records_the_advisory_it_is_checked_against
    text = File.read(PIN)

    assert_includes text, ADVISORY_URL,
                    "the pin must record the advisory's URL, so the claim is checkable without the network"
    assert_includes text, CVE, "the pin must name the CVE it satisfies"
  end

  def test_the_mise_toolchain_reference_names_the_same_release_as_the_pin
    assert_equal pin_version, mise_ruby,
                 "mise.toml and apps/magik/.ruby-version must name the same release, or the box " \
                 "runs a Ruby the pin does not describe"
  end

  def test_the_mise_toolchain_reference_justifies_a_release_that_differs_from_the_pin
    skip "mise.toml names the pinned release, so there is nothing to justify" if mise_ruby == pin_version

    justification = mise_justification

    refute_empty justification,
                 "a mise.toml that names another release must say why, in the comment block " \
                 "adjacent to [tools]"
    assert_includes justification, mise_ruby,
                    "the justification must name the release that differs from the pin"
    assert_match(/\b(compatibility|compatible|constraint|installed|build|shim|stall|resolution)\b/i,
                 justification,
                 "the justification must name a compatibility reason for the different release")
  end

  def test_both_bin_setup_fix_lines_name_the_pinned_release
    text = File.read(SETUP)

    RUBY_CODES.each do |code|
      fix = fix_line_for(text, code)

      refute_nil fix, "bin/setup must print a fix: line for #{code}"
      assert_names_only_the_pin fix, "the #{code} fix"
    end
  end

  def test_both_bin_setup_fix_lines_are_runnable_commands
    text = File.read(SETUP)

    RUBY_CODES.each do |code|
      fix = fix_line_for(text, code)

      refute_nil fix, "bin/setup must print a fix: line for #{code}"
      assert_match(/\Amise install ruby@\S+/, fix,
                   "the #{code} fix must be a command a reader can paste, not advice")
      refute advice?(fix), "the #{code} fix must not read as advice"
    end
  end

  def test_the_error_code_source_page_recommends_the_pinned_release
    assert_recommends_pinned ERROR_CODES_SOURCE
  end

  def test_the_error_code_mirror_recommends_the_pinned_release
    assert_recommends_pinned ERROR_CODES_MIRROR
  end

  def test_the_two_error_code_copies_agree_on_the_fix
    assert_equal fix_cell(File.read(ERROR_CODES_SOURCE)), fix_cell(File.read(ERROR_CODES_MIRROR)),
                 "the mirror is generated from the source; a drift between the two means the " \
                 "shipped copy names a different release than the checkout does"
  end

  private

  # --- assertions over the real tree --------------------------------------------

  # A document's MAGIK_DEV_RUBY_TOO_OLD fix cell must name the pinned release
  # and nothing else. "Names nothing else" is the half that matters: a cell
  # that names the pin once and a stale release once is a cell that installs
  # the wrong Ruby — and a cell that merely CONTAINS the pin hides it.
  #
  # @param path [String] the document to read
  # @return [void]
  def assert_recommends_pinned(path)
    cell = fix_cell(File.read(path))

    assert_names_only_the_pin cell, "the #{path} fix cell"
  end

  # --- the parsers ----------------------------------------------------------------

  # The release a pin file names.
  #
  # @param text [String] the pin file's text
  # @return [String]
  def pin_version_of(text)
    line = text.lines.find { |candidate| !candidate.strip.empty? }
    return "" if line.nil?

    line.split(/\s+/).first.to_s
  end

  # The comment block immediately above [tools] in mise.toml — the place a
  # reader looks for why the toolchain names the release it names.
  #
  # @return [String]
  def mise_justification
    lines = File.readlines(MISE)
    tools = lines.index { |line| line.match?(/^\[tools\]\s*$/) }
    return "" if tools.nil?

    comments = []
    (tools - 1).downto(0) do |index|
      line = lines[index]
      break unless line.lstrip.start_with?("#")

      comments.unshift(line)
    end
    comments.join
  end

  # The release a mise.toml names under [tools].
  #
  # @param text [String] the file's text
  # @return [String]
  def mise_ruby_of(text)
    tools = text[/^\[tools\]\s*$(.*?)(^\[|\z)/m, 1]
    return "" if tools.nil?

    tools[/^\s*ruby\s*=\s*"([^"]+)"/, 1].to_s
  end

  # A fix text must name the pinned release and NOTHING ELSE. Every release it
  # mentions has to be the pin: a command that installs one release and runs
  # another is not a fix, and a text that merely CONTAINS the pin hides that.
  #
  # @param text [String] the fix text
  # @param what [String] what the text is, for the failure message
  # @return [void]
  def assert_names_only_the_pin(text, what)
    pin = pin_version
    named = text.scan(/ruby@(\d+(?:\.\d+)*)/).flatten.uniq

    assert_includes named, pin,
                    "#{what} must name the pinned release #{pin}, so the command a reader pastes " \
                    "installs the Ruby this checkout develops against"
    assert_equal [pin], named,
                 "#{what} must name one release and it must be the pinned one, but it names " \
                 "#{named.inspect}"
  end

  # The `fix:` line a script prints under a code.
  #
  # @param source [String] the script's text
  # @param code [String] the MAGIK_DEV_* code
  # @return [String, nil]
  def fix_line_for(source, code)
    lines = source.lines
    index = lines.index { |line| line.include?(code) }
    return nil if index.nil?

    line = lines[index + 1, 24].find { |candidate| candidate.include?("fix:") }
    return nil if line.nil?

    MagikScripts::Checks::DevCodes.trim(line.sub(/.*fix:\s*/, ""))
  end

  # The `fix:` cell of the MAGIK_DEV_RUBY_TOO_OLD row in an error-code page.
  # The row is a Markdown table row, so the cells are the segments between the
  # pipes — and the last segment is empty, because the row ends with one.
  #
  # @param source [String] the page's text
  # @return [String]
  def fix_cell(source)
    row = source.lines.find { |line| line.include?("`MAGIK_DEV_RUBY_TOO_OLD`") }
    raise "no MAGIK_DEV_RUBY_TOO_OLD row" if row.nil?

    row.split("|").map(&:strip).reject(&:empty?).last.to_s
  end

  # Whether a fix line reads as advice rather than as a command. The gate's own
  # list of advice phrases is the one that counts, so the two cannot disagree
  # about what counts as advice.
  #
  # @param fix [String] the fix text
  # @return [Boolean]
  def advice?(fix)
    MagikScripts::Checks::ErrorCodes::ADVICE.any? { |pattern| pattern.match?(fix) }
  end

  # --- the real values -----------------------------------------------------------

  # The release the pin names.
  #
  # @return [String]
  def pin_version
    @pin_version ||= pin_version_of(File.read(PIN))
  end

  # The release mise.toml names under [tools].
  #
  # @return [String]
  def mise_ruby
    @mise_ruby ||= mise_ruby_of(File.read(MISE))
  end

  # The gemspec's `required_ruby_version`, as a bare version. The gemspec says
  # ">= 3.2"; the floor this test holds the pin to is the 3.2 in it.
  #
  # @return [String, nil]
  def gemspec_floor
    @gemspec_floor ||= begin
      requirement = File.read(GEMSPEC)[/required_ruby_version\s*=\s*"([^"]+)"/, 1]
      requirement.to_s[/>=\s*([\d.]+)/, 1]
    end
  end

  # The releases the recorded advisory marks affected. The record is the pin
  # file's own comment block, which quotes the advisory's list verbatim:
  # "Affected versions, verbatim from that advisory:" followed by one release
  # per line.
  #
  # @return [Array<String>]
  def affected_versions
    @affected_versions ||= versions_under("Affected versions")
  end

  # The releases the recorded advisory marks fixed, read the same way.
  #
  # @return [Array<String>]
  def fixed_versions
    @fixed_versions ||= versions_under("Fixed versions")
  end

  # The releases listed under a heading in the pin file's advisory record.
  # A "or lower" entry names a ceiling, so the ceiling itself is the release
  # the advisory marks affected — "Ruby 3.2.3 or lower" is read as 3.2.3. A
  # line may carry several releases — the fixed list is one line — so every
  # release on the line is read.
  #
  # @param heading [String] the heading to read under
  # @return [Array<String>]
  def versions_under(heading)
    lines = File.readlines(PIN)
    start = lines.index { |line| line.include?(heading) }
    return [] if start.nil?

    versions = []
    lines[(start + 1)..].each do |line|
      found = line.scan(/Ruby\s+(\d+(?:\.\d+)*)/).flatten
      # The list ends at the first line that names no release: the blank
      # comment line under it, or the next heading. Neither is a release, and
      # reading past them would pull the NEXT list into this one.
      break if found.empty?

      versions.concat(found)
    end
    versions.uniq
  end
end
