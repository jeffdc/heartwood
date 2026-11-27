defmodule Heartwood.Guardrails.DuplicateCode do
  @moduledoc """
  Copied code, as a ratchet: Credo's `DuplicatedCode` check, run with the
  `duplicates` config in the app's `.credo.exs`, against a baseline of what
  it found when the check was turned on.

  The app's `.credo.exs` needs a config named `duplicates` that enables the
  check:

      %{
        name: "duplicates",
        files: %{included: ["lib/", "test/"], excluded: [~r"/_build/", ~r"/deps/"]},
        checks: %{enabled: [{Credo.Check.Design.DuplicatedCode, [mass_threshold: 40]}]}
      }

  A finding is keyed by the files that share the copied block, not its
  lines, so the baseline holds when code moves within a file. Credo reports
  one finding per file in the set, so a pair copied once counts 2.

  The baseline is `test/support/duplicate_code_baseline.json`, or
  `config :heartwood_guardrails, duplicate_code_baseline: path`.
  """

  @behaviour Heartwood.Guardrails.Ratchet

  alias Credo.CLI.Output.Shell

  @config_name "duplicates"

  @impl true
  def subject, do: "copied code"

  @impl true
  def baseline_path,
    do:
      Application.get_env(
        :heartwood_guardrails,
        :duplicate_code_baseline,
        "test/support/duplicate_code_baseline.json"
      )

  @impl true
  def counts, do: counts([])

  @doc """
  How many copied-code findings each set of files has, keyed by `key/1`.

  With `only: dir`, reads just `dir`, with the check settings of the
  `duplicates` config.
  """
  @spec counts(keyword()) :: %{String.t() => pos_integer()}
  def counts(opts) do
    opts
    |> issues()
    |> Enum.frequencies_by(&key([&1.filename | files_in(&1.message)]))
  end

  @doc ~S|The baseline key for a set of files: sorted, unique, joined with " + ".|
  @spec key([String.t()]) :: String.t()
  def key(files), do: files |> Enum.uniq() |> Enum.sort() |> Enum.join(" + ")

  @impl true
  def explain(over) do
    lines =
      for {[files], count, allowed} <- over, do: "  #{files}: #{count} (baseline #{allowed})"

    """
    New copied code. Call the existing code instead of copying it, or move the
    shared part into one function both call:

    #{Enum.join(lines, "\n")}

    See each block with: mix credo --config-name #{@config_name}
    Never write the baseline to make new copied code pass.
    """
  end

  defp issues(opts) do
    start_credo()
    argv = ["--mute-exit-status" | config_args(opts[:only])]

    Shell.suppress_output(fn -> send(self(), {:credo, Credo.run(argv)}) end)

    receive do
      {:credo, exec} -> Credo.Execution.get_issues(exec)
    end
  end

  # Credo's services. Under `mix precommit`, `credo --strict` has already
  # started them in this VM without starting the application, so starting
  # the application finds its supervisor running.
  defp start_credo do
    case Application.ensure_all_started(:credo) do
      {:ok, _apps} -> :ok
      {:error, {:credo, {{:already_started, _pid}, _mfa}}} -> :ok
    end
  end

  defp config_args(nil), do: ["--config-name", @config_name]

  defp config_args(dir) do
    checks = %{enabled: [{Credo.Check.Design.DuplicatedCode, check_params()}]}
    config = %{configs: [%{name: @config_name, files: %{included: [dir]}, checks: checks}]}
    path = Path.join(dir, ".credo.exs")
    File.write!(path, inspect(config, limit: :infinity))
    ["--config-file", path, "--config-name", @config_name]
  end

  # The check's settings in the `duplicates` config of `.credo.exs`.
  defp check_params do
    {%{configs: configs}, _} = Code.eval_file(".credo.exs")
    %{checks: %{enabled: checks}} = Enum.find(configs, &(&1.name == @config_name))

    {Credo.Check.Design.DuplicatedCode, params} =
      List.keyfind(checks, Credo.Check.Design.DuplicatedCode, 0)

    params
  end

  # The other files a finding names: "Duplicate code found in lib/a.ex:12, lib/b.ex:40 (mass: 45)."
  defp files_in(message), do: Regex.scan(~r/[\w\/.\-]+\.exs?\b/, message) |> List.flatten()
end
