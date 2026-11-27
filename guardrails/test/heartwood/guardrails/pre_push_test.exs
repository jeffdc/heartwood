defmodule Heartwood.Guardrails.PrePushTest do
  @moduledoc """
  The push guard: `hooks/pre-push`, run through the app's
  `dev/githooks/pre-push` shim that `hooks/install` makes git run, blocks
  force pushes and pushes to main or master from anyone (any agent, any
  harness, a terminal) unless `<APP>_PUSH_MAIN=1` is set for that push. It
  holds on a branch without the shim too, through the copy the install
  keeps. Each test pushes for real to a bare repository.
  """
  use ExUnit.Case, async: true

  import Heartwood.Test.GitRepo

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp} do
    remote = Path.join(tmp, "remote.git")
    dir = Path.join(tmp, "work")

    File.mkdir_p!(tmp)
    git!(tmp, ["init", "-q", "--bare", remote])
    init!(dir)
    git!(dir, ["remote", "add", "origin", remote])

    %{dir: dir, remote: remote}
  end

  defp commit!(dir, file) do
    write!(dir, file, "defmodule #{Macro.camelize(Path.rootname(file))} do\nend\n")
    git!(dir, ["add", file])
    git!(dir, ["commit", "-q", "--no-verify", "-m", "Add #{file}"])
  end

  defp remote_has?(remote, branch),
    do: match?({_, 0}, git(remote, ["rev-parse", "--verify", "-q", "refs/heads/#{branch}"]))

  describe "a push to main" do
    test "is blocked for anyone, with no harness in sight", %{dir: dir, remote: remote} do
      {out, status} = git(dir, ["push", "-q", "origin", "main"])

      assert status != 0
      assert out =~ "pushes to main"
      assert out =~ "TESTAPP_PUSH_MAIN=1"
      refute remote_has?(remote, "main")
    end

    test "goes through with the app's override, TESTAPP_PUSH_MAIN=1", %{dir: dir, remote: remote} do
      assert {_, 0} = git(dir, ["push", "-q", "origin", "main"], [{"TESTAPP_PUSH_MAIN", "1"}])
      assert remote_has?(remote, "main")
    end

    test "isn't let through by another app's override", %{dir: dir, remote: remote} do
      {_, status} = git(dir, ["push", "-q", "origin", "main"], [{"OAKS_PUSH_MAIN", "1"}])

      assert status != 0
      refute remote_has?(remote, "main")
    end

    test "to master is blocked too", %{dir: dir, remote: remote} do
      {_, status} = git(dir, ["push", "-q", "origin", "main:master"])

      assert status != 0
      refute remote_has?(remote, "master")
    end

    test "is blocked on a branch without the shim or the settings", %{dir: dir, remote: remote} do
      File.rm!(Path.join(dir, "dev/githooks/pre-push"))
      File.rm!(Path.join(dir, "dev/guardrails/config.sh"))

      {out, status} = git(dir, ["push", "-q", "origin", "main"])

      assert status != 0
      assert out =~ "TESTAPP_PUSH_MAIN=1"
      refute remote_has?(remote, "main")
    end

    test "is blocked without heartwood in deps/: the shim fails closed", %{
      dir: dir,
      remote: remote
    } do
      File.rm!(Path.join(dir, "deps/heartwood_guardrails"))

      {out, status} = git(dir, ["push", "-q", "origin", "main"])

      assert status != 0
      assert out =~ "Run mix deps.get"
      refute remote_has?(remote, "main")
    end
  end

  describe "a push to another branch" do
    test "goes through", %{dir: dir, remote: remote} do
      git!(dir, ["checkout", "-q", "-b", "feature"])
      commit!(dir, "b.ex")

      assert {_, 0} = git(dir, ["push", "-q", "origin", "feature"])
      assert remote_has?(remote, "feature")
    end

    test "that rewrites its history is blocked", %{dir: dir} do
      git!(dir, ["checkout", "-q", "-b", "feature"])
      commit!(dir, "b.ex")
      git!(dir, ["push", "-q", "origin", "feature"])
      git!(dir, ["reset", "-q", "--hard", "HEAD~1"])
      commit!(dir, "c.ex")

      {out, status} = git(dir, ["push", "-q", "--force", "origin", "feature"])

      assert status != 0
      assert out =~ "force push"
    end

    test "that deletes it goes through", %{dir: dir, remote: remote} do
      git!(dir, ["checkout", "-q", "-b", "feature"])
      git!(dir, ["push", "-q", "origin", "feature"])

      assert {_, 0} = git(dir, ["push", "-q", "origin", "--delete", "feature"])
      refute remote_has?(remote, "feature")
    end
  end

  test "install leaves someone else's pre-push hook alone", %{dir: dir} do
    installed = Path.join(dir, ".git/hooks/pre-push")
    File.write!(installed, "#!/bin/sh\necho mine\n")

    {out, status} = cmd(dir, script("hooks/install"), [])

    assert status != 0
    assert out =~ "already has a pre-push hook"
    assert File.read!(installed) == "#!/bin/sh\necho mine\n"
  end
end
