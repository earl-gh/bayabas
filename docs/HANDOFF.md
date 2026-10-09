# Handoff — build order

Each milestone = a few small PRs, each with tests and a working Pages preview. Finish a milestone before starting the next. Target version after each milestone is shown; release-please produces it from commit types.

## M0 — Scaffold (→ v0.1.0)
1. Create Godot 4.6 project at repo root: Compatibility renderer, landscape, stretch mode `canvas_items`/aspect `expand`, warnings-as-errors for untyped code.
2. Folders per `CLAUDE.md`. Autoloads `Net`, `Session`, `Settings` (stubs).
3. `export_presets.cfg` with presets named exactly **`Web`** (single-threaded, export to `build/web/index.html`), **`Android`**, **`Server`** (Linux, dedicated server feature tag).
4. Add GUT under `addons/gut`, `.gutconfig.json`, one passing test.
5. Title screen: "Bayabas", buttons Practice / Create Room / Join Room (stubs), version label read from `ProjectSettings application/config/version` (CI stamps it from `version.txt`, which release-please owns; keep `config/version` present in `project.godot`).
6. Confirm CI green, Pages shows title screen on iPhone Safari.

## M1 — Offline sandbox (→ v0.2.0)
1. Greybox map: 60×16 m lane, bases, boundary walls, 2 wall layers × 3 columns per side (placeholder boxes).
2. Sim core: `MatchSim.step(dt)`, `PlayerState`, `PlayerInput`, seeded RNG.
3. Movement + collision in sim (simple circle vs AABB, no physics engine dependency in sim).
4. Isometric-style follow camera (ML-like, ~55° pitch); team-relative so your base is always bottom-left.
5. Input: on-screen joystick + 4 skill buttons with **drag-to-aim** and cancel zone; keyboard WASD, mouse aim, Q/E weapons, Space dash, F bookmark, R ball.
6. HP, death, 10 s respawn; Dash (with stumble) and Bookmark.
7. Practice mode with 2 training dummies (stand still / walk back and forth).

## M2 — Weapons (→ v0.3.0)
1. `WeaponDef` resource + generic shape executors: targeted projectile, skillshot, cone, ground AoE w/ delay, placed trap/field, boomerang, wall/shield, bouncing projectile, travelling spinner.
2. `StatusEffect` system: STUN, SLOW, AIRBORNE, POLYMORPH, BOUNCE, KNOCKOUT (rules in GDD).
3. Author the 12 weapons as `.tres` using executors only — no per-weapon scripts unless unavoidable.
4. Aim indicators per shape; cooldown UI with type icon (ATK/CC/BLOCK).
5. Weapon pick screen: 10 s, grouped by street game, auto-fill on timeout; same screen on respawn.
6. Tests: each executor + each status effect.

## M3 — Objectives and neutrals (→ v0.4.0)
1. Destructible wall columns (HP, block move + projectiles, removal).
2. Base scoring zone, point reset flow, set/match scoring, side switch, wall rebuild per set. Scoreboard HUD.
3. Rubber ball: spawn timer, pickup, throw, knockout, ally pass, catch, wall damage, thrower blink.
4. Tricycle: 120 s timer, warning, crossing, knockback.
5. Tests: full scoring sequence, ball state machine, tricycle timing.

## M4 — Multiplayer (→ v0.5.0)
1. Headless server entry (`server/main.tscn`, started when `OS.has_feature("dedicated_server")`), `Dockerfile`, WebSocket port from env `PORT`.
2. Room service: create (mode) → passcode, join, team slot pick, ready toggle, host transfer, start rules from GDD, loading screen sync.
3. Netcode: clients send `PlayerInput` at 30 Hz; server steps `MatchSim`, sends snapshots at 20 Hz; client interpolation for others, prediction + reconciliation for own movement only.
4. Server URL: `Settings.server_url`, overridable on web via `?server=wss://...` query param. Pages build must use `wss://`.
5. Reconnect within 60 s. Integration test: two in-process clients against an in-process server.
6. Deploy doc in `server/README.md` (Fly.io or Render free tier).

## M5 — Art, UI and audio (→ v0.6.0)
Low-poly flat-shaded `.glb` props with one palette texture: sari-sari store, houses, laundry lines, tricycle, electric post with flyers (septic siphoning, hiring, police notice, generic election poster — fictional names only), cardboard walls, street-game weapons. Character: one shared base body with team colors/cosmetic-free. Pinoy-street UI theme, weapon icons, SFX, short BGM loop.

## M6 — Polish and release (→ v1.0.0)
Performance budget (60 fps mid Android, 30+ fps iPhone Safari; < 50 MB web download), balance pass, settings (volume, graphics, joystick size), tutorial overlay, Android signed release in GitHub Releases, `feat!: 1.0` release.

## Fast-and-safe tips
- Write the sim test first, then the code; sim tests run in < 1 s with `godot --headless -s addons/gut/gut_cmdln.gd`.
- Keep scenes thin; logic in scripts so diffs are reviewable from a phone.
- When a CI export fails, read the full log — most failures are a missing preset name or export template version mismatch with `.godot-version`.
