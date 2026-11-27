defmodule Heartwood.Guardrails.PatternsTest do
  # Counting reads the working directory: not async.
  use ExUnit.Case, async: false

  import Heartwood.Test.InDir

  alias Heartwood.Guardrails.Ratchet
  alias Heartwood.Test.GallformersConformance, as: Conformance

  defmodule Budget do
    @moduledoc false
    use Heartwood.Guardrails.Patterns

    @impl Heartwood.Guardrails.Ratchet
    def subject, do: "page CSS"

    @impl Heartwood.Guardrails.Ratchet
    def baseline_path, do: "baseline.json"

    @impl Heartwood.Guardrails.Patterns
    def rules do
      [
        [
          name: :app_css_lines,
          files: ["assets/css/app.css"],
          count: &length(String.split(&1, "\n", trim: true)),
          hint: "Page CSS only shrinks: move it into a component."
        ]
      ]
    end
  end

  defp rules(text), do: text |> Conformance.scan() |> Enum.map(& &1.rule) |> Enum.sort()

  describe "scan/1" do
    test "a template on the system has no findings" do
      text = ~S"""
      <div class="bg-surface text-ink border border-line rounded-panel p-panel">
        <h2 class="text-section">Hosts</h2>
        <p class="text-meta text-muted">14 recorded</p>
        <span class="shadow-float rounded-ctl rounded-full shadow-none">x</span>
      </div>
      """

      assert Conformance.scan(text) == []
    end

    test "flags Tailwind palette colors, black and white" do
      assert rules(~S(<p class="text-gray-500 hover:bg-blue-50 border-red-200/50">)) ==
               [:palette_color, :palette_color, :palette_color]

      assert rules(~S(<p class="bg-white text-black">)) == [:palette_color, :palette_color]
    end

    test "flags the legacy brand palette" do
      assert rules(~S(<p class="text-gf-maroon bg-gf-sky-blue bg-cadet-blue">)) ==
               [:legacy_palette, :legacy_palette, :legacy_palette]
    end

    test "flags the default type scale but not the semantic sizes" do
      assert rules(~S(<p class="text-sm md:text-2xl text-body text-caption">)) ==
               [:type_scale, :type_scale]
    end

    test "flags off-system radii and shadows" do
      assert rules(~S(<p class="rounded rounded-lg rounded-t-md shadow shadow-md">)) ==
               [:radius, :radius, :radius, :shadow, :shadow]
    end

    test "flags arbitrary values, dark variants and inline styles" do
      assert rules(~S(<p class="top-[78px] dark:bg-surface" style="width: 3px">)) ==
               [:arbitrary_value, :dark_variant, :inline_style]
    end

    test "flags all-caps and tracked-out text but not tight tracking" do
      assert rules(~S(<dt class="uppercase tracking-wide md:tracking-wider tracking-tight">)) ==
               [:letter_case, :letter_case, :letter_case]

      assert rules(".gf-x { text-transform: uppercase; }") == [:letter_case]
    end

    test "a rule's filter drops matches: hex colors but not issue numbers or anchors" do
      assert rules(~S(<p data-c="#661419" data-d="#fff">see #123 and #top</p>)) ==
               [:hex_color, :hex_color]
    end

    test "reports the line of each finding" do
      [finding] = Conformance.scan("<div>\n  <p class=\"text-gray-500\">\n</div>")
      assert finding.line == 2
      assert finding.match == "text-gray-500"
    end

    test "with rule names, scans for just those" do
      assert Conformance.scan(~S(<p class="text-sm" style="x">), [:inline_style])
             |> Enum.map(& &1.rule) == [:inline_style]
    end
  end

  describe "counts/0" do
    @describetag :tmp_dir

    test "tallies per file and rule, reading each rule's files and skipping its exempt ones",
         %{tmp_dir: dir} do
      files = %{
        "lib/page.ex" => ~S(<p class="text-sm rounded" style="x">#661419</p>),
        "lib/clean.heex" => ~S(<p class="text-body">),
        "assets/css/app.css" =>
          ".x { color: #fff; text-transform: uppercase; }\n.y { margin: 0 }",
        "assets/css/system/tokens.css" => "--ink: #111111;"
      }

      counts = in_dir(dir, files, &Conformance.counts/0)

      assert counts == %{
               "lib/page.ex" => %{
                 "type_scale" => 1,
                 "radius" => 1,
                 "inline_style" => 1,
                 "hex_color" => 1
               },
               "assets/css/app.css" => %{"hex_color" => 1, "letter_case" => 1}
             }
    end

    test "a counting rule measures each file with its function", %{tmp_dir: dir} do
      css = ".a { }\n.b { }\n\n.c { }\n"

      assert in_dir(dir, %{"assets/css/app.css" => css}, &Budget.counts/0) ==
               %{"assets/css/app.css" => %{"app_css_lines" => 3}}
    end
  end

  describe "explain/1" do
    @describetag :tmp_dir

    test "lists each new finding with its line and the rule's hint, between intro and outro",
         %{tmp_dir: dir} do
      files = %{"lib/page.ex" => "<div>\n  <p class=\"text-gray-500\">\n</div>\n"}

      message =
        in_dir(dir, files, fn ->
          %{over: over} = Ratchet.compare(Conformance.counts(), %{})
          Conformance.explain(over)
        end)

      assert message =~ "New styling bypasses the design system"
      assert message =~ "lib/page.ex: palette_color 1 (baseline 0)"
      assert message =~ "line 2: text-gray-500"
      assert message =~ "→ Use a semantic color"
      assert message =~ "extend the\nsystem first"
    end

    test "a counting rule shows its count and hint, with a default intro", %{tmp_dir: dir} do
      message =
        in_dir(dir, %{"assets/css/app.css" => ".a { }\n.b { }\n"}, fn ->
          Budget.explain([{["assets/css/app.css", "app_css_lines"], 2, 1}])
        end)

      assert message =~ "New page CSS, over the baseline."
      assert message =~ "assets/css/app.css: app_css_lines 2 (baseline 1)"
      assert message =~ "→ Page CSS only shrinks"
    end

    test "is empty with nothing over" do
      assert Conformance.explain([]) == ""
    end
  end
end
