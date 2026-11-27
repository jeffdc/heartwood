# shellcheck shell=bash
# What counts as prose, shared by the commit gate (hooks/pre-commit) and
# CI (bin/changes, run by actions/changes). Sourced, not run: it defines two
# functions and changes nothing else.
#
# heartwood_changed_files [git diff args...]: the paths a change touches.
# --no-renames lists a move by both its paths, so moving code into docs/
# still counts as changing the code it moved.
#
# heartwood_is_prose PROSE FILE: whether FILE is one of PROSE's paths
# (HEARTWOOD_PROSE): a directory, ending in /, covers everything under it;
# any other entry is one file.

heartwood_changed_files() {
  git diff --no-renames --name-only "$@"
}

heartwood_is_prose() {
  local prose=$1 file=$2 path
  for path in $prose; do
    case "$path" in
      */) [[ "$file" == "$path"* ]] && return 0 ;;
      *) [[ "$file" == "$path" ]] && return 0 ;;
    esac
  done
  return 1
}
