defmodule Heartwood.Guardrails.CommitGateTest do
  @moduledoc """
  The commit gate: `hooks/pre-commit`, run through the app's
  `dev/githooks/pre-commit` shim that `hooks/install` makes git run, blocks
  any `git commit` until the tree being committed has a passing reuse
  review, recorded by `bin/record-review` from `bin/review-packet`'s packet.
  """
  use ExUnit.Case, async: true

  import Heartwood.Test.GitRepo

  @moduletag :tmp_dir

  setup %{tmp_dir: dir} do
    init!(dir)
    write!(dir, "a.ex", "defmodule A do\n  def new_fun(x), do: x\nend\n")
    git!(dir, ["add", "a.ex"])
    :ok
  end

  # Through deps/, as the app runs it.
  defp packet(dir),
    do: cmd(dir, Path.join(dir, "deps/heartwood_guardrails/guardrails/bin/review-packet"), [])

  defp review(dir, verdict) do
    {packet, 0} = packet(dir)
    write!(dir, "report.md", "No findings.\n")
    {_, 0} = cmd(dir, script("bin/record-review"), [verdict, "report.md"])
    String.trim(packet)
  end

  describe "a plain git commit" do
    test "with no review is blocked, and nothing is committed", %{tmp_dir: dir} do
      before = head(dir)

      {out, status} = git(dir, ["commit", "-m", "Add new_fun"])

      assert status != 0
      assert out =~ "hasn't had a reuse review"
      assert head(dir) == before
    end

    test "with a passing review goes through", %{tmp_dir: dir} do
      before = head(dir)
      review(dir, "pass")

      assert {_, 0} = git(dir, ["commit", "-q", "-m", "Add new_fun"])
      assert head(dir) != before
    end

    test "the review blocked is blocked", %{tmp_dir: dir} do
      review(dir, "block")

      {out, status} = git(dir, ["commit", "-m", "Add new_fun"])

      assert status != 0
      assert out =~ "the reuse review blocked this change"
    end

    test "after restaging needs a new review", %{tmp_dir: dir} do
      review(dir, "pass")
      write!(dir, "b.ex", "defmodule B do\nend\n")
      git!(dir, ["add", "b.ex"])

      assert {_, status} = git(dir, ["commit", "-m", "Add new_fun"])
      assert status != 0
    end

    test "with -a is checked against the tree it would commit", %{tmp_dir: dir} do
      review(dir, "pass")
      write!(dir, "a.ex", "defmodule A do\n  def other(x), do: x\nend\n")

      assert {_, status} = git(dir, ["commit", "-a", "-m", "Add new_fun"])
      assert status != 0
    end

    test "that concludes a merge goes through", %{tmp_dir: dir} do
      git!(dir, ["commit", "-q", "--no-verify", "-m", "Add new_fun"])
      git!(dir, ["checkout", "-q", "-b", "side", "HEAD~1"])
      write!(dir, "c.ex", "defmodule C do\nend\n")
      git!(dir, ["add", "c.ex"])
      git!(dir, ["commit", "-q", "--no-verify", "-m", "Add C"])
      git!(dir, ["checkout", "-q", "-"])
      git!(dir, ["merge", "-q", "--no-ff", "--no-commit", "side"])

      assert {_, 0} = git(dir, ["commit", "-q", "--no-edit"])
    end

    test "on a branch without the shim goes through", %{tmp_dir: dir} do
      File.rm!(Path.join(dir, "dev/githooks/pre-commit"))

      assert {_, 0} = git(dir, ["commit", "-q", "-m", "Add new_fun"])
    end

    test "without heartwood in deps/ is blocked: the shim fails closed", %{tmp_dir: dir} do
      File.rm!(Path.join(dir, "deps/heartwood_guardrails/guardrails"))

      {out, status} = git(dir, ["commit", "-m", "Add new_fun"])

      assert status != 0
      assert out =~ "Run mix deps.get"
    end

    test "with HEARTWOOD_PATH runs the local checkout's gate", %{tmp_dir: dir} do
      File.rm!(Path.join(dir, "deps/heartwood_guardrails/guardrails"))
      checkout = package() |> Path.dirname()

      {out, status} = git(dir, ["commit", "-m", "Add new_fun"], [{"HEARTWOOD_PATH", checkout}])

      assert status != 0
      assert out =~ "hasn't had a reuse review"
    end
  end

  describe "mix.lock" do
    test "staged without heartwood's entries is blocked, even reviewed", %{tmp_dir: dir} do
      write!(dir, "mix.exs", ~s|{:heartwood_guardrails, github: "jeffdc/heartwood"}\n|)
      write!(dir, "mix.lock", ~s|%{"jason" => {:hex, :jason, "1.4.5"}}\n|)
      git!(dir, ["add", "mix.exs", "mix.lock"])
      review(dir, "pass")

      {out, status} = git(dir, ["commit", "-m", "Update deps"])

      assert status != 0
      assert out =~ "the staged mix.lock has no heartwood entries"
    end

    test "staged with heartwood's entries is reviewed as usual", %{tmp_dir: dir} do
      write!(dir, "mix.exs", ~s|{:heartwood_guardrails, github: "jeffdc/heartwood"}\n|)
      write!(dir, "mix.lock", ~s|%{"heartwood_guardrails" => {:git, "x", "y", []}}\n|)
      git!(dir, ["add", "mix.exs", "mix.lock"])
      review(dir, "pass")

      assert {_, 0} = git(dir, ["commit", "-q", "-m", "Update deps"])
    end
  end

  describe "a commit that touches no code" do
    setup %{tmp_dir: dir} do
      git!(dir, ["reset", "-q", "a.ex"])
      :ok
    end

    defp stage(dir, files) do
      for file <- files, do: write!(dir, file, "Prose.\n")
      git!(dir, ["add" | files])
    end

    test "under the prose paths goes through unreviewed", %{tmp_dir: dir} do
      before = head(dir)

      stage(dir, ["docs/talks/summary.md", "docs/talks/summary.pdf", "runbooks/r.md", "README.md"])

      assert {_, 0} = git(dir, ["commit", "-q", "-m", "Add the summary"])
      assert head(dir) != before
    end

    test "that also touches AGENTS.md or CLAUDE.md needs a review", %{tmp_dir: dir} do
      for rules <- ["AGENTS.md", "CLAUDE.md"] do
        stage(dir, ["docs/notes.md", rules])

        {out, status} = git(dir, ["commit", "-m", "Notes"])

        assert status != 0
        assert out =~ "hasn't had a reuse review"
        git!(dir, ["reset", "-q", rules])
      end
    end

    test "mixed with code needs a review", %{tmp_dir: dir} do
      stage(dir, ["docs/notes.md"])
      git!(dir, ["add", "a.ex"])

      assert {_, status} = git(dir, ["commit", "-m", "Notes and code"])
      assert status != 0
    end

    test "a README below the top level needs a review", %{tmp_dir: dir} do
      stage(dir, ["lib/README.md"])

      assert {_, status} = git(dir, ["commit", "-m", "A lib README"])
      assert status != 0
    end

    test "a file that only starts like a prose directory needs a review", %{tmp_dir: dir} do
      stage(dir, ["docsets/a.md"])

      assert {_, status} = git(dir, ["commit", "-m", "Docsets"])
      assert status != 0
    end

    test "moving code into docs/ needs a review", %{tmp_dir: dir} do
      File.mkdir_p!(Path.join(dir, "docs"))
      git!(dir, ["mv", "a.ex", "docs/a.ex"])

      assert {_, status} = git(dir, ["commit", "-m", "Move A"])
      assert status != 0
    end
  end

  describe "install" do
    test "installs a wrapper that runs the checkout's own hook", %{tmp_dir: dir} do
      installed = Path.join(dir, ".git/hooks/pre-commit")

      assert File.read!(installed) =~ "# testapp: runs dev/githooks/pre-commit"
      assert {_, 0} = cmd(dir, script("hooks/install"), [])
    end

    test "replaces a wrapper from before heartwood", %{tmp_dir: dir} do
      installed = Path.join(dir, ".git/hooks/pre-commit")
      File.write!(installed, "#!/bin/sh\n# oaks: runs scripts/githooks/pre-commit\nexit 0\n")

      assert {_, 0} = cmd(dir, script("hooks/install"), [])
      assert File.read!(installed) =~ "# testapp: runs dev/githooks/pre-commit"
    end

    test "leaves someone else's pre-commit hook alone", %{tmp_dir: dir} do
      installed = Path.join(dir, ".git/hooks/pre-commit")
      File.write!(installed, "#!/bin/sh\necho mine\n")

      {out, status} = cmd(dir, script("hooks/install"), [])

      assert status != 0
      assert out =~ "already has a pre-commit hook"
      assert File.read!(installed) == "#!/bin/sh\necho mine\n"
    end

    test "needs the repository's settings", %{tmp_dir: dir} do
      File.rm!(Path.join(dir, "dev/guardrails/config.sh"))

      {out, status} = cmd(dir, script("hooks/install"), [])

      assert status != 0
      assert out =~ "dev/guardrails/config.sh is missing"
    end
  end

  describe "the packet" do
    test "holds the instructions, the checklist, how to record, the definitions and the tree",
         %{tmp_dir: dir} do
      packet = dir |> review("pass") |> File.read!()

      assert packet =~ "## Instructions"
      assert packet =~ "### Your questions, in order"
      assert packet =~ "Is the change in the plan?"
      assert packet =~ "deps/heartwood_guardrails/guardrails/bin/record-review pass|block -"
      assert packet =~ "```\n## Findings\n"
      assert packet =~ "a.ex: def new_fun(x), do: x"
      assert packet =~ "tree: "
    end

    test "is written to the app's review folder", %{tmp_dir: dir} do
      assert review(dir, "pass") =~ ".git/testapp-review/packet.md"
    end

    test "lists each new file under lib/ for the reviewer to justify", %{tmp_dir: dir} do
      write!(dir, "lib/app/new_thing.ex", "defmodule NewThing do\nend\n")
      write!(dir, "notes.md", "notes\n")
      git!(dir, ["add", "lib/app/new_thing.ex", "notes.md"])

      packet = dir |> review("pass") |> File.read!()
      [_, section] = String.split(packet, "## New files under lib/", parts: 2)
      [section | _] = String.split(section, "\n## ", parts: 2)

      assert section =~ "lib/app/new_thing.ex"
      refute section =~ "notes.md"
      refute section =~ "a.ex"
    end

    test "says when nothing is staged", %{tmp_dir: dir} do
      git!(dir, ["reset", "-q", "a.ex"])

      assert {out, 1} = packet(dir)
      assert out =~ "Nothing is staged"
    end
  end

  test "a review can be recorded from standard input, with no report file", %{tmp_dir: dir} do
    {_, 0} = packet(dir)
    write!(dir, "report.in", "No findings.\n")

    {out, 0} = sh(dir, "#{script("bin/record-review")} pass - < report.in")

    recorded = out |> String.trim() |> File.read!()
    assert recorded =~ "verdict: pass"
    assert recorded =~ "No findings."
    assert {_, 0} = git(dir, ["commit", "-q", "-m", "Add new_fun"])
  end

  test "an empty report on standard input isn't recorded", %{tmp_dir: dir} do
    {_, 0} = packet(dir)

    assert {out, 1} = sh(dir, "#{script("bin/record-review")} pass - < /dev/null")
    assert out =~ "usage"
  end

  test "a review isn't recorded once the staging changed", %{tmp_dir: dir} do
    {_, 0} = packet(dir)
    write!(dir, "b.ex", "defmodule B do\nend\n")
    git!(dir, ["add", "b.ex"])
    write!(dir, "report.md", "No findings.\n")

    assert {out, 1} = cmd(dir, script("bin/record-review"), ["pass", "report.md"])
    assert out =~ "staging changed"
  end
end
