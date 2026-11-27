defmodule Mix.Tasks.Heartwood.BaselineTest do
  # Writes in the working directory and sets application env: not async.
  use ExUnit.Case, async: false

  import Heartwood.Test.InDir

  alias Mix.Tasks.Heartwood.Baseline

  defmodule Widgets do
    @moduledoc false
    @behaviour Heartwood.Guardrails.Ratchet

    @impl true
    def subject, do: "widgets"

    @impl true
    def counts, do: %{"lib/a.ex" => %{"widget" => 2}}

    @impl true
    def baseline_path, do: "test/support/widgets.json"

    @impl true
    def explain(_over), do: ""
  end

  setup do
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)
  end

  @tag :tmp_dir
  test "writes the named ratchet's baseline", %{tmp_dir: dir} do
    in_dir(dir, fn ->
      Baseline.run([inspect(Widgets)])

      assert File.read!("test/support/widgets.json") =~ ~s("widget": 2)
    end)

    assert_received {:mix_shell, :info, [message]}
    assert message =~ "Wrote test/support/widgets.json: 2 findings of widgets"
  end

  @tag :tmp_dir
  test "with no names, writes the configured ratchets", %{tmp_dir: dir} do
    Application.put_env(:heartwood_guardrails, :ratchets, [Widgets])
    on_exit(fn -> Application.delete_env(:heartwood_guardrails, :ratchets) end)

    in_dir(dir, fn ->
      Baseline.run([])
      assert File.exists?("test/support/widgets.json")
    end)
  end

  test "with no names and none configured, says what to do" do
    assert_raise Mix.Error, ~r/Name the ratchets to write/, fn -> Baseline.run([]) end
  end

  test "a ratchet that isn't compiled says why" do
    assert_raise Mix.Error, ~r/isn't compiled in the test environment/, fn ->
      Baseline.run(["MyApp.NoSuchRatchet"])
    end
  end
end
