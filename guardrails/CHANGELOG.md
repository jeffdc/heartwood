# Changelog

Every release that changes `heartwood_guardrails`, newest first. An entry that needs something from an app has "Upgrade:" steps. Versions are heartwood's tags (`v0.y.z`, one series for every package); while it's 0.x, a minor version needs action from an app and a patch is a drop-in.

## Unreleased: v0.1.0

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
- `dev/githooks/pre-commit` and `pre-push` become copies of `hooks/app-shim`; `dev/guardrails/config.sh` holds the settings (gallformers: `HEARTWOOD_APP=gallformers`, `HEARTWOOD_PROSE="docs/ runbooks/ README.md"`); `dev/guardrails/reviewer.md`'s gallformers questions and places to look move to the checklist. Run `deps/heartwood_guardrails/hooks/install` again: it replaces the old wrappers.
