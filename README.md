# Heartwood

Code shared by [Oak Compendium](https://github.com/jeffdc/oaks) and [Gallformers](https://github.com/jeffdc/gallformers): two Elixir and Phoenix LiveView apps with the same toolchain and the same ways of holding their code to its rules.

| Package | Folder | What it holds | How an app depends on it |
|---|---|---|---|
| `heartwood_guardrails` | [`guardrails/`](guardrails/README.md) | Ratchets (pattern rules and copied code held to a baseline), retirements, the commit gate and push guard, the reuse review's packet, the architecture review, `check-toolchain`, `mix heartwood.status` | `only: [:dev, :test], runtime: false` |
| `heartwood_ui` | `ui/` (to come) | Function components with their hooks and CSS: the photo viewer, then the fragment-and-reader | runtime |

Each package's README describes how to use it and lists its contract: what a change must name in the package's CHANGELOG.md when it changes.

## How apps use it

The packages aren't on Hex. An app depends on each one from GitHub, pinned to a release tag, with `sparse:` so only the package's folder is fetched:

```elixir
{:heartwood_guardrails,
 github: "jeffdc/heartwood", sparse: "guardrails", tag: "v0.1.1", only: [:dev, :test], runtime: false}
```

`mix.lock` records the exact commit. Each app keeps its own rules, baselines and settings; heartwood holds only what is the same for both.

## How changes flow

- Releases are tags, `v0.y.z`, one series for both packages. While it's 0.x, a minor version needs something from an app and a patch is a drop-in.
- Each package's CHANGELOG.md has an entry for every tag that changes it; an entry that needs action from an app has "Upgrade:" steps.
- An app moves to a new tag when it chooses. `mix heartwood.status` shows how far behind it is.
- A bug found in an app is fixed here, never in the app's `deps/`, with the app pointed at a local checkout (`HEARTWOOD_PATH`), then tagged and bumped.

The rules for working here are in [AGENTS.md](AGENTS.md); heartwood's architecture, its rules and its periodic reviews are in [docs/architecture/](docs/architecture/README.md). The decision behind heartwood is recorded in Oak Compendium's `docs/architecture/decisions.md` (2026-11-26).

## License

[Apache 2.0](LICENSE).
