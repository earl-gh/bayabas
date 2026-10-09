# CLAUDE.md — rules for Claude Code in this repo

Read first: `docs/HANDOFF.md` (what to build, in order), `docs/GDD.md` (rules + numbers), `docs/PROJECT.md` (scope).
**Android is the primary target** (competition entry); the browser build is optional for players but is the owner's testing channel. The owner works from an **iPhone** in cloud sessions: they can't run the editor. Every change must be verifiable through CI and the **GitHub Pages web build / PR preview link**.

## Stack (do not change without asking)
- Godot **4.6.x** stable (exact version in `.godot-version`), **Compatibility renderer**, GDScript with static types everywhere.
- Web export: **single-threaded** (`variant/thread_support=false`) so it runs on GitHub Pages without COOP/COEP headers.
- Networking: `WebSocketMultiplayerPeer`, **server-authoritative** headless Godot. Clients send inputs only.
- Tests: GUT, run headless in CI.

## Architecture rules (these prevent most bugs)
1. **Sim/view split.** All gameplay rules live in `scripts/sim/` as plain classes (`RefCounted`) that never touch nodes, input, or rendering. `scripts/view/` only reads sim state and plays visuals/audio. The same sim runs on the server, in offline practice, and in tests.
2. **Data-driven.** Every number from `docs/GDD.md` lives in `data/*.tres` (`WeaponDef`, `GameRules`). No magic numbers in code.
3. **Fixed timestep.** Sim advances only in `step(dt)` with dt = 1/30. Use a seeded RNG owned by the match. No `randf()` in sim.
4. **One input format.** `PlayerInput` (move vec, aim vec, buttons bitmask, tick). Touch, keyboard and network all produce it.
5. **Autoloads only:** `Net` (connection + RPC), `Session` (local player/room state), `Settings`. Nothing else global.
6. Signals over polling for view updates; no `get_node("../../..")` — use exported NodePaths or `%UniqueName`.

## Folder layout
```
scenes/{ui,match,map,props,fx}   scripts/{sim,view,net,ui,input}   data/{weapons,characters,rules}
assets/{models,textures,audio,icons,fonts}   server/   tests/{unit,integration}
```

## Workflow — versioning and PRs (mandatory)
- **Never commit to `main`.** One branch per task: `feat/<scope>-<short>`, `fix/...`, `chore/...`, `docs/...`, `test/...`.
- **Conventional Commits** (`feat(weapons): add trumpo airborne`). Breaking: `feat!:`. This drives release-please.
- Small PRs (one HANDOFF task each). Use `.github/pull_request_template.md`. Include the **PR preview URL** in the PR body and how to test it on a phone.
- PR must be green: GUT tests + web export. Squash-merge only.
- Releases: release-please opens a release PR on `main`; merging it tags `vX.Y.Z` and updates `CHANGELOG.md`. Don't edit versions or the changelog by hand. Pre-1.0: `feat` = minor, `fix` = patch.
- **Ship loop (owner-approved):** Claude opens the PR, waits for CI green, squash-merges it, waits for the Pages deploy of `main` to finish, then gives the owner the live link (`https://earl-gh.github.io/bayabas/`) plus what to check. Stop and ask instead if CI is red and not obviously fixable, or if the change is risky or outward-facing. The release-please release PR (tags a version) is still merged only when the owner says so.

## Platforms and how the owner tests
- **Dev channel = web build on the owner's iPhone browser** (Pages root for `main`, `pr-preview/pr-<N>/` for PRs). Always end a ship loop with that link.
- **Android stays releasable at all times:** the `android-debug-apk` CI job must stay green on every PR (artifact `bayabas-debug-apk`). Never merge a change that breaks the `Android` preset or needs desktop-only/thread APIs. Signed release APK/AAB is M6.
- Android-only problems (touch, safe areas, performance) can't be seen on the iPhone web build; call them out in the PR instead of assuming they work.

## Definition of done (per task)
- Static-typed, no warnings (treat warnings as errors in project settings).
- Unit tests for every sim rule touched (`tests/unit/test_<thing>.gd`).
- Works with touch **and** keyboard/mouse; UI usable at 390×844 portrait-safe areas and landscape (game is landscape).
- Web build loads on Pages; nothing requires threads, local files or desktop-only APIs.
- `docs/GDD.md` updated if a rule or number changed.

## Don'ts
- No C#/GDExtension (breaks single-threaded web export). No addons except GUT unless asked.
- No ENet/UDP for gameplay (doesn't work in browsers).
- No accounts, ranked, leveling, items, hero classes/abilities, damage types — out of scope by design. Characters are cosmetic only and randomly assigned.
- Never let a character choice change gameplay (hitbox, stats, timing).
- Don't guess on items listed under "Open decisions" in GDD: implement the default and keep it a data toggle.
