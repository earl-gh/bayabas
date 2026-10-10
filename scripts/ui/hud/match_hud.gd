class_name MatchHud
extends Control
## The whole in-match HUD, built in code (no scene text to patch): overhead bars,
## top row (scoreboard, timers, minimap), joystick, art-only skill buttons, the
## cancel zone, status labels, banner and test buttons. The match screen feeds it
## sim state through `sync_player()` and `sync_score()`.

signal swap_pressed
signal again_pressed
signal hurt_pressed
signal tricycle_pressed

const BANNER_TIME: float = 2.0
const TOP_ROW_Y: float = 52.0
const DOWN_TEXT: String = "YOU'RE DOWN!\nTouch a teammate or your base post to get back up"

var overhead: OverheadHud
var top: Control
var scoreboard: Scoreboard
var info_label: Label
var minimap: LaneMinimap
var joystick: VirtualJoystick
var dash_button: TouchButton
var bookmark_button: TouchButton
var weapon_buttons: Array[AimButton] = []
var ball_button: AimButton
## Weapon 1, weapon 2, guava (the order MatchInput uses).
var aim_buttons: Array[AimButton] = []
var cancel_zone: Control
var respawn_label: Label
var delay_label: Label
var swap_button: Button
var hurt_button: Button
var tricycle_button: Button
var again_button: Button
var banner: Label

var _banner_left: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


## Pixels the top row is pushed down to clear a notch or status bar.
func set_top_inset(pixels: float) -> void:
	top.position.y = pixels


func set_controls_active(active: bool) -> void:
	var controls: Array[Control] = [joystick, dash_button, bookmark_button]
	controls.append_array(aim_buttons)
	for control: Control in controls:
		control.set_process_input(active)


func controls_active() -> bool:
	return dash_button.is_processing_input()


func show_banner(text: String) -> void:
	banner.text = text
	banner.visible = true
	_banner_left = BANNER_TIME
	# pop in: starts big and transparent, settles with a little overshoot
	banner.pivot_offset = banner.size / 2.0
	banner.scale = Vector2.ONE * 1.5
	banner.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(banner, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner, "modulate:a", 1.0, 0.12)


func banner_text() -> String:
	return banner.text if banner.visible else ""


## Buttons, labels and cooldowns for the local player.
func sync_player(sim: MatchSim, rules: GameRules, player: PlayerState, local_id: int, pick_open: bool) -> void:
	delay_label.visible = player.death_delay
	respawn_label.visible = not player.alive
	respawn_label.text = "RESPAWN IN %d" % ceili(player.respawn_time_left)
	swap_button.visible = not player.alive and not pick_open
	# while you wait to respawn the controls are hidden so the countdown and button sit alone at the bottom
	joystick.visible = player.alive
	dash_button.visible = player.alive
	bookmark_button.visible = player.alive
	ball_button.visible = player.alive
	for button: AimButton in weapon_buttons:
		button.visible = player.alive
	# disabled while on cooldown too: no pressing or precasting until ready
	dash_button.set_locked(player.death_delay or player.dash_cooldown_left > 0.0)
	bookmark_button.set_locked(player.death_delay or not player.bookmark_ready())
	dash_button.set_cooldown(player.dash_cooldown_left, rules.dash_cooldown)
	bookmark_button.set_cooldown(player.bookmark_cooldown_left, rules.bookmark_cooldown)
	var weapons_off: bool = not player.alive or player.death_delay or not player.effects.can_cast()
	_sync_guava_button(sim, player, local_id)
	for slot: int in weapon_buttons.size():
		var button: AimButton = weapon_buttons[slot]
		if slot >= player.weapons.size():
			button.set_locked(true)
			continue
		var def: WeaponDef = sim.weapon_defs[player.weapons[slot]]
		if button.label_text != def.short_name or button.sub_text != def.kind_label():
			button.label_text = def.short_name
			button.sub_text = def.kind_label()
			button.icon_id = def.id
			button.sub_color = WeaponPickScreen.kind_color(def.kind)
			button.queue_redraw()
		button.set_locked(weapons_off or player.weapon_cooldowns[slot] > 0.0)
		button.set_cooldown(player.weapon_cooldowns[slot], def.cooldown)


## Top row: score and set pips, guava and tricycle timers; the banner fades out.
func sync_score(sim: MatchSim, rules: GameRules, local_team: int, delta: float) -> void:
	scoreboard.show_score(sim.score, local_team, rules.match_sets_to_win)
	var info: PackedStringArray = PackedStringArray()
	if sim.ball.state == RubberBall.State.NONE:
		info.append("Guava in %ds" % ceili(sim.ball.spawn_timer))
	else:
		info.append("Guava is out!")
	var arrival: float = sim.tricycle.time_to_arrival(rules)
	if sim.tricycle.phase == Tricycle.Phase.CROSSING:
		info.append("Tricycle!")
	else:
		info.append("Tricycle %d:%02d" % [floori(arrival) / 60, floori(arrival) % 60])
	if sim.phase == MatchSim.Phase.POINT_FREEZE:
		info.append("Next round in %d" % ceili(sim.freeze_left))
	info_label.text = "  |  ".join(info)
	again_button.visible = sim.phase == MatchSim.Phase.MATCH_OVER
	if sim.phase != MatchSim.Phase.MATCH_OVER and _banner_left > 0.0:
		_banner_left -= delta
		if _banner_left <= 0.0:
			banner.visible = false


## The guava button is art only; it glows gold while you hold the guava.
func _sync_guava_button(sim: MatchSim, player: PlayerState, local_id: int) -> void:
	var text: String = "Catch"
	if sim.ball.is_holder(local_id):
		text = "Throw"
	elif sim.ball.state == RubberBall.State.FLYING and sim.ball.thrower_id == local_id and sim.ball.can_blink:
		text = "Blink"
	if ball_button.label_text != text:
		ball_button.label_text = text
		ball_button.queue_redraw()
	ball_button.highlight = sim.ball.is_holder(local_id)
	ball_button.set_locked(not player.alive or player.death_delay)


# ---- building ------------------------------------------------------------------

func _build() -> void:
	overhead = OverheadHud.new()
	_place(overhead, Vector4(0, 0, 1, 1), Vector4.ZERO)
	add_child(overhead)
	_build_top_row()
	joystick = VirtualJoystick.new()
	_place(joystick, Vector4(0, 0.45, 0.5, 1), Vector4.ZERO)
	joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(joystick)
	respawn_label = _pill_label("", 44, Vector4(0.5, 1, 0.5, 1), Vector4(-170, -250, 170, -170))
	delay_label = _pill_label(DOWN_TEXT, 26, Vector4(0, 0, 1, 0), Vector4(70, 236, -70, 350))
	delay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	swap_button = _button("CHANGE WEAPONS", 28, Vector4(0.5, 1, 0.5, 1), Vector4(-170, -150, 170, -62))
	swap_button.visible = false
	swap_button.pressed.connect(swap_pressed.emit)
	cancel_zone = _build_cancel_zone()
	var weapon_one: AimButton = _aim_button(Vector4(-194, -194, -44, -44))
	var weapon_two: AimButton = _aim_button(Vector4(-360, -150, -230, -20))
	ball_button = _aim_button(Vector4(-310, -480, -206, -376))
	ball_button.icon_id = &"ball"
	ball_button.label_text = "Catch"
	weapon_buttons = [weapon_one, weapon_two]
	aim_buttons = [weapon_one, weapon_two, ball_button]
	for button: AimButton in aim_buttons:
		button.cancel_zone = cancel_zone
	dash_button = _skill_button(Vector4(-170, -370, -58, -258), &"dash", "Dash")
	bookmark_button = _skill_button(Vector4(-330, -320, -218, -208), &"bookmark", "Mark")
	banner = Label.new()
	_place(banner, Vector4(0, 0.3, 1, 0.3), Vector4(0, -60, 0, 60))
	banner.visible = false
	banner.add_theme_color_override("font_color", Color(1, 0.86, 0.3))
	banner.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.1))
	banner.add_theme_constant_override("outline_size", 12)
	banner.add_theme_font_size_override("font_size", 44)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)
	again_button = _button("Play again", 32, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-160, -30, 160, 60))
	again_button.pressed.connect(again_pressed.emit)
	again_button.visible = false


func _build_top_row() -> void:
	top = Control.new()
	_place(top, Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 520))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	scoreboard = Scoreboard.new()
	_place(scoreboard, Vector4(0.5, 0, 0.5, 0), Vector4(-112, TOP_ROW_Y, 112, 136))
	scoreboard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(scoreboard)
	info_label = Label.new()
	_place(info_label, Vector4(0.5, 0, 0.5, 0), Vector4(-150, 142, 150, 176))
	info_label.theme_type_variation = &"HudPill"
	info_label.add_theme_font_size_override("font_size", 16)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(info_label)
	minimap = LaneMinimap.new()
	_place(minimap, Vector4(0, 0, 0, 0), Vector4(12, 56, 58, 396))
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(minimap)
	hurt_button = _button("-30 HP (test)", 16, Vector4(1, 0, 1, 0), Vector4(-172, 116, -12, 162), top)
	hurt_button.pressed.connect(hurt_pressed.emit)
	tricycle_button = _button("Tricycle (test)", 16, Vector4(1, 0, 1, 0), Vector4(-172, 168, -12, 214), top)
	tricycle_button.pressed.connect(tricycle_pressed.emit)


func _build_cancel_zone() -> Control:
	var zone: Control = Control.new()
	_place(zone, Vector4(1, 1, 1, 1), Vector4(-170, -540, -60, -430))
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.visible = false
	add_child(zone)
	var back: ColorRect = ColorRect.new()
	_place(back, Vector4(0, 0, 1, 1), Vector4.ZERO)
	back.color = Color(0.85, 0.15, 0.15, 0.55)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(back)
	var label: Label = Label.new()
	_place(label, Vector4(0, 0, 1, 1), Vector4.ZERO)
	label.text = "Cancel"
	label.add_theme_font_size_override("font_size", 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	zone.add_child(label)
	return zone


## Anchors first, then offsets (setting an anchor can move offsets).
func _place(control: Control, anchors: Vector4, offsets: Vector4) -> void:
	control.anchor_left = anchors.x
	control.anchor_top = anchors.y
	control.anchor_right = anchors.z
	control.anchor_bottom = anchors.w
	control.offset_left = offsets.x
	control.offset_top = offsets.y
	control.offset_right = offsets.z
	control.offset_bottom = offsets.w


func _pill_label(text: String, font_size: int, anchors: Vector4, offsets: Vector4) -> Label:
	var label: Label = Label.new()
	_place(label, anchors, offsets)
	label.theme_type_variation = &"HudPill"
	label.text = text
	label.visible = false
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _button(text: String, font_size: int, anchors: Vector4, offsets: Vector4, parent: Control = null) -> Button:
	var button: Button = Button.new()
	_place(button, anchors, offsets)
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	(parent if parent != null else self).add_child(button)
	return button


func _aim_button(offsets: Vector4) -> AimButton:
	var button: AimButton = AimButton.new()
	_place(button, Vector4(1, 1, 1, 1), offsets)
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(button)
	return button


func _skill_button(offsets: Vector4, icon: StringName, label: String) -> TouchButton:
	var button: TouchButton = TouchButton.new()
	_place(button, Vector4(1, 1, 1, 1), offsets)
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.icon_id = icon
	button.label_text = label
	add_child(button)
	return button
