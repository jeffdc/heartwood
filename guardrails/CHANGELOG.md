# Changelog

Every release that changes `heartwood_guardrails`, newest first. An entry that needs something from an app has "Upgrade:" steps. Versions are heartwood's tags (`v0.y.z`, one series for every package); while it's 0.x, a minor version needs action from an app and a patch is a drop-in.

## v0.2.3 (2026-11-27)

- Changed: the commit gate no longer reviews AGENTS.md and CLAUDE.md whatever `HEARTWOOD_PROSE` says. They are prose when a prose path or pattern covers them (`*.md`, or the names themselves), like any other file; with the default (`docs/ README.md`) they are still reviewed.
- New: `HEARTWOOD_CODE`, paths the commit gate reviews though a prose path or pattern covers them, for the Markdown an app's code or tests read. CI counts them as code too. With it, `HEARTWOOD_PROSE="*.md"` lets doc-only commits anywhere through unreviewed while the Markdown that code reads is still reviewed and tested. `hooks/prose.sh` has `heartwood_counts_as_prose PROSE CODE FILE` for both.
- Docs: the README's examples pin this tag; "mix.lock and HEARTWOOD_PATH" shows how to skip `mix deps.unlock --check-unused` while `HEARTWOOD_PATH` is set; the v0.1.0 upgrade step's install path is corrected.

Upgrade (optional; nothing changes for an app that doesn't list AGENTS.md or CLAUDE.md under a prose path): move `@heartwood_tag` and the `actions/changes` pin to the new tag. For doc-only commits to need no review, set `HEARTWOOD_PROSE="docs/ *.md"` (with anything else that's prose), and list in `HEARTWOOD_CODE` the Markdown that the app's code or tests read; it can then drop those paths from `HEARTWOOD_CI_PROSE` and `HEARTWOOD_CI_CODE`.

## v0.2.2 (2026-11-27)

- New: patterns in the prose settings. An entry in `HEARTWOOD_PROSE`, `HEARTWOOD_CI_PROSE` or `HEARTWOOD_CI_ALL` may be a pattern (`*`, `?` and `[...]`), where `*` matches across `/`: `HEARTWOOD_CI_PROSE="*.md"` makes every Markdown file prose to CI, new ones included, without listing each. Entries without those characters match as before.
- New: `HEARTWOOD_CI_CODE`, paths that are code to CI though a prose path or pattern covers them, for the Markdown an app's code or tests read (prompts, imported content, fixtures). It takes paths out of the commit gate's prose for CI too, so a fixture under `docs/` no longer has to move.

Upgrade (optional; nothing changes until an app sets them): move `@heartwood_tag` and the `actions/changes` pin to the new tag. To skip CI for any Markdown, add `*.md` to `HEARTWOOD_CI_PROSE` and list the Markdown the app's code or tests read in `HEARTWOOD_CI_CODE`.

## v0.2.1 (2026-11-27)

- New: skipping the CI jobs a pull request doesn't need. `bin/changes` sorts a change's paths into prose and code, and the code into areas, with three new settings: `HEARTWOOD_CI_PROSE` (files that are prose to CI though the commit gate still reviews them), `HEARTWOOD_CI_AREAS` and `HEARTWOOD_CI_ALL` (paths that run everything, as a change to `dev/guardrails/config.sh` always does). `actions/changes` runs it in a workflow; its `expect` input names the areas the workflow reads, so a missing one fails rather than skipping jobs. The README's "CI: skipping what a change doesn't touch" shows how.
- What counts as prose, and how a change's files are listed, is now `hooks/prose.sh`, which the commit gate and `bin/changes` both use. The commit gate behaves as before.

Upgrade (optional; nothing changes until an app adopts it): move `@heartwood_tag` to `v0.2.1`. To skip CI on prose-only pull requests, add the `changes` job and the conditions from the README to each workflow that tests code, with `HEARTWOOD_CI_PROSE` in `dev/guardrails/config.sh` for anything else that is prose to CI.

## v0.1.1 (2026-11-26)

- Fixed: the package's path in an app. Mix checks a `sparse:` dependency out into its folder, so the package is at `deps/heartwood_guardrails/guardrails`, but `hooks/app-shim`'s default `HEARTWOOD_HOME` and the README said `deps/heartwood_guardrails`. The default and the README now say where it is, and the tests lay an app out as Mix does.
- New: the architecture review, a periodic review of the whole repository by several models. `mix heartwood.architecture` writes its packet (`Heartwood.Guardrails.Architecture`), `review/architect.md` holds the reviewer's instructions, and `bin/record-architecture` keeps each model's report, in `<git common dir>/<app>-architecture/<run>/`. Its settings, in `dev/guardrails/config.sh`, have defaults: `HEARTWOOD_ARCHITECTURE` (`docs/architecture/`), `HEARTWOOD_ARCHITECTURE_QUESTIONS` (`dev/guardrails/architecture.md`) and `HEARTWOOD_GRAPH_DEPTH` (`3`).
- `Mix.Tasks.Heartwood.Status.lines/0` returns the report `mix heartwood.status` prints, and `Heartwood.Guardrails.Ratchet.flatten/1` keys counts by their key path; the architecture review uses both.

Upgrade (optional; v0.1.0's setup keeps working):

- Copy `hooks/app-shim` to `dev/githooks/pre-commit` and `pre-push` again; then `HEARTWOOD_HOME` can be dropped from `dev/guardrails/config.sh` if it was set only to work around the old default.
- For the architecture review: add `"heartwood.architecture": :test` to `preferred_envs` in `cli/0`, list the ratchets in `config :heartwood_guardrails, ratchets: [...]` (in `config/test.exs`) so the packet shows them, and write the app's questions for the reviewer in `dev/guardrails/architecture.md`.

## v0.1.0 (2026-11-26)

The first release: gallformers' guardrails (taxogall, 2026-11-26), with what was specific to gallformers made into settings.

- `Heartwood.Guardrails.Ratchet`, the baseline mechanics; `Heartwood.Guardrails.Patterns`, a ratchet built from rules, from the framework half of gallformers' `GallformersWeb.DesignSystem.Conformance`. New: rules name their own files, may filter their matches, and may count with a function instead of a pattern.
- `Heartwood.Guardrails.DuplicateCode` and `Heartwood.Guardrails.Retirements`, from gallformers' `test/support/guardrails/`. A retirement's `matter:` is now `why:`.
- `Heartwood.Guardrails.Assertions`: `assert_ratchet/1` and `assert_no_outstanding_retirements/0,1`.
- `mix heartwood.baseline` (one task for every ratchet) and `mix heartwood.status`.
- The commit gate, the push guard and their installer (`hooks/`), with `hooks/app-shim` for the app's `dev/githooks/`; the reuse review's `bin/review-packet` and `bin/record-review`, with the instructions in the packet itself. New: the commit gate blocks a staged `mix.lock` without heartwood's entries.
- `bin/check-toolchain`, the union of the two apps': every Dockerfile, Typst when `flake.nix` provides it, and `MIX_TAILWIND_PATH` when a Dockerfile sets it.

Upgrade: follow "Using it in an app" in the [README](README.md). For an app with gallformers' guardrails already:

- Its conformance module becomes a `Patterns` ratchet: the rules move into `rules/0`, with each rule's files (gallformers: its templates for every rule, its stylesheets for `hex_color` and `letter_case`, `tokens.css` exempt) and the hex-colour check as a `:filter`. The baseline file carries over unchanged.
- `mix gallformers.design_system.baseline` and `mix gallformers.guardrails.baseline` become `mix heartwood.baseline <ratchet>`.
- Retirement entries use `why:` in place of `matter:`.
- `dev/githooks/pre-commit` and `pre-push` become copies of `hooks/app-shim`; `dev/guardrails/config.sh` holds the settings (gallformers: `HEARTWOOD_APP=gallformers`, `HEARTWOOD_PROSE="docs/ runbooks/ README.md"`); `dev/guardrails/reviewer.md`'s gallformers questions and places to look move to the checklist. Run `deps/heartwood_guardrails/guardrails/hooks/install` again (the path from v0.1.1 on; this entry said `deps/heartwood_guardrails/hooks/install`): it replaces the old wrappers.
