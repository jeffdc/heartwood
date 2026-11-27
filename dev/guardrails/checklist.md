Heartwood is used by Oak Compendium and Gallformers. Look for existing code in `guardrails/lib/`, `guardrails/bin/` and `guardrails/hooks/`.

1. **App-free.** Does the change bring in anything specific to one app: its modules, paths, tokens, names or rules? Test fixtures in `test/support/` may, and say whose they are. A finding blocks.
2. **The contract.** Does the change alter what a package's README lists as its contract (a module's API, a callback, a config key, a script's flags or settings, a hook's behaviour)? Then its CHANGELOG.md must have an entry for it, with "Upgrade:" steps when an app has to do something. A missing entry blocks.
3. **AGENTS.md** holds rules, not status or plans. Status or plans added to it is a finding that blocks.
