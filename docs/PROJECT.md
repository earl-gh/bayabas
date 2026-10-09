# Bayabas — Project Documentation

> Working title. 3D low-poly multiplayer MOBA themed on Filipino street games (larong kalye).

## 1. Abstract

Bayabas is a 3D low-poly multiplayer MOBA built in Godot 4 for mobile and web browsers, themed around classic Filipino street games. Instead of heroes and levels, every player shares the same fixed health and equips two weapons from an arsenal of street-game items: bato-bato-pik, tumbang preso tsinelas and lata, jackstones, and trumpo, each reimagined as an attack, crowd-control or block skill. Matches of 1v1, 2v2 or 3v3 are played in private passcode rooms on a single-lane Filipino street. Teams break through layered cardboard walls, a nod to bahay-bahayan, and score by reaching the enemy's electric-post base as in agawan-base, using volleyball-style set and match scoring. A neutral rubber ball and a passing tricycle add shared, skill-based chaos. With no accounts, ranks or in-match leveling, every match is quick to join and decided by skill alone.

## 2. Hardware and Software Requirements

### 2.1 Players (client)

| Platform | Minimum | Recommended |
|---|---|---|
| Android (native APK) | Android 8.0 (API 26), 3 GB RAM, OpenGL ES 3.0 GPU | Android 11+, 4 GB RAM |
| iPhone / iPad (browser) | iOS/iPadOS 16.4+, Safari with WebGL 2 | iPhone 12 or newer |
| Desktop browser | Chrome/Edge 110+, Firefox 115+, Safari 16.4+, WebGL 2, 4 GB RAM | Dedicated or recent integrated GPU, 8 GB RAM |
| Network | Stable 4G or Wi-Fi, under 150 ms to server | Under 80 ms to server |

Inputs: touch (virtual joystick + drag-to-aim skill buttons) on mobile; keyboard + mouse on desktop. Touch also works on mobile browsers.

### 2.2 Development

| Item | Requirement |
|---|---|
| Engine | Godot 4.6.x stable (pinned in `.godot-version`), **Compatibility renderer** (required for web + low-end mobile) |
| Language | GDScript, fully statically typed |
| Testing | GUT (Godot Unit Test) run headless in CI |
| 3D assets | Blender 4.x, exported as `.glb`; low-poly, flat-shaded, shared palette texture |
| Version control | Git + GitHub (Conventional Commits, PRs, release-please) |
| CI/CD | GitHub Actions: tests, web export, GitHub Pages deploy, PR previews, tagged releases |
| Android build | Android SDK + OpenJDK 17, Godot Android export templates |
| Dev machine | Windows 10+/macOS 12+/Linux, 8 GB RAM (16 GB recommended), GPU with OpenGL 3.3 |

### 2.3 Game server

| Item | Requirement |
|---|---|
| Runtime | Godot 4.6.x headless (Linux server export) in Docker |
| Transport | WebSocket over TLS (`wss://`) — the only transport that works for both browser and native |
| Hosting | Any container host (e.g. Fly.io, Render, a small VPS) |
| Size | 1 vCPU / 512 MB RAM handles several concurrent rooms at a 30 Hz tick |

## 3. Product Features

### 3.1 Rooms and lobby
- **Create or join** a room. No accounts, no ranked or random matchmaking.
- Host picks **1v1, 2v2 or 3v3**; the server generates a short **passcode**.
- Others join with the passcode, pick a team slot and toggle **Ready**.
- Host can start when all present players are ready and **at least one team is full** while the other is at most one short (2v2 and 3v3). 1v1 needs both players.
- **Loading screen** before the match.

### 3.2 Players and combat
- **Fixed health** for everyone; no levels, items, heroes or damage types.
- **Weapon pick:** 10 seconds at match start to choose 2 weapons from the arsenal. Duplicate weapon *types* allowed.
- **Death:** 10-second respawn at base, with the option to swap both weapons.
- **Default skills for all:**
  - *Takbo (Dash)* — quick dash, then a brief stumble (nadapa).
  - *Bookmark* — blink forward with bonus speed, leaving a bookmark; snap back to it after 4 s.
- MOBA-style aiming (drag-to-aim on mobile, mouse on desktop) with range indicators.

### 3.3 Arsenal (12 weapons, 3 types: Attack, Crowd Control, Block)

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

### 3.4 Map and objectives
- **Single mid lane**, Filipino street setting (sari-sari store, jeepney/tricycle stop, laundry lines, basketball ring, etc.).
- **Cardboard walls (bahay-bahayan):** 2 layers per side, each split into 3 columns with their own HP. Break through to open a path.
- **Base (agawan-base):** a concrete electric post covered in flyers (septic siphoning, hiring, police notices, election posters). Stepping on the enemy base scores a point.
- **Volleyball scoring:** points win sets, sets win the match. Teams **switch bases every set**.

### 3.5 Neutral events
- **Rubber ball (center):** spawns every 15 s. Aimed throw knocks out a hit enemy for 3 s; enemies can catch and throw it back; hitting an ally passes it; damages walls. While it travels freely, the thrower can blink to it. The ball despawns on hit and the 15 s timer restarts.
- **Tricycle:** every 2 minutes it crosses the middle of the map from left or right, pushing back anyone it touches.

### 3.6 Platforms and delivery
- One codebase for **web (GitHub Pages)**, **Android**, and an **iOS-friendly web build**.
- **Offline practice mode** (vs. training dummies) so builds can be tested on a phone without a server.
- Every PR gets a **playable web preview link** for testing from an iPhone.
