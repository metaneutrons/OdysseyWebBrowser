#!/bin/sh
# gitleaks over the commits actually being pushed only.
# A full history scan on every push becomes unusably slow as the repository
# grows and teaches people to reach for --no-verify.
#
# Fork-specific range, deviating from the standard's template: the template
# scans @{upstream}..HEAD and falls back to the whole history. Here that would
# scan upstream's commits whenever a sync branch is pushed, and upstream's
# history holds tens of thousands of WebKit test keys. The range is therefore
# every commit that no remote-tracking ref knows yet, origin's or upstream's.
set -eu

command -v gitleaks >/dev/null 2>&1 || {
    printf '\033[31mPush rejected:\033[0m gitleaks is missing (brew install gitleaks).\n' >&2
    exit 1
}

if [ -z "$(git for-each-ref --count=1 refs/remotes)" ]; then
    printf '\033[31mPush rejected:\033[0m no remote-tracking refs; run git fetch first.\n' >&2
    printf '  A full scan would report upstream test keys as findings.\n' >&2
    exit 1
fi

# An empty range means there is nothing new to check.
if [ -z "$(git rev-list --max-count=1 HEAD --not --remotes)" ]; then
    printf 'gitleaks: no unpublished commits.\n' >&2
    exit 0
fi

printf 'gitleaks: checking %s unpublished commit(s)\n' \
    "$(git rev-list --count HEAD --not --remotes)" >&2
exec gitleaks git --redact --verbose --log-opts='HEAD --not --remotes' .
