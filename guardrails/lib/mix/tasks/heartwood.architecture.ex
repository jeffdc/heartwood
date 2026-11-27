defmodule Mix.Tasks.Heartwood.Architecture do
  @shortdoc "Write the architecture review's packet"

  @moduledoc """
  Writes the packet for a periodic architecture review and prints its path.
  A reviewer with fresh context follows the packet (heartwood's
  `review/architect.md` is in it) and keeps its report with
  `bin/record-architecture`. Run it once per run, then give the same packet
  to each model.

      mix heartwood.architecture

  The evidence comes from the Mix project it runs in: its `mix xref` graph,
  the ratchets in `config :heartwood_guardrails, ratchets: [...]` and
  `mix heartwood.status`; the rest from the repository
  (`Heartwood.Guardrails.Architecture` lists it, with the settings).

  Ratchets in `test/support` are compiled only in the test environment: the
  app's `cli/0` sets `preferred_envs: ["heartwood.architecture": :test]`.
  """
  use Mix.Task

  alias Heartwood.Guardrails.Architecture
  alias Mix.Tasks.Heartwood.Status

  @requirements ["app.config"]

  @impl Mix.Task
  def run(_args) do
    {root, 0} = System.cmd("git", ["rev-parse", "--show-toplevel"])

    evidence = %{
      graph: xref_graph(),
      ratchets: Application.get_env(:heartwood_guardrails, :ratchets, []),
      status: Status.lines()
    }

    Mix.shell().info(Architecture.write!(String.trim(root), evidence))
  end

  defp xref_graph do
    path =
      Path.join(System.tmp_dir!(), "heartwood-xref-#{System.unique_integer([:positive])}.json")

    try do
      Mix.Task.run("xref", ["graph", "--format", "json", "--output", path])
      path |> File.read!() |> Jason.decode!()
    after
      File.rm(path)
    end
  end
end
