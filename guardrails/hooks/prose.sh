# shellcheck shell=bash
# What counts as prose, shared by the commit gate (hooks/pre-commit) and
# CI (bin/changes, run by actions/changes). Sourced, not run: it defines
# three functions and changes nothing else.
#
# heartwood_changed_files [git diff args...]: the paths a change touches.
# --no-renames lists a move by both its paths, so moving code into docs/
# still counts as changing the code it moved.
#
# heartwood_is_prose PROSE FILE: whether FILE is one of PROSE's paths
# (HEARTWOOD_PROSE): a directory, ending in /, covers everything under it;
# any other entry is one file, or a pattern (*, ? and [...], as in bash's
# [[ == ]]), where * matches across /: *.md is every Markdown file.
#
# heartwood_counts_as_prose PROSE CODE FILE: whether FILE is one of PROSE's
# paths and none of CODE's (HEARTWOOD_CODE), matched the same way: CODE
# takes back the prose that code or tests read.

heartwood_changed_files() {
  git diff --no-renames --name-only "$@"
}

heartwood_is_prose() {
  local file=$2 path paths
  # read, not an unquoted $1, so a pattern isn't expanded against the
  # files in the working directory.
  read -ra paths <<<"$1"
  for path in ${paths[@]+"${paths[@]}"}; do
    case "$path" in
      */) [[ "$file" == "$path"* ]] && return 0 ;;
      # shellcheck disable=SC2053 # unquoted: the entry is a pattern
      *) [[ "$file" == $path ]] && return 0 ;;
    esac
  done
  return 1
}

heartwood_counts_as_prose() {
  ! heartwood_is_prose "$2" "$3" && heartwood_is_prose "$1" "$3"
}
