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
- `scripts/view/art/kid_model.gd` (`KidModel`): the six kids on **one jointed rig** (hips, spine, neck, thighs, knees, shoulders, elbows) with procedural animation: run cycle, idle, throw, hit flinch, dash, stumble, stun, airborne tumble, knockout, down, and the can when polymorphed. Footstep signals drive footstep sounds.
- All six share one height and proportion; the hitbox is always `GameRules.player_radius`. Outfits, hair and skin tones (varied across the roster) come from `CharacterDef` (`data/characters/*.tres`). A team bandana, armband and ground ring show the team.
- Written with respect (PROJECT 3.2): identity through clothes and style only.

## HUD and UI
- Theme (`scripts/ui/kalyeah_theme.gd`, `KalyeahTheme`): chunky rounded buttons with a dark rim and drop shadow, outlined text, cream text fields, merged into the engine default theme at startup.
- Icons (`scripts/ui/icons.gd`): vector icons for the 12 weapons, Dash, Mark, the guava and the tricycle.
- HUD (`scripts/ui/hud/`): overhead bars and damage numbers, the scoreboard pill with set pips, the lane minimap. Spec in `docs/GDD.md` "HUD". The skill buttons are art only with an ATK / CC / BLK tag.
- The title screen shows a live 3D street with three kids.
- Banners pop in, the camera shakes on hits and wall breaks, buttons click.

## Audio
- `scripts/view/audio/sound_bank.gd` (`SoundBank`): synthesised effects (each weapon has its own cast sound; footsteps, heal, stun, poof, KO, respawn, victory and defeat, UI clicks, the tricycle horn) and a looping music track built in small chunks so phones do not stall.
- `scripts/view/audio/match_audio.gd` (`MatchAudio`) plays them from `MatchSim` signals, so it works online too (the server replays events as the same signals).

## Asset pipeline (planned, P4 onward)
- Models are authored with the Blender Python module (`bpy`, pip-installable in the cloud session) and exported as `.glb` into `assets/models/`. The generator scripts live in the repo (`tools/blender/`), so every asset can be regenerated.
- Each asset: chunky bevelled forms, hand-painted-style textures from a small palette atlas, baked ambient occlusion, vertex colours. Characters get a skeleton and baked animations.
- Budgets: web build under 50 MB, APK under 150 MB, 60 fps target on a recommended phone.
- Effects use CPU particles (web-safe) and simple mesh and ring effects.
- Replacing a procedural prop or character with its `.glb` must not change gameplay: same height and hitbox for the kids, same footprint for props.
