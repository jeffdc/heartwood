defmodule Heartwood.Guardrails.RatchetTest do
  # Reads and writes baselines in the working directory: not async.
  use ExUnit.Case, async: false

  import Heartwood.Test.InDir

  alias Heartwood.Guardrails.Assertions
  alias Heartwood.Guardrails.Ratchet

  defmodule Fixed do
    @moduledoc false
    @behaviour Heartwood.Guardrails.Ratchet

    @impl true
    def subject, do: "widgets"

    @impl true
    def counts, do: Process.get(:counts, %{})

    @impl true
    def baseline_path, do: "test/support/widgets.json"

    @impl true
    def explain(over), do: "Too many widgets: #{inspect(over)}"
  end

  describe "compare/2" do
    test "a count over its baseline is over, with what the baseline allows" do
      current = %{"lib/a.ex" => %{"radius" => 3}, "lib/new.ex" => %{"radius" => 1}}
      baseline = %{"lib/a.ex" => %{"radius" => 2}}

      assert Ratchet.compare(current, baseline).over == [
               {["lib/a.ex", "radius"], 3, 2},
               {["lib/new.ex", "radius"], 1, 0}
             ]
    end

    test "a count below its baseline, or gone, is under" do
      current = %{"lib/a.ex" => %{"radius" => 1}}
      baseline = %{"lib/a.ex" => %{"radius" => 2, "shadow" => 1}}

      assert Ratchet.compare(current, baseline) == %{
               over: [],
               under: [["lib/a.ex", "radius"], ["lib/a.ex", "shadow"]]
             }
    end

    test "flat counts compare by key" do
      assert Ratchet.compare(%{"a.ex + b.ex" => 4}, %{"a.ex + b.ex" => 2, "c.ex + d.ex" => 2}) ==
               %{over: [{["a.ex + b.ex"], 4, 2}], under: [["c.ex + d.ex"]]}
    end
  end

  describe "baselines" do
    @describetag :tmp_dir

    test "are written sorted, with a final newline, and read back", %{tmp_dir: dir} do
      Process.put(:counts, %{"lib/b.ex" => %{"z" => 1, "a" => 2}, "lib/a.ex" => %{"q" => 1}})

      in_dir(dir, fn ->
        assert {"test/support/widgets.json", 4} = Ratchet.write_baseline(Fixed)

        text = File.read!("test/support/widgets.json")
        assert text =~ ~r/"lib\/a.ex".*"lib\/b.ex"/s
        assert text =~ ~r/"a": 2,\s+"z": 1/
        assert String.ends_with?(text, "}\n")
        assert Ratchet.read_baseline(Fixed) == Fixed.counts()
      end)
    end

    test "a missing baseline reads as empty", %{tmp_dir: dir} do
      assert in_dir(dir, fn -> Ratchet.read_baseline(Fixed) end) == %{}
    end
  end

  describe "assert_ratchet/1" do
    @describetag :tmp_dir

    test "passes at the baseline", %{tmp_dir: dir} do
      Process.put(:counts, %{"a" => 1})

      in_dir(dir, fn ->
        Ratchet.write_baseline(Fixed)
        assert Assertions.assert_ratchet(Fixed)
      end)
    end

    test "fails over the baseline with the ratchet's explanation", %{tmp_dir: dir} do
      Process.put(:counts, %{"a" => 2})

      error =
        assert_raise ExUnit.AssertionError, fn ->
          in_dir(dir, fn -> Assertions.assert_ratchet(Fixed) end)
        end

      assert error.message =~ ~s|Too many widgets: [{["a"], 2, 0}]|
    end

    test "fails under the baseline, naming the task that locks it in", %{tmp_dir: dir} do
      in_dir(dir, %{"test/support/widgets.json" => ~s({"a": 2})}, fn ->
        Process.put(:counts, %{"a" => 1})

        error = assert_raise ExUnit.AssertionError, fn -> Assertions.assert_ratchet(Fixed) end

        assert error.message =~ "Widgets went down in 1 place(s)"
        assert error.message =~ "mix heartwood.baseline Heartwood.Guardrails.RatchetTest.Fixed"
      end)
    end
  end
end
