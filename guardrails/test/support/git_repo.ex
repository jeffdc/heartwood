defmodule Heartwood.Test.GitRepo do
  @moduledoc """
  A throwaway git repository laid out as an app that uses heartwood: its
  settings in `dev/guardrails/config.sh`, the shims in `dev/githooks/`, and
  `deps/heartwood_guardrails/guardrails` linked to this package (Mix checks
  a `sparse:` dependency out into its folder). Git runs with global
  and system config shut out, so nothing depends on the machine or harness.
  """

  @package Path.expand("../..", __DIR__)

  @env [
    {"GIT_CONFIG_GLOBAL", "/dev/null"},
    {"GIT_CONFIG_NOSYSTEM", "1"},
    {"GIT_DIR", nil},
    {"GIT_INDEX_FILE", nil},
    {"GIT_WORK_TREE", nil},
    {"CLAUDECODE", nil},
    {"HEARTWOOD_PATH", nil},
    {"TESTAPP_PUSH_MAIN", nil},
    {"GIT_AUTHOR_NAME", "Test"},
    {"GIT_AUTHOR_EMAIL", "test@example.com"},
    {"GIT_COMMITTER_NAME", "Test"},
    {"GIT_COMMITTER_EMAIL", "test@example.com"}
  ]

  @config """
  HEARTWOOD_APP=testapp
  HEARTWOOD_PROSE="docs/ runbooks/ README.md"
  HEARTWOOD_LIB="lib/"
  HEARTWOOD_CHECKLIST=dev/guardrails/checklist.md
  """

  @doc "The package's own directory."
  @spec package() :: Path.t()
  def package, do: @package

  @doc "A path in the package: `script(\"hooks/install\")`."
  @spec script(Path.t()) :: Path.t()
  def script(path), do: Path.join(@package, path)

  @doc """
  Makes `dir` an app repository with one commit, heartwood's hooks shimmed
  in and installed. Options: `branch` (the first branch's name).
  """
  @spec init!(Path.t(), keyword()) :: Path.t()
  def init!(dir, opts \\ []) do
    File.mkdir_p!(dir)
    git!(dir, ["init", "-q", "-b", Keyword.get(opts, :branch, "main")])
    write!(dir, "a.ex", "defmodule A do\nend\n")
    git!(dir, ["add", "a.ex"])
    git!(dir, ["commit", "-q", "-m", "start"])

    write!(dir, "dev/guardrails/config.sh", @config)
    write!(dir, "dev/guardrails/checklist.md", "Is the change in the plan?\n")

    for hook <- ["pre-commit", "pre-push"] do
      path = Path.join(dir, "dev/githooks/#{hook}")
      File.mkdir_p!(Path.dirname(path))
      File.cp!(script("hooks/app-shim"), path)
      File.chmod!(path, 0o755)
    end

    File.mkdir_p!(Path.join(dir, "deps/heartwood_guardrails"))
    File.ln_s!(@package, Path.join(dir, "deps/heartwood_guardrails/guardrails"))
    {_, 0} = cmd(dir, script("hooks/install"), [])
    dir
  end

  @doc "Runs a command in `dir`, with the test git environment and `env` on top."
  @spec cmd(Path.t(), String.t(), [String.t()], list()) :: {String.t(), non_neg_integer()}
  def cmd(dir, command, args, env \\ []),
    do: System.cmd(command, args, cd: dir, env: @env ++ env, stderr_to_stdout: true)

  @doc "Runs a shell command line in `dir`, for redirections."
  @spec sh(Path.t(), String.t()) :: {String.t(), non_neg_integer()}
  def sh(dir, line), do: cmd(dir, "sh", ["-c", line])

  @doc "Runs git in `dir`."
  @spec git(Path.t(), [String.t()], list()) :: {String.t(), non_neg_integer()}
  def git(dir, args, env \\ []), do: cmd(dir, "git", args, env)

  @doc "Runs git in `dir`, and fails unless it succeeds."
  @spec git!(Path.t(), [String.t()]) :: String.t()
  def git!(dir, args) do
    {out, 0} = git(dir, args)
    out
  end

  @doc "Writes a file in `dir`, making its directories."
  @spec write!(Path.t(), Path.t(), String.t()) :: :ok
  def write!(dir, path, contents) do
    full = Path.join(dir, path)
    File.mkdir_p!(Path.dirname(full))
    File.write!(full, contents)
  end

  @doc "HEAD's commit."
  @spec head(Path.t()) :: String.t()
  def head(dir), do: dir |> git!(["rev-parse", "HEAD"]) |> String.trim()
end
