# Kalyeah

*Mga larong Pinoy sa kalye.* A stylised 3D multiplayer MOBA (1v1, 2v2, 3v3) built on Filipino street games: bato-bato-pik, tumbang preso, jackstones and trumpo. Portrait, one thumb, quick matches. Built with Godot 4.6 for Android, with a web build.

- **Play (one live link, updates on every merge to `main`):** <https://earl-gh.github.io/kalyeah/>

## Docs
- [Roadmap](docs/ROADMAP.md): what is done, what is next, and how we build
- [Game design](docs/GDD.md): rules and balance numbers (the source of truth)
- [Art, UI and audio](docs/ART.md): look, assets, HUD, sound
- [Project documentation](docs/PROJECT.md): abstract, requirements, features
- [Server guide](server/README.md): run and deploy the game server
- [CLAUDE.md](CLAUDE.md): rules for Claude Code (stack, architecture, workflow)

## Online play
Create and Join Room need the game server running somewhere. See [server/README.md](server/README.md): free deploy on Render (all in the browser) or Fly.io, then set the repo variable `KALYEAH_SERVER_URL` so the live web build uses it.

## One-time GitHub setup
1. **Settings → Pages →** Build and deployment → Source: **GitHub Actions** (the `Pages` workflow deploys the web build of `main`).
2. **Settings → Actions → General →** Workflow permissions: *Read and write*, and tick *Allow GitHub Actions to create and approve pull requests* (needed by release-please).
3. **Settings → Branches →** protect `main`: require a PR (no required status checks; there is no CI on PRs).

## Workflows
- **Pages** (every push to `main`): runs the unit tests, exports the web build and deploys the live link. If a test fails, nothing is deployed.
- **Android APK** (manual, Actions tab → Run workflow): builds an installable debug APK (`kalyeah-debug-apk`).
- **release-please** (on `main`): keeps the release PR up to date.

## Versioning
Conventional Commits → release-please opens a release PR → merging it tags `vX.Y.Z` and updates `CHANGELOG.md`.

## Run the tests
```sh
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gexit
```

## Starting a Claude Code cloud session
Paste this as the first prompt:

> Read CLAUDE.md and docs/ROADMAP.md. Continue with the next phase on a new branch, follow the workflow rules, open a PR, and stop for my review.
