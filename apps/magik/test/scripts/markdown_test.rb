# frozen_string_literal: true

require_relative "helper"

# The Markdown reader. Every check that reports `file:line` depends on
# `without_fences` keeping the line count intact, so that is tested directly
# rather than through a check.
class MagikScriptsMarkdownTest < Minitest::Test
  Markdown = MagikScripts::Markdown

  PAGE = <<~MD
    # Title

    A [link](one.md) in prose.

    ```bash
    bin/check
    ```

    ## Live today

    | Code | Means |
    |---|---|
    | `MAGIK_A` | a |

    ## Next

    | Code | Means |
    |---|---|
    | `MAGIK_B` | b |
  MD

  def test_fences_carry_their_language_body_and_opening_line
    fence = Markdown.new(PAGE).fences.first

    assert_equal "bash", fence.lang
    assert_equal "bin/check\n", fence.body
    assert_equal 5, fence.line
  end

  def test_without_fences_preserves_the_line_count
    document = Markdown.new(PAGE)

    assert_equal PAGE.lines.size, document.without_fences.lines.size
    refute_includes document.without_fences, "bin/check"
  end

  def test_links_are_read_from_prose_only
    links = Markdown.new("[a](a.md)\n\n```\n[b](b.md)\n```\n").links

    assert_equal ["a.md"], links.map(&:target)
    assert_equal 1, links.first.line
  end

  def test_a_section_stops_at_the_next_heading_of_the_same_level
    body = Markdown.new(PAGE).section("Live today")

    assert_includes body, "MAGIK_A"
    refute_includes body, "MAGIK_B"
  end

  def test_a_missing_section_is_nil_not_an_empty_string
    assert_nil Markdown.new(PAGE).section("Nowhere")
  end

  def test_table_rows_drop_the_header_and_separator
    rows = Markdown.table_rows(Markdown.new(PAGE).section("Live today"))

    assert_equal [["`MAGIK_A`", "a"]], rows
  end
end
