# AROS-NX integration model

This repository is the [AROS-NX](https://github.com/metaneutrons/AROS-NX)
integration fork of the Odyssey Web Browser maintained by
[deadwood2](https://github.com/deadwood2/OdysseyWebBrowser). Odyssey itself,
its licence and its copyright belong to its authors; see `LEGAL` and
`LICENSE.LGPL`. This fork adds build, qualification and release work for
AROS-NX on top of upstream and keeps that work reviewable.

## Branches

| Branch | Job | Who writes |
| --- | --- | --- |
| `main` | Upstream line plus reviewed AROS-NX changes; default branch | pull requests only |
| `odyssey`, `odyssey-*`, `master`, `webkit`, `jaokim_os4_compile`, `kas1e_branch` | Exact mirrors of the upstream branches of the same name | fast-forward pushes only |
| `feature/*`, `fix/*`, `docs/*`, `ci/*`, `chore/*` | Work for `main`, cut from `main` | contributors |
| `pr/<area>-<topic>` | One patch series meant for upstream, cut from the upstream branch it targets | contributors |
| `sync/upstream-<sha12>` | Short-lived proposal that integrates an upstream commit into `main` | maintainer |

`main` started at upstream `odyssey-webkitgtk-2.34.6+wayfarer-3`, commit
`01011649e863`, which is the line upstream actively develops. Upstream's
`odyssey` branch carries the released 2.1 code on WebKitGTK 2.24.4 and is
mirrored, not integrated.

The mirror branches are protected by the ruleset `Upstream mirrors`: they can
be neither deleted nor rewritten. CI reads that ruleset to decide which commits
are upstream's, so the ruleset is the single list of mirrors.

## Merge policy

Own work is merged by **squash**. The pull request title becomes the commit
subject on `main` and must follow Conventional Commits, because release-please
derives the version from it.

An upstream integration is merged with a **merge commit**. A squash would drop
the upstream commit as an ancestor of `main`; the next integration would then
see every earlier upstream change as a conflict. Its title has the form
`chore(upstream): integrate <branch> at <sha12>`.

CI classifies every pull request by content: one that brings in commits from a
mirror branch is an integration and needs the `chore(upstream):` title, any
other pull request must not use it. After the merge, CI checks on `main` that
integrations arrived as merge commits and everything else as single-parent
commits. GitHub cannot restrict the merge button per pull request, so this
check detects a wrong choice instead of preventing it. A squashed integration
is repaired by merging the same upstream commit again with a merge commit.

## Integrating upstream

```bash
git fetch origin && git fetch upstream
branch='odyssey-webkitgtk-2.34.6+wayfarer-3'
old=$(git rev-parse "origin/$branch")
new=$(git rev-parse "upstream/$branch")

# The mirror only ever moves forward. If this fails, upstream rewrote the
# branch: stop and decide how to integrate, do not force anything.
git merge-base --is-ancestor "$old" "$new"
# main must still contain the previously mirrored commit.
git merge-base --is-ancestor "$old" origin/main
git push origin "$new:refs/heads/$branch"

git switch -c "sync/upstream-${new:0:12}" origin/main
git merge --no-ff "$new"        # resolve conflicts here if there are any
git push -u origin HEAD
# --repo is required: in a fork, gh targets the upstream repository by default.
gh pr create --repo metaneutrons/OdysseyWebBrowser --base main \
  --title "chore(upstream): integrate $branch at ${new:0:12}"
```

Merge the pull request with **Create a merge commit** once CI is green.

Upstream moves to a new WebKit base by starting a new branch and rebuilding its
patches on it, rather than by advancing an existing branch. Such a switch is not
a routine integration; it is planned separately.

## Deliberate deviations from the repository standard

| Deviation | Reason |
| --- | --- |
| Merge commits allowed besides squash, no linear history rule | Upstream integrations must keep upstream commits as ancestors of `main` |
| `.gitignore` keeps path-anchored entries | The file is upstream's; the anchored entries name concrete top-level paths, the negations need the anchor, and every local change would conflict on each integration |
| Licence files stay `LICENSE.LGPL` and `LEGAL` | Derived work: the licence of the original stays as it is |
| Secret scanning covers own commits only | Upstream history contains tens of thousands of test keys and vectors in `Source/ThirdParty` that are not secrets of this project |
| `.editorconfig` covers only files this fork owns | Upstream sources follow WebKit's style; editors must not rewrite their whitespace |
