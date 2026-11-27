defmodule Mix.Tasks.Heartwood.Status do
  @shortdoc "Show each heartwood package's pinned tag against the latest"

  @moduledoc """
  For each heartwood package the app depends on: the tag `mix.lock` pins,
  the latest tag in the heartwood repository (from `git ls-remote`), and,
  when the app is behind, where to read what changed.

      mix heartwood.status

  It only informs: it always exits 0, also when the repository can't be
  reached. Upgrading is the app's choice, following the "Upgrade:" steps in
  each package's CHANGELOG.md.
  """
  use Mix.Task

  alias Mix.Dep.Lock

  @impl Mix.Task
  def run(_args), do: Enum.each(lines(), fn line -> Mix.shell().info(line) end)

  @doc "The report for the current project: one line per heartwood package."
  @spec lines() :: [String.t()]
  def lines, do: report(Mix.Project.config()[:deps] || [], Lock.read(), &latest_tag/1)

  @doc """
  One line per heartwood package in `deps`, from its `mix.lock` entry and
  `latest`, a function from the repository's URL to its latest tag (or nil).
  """
  @spec report(list(), map(), (String.t() -> String.t() | nil)) :: [String.t()]
  def report(deps, lock, latest) do
    lines =
      for dep <- deps,
          {name, opts} = name_and_opts(dep),
          String.starts_with?(Atom.to_string(name), "heartwood_"),
          do: line(name, opts, lock[name], latest)

    if lines == [], do: ["No heartwood packages in this project's deps."], else: lines
  end

  defp name_and_opts({name, opts}) when is_list(opts), do: {name, opts}
  defp name_and_opts({name, _requirement}), do: {name, []}
  defp name_and_opts({name, _requirement, opts}), do: {name, opts}

  defp line(name, opts, lock_entry, latest) do
    cond do
      opts[:path] ->
        "#{name}: the local checkout at #{opts[:path]}. mix.lock has no entry for it: " <>
          "unset HEARTWOOD_PATH and run mix deps.get before committing mix.lock."

      match?({:git, _url, _sha, _opts}, lock_entry) ->
        {:git, url, sha, lock_opts} = lock_entry
        pinned = lock_opts[:tag] || String.slice(sha, 0, 7)
        pinned_line(name, pinned, latest.(url), changelog_url(url, lock_opts[:sparse]))

      true ->
        "#{name}: not in mix.lock. Run mix deps.get."
    end
  end

  defp pinned_line(name, pinned, nil, _changelog),
    do: "#{name}: #{pinned}; the latest tag is unknown (git ls-remote failed)."

  defp pinned_line(name, pinned, latest, changelog) do
    if behind?(pinned, latest),
      do: "#{name}: #{pinned}, behind the latest, #{latest}. What changed: #{changelog}",
      else: "#{name}: #{pinned}, the latest."
  end

  defp behind?(pinned, latest) do
    with {:ok, p} <- parse(pinned), {:ok, l} <- parse(latest) do
      Version.compare(p, l) == :lt
    else
      _ -> pinned != latest
    end
  end

  defp parse("v" <> version), do: Version.parse(version)
  defp parse(_other), do: :error

  defp changelog_url(url, sparse) do
    case Regex.run(~r{github\.com[:/]([^/]+)/([^/]+?)(?:\.git)?$}, url) do
      [_, owner, repo] ->
        "https://github.com/#{owner}/#{repo}/blob/main/#{if sparse, do: sparse <> "/"}CHANGELOG.md"

      nil ->
        "CHANGELOG.md in #{url}#{if sparse, do: " (#{sparse}/)"}"
    end
  end

  @doc "The highest `vX.Y.Z` tag in the repository at `url`, or nil when it can't be read."
  @spec latest_tag(String.t()) :: String.t() | nil
  def latest_tag(url) do
    case System.cmd("git", ["ls-remote", "--tags", "--refs", url], stderr_to_stdout: true) do
      {out, 0} ->
        out
        |> String.split("\n", trim: true)
        |> Enum.flat_map(&version_tag/1)
        |> Enum.max_by(&elem(&1, 0), Version, fn -> {nil, nil} end)
        |> elem(1)

      {_out, _status} ->
        nil
    end
  end

  # One `ls-remote` line, "<sha>\trefs/tags/<tag>": its version and tag, when it's vX.Y.Z.
  defp version_tag(line) do
    with [_sha, "refs/tags/" <> tag] <- String.split(line, "\t"),
         {:ok, version} <- parse(tag) do
      [{version, tag}]
    else
      _ -> []
    end
  end
end
