# CLAUDE.md — rules for Claude Code in this repo

Read first: `docs/HANDOFF.md` (what to build, in order), `docs/GDD.md` (rules + numbers), `docs/PROJECT.md` (scope).
**Android is the primary target** (competition entry); the browser build is optional for players but is the owner's testing channel. The owner works from an **iPhone** in cloud sessions: they can't run the editor. Every change must be checkable on the **GitHub Pages web build (one live link, rebuilt on every merge to `main`)**.

## Stack (do not change without asking)
- Godot **4.6.x** stable (exact version in `.godot-version`), **Compatibility renderer**, GDScript with static types everywhere.
- Web export: **single-threaded** (`variant/thread_support=false`) so it runs on GitHub Pages without COOP/COEP headers.
- Networking: `WebSocketMultiplayerPeer`, **server-authoritative** headless Godot. Clients send inputs only.
- Tests: GUT, run headless. Claude runs them locally before every PR (Godot 4.6.2 headless binary from the official GitHub release); the Pages deploy runs them again on `main` and refuses to deploy if any fail.

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
- **Continuous development, meaningful PRs:** one PR per solid chunk of progress (several HANDOFF tasks or a whole milestone), not one PR per tiny task. Use `.github/pull_request_template.md`. In the PR body say what changed and how to check it on a phone on the single live link (`https://earl-gh.github.io/bayabas/`, valid after the owner merges).
- **No CI on PRs.** The owner reads the PR and merges. Before opening it, Claude runs the full GUT suite locally and it must pass.
- Releases: release-please opens a release PR on `main`; merging it tags `vX.Y.Z` and updates `CHANGELOG.md`. Don't edit versions or the changelog by hand. Pre-1.0: `feat` = minor, `fix` = patch.
- **Ship loop (owner merges, Claude never does):**
  1. Develop a meaningful chunk on a feature branch with tests.
  2. Run the full GUT suite locally (and import the project) until everything passes; re-read the diff and fix anything found.
  3. Open the PR with a clear summary, any design choices that need the owner's call, and exactly what to check on the live link. Then hand over and keep going on the next chunk on a new branch.
  4. The owner reads, merges, and checks `https://earl-gh.github.io/bayabas/` once the `Pages` run on `main` finishes. Never merge the release-please PR.

## Platforms and how the owner tests
- **Dev channel = web build on the owner's iPhone browser** (the single Pages link, rebuilt on every merge to `main`). Always hand over with that link and what to check.
- **Android stays releasable:** never add anything that breaks the `Android` export preset or needs desktop-only/thread APIs. An installable debug APK can be built any time from Actions → **Android APK** → Run workflow (artifact `bayabas-debug-apk`). Signed release APK/AAB is M6.
- Android-only problems (touch, safe areas, performance) can't be seen on the iPhone web build; call them out in the PR instead of assuming they work.

## Art and orientation (binding)
- **Portrait (vertical) only**: Android locked to portrait; the web build shows a "rotate your phone" prompt if held in landscape. Bayabas is a vertical MOBA by design (see `docs/PROJECT.md` section 3.8 and `docs/GDD.md` "Vertical layout").
- Art style: Clash of Clans-like, low-poly flat-shaded 3D with a Filipino street theme. Chunky, bright, saturated, readable at phone size. Inspired by, never copied: no Supercell assets, names or logos. Full spec in `docs/PROJECT.md` section 3.8.

## Definition of done (per task)
- Static-typed, no warnings (treat warnings as errors in project settings).
- Unit tests for every sim rule touched (`tests/unit/test_<thing>.gd`).
- Works with touch **and** keyboard/mouse; UI built portrait-first at 720×1280 base and usable at 390×844 with safe areas (notch, home bar); thumb-reachable controls.
- Web build loads on Pages; nothing requires threads, local files or desktop-only APIs.
- `docs/GDD.md` updated if a rule or number changed.

## Don'ts
- No C#/GDExtension (breaks single-threaded web export). No addons except GUT unless asked.
- No ENet/UDP for gameplay (doesn't work in browsers).
- No accounts, ranked, leveling, items, hero classes/abilities, damage types — out of scope by design. Characters are cosmetic only and randomly assigned.
- **No basic attack.** Players only use their picked weapons plus the default skills (Dash, Bookmark).
- Never let a character choice change gameplay (hitbox, stats, timing).
- Don't guess on items listed under "Open decisions" in GDD: implement the default and keep it a data toggle.
