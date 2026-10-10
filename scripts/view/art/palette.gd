class_name Palette
extends RefCounted
## The one shared colour palette (docs/PROJECT.md 3.8): bright, saturated Pinoy
## street colours. Every prop and character picks from here.

const ASPHALT: Color = Color(0.36, 0.37, 0.42)
const ASPHALT_DARK: Color = Color(0.29, 0.3, 0.35)
const LANE_PAINT: Color = Color(0.98, 0.92, 0.55)
const SIDEWALK: Color = Color(0.78, 0.74, 0.66)
const CURB: Color = Color(0.92, 0.9, 0.84)
const CONCRETE: Color = Color(0.72, 0.72, 0.7)
const CARDBOARD: Color = Color(0.76, 0.52, 0.28)
const CARDBOARD_DARK: Color = Color(0.7, 0.5, 0.28)
const TAPE: Color = Color(0.88, 0.76, 0.48)
const WOOD: Color = Color(0.62, 0.42, 0.26)
const ROOF_TIN: Color = Color(0.55, 0.62, 0.66)
const ROOF_RUST: Color = Color(0.74, 0.38, 0.22)
const ROOF_RED: Color = Color(0.86, 0.25, 0.2)
const WALL_MINT: Color = Color(0.62, 0.9, 0.78)
const WALL_PINK: Color = Color(0.98, 0.7, 0.72)
const WALL_SKY: Color = Color(0.62, 0.8, 0.98)
const WALL_LEMON: Color = Color(0.99, 0.9, 0.5)
const WALL_PEACH: Color = Color(0.99, 0.78, 0.58)
const SARI_YELLOW: Color = Color(1.0, 0.82, 0.18)
const SARI_RED: Color = Color(0.92, 0.2, 0.18)
const JEEP_RED: Color = Color(0.9, 0.16, 0.2)
const JEEP_BLUE: Color = Color(0.12, 0.42, 0.9)
const JEEP_CHROME: Color = Color(0.86, 0.88, 0.92)
const LEAF: Color = Color(0.28, 0.72, 0.32)
const LEAF_DARK: Color = Color(0.18, 0.5, 0.24)
const POT: Color = Color(0.78, 0.4, 0.26)
const WINDOW: Color = Color(0.2, 0.28, 0.4)
const DOOR: Color = Color(0.5, 0.3, 0.2)
const POST_GREY: Color = Color(0.68, 0.68, 0.66)
const WIRE: Color = Color(0.12, 0.12, 0.14)
const RUBBER_BALL: Color = Color(1.0, 0.28, 0.5)
const RING_ORANGE: Color = Color(1.0, 0.5, 0.15)
const WHITE: Color = Color(0.97, 0.97, 0.95)
const BLACK: Color = Color(0.1, 0.1, 0.12)
const FLYERS: Array[Color] = [
	Color(1.0, 0.95, 0.4), Color(0.4, 0.85, 1.0), Color(1.0, 0.55, 0.65),
	Color(0.6, 1.0, 0.6), Color(1.0, 1.0, 1.0), Color(1.0, 0.7, 0.3),
]
const LAUNDRY: Array[Color] = [
	Color(1.0, 0.4, 0.4), Color(0.4, 0.7, 1.0), Color(1.0, 0.9, 0.3),
	Color(0.95, 0.95, 0.95), Color(0.6, 0.9, 0.5), Color(0.9, 0.6, 1.0),
]
## Team colours: own team blue, the other red (bandanas, rings, base posts).
const TEAM_OWN: Color = Color(0.2, 0.5, 1.0)
const TEAM_ALLY: Color = Color(0.45, 0.75, 1.0)
const TEAM_ENEMY: Color = Color(1.0, 0.28, 0.28)
