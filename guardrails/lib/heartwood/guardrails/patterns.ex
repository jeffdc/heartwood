defmodule Heartwood.Guardrails.Patterns do
  @moduledoc """
  A ratchet built from rules: each counts a pattern, or some other measure,
  in a set of files, per file and rule.

      defmodule MyAppWeb.Conformance do
        use Heartwood.Guardrails.Patterns

        @impl true
        def subject, do: "off-system styling"

        @impl true
        def baseline_path, do: "test/support/conformance_baseline.json"

        @impl Heartwood.Guardrails.Patterns
        def rules do
          [
            [
              name: :inline_style,
              files: ["lib/my_app_web/**/*.{ex,heex}"],
              pattern: ~r/(?<![\\w-])style=/,
              hint: "Use classes."
            ],
            [
              name: :app_css_lines,
              files: ["assets/css/app.css"],
              count: &length(String.split(&1, "\\n", trim: true)),
              hint: "Page CSS only shrinks: move it into a component."
            ]
          ]
        end
      end

  A rule is a keyword list:

    * `:name` (an atom) names it in the baseline.
    * `:files` are globs, relative to the app's root; `:exempt` lists files
      among them it doesn't read.
    * `:pattern`, a regex, is counted once per match on each line, or
      `:count`, a function from a file's text to a number, measures it.
    * `:filter` (optional, with `:pattern`) says whether a match counts:
      `"#123"` matches a hex-colour pattern but is an issue number.
    * `:hint` is the right token or component, shown when the count grows.

  `use` adds `scan/1,2`, `counts/0` and `explain/1`. A module may also define
  `intro/0` and `outro/0`, the first and last paragraphs of the failure
  message.
  """

  alias Heartwood.Guardrails.Ratchet

  @typedoc "A pattern match: its rule, its line and the text matched."
  @type finding :: %{rule: atom(), line: pos_integer(), match: String.t()}

  @doc "The rules, as described in the moduledoc."
  @callback rules() :: [keyword()]

  @doc "The failure message's first paragraph."
  @callback intro() :: String.t()

  @doc "The failure message's last paragraph."
  @callback outro() :: String.t()

  @optional_callbacks intro: 0, outro: 0

  defmacro __using__(_opts) do
    patterns = __MODULE__

    quote do
      @behaviour Ratchet
      @behaviour unquote(patterns)

      @doc "Scans text with the pattern rules (all, or those named) and returns every finding, in order."
      @spec scan(String.t(), [atom()] | :all) :: [unquote(patterns).finding()]
      def scan(text, only \\ :all), do: unquote(patterns).scan(__MODULE__, text, only)

      @impl Ratchet
      def counts, do: unquote(patterns).counts(__MODULE__)

      @impl Ratchet
      def explain(over), do: unquote(patterns).explain(__MODULE__, over)
    end
  end

  @doc false
  @spec scan(module(), String.t(), [atom()] | :all) :: [finding()]
  def scan(ratchet, text, only) do
    rules =
      for rule <- ratchet.rules(),
          rule[:pattern],
          only == :all or rule[:name] in only,
          do: rule

    text
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line_text, line} ->
      for rule <- rules,
          [match | _] <- Regex.scan(rule[:pattern], line_text),
          counts?(rule, match),
          do: %{rule: rule[:name], line: line, match: match}
    end)
    |> Enum.sort_by(&{&1.line, &1.rule})
  end

  defp counts?(rule, match) do
    case rule[:filter] do
      nil -> true
      filter -> filter.(match)
    end
  end

  @doc false
  @spec counts(module()) :: Ratchet.counts()
  def counts(ratchet) do
    root = File.cwd!()

    ratchet.rules()
    |> Enum.flat_map(fn rule -> for file <- files(root, rule), do: {file, rule} end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.reduce(%{}, fn {file, rules}, acc ->
      text = File.read!(Path.join(root, file))

      by_rule =
        for rule <- rules,
            count = count(ratchet, rule, text),
            count > 0,
            into: %{},
            do: {Atom.to_string(rule[:name]), count}

      if by_rule == %{}, do: acc, else: Map.put(acc, file, by_rule)
    end)
  end

  defp files(root, rule) do
    exempt = rule[:exempt] || []

    rule[:files]
    |> Enum.flat_map(&Path.wildcard(Path.join(root, &1)))
    |> Enum.map(&Path.relative_to(&1, root))
    |> Enum.reject(&(&1 in exempt))
    |> Enum.uniq()
  end

  defp count(ratchet, rule, text) do
    case rule[:count] do
      nil -> length(scan(ratchet, text, [rule[:name]]))
      fun -> fun.(text)
    end
  end

  @doc false
  @spec explain(module(), [Ratchet.over()]) :: String.t()
  def explain(_ratchet, []), do: ""

  def explain(ratchet, over) do
    rules = Map.new(ratchet.rules(), &{Atom.to_string(&1[:name]), &1})

    sections =
      Enum.map(over, fn {[file, rule_name], count, allowed} ->
        rule = Map.fetch!(rules, rule_name)

        lines =
          if rule[:pattern] do
            file
            |> File.read!()
            |> then(&scan(ratchet, &1, [rule[:name]]))
            |> Enum.map_join("", &"      line #{&1.line}: #{&1.match}\n")
          else
            ""
          end

        "  #{file}: #{rule_name} #{count} (baseline #{allowed})\n#{lines}    → #{rule[:hint]}\n"
      end)

    intro =
      if function_exported?(ratchet, :intro, 0),
        do: ratchet.intro(),
        else: "New #{ratchet.subject()}, over the baseline."

    outro =
      if function_exported?(ratchet, :outro, 0), do: "\n" <> ratchet.outro() <> "\n", else: ""

    "#{intro}\n\n#{Enum.join(sections, "\n")}#{outro}"
  end
end
