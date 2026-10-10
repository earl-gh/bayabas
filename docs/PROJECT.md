# Kalyeah — Project Documentation

> 3D stylised multiplayer MOBA for Android, themed on Filipino street games (*mga larong Pinoy sa kalye*). Entry for an Android game development competition.

## 1. Abstract

Kalyeah is a stylised 3D multiplayer MOBA built in Godot 4 for Android, with optional browser play, themed around classic Filipino street games. Instead of heroes and levels, every player shares the same fixed health and equips two weapons from an arsenal of street-game items: bato-bato-pik, tumbang preso tsinelas and lata, jackstones, and trumpo, each reimagined as an attack, crowd-control or block skill. Each player is randomly cast as one of six Filipino kids in everyday Pinoy outfits. Matches of 1v1, 2v2 or 3v3 are played in private passcode rooms on a single-lane Filipino street. Teams break through layered cardboard walls, a nod to bahay-bahayan, and score by reaching the enemy's electric-post base as in agawan-base, using volleyball-style set and match scoring. A neutral guava that heals whoever eats it and a passing tricycle add shared chaos. With no accounts, ranks or leveling, every match is quick to join and decided by skill.

## 2. Hardware and Software Requirements (for playing)

### 2.1 Android app (primary)

| Item | Minimum | Recommended |
|---|---|---|
| Operating system | Android 8.0 Oreo (API 26) | Android 11 or newer |
| Processor | Quad-core 1.8 GHz, 64-bit (ARMv8) | Octa-core 2.0 GHz+ (e.g. Snapdragon 680 / Helio G85 class or better) |
| Memory (RAM) | 3 GB | 4 GB or more |
| Graphics | OpenGL ES 3.0 support | Adreno 610 / Mali-G52 class or better |
| Storage | 200 MB free | 500 MB free |
| Display | 5.0", 720 × 1280, portrait | 6.0"+, 1080 × 1920, portrait |
| Network | Internet for multiplayer (Wi-Fi or 4G), latency under 150 ms | Wi-Fi or 4G/5G, latency under 80 ms |
| Input | Touchscreen (virtual joystick + drag-to-aim skill buttons) | — |
| Software | Kalyeah APK installed (no Google account or sign-in needed) | — |

Practice mode works offline; online rooms need an internet connection.

### 2.2 Web browser (optional)

Players without the app can join the same rooms from a browser.

| Item | Minimum |
|---|---|
| Android browser | Chrome 110+ on Android 8.0+, same phone specs as above |
| Other devices (optional) | Safari 16.4+ on iOS/iPadOS, or a desktop browser (Chrome, Edge, Firefox, Safari) with WebGL 2 |
| Graphics | WebGL 2.0 enabled |
| Memory | 3 GB RAM on mobile, 4 GB on desktop |
| Network | Same as the Android app; first load downloads about 40–50 MB |
| Input | Touch on mobile, keyboard + mouse on desktop |

## 3. Product Features

### 3.1 Rooms and lobby
- **Create or join** a room. No accounts, no ranked or random matchmaking.
- Host picks **1v1, 2v2 or 3v3**; the server generates a short **passcode**.
- Others join with the passcode, pick a team slot and toggle **Ready**.
- Host can start when all present players are ready and **at least one team is full** while the other is at most one short (2v2 and 3v3). 1v1 needs both players.
- **Loading screen** before the match.

### 3.2 Characters (randomized)
- When the match starts, every player is **randomly assigned** one of six Filipino kid characters, each wearing a classic Pinoy kid outfit. No two players in a match share a character.
- Characters are **cosmetic only**: same health, speed and hitbox, so the random draw never affects fairness.
- Each character wears a **team-colored bandana/armband** and has a team ring under their feet so teams stay readable.

| Character | Represents | Outfit |
|---|---|---|
| Junjun | Boy | White sando, basketball shorts, tsinelas, bimpo tucked at the back |
| Ligaya | Girl | Floral bestida, ponytail with clip, tsinelas |
| Migo | Gay boy | Pastel graphic tee knotted at the side, belt bag, colorful headband, printed tsinelas |
| Toni | Lesbian girl | Short haircut, backward cap, oversized basketball jersey, cargo shorts, rubber shoes |
| Popoy | Chubby boy | Striped polo shirt, jersey shorts, tsinelas, ice candy in hand during idle |
| Inday | Dark-skinned girl | PE shirt, jogging pants, pigtails with ponytail bands, rubber shoes |

All six are written with respect: identity is shown through the clothes and style a kid would choose, never through jokes, slurs or exaggerated features. Every character gets the same animation quality and the same confident poses.

### 3.3 Players and combat
- **Fixed health** for everyone; no levels, items, hero classes or damage types.
- **Weapon pick:** 10 seconds at match start to choose 2 weapons from the arsenal. Duplicate weapon *types* allowed.
- **Death delay:** at 0 HP you get temporary gray HP that drains while you walk, with skills disabled; a teammate touching you, or you touching your own base post, revives you with the gray HP left. Once per respawn.
- **Death:** when gray HP runs out (or HP hits 0 again after a revive), a 10-second respawn at base, with the option to swap both weapons.
- **No basic attack:** players only use the skills and weapons they picked.
- **Default skills for all:**
  - *Takbo (Dash)* — quick dash, then a brief stumble (nadapa).
  - *Bookmark* — blink forward with bonus speed, leaving a bookmark; snap back to it after 4 s.
- MOBA-style aiming (drag-to-aim on mobile, mouse on desktop) with range indicators.

### 3.4 Arsenal (12 weapons, 3 types: Attack, Crowd Control, Block)

| Street game | Weapon | Type | Effect |
|---|---|---|---|
| Bato-bato-pik | Bato (Light) | Attack | Throw small rocks at one enemy in range |
| | Bato (Heavy) | Attack | Delayed meteor-style rock in an area; damage + 2 s stun |
| | Gunting (Light) | Attack | Rapid 2–6 snips in a cone |
| | Gunting (Heavy) | Attack | Same cone, delayed single heavy snip |
| | Papel Trap | Crowd Control | Drop crumpled paper; arms a circular slow zone when enemies walk near |
| | Papel Shield | Block | Paper wall that blocks projectiles |
| Tumbang preso | Tsinelas (Light) | Attack | 3 fast regular-size boomerang slippers |
| | Tsinelas (Heavy) | Attack | 1 large, slow boomerang slipper |
| | Lata | Crowd Control | Thrown can; enemies hit turn into a can for 2 s |
| Jackstone | Jacks | Crowd Control | Scatter spiked pieces: slow + small damage |
| | Bola | Crowd Control | Bouncy ball, 2 bounces to max range; each bounce bounces enemies for 1 s |
| Trumpo | Trumpo | Crowd Control | Spinning top travels a set distance, launching enemies airborne for 2 s |

Every weapon has a type icon. All values (damage, cooldowns, ranges) are data-driven and balanced against each other.

### 3.5 Map and objectives
- **Single mid lane**, Filipino street setting (sari-sari store, jeepney/tricycle stop, laundry lines, basketball ring, etc.).
- **Cardboard walls (bahay-bahayan):** 2 layers per side, each split into 3 columns with their own HP. Break through to open a path.
- **Base (agawan-base):** a concrete electric post covered in flyers (septic siphoning, hiring, police notices, election posters). Stepping on the enemy base scores a point.
- **Volleyball scoring:** points win sets, sets win the match. Teams **switch bases every set**.

### 3.6 Neutral events
- **Guava (center):** spawns every 15 s. Eating it off the ground heals half your max HP, and you carry it. An aimed throw knocks out a hit enemy for 3 s; enemies can catch and throw it back; hitting an ally passes it; it damages walls. While it travels freely, the thrower can blink to it. The guava despawns on hit and the 15 s timer restarts.
- **Tricycle:** every 2 minutes it crosses the middle of the map from left or right, pushing back anyone it touches.

### 3.7 Platforms and delivery
- **Android app** is the main release (APK). The **browser version is optional**, built from the same code and hosted on GitHub Pages; app and browser players can play in the same rooms.
- **Offline practice mode** (vs. training dummies) so builds can be tested on a phone without a server.
- **One live web link** (GitHub Pages, rebuilt on every merge to `main`) for testing from an iPhone.

### 3.8 Visual style and orientation
- **Portrait (vertical) only, by design.** Kalyeah is a one-hand-friendly vertical MOBA: the phone is held upright, the lane runs up the screen, your base is at the bottom and the enemy base at the top. Android is locked to portrait; the web build shows a "rotate your phone" prompt if held in landscape.
- **Vertical UI layout:** left thumb = virtual joystick (bottom-left); right thumb = round art-only skill buttons in an arc (bottom-right: two weapons with an ATK / CC / BLK tag, Dash, Mark, and the guava) with drag-to-aim and a cancel zone; top = team portraits, the score and set pips, a timer; a slim lane minimap on the left edge; the kill feed and the weapon pick screen are designed for a tall screen. Over each hero: a health bar, an italic status line above it, and a Dash and a Mark cooldown bar under it (no names). Keep the centre of the screen clear for gameplay.
- **Camera: League of Legends.** The gameplay camera copies League of Legends: 56° pitch, 30° vertical field of view, far and flat. Its distance is chosen so about 13 m of the lane width is visible on a phone (see `docs/ROADMAP.md`). The lane minimap shows the rest; rules and numbers are unchanged (see `docs/GDD.md`).
- **Style target: Clash of Clans design language, stylised 3D, Filipino street theme.** Chunky, toy-like proportions; soft rounded shapes with bevels and painted-looking textures; bright, saturated, high-contrast colours; soft shadows; thick readable silhouettes; bouncy, exaggerated animation; big rounded buttons and painted icons. Everything must read clearly from the camera on a small phone screen.
- **Pinoy flavour:** colours and details from the street (jeepney paint, faded sari-sari signage, laundry lines, tarpaulin posters, concrete and cardboard, bahay-kubo/barong-barong roofs), warm daylight, and kids in everyday clothes.
- **Inspired by, not copied:** match the look and feel only. Do not reuse or imitate any Clash of Clans / Supercell or League of Legends / Riot asset, character, logo, UI art or name.
- Keep to the performance budgets in `docs/ROADMAP.md` (light meshes, shared materials and texture atlases, no more than a few small textures per prop).
