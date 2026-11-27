Heartwood is used by Oak Compendium and Gallformers; anything app-specific belongs in the apps. Its code is in `guardrails/lib/`, `guardrails/bin/`, `guardrails/hooks/` and `guardrails/review/`.

1. **App-free.** Is anything in the packages specific to one app (its modules, paths, tokens, names or rules) outside test fixtures? Or is something an app passes as a setting really the same in both, and could become a default?
2. **The contract.** Does each package's README list everything an app relies on (modules' APIs, callbacks, config keys, scripts' flags and settings, hooks' behaviour), and does each CHANGELOG.md entry since the last review name what changed in it?
3. **Shell and Elixir.** Is logic duplicated between the shell scripts and the Elixir modules (reading `config.sh`, finding the git directory, building paths) where one could serve both?
