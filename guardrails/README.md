# heartwood_guardrails

The checks Oak Compendium and Gallformers hold their code to, with each app's own rules kept in the app:

- **Ratchets:** counts the codebase should have less of, held to a JSON baseline in the app. A test fails when a count goes over its baseline and when it falls below it without the baseline being lowered. `Heartwood.Guardrails.Patterns` builds one from rules (patterns, or counting functions, per file); `Heartwood.Guardrails.DuplicateCode` counts copied code with Credo.
- **Retirements:** a list of modules being replaced, and a test that fails while an old module and its replacement both exist.
- **The commit gate:** a git pre-commit hook that blocks a code commit until a reviewer with fresh context has recorded a passing reuse review of the staged tree, from a packet the app's `review-packet` writes.
- **The push guard:** a git pre-push hook that blocks force pushes and pushes to main or master, from anyone.
- **The architecture review:** a periodic review of the whole repository against its architecture docs, by several models: `mix heartwood.architecture` writes the packet, and each model's report is kept beside it.
- **`check-toolchain`:** fails when the Dockerfiles drift from the Nix dev shell.
- **`mix heartwood.status`:** each heartwood package's pinned tag against the latest.

## Using it in an app

### The dependency

In `mix.exs`, pinned by tag, with a local checkout when `HEARTWOOD_PATH` is set (for working on heartwood from the app; see [mix.lock](#mixlock-and-heartwood_path)):

```elixir
@heartwood_tag "v0.1.1"

defp deps do
  [
    heartwood(:heartwood_guardrails, "guardrails", only: [:dev, :test], runtime: false),
    # …
  ]
end

# heartwood, pinned by tag; HEARTWOOD_PATH=~/dev/heartwood uses that checkout instead.
defp heartwood(package, folder, opts) do
  source =
    case System.get_env("HEARTWOOD_PATH") do
      nil -> [github: "jeffdc/heartwood", sparse: folder, tag: @heartwood_tag]
      path -> [path: Path.join(path, folder)]
    end

  {package, source ++ opts}
end

def cli, do: [preferred_envs: ["heartwood.baseline": :test, "heartwood.architecture": :test]]
```

Mix checks a `sparse:` dependency out into its folder, so the package is at `deps/heartwood_guardrails/guardrails`: the paths below start there.

The app also depends on Credo (`~> 1.7`) itself, for `mix credo`.

### Ratchets

A pattern ratchet is a module in the app, usually in `test/support/` or the web layer:

```elixir
defmodule MyAppWeb.Conformance do
  use Heartwood.Guardrails.Patterns

  @impl Heartwood.Guardrails.Ratchet
  def subject, do: "off-system styling"

  @impl Heartwood.Guardrails.Ratchet
  def baseline_path, do: "test/support/conformance_baseline.json"

  @impl Heartwood.Guardrails.Patterns
  def intro, do: "New styling bypasses the design system (DESIGN.md)."

  @impl Heartwood.Guardrails.Patterns
  def rules do
    [
      [name: :inline_style, files: ["lib/my_app_web/**/*.{ex,heex}"],
       pattern: ~r/(?<![\w-])style=/, hint: "Use classes."],
      [name: :app_css_lines, files: ["assets/css/app.css"],
       count: &length(String.split(&1, "\n", trim: true)),
       hint: "Page CSS only shrinks: move it into a component."]
    ]
  end
end
```

A rule has a `:name`, `:files` (globs from the app's root) with optional `:exempt` files, a `:hint`, and either a `:pattern` (counted per match, with an optional `:filter` on each match) or a `:count` function from a file's text to a number. `intro/0` and `outro/0` are optional.

`Heartwood.Guardrails.DuplicateCode` needs a config named `duplicates` in the app's `.credo.exs`:

```elixir
%{
  name: "duplicates",
  files: %{included: ["lib/", "test/"], excluded: [~r"/_build/", ~r"/deps/"]},
  checks: %{enabled: [{Credo.Check.Design.DuplicatedCode, [mass_threshold: 40]}]}
}
```

The tests, in one module of the app's:

```elixir
defmodule MyApp.GuardrailsTest do
  # DuplicateCode runs Credo, which toggles a global output switch: not async.
  use ExUnit.Case, async: false

  import Heartwood.Guardrails.Assertions

  test "styling stays on the design system", do: assert_ratchet(MyAppWeb.Conformance)
  test "no new copied code", do: assert_ratchet(Heartwood.Guardrails.DuplicateCode)
  test "replaced code is deleted", do: assert_no_outstanding_retirements()
end
```

Baselines are written by `mix heartwood.baseline MyAppWeb.Conformance` (or with no arguments, every ratchet in `config :heartwood_guardrails, ratchets: [...]`): after removing findings, to lock the gain in; never to make new findings pass. A baseline that doesn't exist yet reads as empty, so the first run of the task writes today's counts.

### Retirements

`test/support/retirements.exs` holds a list of `%{retire: Old, replaced_by: New, why: "a plan doc, PR or commit"}`. A task that builds a replacement adds its entry first, as its failing test, and deletes the old module in the same change.

### Hooks and the reuse review

1. Copy [`hooks/app-shim`](hooks/app-shim) to the app's `dev/githooks/pre-commit` and `dev/githooks/pre-push`. Each runs heartwood's hook of its name from `deps/heartwood_guardrails/guardrails` (or `HEARTWOOD_PATH`), and blocks when heartwood is missing.
2. Write the app's settings in `dev/guardrails/config.sh` ([heartwood's own](../dev/guardrails/config.sh) is an example):

   | Setting | Meaning | Default |
   |---|---|---|
   | `HEARTWOOD_APP` | Names the review folder (`<git dir>/<app>-review`) and the push guard's override (`<APP>_PUSH_MAIN=1`) | required |
   | `HEARTWOOD_PROSE` | Paths a commit may touch without a review: a directory ends in `/`, anything else is one file. AGENTS.md and CLAUDE.md are always reviewed. | `docs/ README.md` |
   | `HEARTWOOD_LIB` | Where a new file needs the reviewer's justification | `lib/` |
   | `HEARTWOOD_CHECKLIST` | The app's own questions for the reviewer, and where to look for existing code | `dev/guardrails/checklist.md` |
   | `HEARTWOOD_HOME` | Where the package is, from the root | `deps/heartwood_guardrails/guardrails` |
   | `HEARTWOOD_ARCHITECTURE` | The architecture docs, for the architecture review | `docs/architecture/` |
   | `HEARTWOOD_ARCHITECTURE_QUESTIONS` | The app's own questions for the architecture reviewer | `dev/guardrails/architecture.md` |
   | `HEARTWOOD_GRAPH_DEPTH` | How many path segments name a context in the architecture review's graph | `3` |

3. Install with `deps/heartwood_guardrails/guardrails/hooks/install` (the app's `make hooks`). It puts a wrapper in git's hooks directory that runs the checkout's `dev/githooks/<hook>`, so each branch runs its own version, and keeps a copy of the push guard that holds on a branch without it. It replaces wrappers from before heartwood (`# <app>: runs <dir>/githooks/<hook>`) and leaves any other hook alone.
4. The routine, in the app's AGENTS.md: stage by name, run `deps/heartwood_guardrails/guardrails/bin/review-packet`, have a reviewer with fresh context follow the packet it prints (heartwood's instructions in [`review/reviewer.md`](review/reviewer.md), then the app's checklist), and commit once the reviewer has recorded a pass with `bin/record-review`.

### mix.lock and HEARTWOOD_PATH

A `path:` dependency isn't locked, so with `HEARTWOOD_PATH` set, `mix deps.unlock --unused` (in `precommit`) drops heartwood's entries from `mix.lock`. The commit gate blocks a staged `mix.lock` without them, whatever the review says: unset `HEARTWOOD_PATH`, run `mix deps.get`, and restage it.

### check-toolchain

`deps/heartwood_guardrails/guardrails/bin/check-toolchain`, from the app's root inside the dev shell (in CI, after `mix deps.get`). For every `Dockerfile` and `Dockerfile.*`: the builder's Elixir, OTP and Alpine, the runtime's Alpine, the Tailwind download against `config :tailwind, version:`, `ENV MIX_TAILWIND_PATH` when it's set, and Typst when `flake.nix` provides it; and `flake.nix`'s `tailwindVersion` against `config.exs`.

### The architecture review

A periodic review of the whole repository, not one change: Jeff runs it every so often and gives its packet to several models, for a mix of opinions. Its first job is finding where a new rule is needed and which manual rules could be automated; then violations of the rules that need judgement, rules worth retiring, and where the architecture docs no longer match the code.

1. `mix heartwood.architecture` (in the test environment, so the ratchets in `test/support` count) writes the packet and prints its path: `<git common dir>/<app>-architecture/<run>/packet.md`, where a run is the date and HEAD. The common directory is shared by every worktree of the clone, so nothing needs gitignoring. The packet holds heartwood's instructions ([`review/architect.md`](review/architect.md)), the app's questions (`HEARTWOOD_ARCHITECTURE_QUESTIONS`), how to record, and the evidence: the commits after the last commit that changed `reviews.md` in the architecture docs, the project's `mix xref` graph folded to contexts (`HEARTWOOD_GRAPH_DEPTH`), every ratchet in `config :heartwood_guardrails, ratchets: [...]` against its baseline, `mix heartwood.status`, and every `.md` file in the architecture docs.
2. A reviewer with fresh context follows the packet, read-only, and keeps its report with `bin/record-architecture <run> <model> -` (the report on standard input), as `<model>.md` beside the packet. A model's first report for a run stands: the script refuses a second.
3. Jeff combines a run's reports into one entry in the architecture docs' `reviews.md`; committing it starts the next review's range.

### mix heartwood.status

Prints each heartwood package's pinned tag, the latest tag and, when the app is behind, a link to the package's CHANGELOG.md. It only informs, and always exits 0.

## Contract

A change to any of these gets an entry in [CHANGELOG.md](CHANGELOG.md), with "Upgrade:" steps when an app has to do something:

- The `Heartwood.Guardrails.Ratchet` and `Heartwood.Guardrails.Patterns` callbacks, the rule options, and the shape of counts and baselines.
- The public functions of `Ratchet`, `Patterns` (what `use` adds), `DuplicateCode`, `Retirements`, `Assertions` and `Architecture`, and their failure messages' instructions.
- The application config keys: `:ratchets`, `:duplicate_code_baseline`, `:retirements`, and their defaults.
- The mix tasks' names, arguments and output.
- The settings in `dev/guardrails/config.sh` and their defaults; `hooks/app-shim`, `hooks/install`, `hooks/pre-commit` and `hooks/pre-push`'s behaviour; `bin/review-packet`, `bin/record-review`, `bin/record-architecture` and `bin/check-toolchain`'s arguments, environment, output and what they check; the review folders' names (`<app>-review`, `<app>-architecture`) and the files in them; the packets' sections; the report shapes in `review/reviewer.md` and `review/architect.md`.
