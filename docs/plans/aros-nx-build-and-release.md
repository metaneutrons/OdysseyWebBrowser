# Initiative plan: AROS-NX build and hardened release of Odyssey

Epic: pending, created after this plan is accepted
Decision state: proposed

## Outcome and boundaries

Odyssey for AROS-NX is built in CI from a clean checkout of `main` and
published as signed, attested GitHub releases, so that AROS-NX and its users
can consume a binary whose origin and content are verifiable.

Baseline, measured on 10 October 2026 at `main` = upstream
`odyssey-webkitgtk-2.34.6+wayfarer-3` (`01011649e863`) plus repository tooling:

- No CI builds Odyssey. CI checks only repository hygiene (`ci.yml`).
- `rebuild.sh` offers i386-aros and x86_64-aros, Release and RelWithDebInfo, and
  configures CMake with `Source/cmake/AROS.cmake`, `<cpu>-aros-gcc` and an SDK
  directory hard-coded to upstream's build machine.
- Upstream's history adapts the sources to GCC 6.5.0 and later GCC 10.5.0
  (`d20b3f4fc`, `c74b1d126`); the README still names 6.5.0 and an AROS SDK from
  branch `release-20241102`.
- Upstream's README states 12 minutes on 12 cores with 32 GB RAM and 90 minutes
  on 3 cores with 24 GB RAM. Not measured here.
- `Dist/` holds the runtime files of a distribution (catalogs, configuration,
  fonts, plugins, resources, scripts, Web Inspector).
- No release, tag or package channel of this fork exists. The three upstream
  tags `ODYSSEY_1.26`, `ODYSSEY_2.0` and `ODYSSEY_2.1` are mirrored and immutable.

Scope: x86_64 build for AROS-NX, its packaging, a smoke test, release-please and
the hardened release pipeline, GitHub Releases as the only channel.

Non-goals: Porting Odyssey to further CPUs; changes to WebKit or Odyssey
functionality beyond what the build needs; package channels other than GitHub
Releases; changing upstream's licence.

## Design and decisions

The profile is **hardened** because the fork ships binaries to end users. The
pipeline follows the repository standard's release stages: identity check,
build, cosign signature and GitHub attestation per payload, SPDX SBOM named
`<payload>.spdx.json`, payload completeness, staged prerelease, promotion to
`latest` last. release-please is the only route to a production tag; the
release pipeline has no tag trigger of its own and is started from the
release-please workflow.

Publication secrets live in the protected environment `release`, deployments
restricted to `main` and `v*` tags. The release pull request is created with the
existing release-please GitHub App, not `GITHUB_TOKEN`.

Open decisions, to be settled before the milestone that needs them:

- **D1 Toolchain (M1).** Upstream's GCC 10.5 cross compiler built from AROS
  `release-20241102`, or the AROS-NX LLVM 11 toolchain pinned in AROS-NX's
  `aros-toolchains.lock.toml`. The second keeps Odyssey on the toolchain AROS-NX
  itself uses, but AROS-NX's qualification covers only freestanding C and C++
  objects, not a C++ code base of WebKit's size, and `rebuild.sh` assumes GCC.
- **D2 SDK source (M1).** Which AROS-NX SDK the build links against and how it
  is fetched and pinned (release asset with checksum, or built in CI).
- **D3 Runner (M1).** GitHub-hosted runners for public repositories have 4 vCPU
  and 16 GB RAM; from upstream's figures a build there is forecast at well over
  an hour, before disk limits are known. Alternatives are a larger or
  self-hosted runner. Decided on the measurement from M1-A3.
- **D4 Artefact format (M2).** LHA as on Aminet, or a tar archive; it must be
  what AROS-NX's distribution build consumes.
- **D5 Versioning (M3).** This fork's own SemVer line starting below 1.0, with
  the upstream base named in the release notes, or a scheme that follows
  Odyssey's version numbers. Upstream tags `ODYSSEY_*` are not `v*` tags and
  never collide with the release ruleset.
- **D6 Smoke test (M2).** Whether a hosted AROS (linux-x86_64) can start the
  x86_64 binary headless in CI, or which weaker check replaces that.

## Delivery and acceptance

### M1: Reproducible x86_64 build in CI

Execution: pending
Dependencies: D1, D2, D3

- M1-A1: A workflow builds Odyssey for x86_64-aros from a clean checkout of a
  pull request head, with toolchain and SDK fetched by exact version and
  verified by SHA-256 before use.
- M1-A2: Counter-probe: a toolchain or SDK archive whose checksum does not match
  aborts the build before compiling.
- M1-A3: Wall-clock time, peak disk use and peak memory of one full build are
  recorded in the milestone issue with the run link.
- M1-A4: `rebuild.sh` or a CI-specific entry point takes the SDK directory as
  input; no path of upstream's build machine remains on the CI path.
- M1-A5: The build job reports through `CI Success`, and its triggers keep the
  required check reporting on every pull request (job-level filtering, not a
  workflow `paths` filter).

### M2: Release candidate artefact and smoke test

Execution: pending
Dependencies: M1, D4, D6

- M2-A1: The build produces one distributable archive per target that contains
  the executable and `Dist/`, built with normalised timestamps from
  `SOURCE_DATE_EPOCH` and owners, and is read back after creation.
- M2-A2: Two builds of the same commit produce byte-identical archives, or the
  remaining difference is named and accepted in this plan.
- M2-A3: The smoke test from D6 passes on a valid archive and fails on a
  deliberately corrupted copy for the expected reason.

### M3: release-please and hardened release pipeline

Execution: pending
Dependencies: M2, D5

- M3-A1: `release-please-config.json` and `.release-please-manifest.json` exist
  with `bump-minor-pre-major`, `draft` and `force-tag-creation`; the release pull
  request is opened by the release-please App and CI runs on it.
- M3-A2: Environment `release` exists, restricted to `main` and `v*` tags, and
  holds the App credentials; no publication secret is a repository secret.
- M3-A3: The pipeline implements the hardened stages listed above. Every gate
  has a recorded positive probe and counter-probe, run locally or in isolation
  before the first tag.
- M3-A4: A test tag `v<core>-<suffix>` runs the pipeline end to end up to the
  staged prerelease; the downloaded assets match the candidate inventory and
  every signature and attestation verifies against the downloaded bytes.
- M3-A5: The first production release is promoted to `latest` only after the
  verification of M3-A4 passes for it; its assets are verified byte for byte
  from the public URL afterwards.

### M4: Automated upstream integration proposals

Execution: pending
Dependencies: none

- M4-A1: A scheduled and manually startable workflow fast-forwards the tracked
  mirror branch, refuses to continue when upstream rewrote it or `main` lacks
  the previous mirror commit, and opens a `chore(upstream): integrate …` pull
  request without merging it.
- M4-A2: Its credential is a GitHub App installation token in a protected
  environment, not a stored personal access token, and the pull requests it
  opens trigger CI.
- M4-A3: Probes cover an unchanged upstream, a fast-forward, a rewritten
  upstream branch and an already existing proposal.

The initiative is complete when M1 to M3 are accepted. M4 can be delivered
independently.

## Migration, risks and verification cost

- Upstream moves to a new WebKit base by starting a new branch and rebuilding
  its patches there, not by advancing the existing one. Of the 16 `odyssey-*`
  branches only `odyssey-webkitgtk-2.24.4` is an ancestor of `odyssey`, the line
  `odyssey` continues; `master` and `webkit` are not. Such a switch cannot be
  integrated by a routine merge; it needs its own plan when it happens.
- A tag consumed by a failed pipeline run is lost for good because of the tag
  ruleset. Test tags are budgeted per M3-A4, and jobs a prerelease skips are
  first executed by a production tag.
- The build cost on hosted runners is a forecast from upstream's figures, not a
  measurement; M1-A3 replaces it with one.
- Upstream history contains WebKit test keys; the secret scan therefore covers
  own commits only (see AROS-NX.md).

## Decision changes

None yet.
