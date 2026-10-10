# Contributing

This is the AROS-NX integration fork of the Odyssey Web Browser. Read
[AROS-NX.md](AROS-NX.md) first: it explains which branch takes which change and
how upstream is integrated. Changes that are not specific to AROS-NX belong
upstream at [deadwood2/OdysseyWebBrowser](https://github.com/deadwood2/OdysseyWebBrowser);
prepare them on a `pr/<area>-<topic>` branch cut from the upstream branch they
target.

## Commits and pull requests

- Everything written into the repository is English: commit messages, pull
  request titles and bodies, branch names, changelog entries.
- Commit subjects and pull request titles follow
  [Conventional Commits](https://www.conventionalcommits.org/): `feat`, `fix`,
  `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`,
  an optional lower-case scope, `!` for a breaking change. At most 100
  characters.
- One pull request carries changes of one kind. The squash subject decides the
  changelog section, so a fix that travels inside a `feat` pull request is filed
  under Features.
- Own work is merged by squash. Upstream integrations are merged with a merge
  commit and titled `chore(upstream): integrate <branch> at <sha12>`; see
  [AROS-NX.md](AROS-NX.md#merge-policy).
- No AI attribution trailers (`Co-authored-by: … Claude`, `Generated with
  Claude Code`) in commits or pull requests.
- Cut work branches from `main`: `feature/*`, `fix/*`, `docs/*`, `ci/*`,
  `chore/*`.

## Local checks

The hooks run through [lefthook](https://lefthook.dev) and need
[gitleaks](https://github.com/gitleaks/gitleaks):

```bash
brew install lefthook gitleaks
lefthook install
```

They check the commit message, refuse direct commits to `main`, staged build
directories and files over 5 MiB, and scan staged changes and unpublished
commits for secrets. If a hook gets in your way, fix the cause or ask; do not
use `--no-verify`. CI repeats every check and is what decides.

Run the same checks by hand with:

```bash
lefthook run pre-commit
lefthook run pre-push
```

## Building

Building Odyssey needs an AROS cross compiler and SDK; see [README.md](README.md).
Larger initiatives such as the CI build and the release pipeline are planned in
[docs/plans/](docs/plans/), with an epic and one issue per milestone.
