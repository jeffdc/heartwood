# Architectural rules

The rules heartwood's code must follow, each with its check and its baseline. Every rule here is one Jeff has stated, with its source. Rules a review proposes stay in [reviews.md](reviews.md) until Jeff adopts them.

- **Check** names the automated check and where it runs: local (`make done-checks`), CI, or both. "Manual" means it's checked by hand, in the reuse review or the architecture review, until it has a check.
- **Baseline** is the count of known violations at the last review.
- IDs are stable and never reused. A retired rule stays, marked retired.

| ID | Rule | Source | Check | Baseline |
|---|---|---|---|---|
| H1 | App-free: nothing specific to one app (its modules, paths, tokens, names or rules) outside test fixtures (the preview's included), which say whose they are. What differs per app is a setting or an argument. | AGENTS.md; Oak Compendium's decisions.md, 2026-11-26 heartwood | Manual (the reuse review's checklist, question 1) | 0 |
| H2 | A change to a package's contract (its README's "Contract") has an entry in its CHANGELOG.md, with "Upgrade:" steps when an app has to act. | AGENTS.md, Changes and releases | Manual (the reuse review's checklist, question 2) | 0 |
| H3 | Scripts and hooks are tested by running them for real: git in throwaway repositories, `check-toolchain` against fixture roots. | AGENTS.md, Working here | Manual | 0 |
| H4 | Work is finished only when `make done-checks` passes, and CI requires the same checks before a PR can merge (a package's jobs are skipped when a PR changes none of its code, only prose). | AGENTS.md, Working here | `make done-checks`; CI's jobs, required by the ruleset on main | 0 |
| H5 | Main changes only through pull requests; no force pushes. | AGENTS.md, Before you commit | The ruleset on main: on GitHub. The push guard (`dev/githooks/pre-push`): local, per clone (`make hooks`). | 0 |
| H6 | Every commit that touches code has a passing reuse review by a reviewer with fresh context. | AGENTS.md, Before you commit | The commit gate (`dev/githooks/pre-commit`): local, per clone | 0 |
| H7 | AGENTS.md holds rules, not status or plans. | AGENTS.md | Manual (the reuse review's checklist, question 3) | 0 |
| H8 | A shared component takes each app's design system: its own class prefix, in plain CSS in `@layer components`, reading only its own custom properties, each with a neutral default; no Tailwind utilities in its markup; `class` for the app's adapter and layout only; its words are labels with defaults. | Oak Compendium's decisions.md, 2026-11-25 and 2026-11-26 heartwood; architecture-groundwork.md, section 3 | Manual (the reuse review) | 0 |
