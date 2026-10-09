# Bayabas — Project Documentation

> 3D low-poly multiplayer MOBA for Android, themed on Filipino street games (larong kalye). Entry for an Android game development competition.

## 1. Abstract

Bayabas is a 3D low-poly multiplayer MOBA built in Godot 4 for Android, with optional browser play, themed around classic Filipino street games. Instead of heroes and levels, every player shares the same fixed health and equips two weapons from an arsenal of street-game items: bato-bato-pik, tumbang preso tsinelas and lata, jackstones, and trumpo, each reimagined as an attack, crowd-control or block skill. Each player is randomly cast as one of six Filipino kids in everyday Pinoy outfits. Matches of 1v1, 2v2 or 3v3 are played in private passcode rooms on a single-lane Filipino street. Teams break through layered cardboard walls, a nod to bahay-bahayan, and score by reaching the enemy's electric-post base as in agawan-base, using volleyball-style set and match scoring. A neutral rubber ball and a passing tricycle add shared chaos. With no accounts, ranks or leveling, every match is quick to join and decided by skill.

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
| Software | Bayabas APK installed (no Google account or sign-in needed) | — |

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
- **Death:** 10-second respawn at base, with the option to swap both weapons.
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
- **Rubber ball (center):** spawns every 15 s. Aimed throw knocks out a hit enemy for 3 s; enemies can catch and throw it back; hitting an ally passes it; damages walls. While it travels freely, the thrower can blink to it. The ball despawns on hit and the 15 s timer restarts.
- **Tricycle:** every 2 minutes it crosses the middle of the map from left or right, pushing back anyone it touches.

### 3.7 Platforms and delivery
- **Android app** is the main release (APK). The **browser version is optional**, built from the same code and hosted on GitHub Pages; app and browser players can play in the same rooms.
- **Offline practice mode** (vs. training dummies) so builds can be tested on a phone without a server.
- **One live web link** (GitHub Pages, rebuilt on every merge to `main`) for testing from an iPhone.

### 3.8 Visual style and orientation
- **Portrait (vertical) only, by design.** Bayabas is a one-hand-friendly vertical MOBA: the phone is held upright, the lane runs up the screen, your base is at the bottom and the enemy base at the top. Android is locked to portrait; the web build shows a "rotate your phone" prompt if held in landscape.
- **Vertical UI layout:** left thumb = virtual joystick (bottom-left); right thumb = 4 skill buttons in an arc (bottom-right) with drag-to-aim and cancel zone; top bar = score/sets, ball timer, tricycle warning; slim vertical lane minimap on one edge; kill feed and weapon pick screen designed for a tall screen. Keep the centre of the screen clear for gameplay.
- **Vertical gameplay adaptation:** the camera shows the whole 16 m lane width and roughly 22-26 m of lane length ahead, so the fight is read as a tall corridor; offscreen threats are shown by edge indicators and the minimap. Rules and numbers are unchanged (see `docs/GDD.md`); only camera, UI and framing change.
- **Style target: Clash of Clans-like, low-poly 3D, Filipino street theme.** Chunky, toy-like proportions; bright, saturated, high-contrast colours; clean flat-shaded low-poly meshes with one shared palette texture; soft rounded shapes, thick readable silhouettes, light cartoon outlines and bouncy, exaggerated animation; playful UI with big rounded buttons. Everything must read clearly from the isometric ~55 degree camera on a small phone screen.
- **Pinoy flavour:** colours and details from the street (jeepney paint, faded sari-sari signage, laundry lines, tarpaulin posters, concrete and cardboard, bahay-kubo/barong-barong roofs), warm daylight, and kids in everyday clothes.
- **Inspired by, not copied:** match the look and feel only. Do not reuse or imitate any Clash of Clans / Supercell asset, character, logo, UI art or name.
- Keep to the performance budget in HANDOFF M6 (low poly counts, one material per prop where possible).
