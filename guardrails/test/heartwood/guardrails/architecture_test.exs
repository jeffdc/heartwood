defmodule Heartwood.Guardrails.ArchitectureTest do
  @moduledoc """
  The architecture review: `Heartwood.Guardrails.Architecture` writes the
  packet in git's common directory, and `bin/record-architecture` keeps
  each model's report beside it.
  """
  # ratchets/1 reads a baseline from the working directory: not async.
  use ExUnit.Case, async: false

  import Heartwood.Test.GitRepo

  alias Heartwood.Guardrails.Architecture

  @moduletag :tmp_dir

  defmodule Widgets do
    @moduledoc false
    @behaviour Heartwood.Guardrails.Ratchet

    @impl true
    def subject, do: "widgets"
    @impl true
    def counts, do: %{"lib/a.ex" => %{"radius" => 2}, "lib/b.ex + lib/c.ex" => 1}
    @impl true
    def baseline_path, do: "widgets.json"
    @impl true
    def explain(_over), do: ""
  end

  @date ~D[2026-11-26]
  @evidence %{graph: %{}, ratchets: [], status: ["heartwood_guardrails: v0.1.1, the latest."]}

  defp commit!(dir, path, contents, message) do
    write!(dir, path, contents)
    git!(dir, ["add", path])
    git!(dir, ["commit", "-q", "--no-verify", "-m", message])
  end

  defp run_id(dir), do: "2026-11-26-" <> String.trim(git!(dir, ["rev-parse", "--short", "HEAD"]))

  describe "settings" do
    test "have defaults", %{tmp_dir: dir} do
      init!(dir)

      assert Architecture.settings(dir) == %{
               app: "testapp",
               docs: "docs/architecture",
               questions: "dev/guardrails/architecture.md",
               depth: 3
             }
    end

    test "come from dev/guardrails/config.sh", %{tmp_dir: dir} do
      init!(dir)

      File.write!(
        Path.join(dir, "dev/guardrails/config.sh"),
        "HEARTWOOD_APP=other\nHEARTWOOD_ARCHITECTURE=notes/arch/\n" <>
          "HEARTWOOD_ARCHITECTURE_QUESTIONS=notes/q.md\nHEARTWOOD_GRAPH_DEPTH=4\n"
      )

      assert Architecture.settings(dir) == %{
               app: "other",
               docs: "notes/arch",
               questions: "notes/q.md",
               depth: 4
             }
    end
  end

  test "the graph folds files to contexts, leaving out tests and dependencies within one" do
    graph = %{
      "lib/app/species.ex" => %{
        "lib/app/sources.ex" => "runtime",
        "lib/app/species/merge.ex" => "runtime"
      },
      "lib/app/species/merge.ex" => %{
        "lib/app/sources/text.ex" => "export",
        "lib/app/sources.ex" => "runtime"
      },
      "lib/app_web/page.ex" => %{"lib/app/species.ex" => "compile"},
      "test/support/fixtures.ex" => %{"lib/app/species.ex" => "runtime"}
    }

    assert Architecture.fold(graph, 3) == [
             {"lib/app/species", "lib/app/sources", %{"export" => 1, "runtime" => 2}},
             {"lib/app_web/page", "lib/app/species", %{"compile" => 1}}
           ]
  end

  describe "commits since the last review" do
    test "are those after the last commit that changed reviews.md", %{tmp_dir: dir} do
      init!(dir)
      commit!(dir, "docs/architecture/reviews.md", "# Reviews\n", "Record a review")
      reviewed = String.trim(git!(dir, ["rev-parse", "--short", "HEAD"]))
      commit!(dir, "lib/b.ex", "defmodule B do\nend\n", "Add B")
      commit!(dir, "docs/architecture/README.md", "# Architecture\n", "Describe B")

      assert {^reviewed, [describe, add]} = Architecture.commits(dir, "docs/architecture")
      assert describe =~ ~r/^\w+ \d{4}-\d\d-\d\d Describe B$/
      assert add =~ "Add B"
    end

    test "are every commit before the first review", %{tmp_dir: dir} do
      init!(dir)

      assert {nil, [start]} = Architecture.commits(dir, "docs/architecture")
      assert start =~ "start"
    end
  end

  describe "ratchets" do
    test "show each count against its baseline", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "widgets.json"), ~s|{"lib/a.ex": {"radius": 3}, "lib/d.ex": 1}|)

      text = File.cd!(dir, fn -> Architecture.ratchets([Widgets]) end)

      assert text =~ "Total 3, baseline 4 (`widgets.json`)."
      assert text =~ "- lib/a.ex: radius: 2 (baseline 3)"
      assert text =~ "- lib/b.ex + lib/c.ex: 1 (baseline 0)"
      assert text =~ "- lib/d.ex: 0 (baseline 1)"
    end

    test "say when none are configured or one isn't compiled" do
      assert Architecture.ratchets([]) =~ "None configured"

      assert Architecture.ratchets([NotCompiled.Anywhere]) =~
               "MIX_ENV=test mix heartwood.architecture"
    end
  end

  describe "the packet" do
    test "holds the instructions, the questions, how to record and the evidence", %{tmp_dir: dir} do
      init!(dir)
      commit!(dir, "docs/architecture/reviews.md", "# Reviews\n", "Record a review")

      commit!(
        dir,
        "docs/architecture/README.md",
        "# Architecture\n\n```mermaid\nA --> B\n```\n",
        "Describe"
      )

      write!(dir, "dev/guardrails/architecture.md", "Does every context own its tables?\n")

      evidence = %{@evidence | graph: %{"lib/app/a.ex" => %{"lib/app/b.ex" => "runtime"}}}
      path = Architecture.write!(dir, evidence, @date)
      packet = File.read!(path)
      run = run_id(dir)

      assert path == Path.join([dir, ".git", "testapp-architecture", run, "packet.md"])
      assert packet =~ "run: #{run}"
      assert packet =~ "### Your questions, in order"
      assert packet =~ "Does every context own its tables?"
      assert packet =~ "bin/record-architecture #{run} <model> - <<'REPORT'"
      assert packet =~ "(1):\n\n    "
      assert packet =~ "Describe"
      assert packet =~ "- lib/app/a → lib/app/b (runtime 1)"
      assert packet =~ "None configured"
      assert packet =~ "heartwood_guardrails: v0.1.1, the latest."
      assert packet =~ "### docs/architecture/README.md\n\n~~~~markdown\n# Architecture\n"
      assert packet =~ "### docs/architecture/reviews.md"
    end

    test "says when the repository has no questions or architecture docs", %{tmp_dir: dir} do
      init!(dir)

      packet = dir |> Architecture.write!(@evidence, @date) |> File.read!()

      assert packet =~ "## This repository's questions\n\nNone."
      assert packet =~ "None found in `docs/architecture/`."
    end

    test "from a worktree goes in the clone's common directory", %{tmp_dir: dir} do
      init!(Path.join(dir, "main"))
      # The settings are committed, so the worktree has them.
      commit!(
        Path.join(dir, "main"),
        "dev/guardrails/config.sh",
        "HEARTWOOD_APP=testapp\n",
        "Settings"
      )

      git!(Path.join(dir, "main"), [
        "worktree",
        "add",
        "-q",
        "-b",
        "other",
        Path.join(dir, "other")
      ])

      path = Architecture.write!(Path.join(dir, "other"), @evidence, @date)

      assert String.starts_with?(path, Path.join([dir, "main", ".git", "testapp-architecture"]))
    end
  end

  describe "record-architecture" do
    setup %{tmp_dir: dir} do
      init!(dir)
      Architecture.write!(dir, @evidence, @date)
      %{run: run_id(dir)}
    end

    defp record(dir, args, report),
      do:
        sh(
          dir,
          "printf '%s' '#{report}' | #{script("bin/record-architecture")} #{Enum.join(args, " ")} -"
        )

    test "keeps a model's report beside the run's packet", %{tmp_dir: dir, run: run} do
      {out, 0} = record(dir, [run, "model-a"], "## Proposed rules\n\nNone.")

      path = Path.join([dir, ".git", "testapp-architecture", run, "model-a.md"])
      assert String.trim(out) == path
      assert File.read!(path) == "run: #{run}\nmodel: model-a\n\n## Proposed rules\n\nNone.\n"
    end

    test "keeps a report from a file", %{tmp_dir: dir, run: run} do
      write!(dir, "report.md", "No findings.\n")

      {_, 0} = cmd(dir, script("bin/record-architecture"), [run, "model-a", "report.md"])

      assert File.read!(Path.join([dir, ".git", "testapp-architecture", run, "model-a.md"])) =~
               "No findings."
    end

    test "refuses a second report from the same model", %{tmp_dir: dir, run: run} do
      {_, 0} = record(dir, [run, "model-a"], "first")
      {out, status} = record(dir, [run, "model-a"], "second")

      assert status != 0
      assert out =~ "first answer stands"

      assert File.read!(Path.join([dir, ".git", "testapp-architecture", run, "model-a.md"])) =~
               "first"

      assert {_, 0} = record(dir, [run, "model-b"], "another view")
    end

    test "refuses an empty report, a run with no packet, and an odd model name", %{
      tmp_dir: dir,
      run: run
    } do
      assert {_, status} = record(dir, [run, "model-a"], "")
      assert status != 0

      assert {out, status} = record(dir, ["2020-01-01-abc1234", "model-a"], "report")
      assert status != 0
      assert out =~ "has no packet"

      assert {out, status} = record(dir, [run, "../escape"], "report")
      assert status != 0
      assert out =~ "may hold only"
    end
  end
end
