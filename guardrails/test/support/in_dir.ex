defmodule Heartwood.Test.InDir do
  @moduledoc """
  Runs a function with a directory as the working directory: ratchets read
  the app's root from it. The working directory is the VM's, so tests that
  use this aren't async.
  """

  alias Heartwood.Test.GitRepo

  @doc "Writes `files` (path => contents) under `dir`, then runs `fun` from `dir`."
  @spec in_dir(Path.t(), %{Path.t() => String.t()}, (-> result)) :: result when result: var
  def in_dir(dir, files \\ %{}, fun) do
    for {path, contents} <- files, do: GitRepo.write!(dir, path, contents)

    File.cd!(dir, fun)
  end
end
