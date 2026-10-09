# Art, UI and audio (M5)

Everything visual and audible is **built in code**: no image, model or sound
files to license, review or download. Phone-friendly and small (the web build
stays tiny). Style target: docs/PROJECT.md 3.8 (Clash of Clans-like low-poly,
Filipino street; inspired by, never copied).

## 3D: low-poly kit
- `scripts/view/art/low_poly.gd` (`LowPoly`): boxes, prisms/cones, chunky spheres and
  gable roofs with **one colour per face** (vertex colours) and flat normals. Every
  mesh uses **one shared material** (`LowPoly.material()`), the "one palette"
  budget in HANDOFF M6.
- `scripts/view/art/palette.gd` (`Palette`): the single colour palette (jeepney
  red/blue, sari-sari yellow, house pastels, cardboard, asphalt, team colours).
- `scripts/view/art/props.gd` (`Props`): sari-sari store, houses, laundry lines,
  electric post with flyers, cardboard walls, basketball ring, jeepney, stop sign,
  plants, tricycle, rubber ball, the thrown weapon objects, and the polymorph can.
  Meshes are cached and checked by a test to stay under 3000 vertices each.
- `scripts/view/street_map.gd` (`StreetMap`): the street around the unchanged lane:
  - asphalt with lane paint;
  - a cross street at the midline (where the tricycle drives), with zebra crossings;
  - curbs on the boundaries, sidewalks, rows of houses;
  - an electric post with a team-coloured band at each base.

## Characters
- `scripts/view/art/kid_model.gd` (`KidModel`): one shared body for all six kids.
  - Same height and proportions for everyone; the hitbox is always `GameRules.player_radius`.
  - Drawn 1.3x for chunky, toy-like proportions (visual only).
  - The outfit comes from `CharacterDef` (`data/characters/*.tres`): hair, top, bottom, shoes or tsinelas, extra (bimpo, hair clip, headband + belt bag, ice candy, pony bands), colours, and skin tone. The skin tones vary across the roster.
  - A team-coloured bandana and armband, plus a team ring on the ground.
- Animation is code-driven:
  - walk swing and idle breathing;
  - lean on dash and on stumble;
  - spin when airborne or bounced, wobble when stunned or knocked out;
  - a can when polymorphed, grey in the death delay.
- Characters are written with respect (PROJECT 3.2): identity shows through clothes and style only.

## UI
- `scripts/ui/bayabas_theme.gd` (`BayabasTheme`): chunky rounded buttons with a dark
  rim and a drop shadow, outlined text, cream text fields. It is merged into the
  engine default theme at startup, so every Control gets it.
- `scripts/ui/icons.gd` (`Icons`): vector icons for the 12 weapons, dash, bookmark,
  ball and the title guava. They're drawn on the round skill buttons and the weapon pick cards.

## Audio
- `scripts/view/audio/sound_bank.gd` (`SoundBank`): synthesised SFX and the music loop.
  - SFX: cast, hit, snip, boing, bonk, crunch, thud, point jingles, set fanfare, tricycle horn, down, revive, click, dash.
  - Music: an 8-bar pentatonic tune, rendered a few thousand samples per frame so phones don't stall.
- `scripts/view/audio/match_audio.gd` (`MatchAudio`): plays them on MatchSim signals.
  It works online too, because the server replays events as the same signals.
  Volume settings come in M6.

## Replacing with hand-made assets later
- **Models:** each builder returns an `ArrayMesh`. A `.glb` mesh can be swapped in per prop or character without touching gameplay, as long as the kids keep the same height.
- **Sounds:** a recorded sound only has to be returned for the same id.
