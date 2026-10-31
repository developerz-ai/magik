# frozen_string_literal: true
#
# ASPIRATIONAL DSL — this file does not run and cannot yet. Magik is spec only
# as of 2026-08-26: `theme` is not a method that exists, and loading this file
# would raise NoMethodError. See dummy/README.md.
#
# config/theme.rb  —  design tokens, light and dark.
#
# Its own file because it is the one part of the app a designer edits and a
# backend developer does not. Everything here compiles to CSS custom properties;
# there is no JavaScript theme switch and no client-side style computation
# (spec decision 4).
#
# Demonstrates: theme, tokens, light/dark via CSS variables (Phase 2).

theme do
  # Semantic names, not colour names. `color_danger` survives a rebrand;
  # `color_red` becomes a lie the first time danger is orange.
  tokens do
    color_primary "#1f6feb"
    color_danger  "#d1242f"
    color_warn    "#9a6700"
    color_success "#1a7f37"
    radius        "6px"
    font_body     "system-ui, -apple-system, Segoe UI, sans-serif"
    font_mono     "ui-monospace, SFMono-Regular, Menlo, monospace"
  end

  # Only the tokens that differ. Redefining the whole palette per mode is how
  # one colour ends up correct in light and wrong in dark.
  dark do
    color_primary "#4493f8"
    color_danger  "#f85149"
  end

  # light | dark | system. `system` follows prefers-color-scheme with no
  # JavaScript at all; a user override is a cookie the server reads.
  mode :system
end
