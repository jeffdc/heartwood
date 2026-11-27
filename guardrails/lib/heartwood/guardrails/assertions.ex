defmodule Heartwood.Guardrails.Assertions do
  @moduledoc """
  The guardrails' tests, as assertions an app's test module calls:

      defmodule MyApp.GuardrailsTest do
        # DuplicateCode runs Credo, which toggles a global output switch: not async.
        use ExUnit.Case, async: false

        import Heartwood.Guardrails.Assertions

        test "styling stays on the design system", do: assert_ratchet(MyAppWeb.Conformance)
        test "no new copied code", do: assert_ratchet(Heartwood.Guardrails.DuplicateCode)
        test "replaced code is deleted", do: assert_no_outstanding_retirements()
      end
  """

  import ExUnit.Assertions

  alias Heartwood.Guardrails.Ratchet
  alias Heartwood.Guardrails.Retirements

  @doc """
  Asserts that no count is over the ratchet's baseline, and that no count
  fell below it without the baseline being lowered. Counts once.
  """
  @spec assert_ratchet(module()) :: true
  def assert_ratchet(ratchet) do
    %{over: over, under: under} = Ratchet.compare(ratchet)

    assert over == [], ratchet.explain(over)
    assert under == [], Ratchet.under_message(ratchet, under)
  end

  @doc "Asserts that every replaced module in the retirements list is gone."
  @spec assert_no_outstanding_retirements(Path.t()) :: true
  def assert_no_outstanding_retirements(path \\ Retirements.path()) do
    outstanding = path |> Retirements.read() |> Retirements.outstanding()

    assert outstanding == [], Retirements.explain(outstanding)
  end
end
