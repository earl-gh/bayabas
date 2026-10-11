# Game Design Spec (source of truth for rules + starting numbers)

All numbers live in `res://data/` resources, never hardcoded. Units: meters, seconds. Values below are **starting points** for balancing; change them in data, not code.

## Core
| Key | Value |
|---|---|
| Player max HP | 100 (same for everyone) |
| Move speed | 5.0 m/s |
| Server tick | 30 Hz; snapshots to clients at 20 Hz |
| Weapon pick time | 10 s (match start); unpicked slots auto-fill with random weapons |
| Respawn time | 10 s after a real death, in own yard; weapons can be swapped any number of times during the timer (D13) |
| Basic attack | **None.** There is no basic attack: players only use the weapons they picked plus the two default skills (owner decision) |

## Characters (cosmetic, randomized)
- Roster (`data/characters/*.tres`, `CharacterDef`): `junjun` boy, `ligaya` girl, `migo` gay boy, `toni` lesbian girl, `popoy` chubby boy, `inday` dark-skinned girl. Outfits in `docs/PROJECT.md` §3.2.
- Assigned by the **server** at match start with the match's seeded RNG: shuffle the roster, give one per player, no duplicates (6 characters ≥ max 6 players). Fixed for the whole match, including respawns and set switches.
- Purely visual: identical hitbox (circle r=0.4 m), HP, speed, animations timing. Shown in loading screen, scoreboard and kill feed.
- Team readability: team-colored bandana/armband + ground ring; enemy outline on the local client.
- Practice mode: random character for the player, dummies use the others. Practice has two training dummies on the enemy team (one stands still, one walks sideways +/-3 m around its post at half speed) and one standing ally dummy, so the revive touch can be tested. Dummies never attack or use skills, have no death delay, and respawn at their spot after 10 s.

## Death delay (once per respawn)
- When HP reaches 0 the player does **not** die yet. They enter the **death delay**: HP stays 0 and they get temporary **gray HP**.
- Gray HP **drains while they move** (rate scales with stick length; standing still costs nothing). If gray HP reaches 0 they really die and respawn after 10 s with full HP.
- **Skills are disabled** during the death delay (dash, bookmark, weapons). Movement still works.
- **Revive:** a living teammate (not themselves in death delay) touching the downed player revives them, or the downed player touches **their own base's electric post** and revives themselves with no help. They come back with the **gray HP they had left** as their HP (at least 1).
- The death delay can trigger **only once per respawn**: if HP reaches 0 again after a revive, the player dies for real. Respawning re-arms it.
- Training dummies in practice mode have no death delay.
- Numbers (starting points, in `data/rules/game_rules.tres`): gray HP 50, drain 8 per second at full stick, same move speed, teammate touch within 1.0 m (center to center), base post touch within 1.2 m of the post center. Enemies cannot damage a player in death delay (D8).

## Default skills
| Skill | Effect | CD |
|---|---|---|
| Takbo (Dash) | 5 m dash over 0.2 s, then 0.4 s stumble (can't move/cast) | 8 s |
| Pin (Bookmark; replaces Dash on the HUD) | Leaves a pin (red round head) where you stand, dashes 3.2 m (`bookmark_blink`) **the way you face on a tap, or the way you drag** (an aimed skill: press, drag to choose the direction, release; the preview is a band the length of the dash), tumbles 0.45 s (can't move/cast), then after 4 s snaps back to the pin. **Press again to return early.** | 14 s, **starting when you are back at the pin** |

**One skill at a time (owner):** while one skill button is held (aiming), no other skill button can be pressed or cast; the pin is ignored until the release.

**No precasting (owner):** a skill or weapon on cooldown is disabled. Its button is dimmed and ignores presses, and holding a key or button through the cooldown does nothing when the cooldown ends; it needs a fresh press. Bookmark can't be used again while you are still out on a mark, and its cooldown only starts after the return (or when you die out on a mark).

Dash and Bookmark blink stop at walls that block you, i.e. the enemy's walls and the lane edges (your own team's walls are passable). Death cancels active dash/stumble/bookmark effects; cooldowns keep running through death and respawn.

## Weapons
Status effects: `STUN` (no move/cast), `SLOW(x%)`, `AIRBORNE` (stun + vertical anim, no knockback), `POLYMORPH` (can: no cast, 50% speed), `BOUNCE` (short airborne), `KNOCKOUT` (downed, no actions; no longer caused by the guava).

- **Casting while moving (owner):** every weapon can be aimed while you keep moving. **Light attacks** can also be cast while moving (no rooting). **Heavy attacks** (Bato H, Gunting H, Tsinelas H; `cast_lock` in `data/weapons/*.tres`, 0.5-0.6 s) root the caster until their cast animation finishes.
- **Aim previews:** a ground circle (rock meteor and the like) is drawn alone, with no line from the player to it. The guava's throw is drawn as a thick band (about 1.1 m wide) instead of a line.
Statuses never stack: only one is active at a time and a new status of a different kind overwrites the current one. The same status re-applied keeps the longer time (SLOW keeps the stronger slow).

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
| heal (Langit Lupa) | HEAL | instant: **tap heals yourself**, **drag toward a teammate** (within 8 m, 60° cone around the drag) heals them; a drag with nobody there does nothing and costs no cooldown. Never heals enemies. Aim preview: a ring around the teammate, no line to them | 30 HP (`heal`) | — | — | 12 |
| langit_lupa (Langit Lupa) | BLOCK | a **person-wide (1.2 m)** block of earth rises 2.2 m in front of you in the aimed direction, blocks enemy projectiles, then **collapses back to the ground after 3.5 s** | — | — | — | 14 |

Two copies of the same weapon cannot be equipped; two weapons of the same *type* can.

### Casting and aiming
- **Cast on release.** Hold a weapon button to aim, release to cast. Releasing over the **Cancel** zone (shown above the buttons while aiming) cancels; nothing is spent. Keyboard: hold Q / E to aim at the mouse, release to cast; Esc or right mouse while holding cancels.
- **Auto-aim:** a tap (or a drag shorter than the deadzone, `aim_deadzone` 0.1 of full stick) aims at the nearest targetable enemy in range; with nobody in range it fires straight ahead (ground shapes land at full range). Drag length scales the distance for ground shapes (lata, bato heavy, papel trap, jacks).
- **Auto-aim never follows a moving enemy while you hold (owner, fairness).** It is taken once, at the moment you press: the spot (relative to you) or, for `bato_light`, the enemy. Holding keeps that aim; if the enemy walks away the cast still goes where they were. Dragging past the deadzone aims by hand instead.
- `bato_light` throws at the enemy locked at the press. If that enemy has left range (or is down) when you release, nothing is thrown and **no cooldown** is spent. Once thrown, the rock homes on that enemy (a targeted projectile, per the weapon table).
- A hard CC (or going down) while aiming drops the aim; press again when it ends.
- `gunting_light` snips: 2 on a tap, +1 per 0.25 s held, max 6, all on release.
- Projectiles are stopped by enemy cardboard walls, the lane edges and enemy paper shields; they pass through their own team's walls and shields (D11).
- Boomerangs (tsinelas) hit each enemy once going out and once coming back, turn back at max range or when they hit a wall, and are caught within 0.8 m of the thrower (`boomerang_catch_distance`).
- An unarmed `papel_trap` waits on the ground for 20 s (`lifetime`) before it disappears.
- Lata travels at 14 m/s to its point before it lands; bato heavy lands 0.6 s after the cast.
- Effects are applied before damage. Players in the death delay are not hit by anything (D8).

## Map (single mid lane, 80 m long × 16 m wide)
- Layout per side, from the lane end toward mid: the **yard** (8 m) → the **inner wall row**, with the **electric post standing at the center of it** → a long stretch → the **middle wall row** → mid.
- Each wall layer = 3 columns (left / center / right), each column 150 HP (owner: 300 was too tough). A column at 0 HP is removed and opens that slot. Every hit shows: the sheet flashes and wobbles, cardboard chips fly, the damage number pops above it, a cardboard-coloured health bar appears over a damaged column, and rips, holes and tape spread over it as it weakens; it bursts into chips when it breaks.
- **A team passes straight through its own cardboard walls; the enemy team is blocked by them** (owner decision, completes D5). Boundary walls block everyone. Walls take damage from enemy attacks and the ball (ball: 60). Which projectiles a wall stops: enemy projectiles are blocked; own-team projectiles pass through (D11).
- What damages a wall column: enemy weapons deal their normal damage to it. The targeted rock (Bato light) normally needs an enemy in range; with none, it is thrown straight at the nearest enemy wall column in range instead. A projectile that hits it deals its damage once (a boomerang turns back); ground areas, jacks ticks and bola bounces hit every column inside their circle; cones hit columns in front within range. Non-damaging weapons (trap, shield) don't hurt walls. Own walls never take damage from their own team.
- **Scoring (owner): going behind the enemy's inner wall is a point.** A living, non-CC'd enemy standing in the yard behind a team's inner wall for **2 s** (`base_capture_time`, owner: harder than before) scores. The yard is tinted in that team's colour. The enemy team is blocked by the inner wall, so they have to break a column (150 HP) to get in. Players start and respawn in the middle of their own yard; the electric post (revive touch) is at the center of the inner wall.
- Boundary walls on the long sides (house fronts, fences).
- Lane geometry (owner): **the distance between a team's middle wall row and its inner wall row is the same as the distance between the two middle rows**, 21.3 m, so the middle stays 16 x 21.3 m (3:4) and so does the stretch in front of each base. The post/inner wall row is 32 m from the middle and 8 m from the lane end (80 m lane). It lives in `data/rules/map_layout.tres` (`lane_length`, `base_inset`, `wall_first_layer_from_base`, `wall_layer_spacing`); adjust there, not in code. The look is separate (`docs/ART.md`). A lane end to end takes about 16 s at full speed.

## Vertical layout (portrait game)
- The lane runs **along the screen's long axis**: your base at the bottom, the enemy base at the top. The server/sim map is orientation-agnostic (lane axis = Z); only the camera and UI know about portrait.
- Camera (data, tunable in `data/rules/camera_rules.tres`), **copied from League of Legends** (owner):
  - **Tuned to the owner's gameplay reference: a bird's-eye view from behind and to the right of the hero** (not turned at all: straight behind the hero, so the street runs straight up the screen), 56° pitch and an **ultra-wide lens**: 52° vertical field of view, so about **19 m** is visible across the screen at the hero on any phone shape (the 0.5x look: more of the lane to each side, the edges stretch a little, a stronger edge vignette; kids are drawn 10% bigger so they stay readable; hitboxes are unchanged). The joystick, drag-aim and keyboard follow the screen: pushing up moves toward the top of the screen. All numbers live in `data/rules/camera_rules.tres` (`yaw_offset_degrees`, `pitch_degrees`, `vfov_degrees`, `visible_width`).
  - It follows you sideways, never showing more than 1 m past the curb, looks 2.5 m ahead toward the enemy base, eases after the hero (7/s) and stops 5 m before each lane end.
  - The lane minimap shows the rest of the width.
  - Team-relative: both teams see their own base at the bottom (the view flips for the other team).
- Offscreen awareness: edge indicators for allies/enemies/ball/tricycle plus a slim lane minimap. Aim previews and skill ranges must remain readable within the visible area (long-range weapons rely on drag-to-aim and edge indicators).
- Because the visible depth is shorter than the lane, ranges, speeds and the lane length stay as specified; balance is re-checked in M6 with real play on phones.

## HUD
- **Over each hero:** a segmented health bar (green you, blue ally, red enemy, grey for gray HP in the death delay). **No names.** A status (*Stunned*, *Down*, ...) is shown in *italic* above the bar. Under the bar, one thin bar: the **pin** cooldown. **No damage numbers** (none on heroes or walls); heals pop a green +N.
- **Skill buttons:** art only (weapon icons, the pin, guava), the weapon's type as a small tag (ATK, CC or BLK), a cooldown number, a ready flash. Buttons on cooldown are disabled.
- **Top:** a square minimap (gold frame) at the top left showing the lane slanted from your base (bottom left) to the enemy base (top right), with a small settings button beside it, top aligned; the guava and tricycle countdowns in the centre; score and set pips at the top right. The settings button opens a see-through menu: the practice test buttons, Resume, Exit match. There is no health panel in the corner.
- **Controls:** fixed at the bottom centre, no handedness setting: the joystick sits on the centre line and the four skills fan out in a symmetrical arc over it: weapon 1, weapon 2, the pin, the guava (left to right). Each skill button is a cardboard disc with the painted icon whole on it; the icon's own glow shows the type (attack red, crowd control violet, block blue, heal green). The pin button shows the pin, the blue dash arrow during the blink and the pin-with-return-arrow while the kid is out on the pin; the guava button shows the whole or the bitten guava.
- The pin bar shows your own and everyone else's pin (it fills as it recharges; it turns gold and drains while the kid is out on the pin). The minimap is a square, cropped to its frame, with the lane slanted from your base (bottom left) to the enemy base (top right).

## Scoring (volleyball format)
- **Point**: get behind the enemy's inner wall (see Map). After a point: 3 s freeze, all players reset to their bases at full HP, cooldowns reset. Walls **persist** within a set.
- **Set**: first to 5 points, win by 2, hard cap 7.
- **Match**: best of 3 sets. Teams switch bases each set; walls fully rebuild each set.
- Implementation defaults: during the 3 s freeze nothing moves. The reset also clears status effects, weapon objects on the field, the ball (its 15 s spawn timer restarts) and an active tricycle crossing (the next one comes a full interval later). Dead players come back too. After the last point of the match the game stops and shows the result. Numbers in `data/rules/game_rules.tres` (`base_capture_time`, `point_freeze_time`, `set_points_to_win`, `set_win_by`, `set_point_cap`, `match_sets_to_win`).

## The guava (neutral ball)
The neutral at the centre of the lane is a **guava** (*bayabas* is the Tagalog word for guava). It can be eaten, carried and thrown:
- **Bite it to heal.** Walking over the guava picks it up and heals nothing. With it in hand, **tap** the guava button to take a bite: each bite heals **a quarter of max HP** (25 of 100, capped at max; `ball_bite_heal_fraction`). The second bite (`ball_bites`) eats it up, and the next guava comes after the usual 15 s. A tap is a press released within 0.25 s (`ball_tap_time`) without dragging. A catch, a pass or a pickup never heals. Nobody who is dead or down can be healed.
- **Throw it to hurt.** **Press and drag** (the skill indicator shows) or hold the button longer than a tap, then release. A **whole** guava hits an enemy for a **quarter of max HP** (25, `ball_hit_damage_fraction`); a **bitten** one for **an eighth** (12.5, rounded to 13, `ball_bitten_damage_fraction`). There is no knockout any more. The button shows the whole or the bitten guava, and **is only on the HUD while you hold the guava**, can blink to your own throw, or an enemy's throw is flying (so you can still catch it).
- Each bite shows a green "+25" over the player.
- Spawns at center every 15 s if none exists.
- Pick up: walk over it. Holder can throw (skillshot, 12 m, fast). Holder moves at 90% speed.
- Hit enemy → damage (above), the guava despawns, timer restarts.
- Enemy "catch": an enemy who presses the Catch button within 0.3 s before contact catches it instead (becomes holder). **(D2 confirm)**
- Hit ally → ally becomes holder (no heal); the bites stay.
- Hit cardboard wall → 60 dmg, the guava despawns, timer restarts.
- Hit boundary or max range → drops on the ground, can be picked up .
- While in flight and not yet hit anything, the **thrower** can recast to blink to the guava. **(D3 confirm: thrower only)**
- Controls: one **guava button** (R on keyboard), art only. With the guava in hand (the button glows gold) press, drag to aim and release to throw (auto-aim locked at the press like weapons, cancel zone works); while your own throw flies a press blinks to it; otherwise a press opens the 0.3 s catch window.
- Implementation defaults: thrown at 20 m/s (`ball_speed`); an enemy paper shield stops it and it drops there; it passes through the thrower's own walls (D11) and only damages enemy walls; the holder drops it when they go down or die; the blink moves the thrower onto the ball and the ball keeps flying. Numbers in `data/rules/game_rules.tres` (`ball_*`).

## Tricycle
- Every 120 s (first at 120 s), drives across the map's midline from a random side, ~3 s crossing, warning horn + lane marker 2 s before.
- Contact: 8 m knockback perpendicular to its path, away from it; no damage. **(D4 confirm)**
- Implementation defaults: the push is spread over 0.3 s and stops at walls that block you; each player is pushed at most once per crossing; it pushes players in the death delay too. Practice mode has a "Tricycle (test)" button. Numbers in `data/rules/game_rules.tres` (`tricycle_*`).

## Lobby rules
- Modes: 1v1, 2v2, 3v3. Passcode: 6 chars, A–Z/2–9, no ambiguous chars.
- Start allowed when: every present player is Ready AND one team has N players AND the other has ≥ N−1 (N=1 requires both).
- Host leaves in lobby → next player becomes host. Player disconnect in match → slot stays, 60 s to reconnect.
- Implementation defaults (M4):
  - A new player joins the smaller team; tap **Join** on the other team to switch, which un-readies you.
  - Names are up to 12 characters ("Player" if empty).
  - Loading waits up to 15 s for every client, then starts anyway.
  - The 10 s weapon pick has 1 s of grace on the server; empty picks are filled at random.
  - A dropped player stands still in the match.
  - The match screen reconnects by itself, and **Rejoin last match** in the lobby (or reloading the page) works within the 60 s.
  - After the window the slot just stays idle.
  - Rooms live in server memory only.
  - Numbers are in `data/rules/net_rules.tres`.
- Netcode:
  - Clients send their input every sim tick (30 Hz). The server applies one input per tick per player, oldest first, so a quick tap is never lost.
  - Snapshots go out at 20 Hz.
  - Your own movement is predicted and corrected; other players are drawn 0.1 s in the past between snapshots.
  - Server-side events (hits, deaths, points, the ball, the tricycle) are replayed on the client as the same signals the offline game uses.

## Open decisions (defaults are implemented; change if the designer says so)
- **D1** ~~Basic attack~~ **Decided: no basic attack** (owner). See D10.
- **D2** Ball catch input/timing.
- **D3** Who can blink to the ball (default: thrower only).
- **D4** Tricycle push direction (default: perpendicular, away from vehicle).
- **D5** Original brief for walls ends with "This must …" — unfinished requirement. Partly answered by the owner: a team can pass through its own walls (implemented). Ask whether anything else was meant.
- **D11** Do a team's own projectiles pass through its own walls? Default **yes** (matches movement; implemented in M2).
- **D7** Bookmark "then return to mark": default = the player is moved back to the mark when the 4 s speed boost ends (data toggle `bookmark_returns` in `data/rules/game_rules.tres`).
- **D8** Can enemies damage a player in the death delay? Default **no** (untargetable); data toggle `death_delay_takes_damage` (damage then drains gray HP).
- **D9** Death-delay numbers (gray HP 50, drain 8/s, touch distances) are placeholders; tune in data.
- **D10** With no basic attack, a loadout of only non-damaging weapons (e.g. `papel_trap` + `papel_shield`) deals no damage. Default: allowed; consider requiring at least one damaging weapon at pick time.
- **D12** Unarmed papel trap lifetime (not in the brief): default 20 s.
- **D13** ~~Respawn weapon swap~~ **Decided (owner): swap with no limit while dead.** For the whole respawn timer you can change weapons as often as you like. The swap screen opens on death with your current weapons pre-picked and shows the respawn countdown; every full pair applies at once; **Done** closes it and a **Swap weapons** button reopens it while still dead. It closes when you respawn. No swapping while alive. A weapon kept across a swap keeps its cooldown.
- **D14** *Heal* numbers were not given by the owner: defaults 30 HP, 12 s cooldown, 8 m range, 60° pick cone, tap = self (all in `data/weapons/heal.tres`). Confirm or change.
- **D15** *Lupa (soil block)* numbers were not given by the owner: defaults 1.2 m wide, 2.2 m in front, stands 3.5 s then collapses, 14 s cooldown, blocks projectiles like the paper shield (`data/weapons/langit_lupa.tres`). Confirm or change; say if it should also block movement.
- **D6** Only one Block weapon exists — consider a second one for loadout variety.
