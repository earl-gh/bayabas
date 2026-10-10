# Kalyeah roadmap

What is built, what is next, and the rules for building it. Rules and numbers live in `GDD.md`; look and feel in `ART.md`; scope in `PROJECT.md`.

## Done

| Milestone | What shipped |
|---|---|
| M0 Scaffold | Godot 4.6 project, web + Android + server export presets, GUT, title screen, Pages deploy |
| M1 Sandbox | Sim core (fixed 30 Hz step, seeded RNG), movement and collision, follow camera, touch/keyboard input, death delay, Dash and Bookmark, practice dummies, six random characters |
| M2 Weapons | 12 weapons as data over 9 generic shapes, status effects, weapon pick (10 s) and respawn swap, aim and cancel, cooldown rules (no precasting, auto-aim locked at the press) |
| M3 Objectives | Breakable cardboard walls, base scoring, sets and side switch, the guava neutral (heals half HP on pickup, can be thrown), tricycle |
| M4 Multiplayer | Rooms with passcodes, headless authoritative server, snapshots, prediction and reconnect, lobby screens, Dockerfile and deploy guide |
| M5 Look and feel (first pass) | Procedural low-poly street, props and kids, themed UI, vector icons, synthesised audio, MOBA HUD, camera, rigged kid animation |

## Next: the Kalyeah visual overhaul

Goal: the look of the owner's reference image (League of Legends mid view, Clash of Clans design language, Filipino street): soft, chunky, painted-looking 3D with readable effects. Procedural boxes are not enough; real Blender-authored assets are.

| Phase | Work | Done when |
|---|---|---|
| P0 ✅ | Rename to Kalyeah; docs cleaned up (this file replaces `HANDOFF.md`) | no stale names or docs; tests green |
| P1 ✅ | The match screen is split into `MatchInput`, `MatchHud` (all HUD built in code) and wiring; `practice.tscn` is 79 lines | behaviour unchanged, tests green |
| P2 ✅ | HUD spec below | screenshot matches the spec |
| P3 ✅ | League of Legends camera | numbers below, camera tests updated |
| P4 | Sprite kids (replaces the Blender kids): Junjun done; Ligaya, Migo, Toni, Popoy, Inday waiting for sheets | all six kids use their own sprites |
| P5 | Environment kit in Blender (tin roofs, cardboard sheets, tyres, plants, hoop, drains, tricycle with driver, base post with posters) | street matches the reference |
| P6 | Effects: impact debris, trails, dust, ground rings, per-weapon projectiles | every weapon has a clear effect |
| P7 | UI pass: painted skill icons, team portraits and timer across the top, framed minimap | HUD matches the reference |
| P8 | Performance and Android: frame rate, download size, APK | budgets below |

Budgets (M6): 60 fps on a recommended Android phone, 30+ on the minimum; APK under 150 MB; web build under 50 MB.

### HUD spec (owner)
- No player name above the health bar.
- A status such as *Stunned* is **italic** and shown **above** the health bar.
- Below the health bar, one row with two thin bars: **Dash** cooldown on the left and **Mark** cooldown on the right.
- Skill buttons are art only, plus the weapon type (ATK, CC or BLK) as a small tag. No health panel in the top-left corner.

### Camera spec (owner): exactly League of Legends
- Pitch **56°** from horizontal, field of view **30°** (vertical), far camera with a flat perspective.
- The camera distance is derived from the screen shape so about 13 m of the lane width is visible on any phone; the angle and field of view are not changed for that. It looks 2.5 m ahead of the hero.
- It follows the hero and eases after them; it does not tilt or roll.

## Rules for building (to avoid retries)
1. **No regex on `.tscn` files.** Complex screens are built in code and tested; scene files stay small and stable.
2. **Every text replacement is guarded:** it must match the expected number of times or the edit stops.
3. **One concern per commit.** Each step ends with: project import, the full GUT suite, and a 720×1280 screenshot checked by eye.
4. Files over about 400 lines are split before they are edited again.
5. Pull requests are meaningful chunks, opened by Claude and merged by the owner. See `CLAUDE.md`.

## Decisions log
- No basic attack; death delay with gray HP; teams pass through their own walls (see `GDD.md`).
- The neutral is the guava; eating it heals half max HP and you keep it to throw (change in one data value).
- Game name: **Kalyeah**. Tagline: *Mga larong Pinoy sa kalye*. Android package `com.kalyeah.game`.
- Environment assets are made in Blender (the `bpy` Python module works in the cloud session). The kids are sprites from sheets the owner generates (`tools/sprites/slice_sheets.py` cuts them).
- Multiplayer is built and tested; deploying the server and setting `KALYEAH_SERVER_URL` is the owner's step (`server/README.md`).
