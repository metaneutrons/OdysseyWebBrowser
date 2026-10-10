#!/usr/bin/env bash
# Enforces the merge policy of AROS-NX.md: own work is squashed, an upstream
# integration arrives as a merge commit titled "chore(upstream): integrate …".
#
#   check-integration-policy.sh pr   <base-sha> <head-sha>    (title in PR_TITLE)
#   check-integration-policy.sh main <before-sha> <after-sha>
#
# "pr" classifies a pull request by content before the merge: it is an
# integration exactly when it brings in commits reachable from a mirror branch.
# "main" checks the commits a push added to main after the merge: a merge
# commit must be an integration, and an integration must be a merge commit.
# GitHub cannot restrict the merge button per pull request, so "main" detects
# the wrong button rather than preventing it.
#
# Mirror refs come from scripts/ci/mirror-refs.sh, or from the file named in
# MIRROR_REFS_FILE (one ref per line); the probes use the latter.
set -euo pipefail

die() { printf '::error::%s\n' "$*" >&2; exit 1; }

here=$(dirname "$0")
if [[ -n ${MIRROR_REFS_FILE:-} ]]; then
    mapfile -t mirrors < <(sort -u "$MIRROR_REFS_FILE")
else
    mapfile -t mirrors < <("$here/mirror-refs.sh" | sort -u)
fi
[[ ${#mirrors[@]} -gt 0 ]] || die 'no mirror refs; refusing to classify'

integration_title='^chore\(upstream\): integrate .+'
upstream_scope='^chore\(upstream\)'

# Number of commits in <from>..<to> that are upstream's.
upstream_commits() {
    local all own
    all=$(git rev-list --count "$2" "^$1")
    own=$(git rev-list --count "$2" "^$1" --not "${mirrors[@]}")
    echo $((all - own))
}

mode=${1:-}
case "$mode" in
pr)
    base=${2:?base sha missing} head=${3:?head sha missing}
    title=${PR_TITLE:?PR_TITLE is not set}
    n=$(upstream_commits "$base" "$head")
    if [[ $n -gt 0 ]]; then
        printf 'Integration: brings in %s upstream commit(s).\n' "$n"
        [[ $title =~ $integration_title ]] ||
            die "this pull request integrates upstream; its title must read 'chore(upstream): integrate <branch> at <sha12>'"
        printf '::notice::Merge this pull request with "Create a merge commit", not by squash.\n'
    else
        printf 'Own work: no upstream commits.\n'
        [[ ! $title =~ $upstream_scope ]] ||
            die "'chore(upstream)' is reserved for upstream integrations; this pull request brings in no upstream commit"
    fi
    ;;
main)
    before=${2:?before sha missing} after=${3:?after sha missing}
    if [[ $before =~ ^0+$ ]] || ! git cat-file -e "${before}^{commit}" 2>/dev/null; then
        commits=$after
    else
        commits=$(git rev-list --first-parent --reverse "$after" "^$before")
    fi
    status=0
    for c in $commits; do
        read -r -a parents <<<"$(git rev-list --parents -n 1 "$c")"
        np=$((${#parents[@]} - 1))
        subject=$(git log -1 --format=%s "$c")
        short=$(git rev-parse --short=12 "$c")
        case "$np" in
        1)
            if [[ $subject =~ $upstream_scope ]]; then
                printf '::error::%s "%s" is an integration merged by squash; upstream lost its ancestry. Merge the same upstream commit again with a merge commit.\n' "$short" "$subject"
                status=1
            fi
            ;;
        2)
            n=$(upstream_commits "${parents[1]}" "${parents[2]}")
            if [[ $n -eq 0 ]]; then
                printf '::error::%s "%s" is own work merged with a merge commit; own work is squashed.\n' "$short" "$subject"
                status=1
            elif [[ ! $subject =~ $integration_title ]]; then
                printf '::error::%s integrates %s upstream commit(s) but is titled "%s".\n' "$short" "$n" "$subject"
                status=1
            else
                printf '%s integration of %s upstream commit(s): ok\n' "$short" "$n"
            fi
            ;;
        *)
            printf '::error::%s has %s parents; octopus merges are not allowed on main.\n' "$short" "$np"
            status=1
            ;;
        esac
    done
    exit "$status"
    ;;
*)
    die "usage: $0 pr <base> <head> | main <before> <after>"
    ;;
esac
