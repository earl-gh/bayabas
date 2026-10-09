# Game Design Spec (source of truth for rules + starting numbers)

All numbers live in `res://data/` resources, never hardcoded. Units: meters, seconds. Values below are **starting points** for balancing; change them in data, not code.

## Core
| Key | Value |
|---|---|
| Player max HP | 100 (same for everyone) |
| Move speed | 5.0 m/s |
| Server tick | 30 Hz; snapshots to clients at 20 Hz |
| Weapon pick time | 10 s (match start); unpicked slots auto-fill with random weapons |
| Respawn time | 10 s, at own base, weapon swap allowed during the timer |
| Basic attack | **Decision pending (D1)** — default ON: melee "suntok", 6 dmg, 2.0 m, 0.8 s |

## Characters (cosmetic, randomized)
- Roster (`data/characters/*.tres`, `CharacterDef`): `junjun` boy, `ligaya` girl, `migo` gay boy, `toni` lesbian girl, `popoy` chubby boy, `inday` dark-skinned girl. Outfits in `docs/PROJECT.md` §3.2.
- Assigned by the **server** at match start with the match's seeded RNG: shuffle the roster, give one per player, no duplicates (6 characters ≥ max 6 players). Fixed for the whole match, including respawns and set switches.
- Purely visual: identical hitbox (capsule r=0.4 m), HP, speed, animations timing. Shown in loading screen, scoreboard and kill feed.
- Team readability: team-colored bandana/armband + ground ring; enemy outline on the local client.
- Practice mode: random character for the player, dummies use the others.

## Default skills
| Skill | Effect | CD |
|---|---|---|
| Takbo (Dash) | 5 m dash over 0.2 s, then 0.4 s stumble (can't move/cast) | 8 s |
| Bookmark | Place mark, blink 4 m forward, +30% speed for 4 s, then return to mark | 14 s |

Dash and Bookmark blink stop at walls (they never pass through). Death cancels active dash/stumble/bookmark effects; cooldowns keep running through death and respawn.

## Weapons
Status effects: `STUN` (no move/cast), `SLOW(x%)`, `AIRBORNE` (stun + vertical anim, no knockback), `POLYMORPH` (can: no cast, 50% speed), `BOUNCE` (short airborne), `KNOCKOUT` (ball; downed, no actions).
Effects do not stack with themselves; a new hard CC refreshes duration.

| ID | Type | Shape | Range | Damage | Effect | CD |
|---|---|---|---|---|---|---|
| bato_light | ATK | targeted projectile, nearest enemy in range | 7 | 14 | — | 4 |
| bato_heavy | ATK | ground AoE r=2.0, 0.6 s delay | 8 | 22 | STUN 2 s | 12 |
| gunting_light | ATK | cone 60°, 3 m, 2–6 snips (by hold/tap) | 3 | 4/snip | — | 5 |
| gunting_heavy | ATK | cone 60°, 3.5 m, 0.5 s delay | 3.5 | 24 | — | 9 |
| papel_trap | CC | placed, 0.75 s arm; triggers r=1.5 → slow zone r=2.5, 3 s | 6 | 0 | SLOW 40% | 12 |
| papel_shield | BLOCK | wall 3 m wide in front, 2.5 s, blocks enemy projectiles (incl. ball) | — | — | — | 14 |
| tsinelas_light | ATK | 3 boomerangs, fast, 0.15 s apart, out + back | 7 | 8 each way | — | 6 |
| tsinelas_heavy | ATK | 1 large boomerang, slow, out + back | 8 | 18 each way | — | 10 |
| lata | CC | thrown to point, r=1.5 | 7 | 5 | POLYMORPH 2 s | 14 |
| jacks | CC | scatter field r=2.0, lasts 4 s | 6 | 3 per 0.5 s | SLOW 30% | 11 |
| bola | CC | skillshot, 2 bounces (at 1/2 and full range), r=1.2 per bounce | 9 | 6 per bounce | BOUNCE 1 s | 12 |
| trumpo | CC | linear spinning projectile, stops at max range | 8 | 10 | AIRBORNE 2 s (once per target) | 15 |

Two copies of the same weapon cannot be equipped; two weapons of the same *type* can.

## Map (single mid lane, ~60 m long × 16 m wide)
- Layout per side, from base outward: base post → wall layer 1 → wall layer 2 → mid.
- Each wall layer = 3 columns (left / center / right), each column 300 HP. A column at 0 HP is removed and opens that slot.
- Walls block movement and projectiles. Walls take damage from all attacks and the ball (ball: 60).
- Base zone: circle r=2 around the electric post. A living, non-CC'd enemy standing in it for 0.5 s scores.
- Boundary walls on the long sides (house fronts, fences).
- Greybox placeholder geometry (base 4 m from each lane end, wall layers 7 m and 12 m from the base, 1 m thick) lives in `data/rules/map_layout.tres`; adjust there, not in code.

## Vertical layout (portrait game)
- The lane runs **along the screen's long axis**: your base at the bottom, the enemy base at the top. The server/sim map is orientation-agnostic (lane axis = Z); only the camera and UI know about portrait.
- Camera (data, tunable in `data/rules`): ~55° pitch, follows the local player, shows the full 16 m width and about 24 m of lane length. Values in `data/rules/camera_rules.tres` (pitch 55°, horizontal FOV 50°, lane + 2 m fills the screen width; the camera is centered on the lane and follows the player along it, stopping 6 m before each end). Team-relative: both teams see their own base at the bottom (view flips for the other team).
- Offscreen awareness: edge indicators for allies/enemies/ball/tricycle plus a slim lane minimap. Aim previews and skill ranges must remain readable within the visible area (long-range weapons rely on drag-to-aim and edge indicators).
- Because the visible depth is shorter than the lane, ranges, speeds and the lane length stay as specified; balance is re-checked in M6 with real play on phones.

## Scoring (volleyball format)
- **Point**: reach enemy base. After a point: 3 s freeze, all players reset to their bases at full HP, cooldowns reset. Walls **persist** within a set.
- **Set**: first to 5 points, win by 2, hard cap 7.
- **Match**: best of 3 sets. Teams switch bases each set; walls fully rebuild each set.

## Rubber ball
- Spawns at center every 15 s if none exists.
- Pick up: walk over it. Holder can throw (skillshot, 12 m, fast). Holder moves at 90% speed.
- Hit enemy → `KNOCKOUT` 3 s, ball despawns, timer restarts.
- Enemy "catch": an enemy who presses the Catch button within 0.3 s before contact catches it instead (becomes holder). **(D2 confirm)**
- Hit ally → ally becomes holder.
- Hit cardboard wall → 60 dmg, ball despawns, timer restarts.
- Hit boundary or max range → drops on ground, can be picked up.
- While in flight and not yet hit anything, the **thrower** can recast to blink to the ball. **(D3 confirm: thrower only)**

## Tricycle
- Every 120 s (first at 120 s), drives across the map's midline from a random side, ~3 s crossing, warning horn + lane marker 2 s before.
- Contact: 8 m knockback perpendicular to its path, away from it; no damage. **(D4 confirm)**

## Lobby rules
- Modes: 1v1, 2v2, 3v3. Passcode: 6 chars, A–Z/2–9, no ambiguous chars.
- Start allowed when: every present player is Ready AND one team has N players AND the other has ≥ N−1 (N=1 requires both).
- Host leaves in lobby → next player becomes host. Player disconnect in match → slot stays, 60 s to reconnect.

## Open decisions (defaults are implemented; change if the designer says so)
- **D1** Basic attack exists? (default yes — otherwise a CC-only loadout cannot damage)
- **D2** Ball catch input/timing.
- **D3** Who can blink to the ball (default: thrower only).
- **D4** Tricycle push direction (default: perpendicular, away from vehicle).
- **D5** Original brief for walls ends with "This must …" — unfinished requirement; ask designer.
- **D7** Bookmark "then return to mark": default = the player is moved back to the mark when the 4 s speed boost ends (data toggle `bookmark_returns` in `data/rules/game_rules.tres`).
- **D6** Only one Block weapon exists — consider a second one for loadout variety.
