# Bayabas

3D low-poly multiplayer MOBA (1v1 / 2v2 / 3v3) themed on Filipino street games. Godot 4.6, web + mobile.

- **Play (main):** `https://earl-gh.github.io/bayabas/`
- **PR previews:** `https://earl-gh.github.io/bayabas/pr-preview/pr-<N>/` (link is posted on each PR)

## Docs
- [Project documentation](docs/PROJECT.md) — abstract, requirements, features
- [Game design spec](docs/GDD.md) — rules and balance numbers
- [Handoff / build order](docs/HANDOFF.md) — milestones for Claude Code
- [CLAUDE.md](CLAUDE.md) — rules for Claude Code (stack, architecture, PR/versioning)

## One-time GitHub setup
1. **Settings → Pages →** Source: *Deploy from a branch*, Branch: `gh-pages` / root (the branch appears after the first Pages run).
2. **Settings → Actions → General →** Workflow permissions: *Read and write*, and tick *Allow GitHub Actions to create and approve pull requests* (needed by release-please and PR previews).
3. **Settings → Branches →** protect `main`: require PR, require the `CI` check, squash merge only.

## Versioning
Conventional Commits → release-please opens a release PR → merging it tags `vX.Y.Z` and updates `CHANGELOG.md`.

## Starting a Claude Code cloud session
Paste this as the first prompt:

> Read CLAUDE.md and docs/HANDOFF.md. Start M0 task 1 on a new branch, follow the workflow rules, open a PR with the preview link, and stop for my review.
