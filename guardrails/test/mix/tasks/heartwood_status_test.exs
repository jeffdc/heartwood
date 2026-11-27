defmodule Mix.Tasks.Heartwood.StatusTest do
  use ExUnit.Case, async: true

  alias Heartwood.Test.GitRepo
  alias Mix.Tasks.Heartwood.Status

  @url "https://github.com/jeffdc/heartwood.git"
  @sha "0123456789abcdef0123456789abcdef01234567"

  defp lock(tag),
    do: %{heartwood_guardrails: {:git, @url, @sha, [sparse: "guardrails", tag: tag]}}

  defp deps, do: [{:heartwood_guardrails, github: "jeffdc/heartwood", sparse: "guardrails"}]

  describe "report/3" do
    test "an app on the latest tag says so" do
      assert Status.report(deps(), lock("v0.2.0"), fn @url -> "v0.2.0" end) ==
               ["heartwood_guardrails: v0.2.0, the latest."]
    end

    test "an app behind the latest tag gets the package's changelog" do
      [line] = Status.report(deps(), lock("v0.2.0"), fn _ -> "v0.10.0" end)

      assert line =~ "v0.2.0, behind the latest, v0.10.0"
      assert line =~ "https://github.com/jeffdc/heartwood/blob/main/guardrails/CHANGELOG.md"
    end

    test "an unreachable repository is reported, not an error" do
      assert [line] = Status.report(deps(), lock("v0.2.0"), fn _ -> nil end)
      assert line =~ "the latest tag is unknown"
    end

    test "a local checkout says mix.lock has no entry for it" do
      deps = [{:heartwood_guardrails, path: "/src/heartwood/guardrails"}]

      assert [line] = Status.report(deps, %{}, fn _ -> flunk("no lookup for a path dep") end)
      assert line =~ "the local checkout at /src/heartwood/guardrails"
      assert line =~ "unset HEARTWOOD_PATH"
    end

    test "a dependency not yet fetched" do
      assert [line] = Status.report(deps(), %{}, fn _ -> nil end)
      assert line =~ "not in mix.lock"
    end

    test "only heartwood packages are reported" do
      deps = [{:jason, "~> 1.2"}, {:credo, "~> 1.7", only: :test}]

      assert Status.report(deps, %{}, fn _ -> nil end) == [
               "No heartwood packages in this project's deps."
             ]
    end
  end

  describe "latest_tag/1" do
    @describetag :tmp_dir

    test "is the highest vX.Y.Z tag, by version, not by name", %{tmp_dir: dir} do
      GitRepo.git!(dir, ["init", "-q"])
      GitRepo.git!(dir, ["commit", "-q", "--allow-empty", "-m", "start"])
      for tag <- ~w(v0.2.0 v0.10.0 v0.9.1 not-a-version), do: GitRepo.git!(dir, ["tag", tag])

      assert Status.latest_tag(dir) == "v0.10.0"
    end

    test "is nil when the repository can't be read", %{tmp_dir: dir} do
      assert Status.latest_tag(Path.join(dir, "missing")) == nil
    end
  end
end
