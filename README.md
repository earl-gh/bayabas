# Bayabas

3D low-poly multiplayer MOBA (1v1 / 2v2 / 3v3) themed on Filipino street games. Godot 4.6, web + mobile.

- **Play (single live link, updates on every merge to `main`):** `https://earl-gh.github.io/bayabas/`

## Online play
Create/Join Room needs the game server running somewhere. See [server/README.md](server/README.md): free deploy on Render (all in the browser) or Fly.io, then set the repo variable `BAYABAS_SERVER_URL` so the live web build uses it.

## Docs
- [Project documentation](docs/PROJECT.md) — abstract, requirements, features
- [Game design spec](docs/GDD.md) — rules and balance numbers
- [Handoff / build order](docs/HANDOFF.md) — milestones for Claude Code
- [CLAUDE.md](CLAUDE.md) — rules for Claude Code (stack, architecture, PR/versioning)

## One-time GitHub setup
1. **Settings → Pages →** Build and deployment → Source: **GitHub Actions** (the `Pages` workflow deploys the web build of `main`).
2. **Settings → Actions → General →** Workflow permissions: *Read and write*, and tick *Allow GitHub Actions to create and approve pull requests* (needed by release-please).
3. **Settings → Branches →** protect `main`: require a PR (no required status checks; there is no CI on PRs).

## Workflows
- **Pages** (on every push to `main`): runs the unit tests, exports the web build and deploys the live link. If a test fails, nothing is deployed.
- **Android APK** (manual, Actions tab → Run workflow): builds an installable debug APK.
- **release-please** (on `main`): keeps the release PR up to date.

## Versioning
Conventional Commits → release-please opens a release PR → merging it tags `vX.Y.Z` and updates `CHANGELOG.md`.

## Starting a Claude Code cloud session
Paste this as the first prompt:

> Read CLAUDE.md and docs/HANDOFF.md. Start M0 task 1 on a new branch, follow the workflow rules, open a PR, review it, and stop for my review.
