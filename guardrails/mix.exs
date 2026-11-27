defmodule Heartwood.Guardrails.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/jeffdc/heartwood"

  def project do
    [
      app: :heartwood_guardrails,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: false,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      description:
        "Ratchets, retirements, git hooks and the reuse review shared by Oak Compendium and Gallformers.",
      source_url: @source_url,
      aliases: aliases()
    ]
  end

  def cli, do: [preferred_envs: [precommit: :test]]

  def application, do: [extra_applications: [:logger]]

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:jason, "~> 1.2"},
      # Started by DuplicateCode when it runs, not with the app.
      {:credo, "~> 1.7", runtime: false}
    ]
  end

  defp aliases do
    [
      precommit: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict",
        "deps.unlock --check-unused",
        "test"
      ]
    ]
  end
end
