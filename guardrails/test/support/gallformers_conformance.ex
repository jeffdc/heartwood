defmodule Heartwood.Test.GallformersConformance do
  @moduledoc """
  Gallformers' design-system rules (its `GallformersWeb.DesignSystem.Conformance`
  on taxogall, 2026-11-26), as a pattern ratchet: the fixture that tests
  `Heartwood.Guardrails.Patterns` against real rules. Reads `lib/` and
  `assets/css/` under the working directory.
  """
  use Heartwood.Guardrails.Patterns

  @templates ["lib/**/*.ex", "lib/**/*.heex"]
  @css ["assets/css/**/*.css"]

  @palette ~w(gray slate zinc neutral stone red orange amber yellow lime green emerald teal
              cyan sky blue indigo violet purple fuchsia pink rose)
  @legacy_palette ~w(gf-maroon gf-sky-blue gf-autumn gf-cream cadet-blue canary independence
                     new-york-pink persian-orange table-header table-selected)
  @color_props ~w(text bg border border-t border-b border-l border-r border-x border-y ring
                  outline divide fill stroke from via to placeholder decoration accent caret)

  # A class token may carry variants (hover:, md:, group-hover: …) before it.
  @variants "(?:[a-z0-9-]+:)*"
  @start "(?<![\\w-])"

  @impl Heartwood.Guardrails.Ratchet
  def subject, do: "off-system styling"

  @impl Heartwood.Guardrails.Ratchet
  def baseline_path, do: "test/support/design_system_baseline.json"

  @impl Heartwood.Guardrails.Patterns
  def intro, do: "New styling bypasses the design system (docs/design-system/)."

  @impl Heartwood.Guardrails.Patterns
  def outro,
    do:
      "If the new code is right and the system lacks what it needs, extend the\n" <>
        "system first (tokens or a documented component), then use it."

  @impl Heartwood.Guardrails.Patterns
  def rules do
    [
      [
        name: :palette_color,
        files: @templates,
        pattern:
          ~r/#{@start}#{@variants}(?:#{Enum.join(@color_props, "|")})-(?:(?:#{Enum.join(@palette, "|")})-\d{2,3}|black|white)(?:\/\d+)?(?![\w-])/,
        hint: "Use a semantic color: text-ink, bg-paper, border-line."
      ],
      [
        name: :legacy_palette,
        files: @templates,
        pattern:
          ~r/#{@start}#{@variants}(?:#{Enum.join(@color_props, "|")})-(?:#{Enum.join(@legacy_palette, "|")})(?:\/\d+)?(?![\w-])/,
        hint: "Use the semantic brand colors: text-brand, bg-brand-fill."
      ],
      [
        name: :type_scale,
        files: @templates,
        pattern: ~r/#{@start}#{@variants}text-(?:xs|sm|base|lg|xl|[2-9]xl)(?![\w-])/,
        hint: "Use the semantic sizes: text-page, text-section, text-body, text-meta."
      ],
      [
        name: :radius,
        files: @templates,
        pattern:
          ~r/#{@start}#{@variants}rounded(?:-(?:t|b|l|r|s|e|tl|tr|bl|br|ss|se|es|ee))?(?:-(?:none|xs|sm|md|lg|xl|2xl|3xl))?(?![\w-])/,
        hint: "Use rounded-ctl, rounded-panel or rounded-full."
      ],
      [
        name: :shadow,
        files: @templates,
        pattern: ~r/#{@start}#{@variants}shadow(?:-(?:2xs|xs|sm|md|lg|xl|2xl|inner))?(?![\w-])/,
        hint: "Only floating things cast a shadow: shadow-float."
      ],
      [
        name: :arbitrary_value,
        files: @templates,
        pattern: ~r/#{@start}#{@variants}-?[a-z][a-z0-9-]*-\[[^\]\s"]+\]/,
        hint: "Use a token."
      ],
      [
        name: :dark_variant,
        files: @templates,
        pattern: ~r/#{@start}dark:/,
        hint: "Don't use dark: variants."
      ],
      [
        name: :inline_style,
        files: @templates,
        pattern: ~r/#{@start}style=/,
        hint: "Use classes."
      ],
      [
        name: :hex_color,
        files: @templates ++ @css,
        exempt: ["assets/css/system/tokens.css"],
        pattern: ~r/#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3,4})(?![0-9a-zA-Z_-])/,
        # "#123" is an issue number, not a color: a hex color has a letter or six digits.
        filter: fn "#" <> hex -> String.match?(hex, ~r/[a-fA-F]/) or String.length(hex) >= 6 end,
        hint: "Colors come from tokens in assets/css/system/tokens.css."
      ],
      [
        name: :letter_case,
        files: @templates ++ @css,
        pattern: ~r/#{@start}#{@variants}(?:uppercase|tracking-(?:wide|wider|widest))(?![\w-])/,
        hint: "Text is in sentence case, labels too."
      ]
    ]
  end
end
