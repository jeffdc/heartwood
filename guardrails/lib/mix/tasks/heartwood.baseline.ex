defmodule Mix.Tasks.Heartwood.Baseline do
  @shortdoc "Lock in ratchets' baselines"

  @moduledoc """
  Recounts each ratchet and writes today's counts as its baseline. Run it
  after removing findings, so the ratchet's test holds the gain. Never run
  it to make new findings pass.

      mix heartwood.baseline MyAppWeb.Conformance
      mix heartwood.baseline Heartwood.Guardrails.DuplicateCode
      mix heartwood.baseline

  With no arguments, it writes every ratchet in
  `config :heartwood_guardrails, ratchets: [...]`.

  Ratchets in `test/support` are compiled only in the test environment: the
  app's `cli/0` sets `preferred_envs: ["heartwood.baseline": :test]`.
  """
  use Mix.Task

  alias Heartwood.Guardrails.Ratchet

  @requirements ["app.config"]

  @impl Mix.Task
  def run(args) do
    ratchets =
      case args do
        [] -> Application.get_env(:heartwood_guardrails, :ratchets, [])
        names -> Enum.map(names, &Module.concat([&1]))
      end

    if ratchets == [] do
      Mix.raise(
        "Name the ratchets to write (mix heartwood.baseline MyAppWeb.Conformance), " <>
          "or list them in config :heartwood_guardrails, ratchets: [...]."
      )
    end

    for ratchet <- ratchets do
      unless Code.ensure_loaded?(ratchet) do
        Mix.raise(
          "#{inspect(ratchet)} isn't compiled in the #{Mix.env()} environment. " <>
            ~s|Set preferred_envs: ["heartwood.baseline": :test] in the app's cli/0.|
        )
      end

      {path, total} = Ratchet.write_baseline(ratchet)

      Mix.shell().info(
        "Wrote #{path}: #{total} findings of #{ratchet.subject()} in the baseline."
      )
    end
  end
end
