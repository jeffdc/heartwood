# Heartwood

Code shared by Oak Compendium (`~/dev/oaks`) and Gallformers (`~/dev/gallformers`). What's here is used by both, so it must fit both: anything specific to one app (its modules, paths, tokens, names or rules) stays in that app, and reaches heartwood only as a setting or an argument. Test fixtures in `test/support/` may come from one app, and say whose they are.

## Working here

- **Run everything inside the Nix dev shell** (direnv, or `nix develop -c <cmd>`): the same Elixir and OTP as both apps.
- **Each package is its own Mix project** in its folder (`guardrails/`); run mix there.
- **`make done-checks` must pass** before work is finished: each package's `mix precommit` (format, compile with warnings as errors, `credo --strict`, unused deps, tests), Dialyzer and the security audits. CI requires the same.
- **Search before you write.** Look in the packages for code that already does the job before adding a module, function or script.
- **Scripts and hooks are tested** by running them for real (git in throwaway repositories, `check-toolchain` against fixture roots). A change to one changes its test.
- **Prose isn't hard-wrapped:** one line per paragraph or list item, in docs, READMEs, changelogs and commit message bodies. Code comments follow the file.

## Before you commit

The pre-commit hook (`dev/githooks/`, installed by `make hooks`) blocks a commit without a passing reuse review. A commit touching only `docs/`, the READMEs or the changelogs needs none.

1. Stage files by name, then run `guardrails/bin/review-packet`.
2. A reviewer with fresh context, not yours, follows the packet and records its verdict.
3. On block: fix, restage, review again. Never re-run the review for a different answer; disputes go to Jeff.
4. Commit once it passes.

Never force-push, and never push main; the pre-push hook blocks both. Changes reach main through pull requests, which Jeff merges.

## Changes and releases

- **The contract** is what each package's README lists under "Contract". A change to it gets an entry in that package's CHANGELOG.md, under "Unreleased", with "Upgrade:" steps when an app has to do something.
- **Versions** are tags, `v0.y.z`, one series for both packages. While it's 0.x, a change that needs action from an app is a minor version; a drop-in is a patch. A package's `@version` in `mix.exs` matches the tag that releases it.
- **A release** is a tag on main, after Jeff merges, made with Jeff's go-ahead: the changelog's "Unreleased" becomes the version and date, and the tag is pushed (`git push origin vX.Y.Z`).
- **A change is done** when it's tagged with its changelog entry, the app that needed it is on the new tag with its checks passing, and the other app either is too or has an entry in its `docs/backlog.md` ("Upgrade heartwood to vX.Y.Z: <steps>").
- **A bug found in an app** is fixed here, with the app pointed at this checkout (`HEARTWOOD_PATH=~/dev/heartwood`), never in the app's `deps/`.
