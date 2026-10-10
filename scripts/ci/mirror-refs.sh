#!/usr/bin/env bash
# Prints the local refs of all upstream mirror branches, one per line.
#
# The ruleset "Upstream mirrors" is the only list of mirrors (see AROS-NX.md).
# This script reads its include patterns and matches them against the
# remote-tracking branches of REMOTE, so CI never keeps a second copy of the
# list. Commits reachable from these refs are upstream's.
#
# Usage: mirror-refs.sh [ruleset-json]
#   Without an argument the ruleset is read through the GitHub API, which
#   needs GITHUB_REPOSITORY and an authenticated gh. With a file argument the
#   ruleset JSON is read from that file; the probes use this.
# Environment: REMOTE (default origin), RULESET_NAME (default Upstream mirrors).
set -euo pipefail

remote=${REMOTE:-origin}
name=${RULESET_NAME:-Upstream mirrors}

die() { printf '::error::%s\n' "$*" >&2; exit 1; }

if [[ $# -ge 1 ]]; then
    ruleset=$(cat "$1")
else
    : "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is not set}"
    ids=$(gh api "repos/$GITHUB_REPOSITORY/rulesets" \
        --jq ".[] | select(.name == \"$name\" and .target == \"branch\") | .id")
    count=$(grep -c . <<<"$ids" || true)
    [[ $count -eq 1 ]] || die "expected exactly one branch ruleset named '$name', found $count"
    ruleset=$(gh api "repos/$GITHUB_REPOSITORY/rulesets/$ids")
fi

[[ $(jq -r .enforcement <<<"$ruleset") == active ]] ||
    die "ruleset '$name' is not active; its branches cannot be trusted as mirrors"
[[ $(jq '.conditions.ref_name.exclude | length' <<<"$ruleset") -eq 0 ]] ||
    die "ruleset '$name' has exclude patterns; this script does not evaluate them"

mapfile -t patterns < <(jq -r '.conditions.ref_name.include[]' <<<"$ruleset")
[[ ${#patterns[@]} -gt 0 ]] || die "ruleset '$name' has no include patterns"

mapfile -t branches < <(git for-each-ref --format='%(refname:lstrip=3)' "refs/remotes/$remote/")

found=0
for pattern in "${patterns[@]}"; do
    [[ $pattern == refs/heads/* ]] || die "unsupported pattern '$pattern' in ruleset '$name'"
    glob=${pattern#refs/heads/}
    for branch in "${branches[@]}"; do
        # In a ruleset, * does not match a slash. Mirror names never contain one.
        [[ $branch == */* ]] && continue
        # shellcheck disable=SC2053  # the right-hand side is a glob on purpose
        if [[ $branch == $glob ]]; then
            printf 'refs/remotes/%s/%s\n' "$remote" "$branch"
            found=$((found + 1))
        fi
    done
done

[[ $found -gt 0 ]] || die "no remote-tracking branch of '$remote' matches ruleset '$name'"
