#!/usr/bin/env bash
# Which packages a change touches, for CI to skip the jobs it doesn't need.
# Prints `guardrails=true|false` and `ui=true|false`, the lines
# GITHUB_OUTPUT takes. With two commits, reads the paths changed between
# them (BASE...HEAD, a move listed by both its paths); with none, one path
# per line on stdin.
#
# Prose touches neither: the commit gate's prose (HEARTWOOD_PROSE in
# dev/guardrails/config.sh, matched by guardrails/hooks/prose.sh, which the
# gate uses too) and Markdown at the repository's root, which no package
# reads. Any other path under guardrails/ or ui/ touches that
# package; any other path at all (the flake, the workflows, the Makefile,
# the review config) touches both.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source-path=SCRIPTDIR source=../../../guardrails/hooks/prose.sh
. "$here/../../../guardrails/hooks/prose.sh"

root=$(git rev-parse --show-toplevel)
config=${HEARTWOOD_CONFIG:-$root/dev/guardrails/config.sh}
# shellcheck source=/dev/null
. "$config"
prose=${HEARTWOOD_PROSE:-}

# Unlike the commit gate, CI needn't run for AGENTS.md or CLAUDE.md: no
# package reads Markdown at the root.
is_prose() {
  case "$1" in */*) ;; *.md) return 0 ;; esac
  heartwood_is_prose "$prose" "$1"
}

classify() {
  local guardrails=false ui=false path
  while IFS= read -r path || [ -n "$path" ]; do
    [ -z "$path" ] && continue
    is_prose "$path" && continue
    case "$path" in
      guardrails/*) guardrails=true ;;
      ui/*) ui=true ;;
      *) guardrails=true; ui=true ;;
    esac
  done
  echo "guardrails=$guardrails"
  echo "ui=$ui"
}

if [ $# -eq 2 ]; then
  (cd "$root" && heartwood_changed_files "$1...$2") | classify
else
  classify
fi
