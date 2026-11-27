defmodule Heartwood.Guardrails.RetirementsTest do
  use ExUnit.Case, async: true

  import Heartwood.Guardrails.Assertions

  alias Heartwood.Guardrails.Retirements

  @old Heartwood.Guardrails.Ratchet
  @new Heartwood.Guardrails.Patterns

  describe "outstanding/1" do
    test "an entry whose old module and replacement both exist is outstanding" do
      entry = %{retire: @old, replaced_by: @new, why: "plan.md"}

      assert Retirements.outstanding([entry]) == [entry]
    end

    test "an entry whose old module is gone is done" do
      entry = %{retire: Heartwood.NoSuchModule, replaced_by: @new, why: "plan.md"}

      assert Retirements.outstanding([entry]) == []
    end

    test "an entry whose replacement isn't built yet waits for it" do
      entry = %{retire: @old, replaced_by: Heartwood.NotBuiltYet, why: "plan.md"}

      assert Retirements.outstanding([entry]) == []
    end
  end

  test "explain/1 names each module to delete, its replacement and why" do
    entry = %{retire: @old, replaced_by: @new, why: "docs/plan.md, phase 2"}

    assert Retirements.explain([entry]) =~
             "Heartwood.Guardrails.Ratchet is replaced by Heartwood.Guardrails.Patterns (docs/plan.md, phase 2)"
  end

  @tag :tmp_dir
  test "assert_no_outstanding_retirements/1 fails while an old module is still here",
       %{tmp_dir: dir} do
    path = Path.join(dir, "retirements.exs")
    File.write!(path, "[%{retire: #{inspect(@old)}, replaced_by: #{inspect(@new)}, why: \"x\"}]")

    error = assert_raise ExUnit.AssertionError, fn -> assert_no_outstanding_retirements(path) end
    assert error.message =~ "Replaced code is still here"
  end

  test "heartwood has no outstanding retirements" do
    assert_no_outstanding_retirements()
  end
end
