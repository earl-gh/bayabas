class_name MatchHud
extends Control
## The whole in-match HUD, built in code (no scene text to patch): overhead bars,
## top row (square slanted minimap and settings button on the left, score in the
## centre, guava and tricycle timers on the right), the settings menu, and the
## one-thumb controls: the joystick sits where a MOBA's basic attack would (bottom
## right) with weapon 1, weapon 2, the pin and the guava in an arc around it; the
## left-handed setting mirrors them.
## The match screen feeds it sim state through `sync_player()` and `sync_score()`.

signal swap_pressed
signal again_pressed
signal hurt_pressed
signal tricycle_pressed
signal exit_pressed

const BANNER_TIME: float = 2.0
const TOP_ROW_Y: float = 40.0
const MARGIN: float = 14.0
const MINIMAP_SIZE: Vector2 = Vector2(150.0, 150.0)
const GEAR_SIZE: float = 64.0
const SCORE_SIZE: Vector2 = Vector2(200.0, 84.0)
const INFO_SIZE: Vector2 = Vector2(144.0, 58.0)
## One-thumb controls, as (distance from the near side edge, distance from the
## bottom) of each control's centre on the 720x1280 base, for the right hand.
const STICK_CENTER: Vector2 = Vector2(140.0, 150.0)
const STICK_ZONE: float = 270.0
const ARC_RADIUS: float = 232.0
## Arc angles (degrees from straight left, toward straight up) of weapon 1,
## weapon 2, the pin and the guava around the joystick.
const ARC_ANGLES: Array[float] = [0.0, 30.0, 60.0, 90.0]
const WEAPON_SIZE: float = 120.0
const SKILL_SIZE: float = 104.0
const CANCEL_AT: Vector2 = Vector2(118.0, 520.0)
const CANCEL_SIZE: Vector2 = Vector2(110.0, 100.0)
const DOWN_TEXT: String = "YOU'RE DOWN!\nTouch a teammate or your base post to get back up"

var overhead: OverheadHud
var top: Control
var scoreboard: Scoreboard
var info_label: Label
var minimap: LaneMinimap
var joystick: VirtualJoystick
var bookmark_button: TouchButton
var weapon_buttons: Array[AimButton] = []
var ball_button: AimButton
## Weapon 1, weapon 2, guava (the order MatchInput uses).
var aim_buttons: Array[AimButton] = []
var cancel_zone: Control
var respawn_label: Label
var respawn_panel: RespawnPanel
var delay_label: Label
var swap_button: Button
var hurt_button: Button
var tricycle_button: Button
var again_button: Button
var settings_button: TextureButton
var menu: MatchMenu
var left_handed: bool = false
var banner: Label

var _banner_left: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	layout_controls(Settings.left_handed)
	Settings.handedness_changed.connect(layout_controls)


## Pixels the top row is pushed down to clear a notch or status bar.
func set_top_inset(pixels: float) -> void:
	top.position.y = pixels


func set_controls_active(active: bool) -> void:
	var controls: Array[Control] = [joystick, bookmark_button]
	controls.append_array(aim_buttons)
	for control: Control in controls:
		control.set_process_input(active)


func controls_active() -> bool:
	return bookmark_button.is_processing_input()


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
	respawn_panel.sync(player, rules.respawn_time, pick_open)
	# while you wait to respawn the controls are hidden so the countdown and button sit alone at the bottom
	joystick.visible = player.alive
	bookmark_button.visible = player.alive
	ball_button.visible = player.alive
	for button: AimButton in weapon_buttons:
		button.visible = player.alive
	# disabled while on cooldown too: no pressing or precasting until ready
	# the pin: ready, or out on the pin (then the same button brings you back early)
	bookmark_button.set_locked(player.death_delay or not (player.bookmark_ready() or player.mark_active))
	bookmark_button.highlight = player.mark_active
	_set_icon(bookmark_button, &"dash" if player.dash_time_left > 0.0 else (&"pin_return" if player.mark_active else &"pin"))
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
	info_label.text = "\n".join(info)
	again_button.visible = sim.phase == MatchSim.Phase.MATCH_OVER
	if sim.phase != MatchSim.Phase.MATCH_OVER and _banner_left > 0.0:
		_banner_left -= delta
		if _banner_left <= 0.0:
			banner.visible = false


func _set_icon(button: TouchButton, icon: StringName) -> void:
	if button.icon_id != icon:
		button.icon_id = icon
		button.queue_redraw()


## The guava button is art only (whole or bitten guava); it glows gold while you hold the guava.
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
	_set_icon(ball_button, &"guava_bitten" if sim.ball.is_holder(local_id) and sim.ball.bites > 0 else &"guava")
	ball_button.set_locked(not player.alive or player.death_delay)


# ---- building ------------------------------------------------------------------

func _build() -> void:
	overhead = OverheadHud.new()
	_place(overhead, Vector4(0, 0, 1, 1), Vector4.ZERO)
	add_child(overhead)
	_build_top_row()
	joystick = VirtualJoystick.new()
	joystick.rest_fraction = Vector2(0.5, 0.5)
	joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(joystick)
	delay_label = _pill_label(DOWN_TEXT, 26, Vector4(0, 0, 1, 0), Vector4(70, 236, -70, 350))
	delay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cancel_zone = _build_cancel_zone()
	var weapon_one: AimButton = _aim_button()
	var weapon_two: AimButton = _aim_button()
	ball_button = _aim_button()
	ball_button.icon_id = &"guava"
	ball_button.label_text = "Catch"
	weapon_buttons = [weapon_one, weapon_two]
	aim_buttons = [weapon_one, weapon_two, ball_button]
	for button: AimButton in aim_buttons:
		button.cancel_zone = cancel_zone
	bookmark_button = _skill_button(&"pin", "Pin")
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
	respawn_panel = RespawnPanel.new()
	add_child(respawn_panel)
	respawn_label = respawn_panel.respawn_label
	swap_button = respawn_panel.swap_button
	respawn_panel.swap_pressed.connect(swap_pressed.emit)
	# last, so it draws over the skill buttons
	menu = MatchMenu.new()
	add_child(menu)
	hurt_button = menu.hurt_button
	tricycle_button = menu.tricycle_button
	menu.hurt_pressed.connect(hurt_pressed.emit)
	menu.tricycle_pressed.connect(tricycle_pressed.emit)
	menu.exit_pressed.connect(exit_pressed.emit)
	menu.closed.connect(set_controls_active.bind(true))


## Puts the joystick at the bottom corner (right, or left when `left`) and the
## skills in an arc around it; everything mirrors for the left hand.
func layout_controls(left: bool) -> void:
	left_handed = left
	_put(joystick, STICK_CENTER, Vector2(STICK_ZONE, STICK_ZONE))
	var arc: Array[Control] = [weapon_buttons[0], weapon_buttons[1], bookmark_button, ball_button]
	for i: int in arc.size():
		var angle: float = deg_to_rad(ARC_ANGLES[i])
		var at: Vector2 = STICK_CENTER + Vector2(cos(angle), sin(angle)) * ARC_RADIUS
		var side: float = WEAPON_SIZE if i < 2 else SKILL_SIZE
		_put(arc[i], at, Vector2(side, side))
	_put(cancel_zone, CANCEL_AT, CANCEL_SIZE)


## Places `control` with its centre `at` = (from the near side edge, from the bottom).
func _put(control: Control, at: Vector2, extent: Vector2) -> void:
	var anchor_x: float = 0.0 if left_handed else 1.0
	var center_x: float = at.x if left_handed else -at.x
	_place(control, Vector4(anchor_x, 1, anchor_x, 1), Vector4(
		center_x - extent.x / 2.0, -at.y - extent.y / 2.0, center_x + extent.x / 2.0, -at.y + extent.y / 2.0))


func _build_top_row() -> void:
	top = Control.new()
	_place(top, Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 520))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	# left: square minimap, then the settings button beside it (top aligned)
	minimap = LaneMinimap.new()
	_place(minimap, Vector4(0, 0, 0, 0), Vector4(MARGIN, TOP_ROW_Y, MARGIN + MINIMAP_SIZE.x, TOP_ROW_Y + MINIMAP_SIZE.y))
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(minimap)
	settings_button = TextureButton.new()
	settings_button.texture_normal = Icons.art(&"gear")
	settings_button.ignore_texture_size = true
	settings_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var gear_x: float = MARGIN * 1.6 + MINIMAP_SIZE.x
	_place(settings_button, Vector4(0, 0, 0, 0), Vector4(gear_x, TOP_ROW_Y, gear_x + GEAR_SIZE, TOP_ROW_Y + GEAR_SIZE))
	settings_button.pressed.connect(toggle_menu)
	top.add_child(settings_button)
	# right: guava and tricycle countdowns
	info_label = Label.new()
	_place(info_label, Vector4(1, 0, 1, 0), Vector4(-MARGIN - INFO_SIZE.x, TOP_ROW_Y, -MARGIN, TOP_ROW_Y + INFO_SIZE.y))
	info_label.theme_type_variation = &"HudPill"
	info_label.add_theme_font_size_override("font_size", 17)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(info_label)
	# centre: score
	scoreboard = Scoreboard.new()
	_place(scoreboard, Vector4(0.5, 0, 0.5, 0), Vector4(-SCORE_SIZE.x / 2.0, TOP_ROW_Y, SCORE_SIZE.x / 2.0, TOP_ROW_Y + SCORE_SIZE.y))
	scoreboard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(scoreboard)


## Open or close the settings menu; the controls ignore touches while it is open.
func toggle_menu() -> void:
	if menu.visible:
		menu.close()
		return
	set_controls_active(false)
	menu.open()


func _build_cancel_zone() -> Control:
	var zone: Control = Control.new()
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


func _aim_button() -> AimButton:
	var button: AimButton = AimButton.new()
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(button)
	return button


func _skill_button(icon: StringName, label: String) -> TouchButton:
	var button: TouchButton = TouchButton.new()
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.icon_id = icon
	button.label_text = label
	add_child(button)
	return button
