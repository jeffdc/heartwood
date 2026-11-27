defmodule Heartwood.Guardrails.Architecture do
  @moduledoc """
  The architecture review's packet: the same evidence for every run of the
  periodic architecture review, which Jeff runs every so often with a
  different model each time. `mix heartwood.architecture` gathers it and
  writes the packet; the reviewer follows `review/architect.md`, which the
  packet holds, and keeps its report with `bin/record-architecture`.

  The evidence: the commits since the last review (those after the last
  commit that changed the architecture docs' `reviews.md`), the project's
  `mix xref` graph folded to contexts, every ratchet against its baseline,
  `mix heartwood.status`, the repository's own questions for the reviewer,
  and the architecture docs.

  A run is the date and HEAD. Its packet and reports are in git's common
  directory, `<app>-architecture/<run>/`, shared by every worktree of the
  clone.

  Settings, in `dev/guardrails/config.sh`:

    * `HEARTWOOD_APP` names the folder, as for the reuse review.
    * `HEARTWOOD_ARCHITECTURE`: the architecture docs (default
      `docs/architecture/`).
    * `HEARTWOOD_ARCHITECTURE_QUESTIONS`: the repository's questions for the
      reviewer (default `dev/guardrails/architecture.md`).
    * `HEARTWOOD_GRAPH_DEPTH`: how many path segments name a context when
      the graph is folded (default 3: `lib/my_app/accounts.ex` and
      `lib/my_app/accounts/user.ex` are both `lib/my_app/accounts`).
  """

  alias Heartwood.Guardrails.Ratchet

  @package Path.expand("../../..", __DIR__)

  @typedoc "The repository's settings for the review."
  @type settings :: %{
          app: String.t(),
          docs: Path.t(),
          questions: Path.t(),
          depth: pos_integer()
        }

  @typedoc "A folded dependency: from one context to another, with how many of each kind."
  @type edge :: {String.t(), String.t(), %{String.t() => pos_integer()}}

  @typedoc "What the task gathers from the Mix project for the packet."
  @type evidence :: %{graph: map(), ratchets: [module()], status: [String.t()]}

  @doc "The repository's settings, from `dev/guardrails/config.sh` under `root`, with their defaults."
  @spec settings(Path.t()) :: settings()
  def settings(root) do
    script = ~S"""
    . ./dev/guardrails/config.sh || exit 1
    printf '%s\n' "${HEARTWOOD_APP:-}" "${HEARTWOOD_ARCHITECTURE:-docs/architecture/}" \
      "${HEARTWOOD_ARCHITECTURE_QUESTIONS:-dev/guardrails/architecture.md}" "${HEARTWOOD_GRAPH_DEPTH:-3}"
    """

    case System.cmd("sh", ["-c", script], cd: root, stderr_to_stdout: true) do
      {out, 0} ->
        [app, docs, questions, depth | _] = String.split(out, "\n")
        if app == "", do: raise("dev/guardrails/config.sh must set HEARTWOOD_APP")

        %{
          app: app,
          docs: String.trim_trailing(docs, "/"),
          questions: questions,
          depth: String.to_integer(depth)
        }

      {out, _status} ->
        raise "dev/guardrails/config.sh couldn't be read: #{out}"
    end
  end

  @doc """
  Folds `mix xref graph --format json` output to contexts: each file is
  named by its first `depth` path segments, without its extension. Test
  files and dependencies within one context are left out.
  """
  @spec fold(map(), pos_integer()) :: [edge()]
  def fold(graph, depth) do
    for {source, sinks} <- graph,
        not test?(source),
        {sink, kind} <- sinks,
        not test?(sink),
        from = context(source, depth),
        to = context(sink, depth),
        from != to do
      {{from, to}, kind}
    end
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map(fn {{from, to}, kinds} -> {from, to, Enum.frequencies(kinds)} end)
    |> Enum.sort()
  end

  defp context(path, depth),
    do: path |> Path.rootname() |> Path.split() |> Enum.take(depth) |> Path.join()

  defp test?(path), do: String.starts_with?(path, "test/")

  @doc """
  The commits since the last review: after the last commit that changed
  `<docs>/reviews.md`, or every commit when none has. Returns that commit
  (or nil) and one line per commit, newest first.
  """
  @spec commits(Path.t(), Path.t()) :: {String.t() | nil, [String.t()]}
  def commits(root, docs) do
    since =
      case git!(root, ["log", "-1", "--format=%h", "--", Path.join(docs, "reviews.md")]) do
        "" -> nil
        sha -> sha
      end

    range = if since, do: "#{since}..HEAD", else: "HEAD"
    lines = git!(root, ["log", "--format=%h %ad %s", "--date=short", range])
    {since, String.split(lines, "\n", trim: true)}
  end

  @doc """
  Each ratchet's counts against its baseline, as markdown. A ratchet that
  isn't compiled in this environment (one in `test/support`, outside the
  test environment) says so.
  """
  @spec ratchets([module()]) :: String.t()
  def ratchets([]),
    do: "None configured (`config :heartwood_guardrails, ratchets: [...]`).\n"

  def ratchets(modules), do: Enum.map_join(modules, "\n", &ratchet/1)

  defp ratchet(module) do
    if Code.ensure_loaded?(module) do
      current = module.counts()
      baseline = Ratchet.read_baseline(module)
      rows = rows(current, baseline)

      """
      ### #{inspect(module)}: #{module.subject()}

      Total #{Ratchet.total(current)}, baseline #{Ratchet.total(baseline)} (`#{module.baseline_path()}`).

      #{if rows == [], do: "No counts.", else: Enum.join(rows, "\n")}
      """
    else
      """
      ### #{inspect(module)}

      Not compiled in the #{Mix.env()} environment: run `MIX_ENV=test mix heartwood.architecture`, or set `preferred_envs: ["heartwood.architecture": :test]` in the project's `cli/0`.
      """
    end
  end

  # One line per key in the counts or the baseline: "- key: count (baseline n)".
  defp rows(current, baseline) do
    current = Ratchet.flatten(current)
    baseline = Ratchet.flatten(baseline)

    for key <- Enum.sort(Enum.uniq(Map.keys(current) ++ Map.keys(baseline))) do
      "- #{Enum.join(key, ": ")}: #{Map.get(current, key, 0)} (baseline #{Map.get(baseline, key, 0)})"
    end
  end

  @doc """
  Writes the packet for `root` (the repository) from `evidence`, as of
  `date`, and returns its path: `<git common dir>/<app>-architecture/<run>/packet.md`.
  """
  @spec write!(Path.t(), evidence(), Date.t()) :: Path.t()
  def write!(root, evidence, date \\ NaiveDateTime.to_date(NaiveDateTime.local_now())) do
    settings = settings(root)
    run = "#{Date.to_iso8601(date)}-#{git!(root, ["rev-parse", "--short", "HEAD"])}"
    dir = Path.join([common_dir(root), "#{settings.app}-architecture", run])
    File.mkdir_p!(dir)
    path = Path.join(dir, "packet.md")
    File.write!(path, packet(root, settings, run, evidence))
    path
  end

  defp packet(root, settings, run, evidence) do
    {since, commits} = commits(root, settings.docs)
    record = relative(Path.join(@package, "bin/record-architecture"), root)

    """
    # Architecture review packet

    run: #{run}

    ## Instructions

    #{instructions()}
    ## This repository's questions

    #{read_or(Path.join(root, settings.questions), "None.\n")}
    ## Recording your report

    Run, from the repository, with your model's name or ID and your report on standard input:

        #{record} #{run} <model> - <<'REPORT'
        ## Proposed rules
        …
        REPORT

    ## Commits since the last review

    #{commit_lines(since, commits, settings.docs)}
    ## Dependencies between contexts

    From `mix xref graph --format json`, each file named by its first #{settings.depth} path segments; test files and dependencies within a context are left out. Each count is the number of file-to-file dependencies of that kind (compile, export or runtime).

    #{edges(fold(evidence.graph, settings.depth))}
    ## Ratchets

    #{ratchets(evidence.ratchets)}
    ## Heartwood

    #{Enum.map_join(evidence.status, "\n", &"    #{&1}")}

    ## Architecture docs

    #{docs(root, settings.docs)}
    """
  end

  # review/architect.md without its title, its sections one level down, as
  # the reuse review's packet does; its report shape, in a code block, stays.
  defp instructions do
    Path.join(@package, "review/architect.md")
    |> File.read!()
    |> String.split("\n")
    |> Enum.drop(1)
    |> Enum.map_reduce(false, fn line, fenced ->
      fenced = if String.starts_with?(line, "```"), do: not fenced, else: fenced
      line = if not fenced and String.starts_with?(line, "## "), do: "#" <> line, else: line
      {line, fenced}
    end)
    |> elem(0)
    |> Enum.join("\n")
  end

  defp commit_lines(nil, commits, docs),
    do:
      "No commit has changed `#{docs}/reviews.md` yet, so every commit (#{length(commits)}):\n\n#{indent(commits)}"

  defp commit_lines(since, commits, docs),
    do:
      "After #{since}, the last commit that changed `#{docs}/reviews.md` (#{length(commits)}):\n\n#{indent(commits)}"

  defp edges([]), do: "None.\n"

  defp edges(edges) do
    Enum.map_join(edges, "", fn {from, to, kinds} ->
      counts = kinds |> Enum.sort() |> Enum.map_join(", ", fn {kind, n} -> "#{kind} #{n}" end)
      "- #{from} → #{to} (#{counts})\n"
    end)
  end

  # Each doc in a tilde fence, which holds the backtick fences docs use.
  defp docs(root, dir) do
    files =
      Path.join([root, dir, "*.md"])
      |> Path.wildcard()
      |> Enum.sort_by(&{Path.basename(&1) != "README.md", &1})

    if files == [] do
      "None found in `#{dir}/`.\n"
    else
      Enum.map_join(files, "\n", fn file ->
        "### #{relative(file, root)}\n\n~~~~markdown\n#{File.read!(file)}~~~~\n"
      end)
    end
  end

  defp indent([]), do: "    None.\n"
  defp indent(lines), do: Enum.map_join(lines, "", &"    #{&1}\n")

  defp read_or(path, default), do: if(File.exists?(path), do: File.read!(path), else: default)

  defp relative(path, root), do: Path.relative_to(path, root)

  defp common_dir(root), do: Path.expand(git!(root, ["rev-parse", "--git-common-dir"]), root)

  defp git!(root, args) do
    {out, 0} = System.cmd("git", args, cd: root)
    String.trim(out)
  end
end
