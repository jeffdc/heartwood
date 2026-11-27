defmodule Heartwood.Guardrails.Retirements do
  @moduledoc """
  Replacing means deleting.

  The retirements list names modules being replaced:

      [%{retire: MyApp.OldThing, replaced_by: MyApp.NewThing, why: "docs/plan.md, phase 2"}]

  An entry is outstanding while both modules exist, and
  `Heartwood.Guardrails.Assertions.assert_no_outstanding_retirements/0`
  fails until the old one is deleted. A task that builds a replacement adds
  its entry first, as its failing test, and deletes the old module in the
  same change. Once the old module is gone, remove its entry.

  `why` cites the plan doc, PR or commit behind the replacement.

  The list is `test/support/retirements.exs`, or
  `config :heartwood_guardrails, retirements: path`.
  """

  @type entry :: %{retire: module(), replaced_by: module(), why: String.t()}

  @doc "The retirements list's path."
  @spec path() :: Path.t()
  def path,
    do: Application.get_env(:heartwood_guardrails, :retirements, "test/support/retirements.exs")

  @doc "The entries in the retirements list."
  @spec read(Path.t()) :: [entry()]
  def read(path \\ path()) do
    {entries, _binding} = Code.eval_file(path)
    entries
  end

  @doc "The entries whose old module and replacement both still exist."
  @spec outstanding([entry()]) :: [entry()]
  def outstanding(entries),
    do: Enum.filter(entries, &(exists?(&1.retire) and exists?(&1.replaced_by)))

  @doc "The failure message for outstanding entries."
  @spec explain([entry()]) :: String.t()
  def explain(entries) do
    lines =
      for e <- entries,
          do: "  #{inspect(e.retire)} is replaced by #{inspect(e.replaced_by)} (#{e.why})"

    """
    Replaced code is still here. Delete it in this change, with its tests and
    its callers moved to the replacement, then remove its entry from
    #{path()}:

    #{Enum.join(lines, "\n")}
    """
  end

  defp exists?(module), do: Code.ensure_loaded?(module)
end
