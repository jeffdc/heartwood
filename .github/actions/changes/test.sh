#!/usr/bin/env bash
# Runs changes.sh on lists of paths, with this repository's prose list, and
# on real commits of this repository, and checks what it prints.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
failures=0

expect() {
  local name=$1 expected=$2 got=$3
  if [ "$got" = "$expected" ]; then
    echo "ok: $name"
  else
    echo "FAIL: $name: expected '$expected', got '$got'"
    failures=$((failures + 1))
  fi
}

check() {
  expect "$1" "$2" "$(printf '%s' "$3" | "$here/changes.sh" | paste -sd' ' -)"
}

check "nothing" "guardrails=false ui=false" ""
check "prose only" "guardrails=false ui=false" $'README.md\nui/CHANGELOG.md\nguardrails/README.md\ndocs/architecture/rules.md\nAGENTS.md\nCLAUDE.md\nPRODUCT.md'
check "the reviewer's instructions are guardrails code" "guardrails=true ui=false" $'guardrails/review/reviewer.md'
check "Markdown under a package that isn't listed as prose is code" "guardrails=false ui=true" $'ui/dev/notes.md'
check "guardrails code" "guardrails=true ui=false" $'guardrails/lib/heartwood/guardrails/ratchet.ex\nguardrails/CHANGELOG.md'
check "ui code" "guardrails=false ui=true" $'ui/lib/heartwood/ui/photo_viewer.ex\nui/package-lock.json'
check "both packages" "guardrails=true ui=true" $'guardrails/mix.lock\nui/mix.lock'
check "shared files touch both" "guardrails=true ui=true" $'flake.nix'
check "a workflow touches both" "guardrails=true ui=true" $'.github/workflows/ci.yml\ndocs/x.md'
check "the review config touches both" "guardrails=true ui=true" $'dev/guardrails/config.sh'
check "the review checklist touches both" "guardrails=true ui=true" $'dev/guardrails/checklist.md'

# Real commits: the one that added heartwood_ui (code in both packages and
# outside them), one that only changed docs/, and the v0.1.1 release.
real() {
  expect "$1" "$2" "$("$here/changes.sh" "$3" "$4" | paste -sd' ' -)"
}

real "the heartwood_ui commit" "guardrails=true ui=true" 0cd7ff7~1 0cd7ff7
real "a docs-only commit" "guardrails=false ui=false" a445daf~1 a445daf
real "the v0.1.1 release" "guardrails=true ui=true" 58e39fd~1 58e39fd

# A move out of a package into docs/ removes a file the package reads: it
# touches the package, as the commit gate counts it. In a throwaway
# repository with this repository's layout and prose list.
repo=$(mktemp -d)
trap 'rm -rf "$repo"' EXIT
(
  cd "$repo"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  mkdir -p dev/guardrails guardrails/review docs
  echo 'HEARTWOOD_PROSE="docs/ README.md"' > dev/guardrails/config.sh
  echo "instructions" > guardrails/review/reviewer.md
  git add -A && git commit -qm base
  git mv guardrails/review/reviewer.md docs/reviewer.md
  git commit -qm move
)
expect "a move into docs/ touches the package it left" "guardrails=true ui=false" \
  "$(cd "$repo" && "$here/changes.sh" HEAD~1 HEAD | paste -sd' ' -)"

[ "$failures" -eq 0 ]
