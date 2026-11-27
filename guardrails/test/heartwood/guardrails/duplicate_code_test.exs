defmodule Heartwood.Guardrails.DuplicateCodeTest do
  # Runs Credo, which toggles Credo's global output switch: not async.
  use ExUnit.Case, async: false

  import Heartwood.Guardrails.Assertions

  alias Heartwood.Guardrails.DuplicateCode

  @copied """
  defmodule Copied do
    def rows(rows) do
      rows
      |> Enum.filter(&(&1.kind == :plant and &1.rank in [:species, :subspecies]))
      |> Enum.map(&%{id: "taxon:\#{&1.id}", name: &1.name, meta: Enum.join(&1.aliases, ", ")})
      |> Enum.sort_by(&{&1.meta, String.downcase(&1.name)})
      |> Enum.take(20)
    end
  end
  """

  @own """
  defmodule Own do
    def total(items), do: items |> Enum.map(& &1.count) |> Enum.sum()
  end
  """

  describe "counts/1" do
    @tag :tmp_dir
    test "a block copied between two files is a finding for that pair", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "a.ex"), @copied)
      File.write!(Path.join(dir, "b.ex"), String.replace(@copied, "Copied", "CopiedAgain"))
      File.write!(Path.join(dir, "c.ex"), @own)

      # Credo names files relative to the project root.
      pair =
        DuplicateCode.key(for f <- ["b.ex", "a.ex"], do: Path.relative_to_cwd(Path.join(dir, f)))

      assert DuplicateCode.counts(only: dir) == %{pair => 2}
    end

    @tag :tmp_dir
    test "code that isn't copied has no findings", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "a.ex"), @copied)
      File.write!(Path.join(dir, "c.ex"), @own)

      assert DuplicateCode.counts(only: dir) == %{}
    end
  end

  test "explain/1 lists each set of files and how to see the blocks" do
    message = DuplicateCode.explain([{["lib/a.ex + lib/b.ex"], 4, 2}])

    assert message =~ "lib/a.ex + lib/b.ex: 4 (baseline 2)"
    assert message =~ "mix credo --config-name duplicates"
  end

  # Heartwood holds itself to the ratchet it ships. One test, so Credo reads
  # the codebase once.
  test "heartwood's own code has no copied code beyond its baseline" do
    assert_ratchet(DuplicateCode)
  end
end
