class_name CharacterDef
extends Resource
## A cosmetic character (docs/PROJECT.md 3.2). Never affects gameplay: same HP,
## speed, hitbox and timings for everyone. `tint` colours the placeholder body
## until the real models land in M5.

@export var id: StringName = &""
@export var display_name: String = ""
@export var tint: Color = Color.WHITE
