defmodule Heartwood.Guardrails.MixProject do
  use Mix.Project

  @version "0.2.3"
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
      dialyzer: dialyzer(),
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
      {:credo, "~> 1.7", runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp dialyzer do
    [
      plt_core_path: "priv/plts/core.plt",
      plt_local_path: "priv/plts/project.plt",
      plt_add_apps: [:mix, :ex_unit, :credo],
      flags: [
        :error_handling,
        :unknown
      ]
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
