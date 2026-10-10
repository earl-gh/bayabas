# Art, UI and audio

Look: **Clash of Clans design language** (soft, chunky, painted-looking, toy-like) on a **League of Legends camera**, in a Filipino street. Inspired by, never copied (`docs/PROJECT.md` 3.8). The target is the owner's reference image; the work to get there is the visual overhaul in `docs/ROADMAP.md`.

## Where we are
The current art is a first pass built **in code**: procedural meshes, vector icons and synthesised sound, with no asset files. It is soft-shaded and readable but not final. The plan replaces it piece by piece with real assets made in Blender (see "Asset pipeline").

### 3D (procedural, current)
- `scripts/view/art/low_poly.gd` (`LowPoly`): bevelled boxes, smooth cylinders and spheres, gable roofs, with vertex colours and **one shared matte material** (wrap lighting, soft rim, no hard speculars). Cartoon outlines come from an inverted shell (`add_outline`).
- `scripts/view/art/palette.gd` (`Palette`): the shared colour palette.
- `scripts/view/art/props.gd` (`Props`): sari-sari store, houses (one and two storey), laundry lines, electric post with flyers, power poles and wires, banderitas, tarpaulins, basketball ring, jeepney, tricycle, plants and trees, manholes, hopscotch, the guava, the thrown weapon objects, and the polymorph can. Meshes are cached and kept under a vertex budget by a test.
- **Cardboard walls** are the bahay-bahayan: disassembled boxes as single flat sheets (creases, tape, printing, curled flaps, a torn corner) leaning on sticks. Never stacked boxes.
- `scripts/view/street_map.gd` (`StreetMap`): asphalt, lane paint, a cross street with zebra crossings, curbs, sidewalks, house rows, base pads and posts, props. The lane geometry comes from `MapLayout` and never changes for looks.
- Lighting: one sun with soft shadows, 2x MSAA, saturation grading, a light distance haze.

### Characters (current)
- `scripts/view/art/kid_model.gd` (`KidModel`): the kids are **pre-rendered sprites** (like Clash of Clans): one pose per state in 5 directions (toward, toward-right, right, away-right, away; the left side is mirrored) from `assets/sprites/<kid>/<pose>_<dir>.png`, cut from generated sheets by `tools/sprites/slice_sheets.py` (magenta keyed out). Poses: idle, run, cast, stun (stars; used for every hard status), down (face down: the stumble after a dash), ko_stagger (delayed death and the start of a knockout), ko_lying (after a knockout fall). Motion is added in code (run bounce, breathing, hit tint, dash stretch). Kids without their own sheets use Junjun's. No team colour on the kid: the health bar tells teams apart.
- All six share one height and proportion; the hitbox is always `GameRules.player_radius`. Outfits, hair and skin tones (varied across the roster) come from `CharacterDef` (`data/characters/*.tres`). A team bandana, armband and ground ring show the team.
- Written with respect (PROJECT 3.2): identity through clothes and style only.

## HUD and UI
- Theme (`scripts/ui/kalyeah_theme.gd`, `KalyeahTheme`): chunky rounded buttons with a dark rim and drop shadow, outlined text, cream text fields, merged into the engine default theme at startup.
- Icons (`scripts/ui/icons.gd`): **painted PNGs** in `assets/icons/` for the 12 weapons, Dash, Bookmark, the guava, the settings gear and the round button face (gold rim, navy face), all drawn with Pillow by `tools/art/make_assets.py` (4x supersampled, chunky dark outline, gradient, highlight, drop shadow). The old vector drawings remain as a fallback.
- HUD (`scripts/ui/hud/`, built in code by `MatchHud`): over each hero a health bar, an *italic* status above it ("Stunned") and a Dash and a Mark cooldown bar under it (no names); damage and heal numbers; the scoreboard pill with set pips; the lane minimap. Spec in `docs/GDD.md` "HUD". The skill buttons are art only with an ATK / CC / BLK tag.
- The title screen shows a live 3D street with three kids.
- Banners pop in, the camera shakes on hits and wall breaks, buttons click.

## Street textures (Pillow)
- `tools/art/make_assets.py` also paints `assets/textures/`: warm asphalt and concrete pavers (tiling), six kids' marker doodles for the cardboard walls (sun, house, star, crown, smiley, heart "PINAS"), the SARI-SARI STORE sign, three barangay posters, the DAHAN-DAHAN road paint and chalk piko and tumbang preso marks.
- `scripts/view/art/street_art.gd` (`StreetArt`) puts them in the world: textured ground planes, doodles on both faces of every wall (darkened with the wall's damage), billboard signs and posters, ground decals that turn to read the right way up for the viewer's side.
- Rerun: `python3 tools/art/make_assets.py` (all) or `python3 tools/art/make_assets.py guava dash` (only those icons). Textures used in 3D are imported with mipmaps.

## Cinematic daylight and depth (after the sanga Tokhang intro frames)
- Lighting (`StreetMap.make_environment` and `_light_scene`): a cool-white, fairly high key sun, a sky-blue fill light from the other side and a bright cool ambient, so the whole picture reads bright and cool (no warm dark tone); a soft bloom on the brightest highlights and a light blue distance haze. All numbers are constants at the top of `street_map.gd`.
- Film finish (`scripts/view/cinematic.gd`, `shaders/cinematic.gdshader`), drawn under the HUD: a soft vignette and fine moving grain (no blur anywhere), plus dust motes drifting in the sunlight around the hero.
- Painted 9-slice frames (`tools/art/make_frames.py`, `assets/ui/`): bevelled gold-framed navy panels with an inner shadow and a top gloss, glossy bevelled buttons with a darker lip (orange, green, red, blue, grey, gold; pressed variants without the lip), dark rimmed pills. `KalyeahTheme.painted_button / painted_panel / painted_pill` use them for every button, the menu, the knocked-out card, the pick screen plates and the HUD pills.
- Wall damage (`walls_view.gd`, `OverheadHud`): flash, wobble, flying cardboard chips, a damage number, a health bar over damaged columns, and rips / holes / tape (`assets/textures/cardboard_tears.png`) fading in as a column weakens.

## Audio
- `scripts/view/audio/sound_bank.gd` (`SoundBank`): synthesised effects (each weapon has its own cast sound; footsteps, heal, stun, poof, KO, respawn, victory and defeat, UI clicks, the tricycle horn) and a looping music track built in small chunks so phones do not stall.
- `scripts/view/audio/match_audio.gd` (`MatchAudio`) plays them from `MatchSim` signals, so it works online too (the server replays events as the same signals).

## Asset pipeline (planned, P4 onward)
- Environment models (not the kids, who are sprites) are authored with the Blender Python module (`bpy`, pip-installable in the cloud session) and exported as `.glb` into `assets/models/`. Generator scripts will live in `tools/blender/` so every asset can be regenerated.
- Each asset: chunky bevelled forms, hand-painted-style textures from a small palette atlas, baked ambient occlusion, vertex colours. Characters get a skeleton and baked animations.
- Budgets: web build under 50 MB, APK under 150 MB, 60 fps target on a recommended phone.
- Effects use CPU particles (web-safe) and simple mesh and ring effects.
- Replacing a procedural prop or character with its `.glb` must not change gameplay: same height and hitbox for the kids, same footprint for props.
