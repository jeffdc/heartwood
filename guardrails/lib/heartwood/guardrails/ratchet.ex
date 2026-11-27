defmodule Heartwood.Guardrails.Ratchet do
  @moduledoc """
  A count that may only go down.

  A ratchet counts something the codebase should have less of (styling that
  bypasses the design system, copied code) and holds the counts to a
  baseline: a JSON file in the app, written by `mix heartwood.baseline`.
  `Heartwood.Guardrails.Assertions.assert_ratchet/1` fails both ways: when a
  count goes over its baseline (new findings) and when it goes under it (an
  improvement the baseline should lock in).

  Counts map a key to a count, or to a map of counts one level down:

      %{"lib/app_web/page.ex" => %{"radius" => 2}}   # per file and rule
      %{"lib/a.ex + lib/b.ex" => 2}                 # per set of files

  A ratchet is a module with these callbacks. `Heartwood.Guardrails.Patterns`
  builds one from a list of rules; `Heartwood.Guardrails.DuplicateCode` is one.
  """

  @type counts :: %{String.t() => pos_integer() | %{String.t() => pos_integer()}}

  @typedoc "A count over its baseline: its key path, the count and what the baseline allows."
  @type over :: {[String.t()], pos_integer(), non_neg_integer()}

  @doc ~S|What it counts, for messages: "off-system styling", "copied code".|
  @callback subject() :: String.t()

  @doc "Today's counts, read from the working directory (the app's root)."
  @callback counts() :: counts()

  @doc "The baseline's path, relative to the app's root."
  @callback baseline_path() :: Path.t()

  @doc "Explains the counts that went over their baseline: what was found, and what to do instead."
  @callback explain([over()]) :: String.t()

  @doc "The baseline the ratchet holds to; empty when there is none yet."
  @spec read_baseline(module()) :: counts()
  def read_baseline(ratchet) do
    path = ratchet.baseline_path()
    if File.exists?(path), do: path |> File.read!() |> Jason.decode!(), else: %{}
  end

  @doc """
  Writes today's counts as the baseline, with keys sorted so diffs stay
  readable. Returns the path and the total it holds.
  """
  @spec write_baseline(module()) :: {Path.t(), non_neg_integer()}
  def write_baseline(ratchet) do
    path = ratchet.baseline_path()
    counts = ratchet.counts()
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, [Jason.encode_to_iodata!(sorted(counts), pretty: true), "\n"])
    {path, total(counts)}
  end

  @doc """
  Compares today's counts with the baseline: `over` lists the counts above
  it, `under` the key paths whose count fell below it.
  """
  @spec compare(module()) :: %{over: [over()], under: [[String.t()]]}
  def compare(ratchet), do: compare(ratchet.counts(), read_baseline(ratchet))

  @doc false
  @spec compare(counts(), counts()) :: %{over: [over()], under: [[String.t()]]}
  def compare(current, baseline) do
    current = flatten(current)
    baseline = flatten(baseline)

    over =
      for {path, count} <- Enum.sort(current),
          allowed = Map.get(baseline, path, 0),
          count > allowed,
          do: {path, count, allowed}

    under = for {path, count} <- Enum.sort(baseline), Map.get(current, path, 0) < count, do: path

    %{over: over, under: under}
  end

  @doc "The failure message for counts that fell below the baseline."
  @spec under_message(module(), [[String.t()]]) :: String.t()
  def under_message(ratchet, under) do
    places = Enum.map_join(under, "\n", &"  #{Enum.join(&1, ": ")}")

    """
    #{String.capitalize(ratchet.subject())} went down in #{length(under)} place(s):

    #{places}

    Lock it in with:

        mix heartwood.baseline #{inspect(ratchet)}
    """
  end

  @doc "The sum of all counts."
  @spec total(counts()) :: non_neg_integer()
  def total(counts), do: counts |> flatten() |> Map.values() |> Enum.sum()

  defp flatten(counts) do
    Enum.reduce(counts, %{}, fn
      {key, count}, acc when is_integer(count) ->
        Map.put(acc, [key], count)

      {key, nested}, acc when is_map(nested) ->
        Enum.reduce(nested, acc, fn {inner, count}, acc -> Map.put(acc, [key, inner], count) end)
    end)
  end

  defp sorted(counts) do
    counts
    |> Enum.sort()
    |> Enum.map(fn
      {key, nested} when is_map(nested) -> {key, Jason.OrderedObject.new(Enum.sort(nested))}
      pair -> pair
    end)
    |> Jason.OrderedObject.new()
  end
end
