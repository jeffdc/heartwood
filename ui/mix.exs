defmodule Heartwood.UI.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/jeffdc/heartwood"

  def project do
    [
      app: :heartwood_ui,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: false,
      # LiveView's compiler writes the manifests of the colocated hooks and
      # CSS, which the apps import.
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      # The preview recompiles on reload (dev.exs).
      listeners: [Phoenix.CodeReloader],
      deps: deps(),
      description:
        "Function components, with their hooks and CSS, shared by Oak Compendium and Gallformers.",
      source_url: @source_url,
      dialyzer: dialyzer(),
      aliases: aliases()
    ]
  end

  def cli, do: [preferred_envs: [precommit: :test]]

  def application, do: [extra_applications: [:logger]]

  defp deps do
    [
      {:phoenix_live_view, "~> 1.2"},
      {:lazy_html, ">= 0.1.0", only: :test},
      # The preview (dev.exs, `mix dev`).
      {:bandit, "~> 1.5", only: :dev},
      {:jason, "~> 1.2", only: [:dev, :test]},
      {:esbuild, "~> 0.10", only: :dev},
      {:phoenix_live_reload, "~> 1.6", only: :dev},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp dialyzer do
    [
      plt_core_path: "priv/plts/core.plt",
      plt_local_path: "priv/plts/project.plt",
      flags: [:error_handling, :unknown]
    ]
  end

  defp aliases do
    [
      dev: "run --no-halt dev.exs",
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
