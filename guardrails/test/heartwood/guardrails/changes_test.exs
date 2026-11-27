defmodule Heartwood.Guardrails.ChangesTest do
  @moduledoc """
  `bin/changes`, which CI runs (through `actions/changes`) to skip the jobs
  a change doesn't need: what it prints for a change between two commits of
  a throwaway app repository, for paths on stdin, and for `--all`, with the
  app's prose and areas from `dev/guardrails/config.sh`.
  """
  use ExUnit.Case, async: true

  import Heartwood.Test.GitRepo

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp} do
    %{dir: init!(Path.join(tmp, "app"))}
  end

  defp settings!(dir, lines) do
    path = Path.join(dir, "dev/guardrails/config.sh")
    File.write!(path, File.read!(path) <> lines)
  end

  # Commits only the paths given (nil deletes one), leaving the app's own
  # setup (dev/, deps/) out of the change.
  defp commit!(dir, changes) do
    for {path, contents} <- changes do
      if contents do
        write!(dir, path, contents)
        git!(dir, ["add", path])
      else
        git!(dir, ["rm", "-q", path])
      end
    end

    git!(dir, ["commit", "-q", "--no-verify", "-m", "change"])
    head(dir)
  end

  defp changes(dir, args, input \\ nil) do
    {out, status} =
      if input,
        do: sh(dir, "printf '%s' '#{input}' | #{script("bin/changes")} #{Enum.join(args, " ")}"),
        else: cmd(dir, script("bin/changes"), args)

    {Map.new(String.split(out, "\n", trim: true), &line/1), status}
  end

  defp line(line) do
    [key, value] = String.split(line, "=", parts: 2)
    {key, value}
  end

  defp between(dir, change) do
    base = head(dir)
    tip = commit!(dir, change)
    {result, 0} = changes(dir, [base, tip])
    result
  end

  describe "with no areas" do
    test "a change to code is code", %{dir: dir} do
      assert %{"code" => "true", "areas" => "{}"} = between(dir, [{"lib/b.ex", "x"}])
    end

    test "a change to the prose only isn't", %{dir: dir} do
      assert %{"code" => "false"} =
               between(dir, [{"docs/guide.md", "x"}, {"runbooks/r.md", "x"}, {"README.md", "x"}])
    end

    test "Markdown outside the prose list is code", %{dir: dir} do
      assert %{"code" => "true"} = between(dir, [{"lib/notes.md", "x"}])
    end

    test "a move from code into the prose is code: the code is gone", %{dir: dir} do
      commit!(dir, [{"lib/b.ex", "x"}])
      base = head(dir)
      File.mkdir_p!(Path.join(dir, "docs"))
      git!(dir, ["mv", "lib/b.ex", "docs/b.ex"])
      git!(dir, ["commit", "-q", "--no-verify", "-m", "move"])

      assert {%{"code" => "true"}, 0} = changes(dir, [base, head(dir)])
    end

    test "a deletion is code", %{dir: dir} do
      assert %{"code" => "true"} = between(dir, [{"a.ex", nil}])
    end

    test "HEARTWOOD_CI_PROSE adds files that are prose to CI", %{dir: dir} do
      settings!(dir, ~s(HEARTWOOD_CI_PROSE="AGENTS.md PRODUCT.md"\n))
      assert %{"code" => "false"} = between(dir, [{"AGENTS.md", "x"}, {"PRODUCT.md", "x"}])
      assert %{"code" => "true"} = between(dir, [{"DESIGN.md", "x"}])
    end
  end

  describe "with areas" do
    setup %{dir: dir} do
      settings!(dir, ~s(HEARTWOOD_CI_AREAS="api=api/ web=web/"\n))
      :ok
    end

    test "code in an area touches only that area", %{dir: dir} do
      assert %{"code" => "true", "areas" => ~s({"api":true,"web":false})} =
               between(dir, [{"api/lib/x.ex", "x"}])
    end

    test "code in two areas touches both", %{dir: dir} do
      assert %{"areas" => ~s({"api":true,"web":true})} =
               between(dir, [{"api/x.ex", "x"}, {"web/y.ex", "x"}])
    end

    test "code outside every area touches them all", %{dir: dir} do
      assert %{"areas" => ~s({"api":true,"web":true})} = between(dir, [{"flake.nix", "x"}])
    end

    test "prose in an area touches nothing", %{dir: dir} do
      assert %{"code" => "false", "areas" => ~s({"api":false,"web":false})} =
               between(dir, [{"docs/api.md", "x"}])
    end

    test "--all touches everything, for a push or a scheduled run", %{dir: dir} do
      assert {%{"code" => "true", "areas" => ~s({"api":true,"web":true})}, 0} =
               changes(dir, ["--all"])
    end

    test "reads paths from stdin with no commits", %{dir: dir} do
      assert {%{"code" => "true", "areas" => ~s({"api":false,"web":true})}, 0} =
               changes(dir, [], "web/a.ex\ndocs/b.md")
    end
  end

  test "fails on an area whose path doesn't end in /, which would claim its neighbours",
       %{dir: dir} do
    settings!(dir, ~s(HEARTWOOD_CI_AREAS="ui=ui"\n))
    {out, status} = cmd(dir, script("bin/changes"), ["--all"])

    assert status != 0
    assert out =~ ~s("ui=ui" isn't name=path/)
  end

  test "fails without the app's settings, so CI runs everything", %{dir: dir} do
    File.rm!(Path.join(dir, "dev/guardrails/config.sh"))
    {out, status} = cmd(dir, script("bin/changes"), ["--all"])

    assert status != 0
    assert out =~ "dev/guardrails/config.sh is missing"
  end

  test "fails on an unknown base commit", %{dir: dir} do
    {_out, status} = cmd(dir, script("bin/changes"), ["0000000", "HEAD"])
    assert status != 0
  end
end
