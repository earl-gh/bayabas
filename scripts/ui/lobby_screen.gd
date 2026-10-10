class_name LobbyScreen
extends Control
## Online lobby (portrait): server address and name, then Create (1v1 / 2v2 / 3v3)
## or Join (6-letter code), then the room: two team columns, Ready, Start (host)
## and Leave. When the host starts, it switches to the online match scene.
## Built in code; all networking goes through the GameClient in `Net`.

enum Intent { CREATE, JOIN }

const MATCH_SCENE: String = "res://scenes/match/online.tscn"
const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"
const TEAM_NAMES: Array[String] = ["Blue team", "Red team"]
const TEAM_COLORS: Array[Color] = [Color(0.45, 0.65, 1.0), Color(1.0, 0.45, 0.45)]
const FONT: int = 28
const BIG_FONT: int = 56

var client: GameClient
var intent: Intent = Intent.CREATE
## Off in tests: stay on this screen when the match starts loading.
var enter_match_on_start: bool = true
var _intent_set: bool = false
var _rejoining: bool = false
var _rejoin_button: Button
## The action to send once the connection is up.
var _pending: Callable = Callable()

var _setup: VBoxContainer
var _room_box: VBoxContainer
var _url_edit: LineEdit
var _name_edit: LineEdit
var _code_edit: LineEdit
var _size_buttons: Array[Button] = []
var _go_button: Button
var _status: Label
var _code_label: Label
var _team_lists: Array[VBoxContainer] = []
var _team_buttons: Array[Button] = []
var _ready_button: Button
var _start_button: Button
var _team_size: int = 1


func _ready() -> void:
	if client == null:
		client = Net.client
	if not _intent_set:
		intent = Session.lobby_intent as Intent
	_build()
	client.connection_changed.connect(_on_connection_changed)
	client.error_received.connect(_on_error)
	client.room_changed.connect(_on_room_changed)
	client.match_loading.connect(_on_match_loading)
	client.welcomed.connect(_on_welcomed)
	_show_room(not client.room.is_empty())
	if not client.room.is_empty():
		_on_room_changed(client.room)


## Tests / callers: choose Create or Join before the screen enters the tree.
func set_intent(value: Intent) -> void:
	intent = value
	_intent_set = true


func set_fields(url: String, player_name: String, code: String = "") -> void:
	_url_edit.text = url
	_name_edit.text = player_name
	if _code_edit != null:
		_code_edit.text = code


func code_text() -> String:
	return _code_label.text


func in_room() -> bool:
	return _room_box.visible


func press_ready() -> void:
	_ready_button.button_pressed = not _ready_button.button_pressed
	client.set_ready(_ready_button.button_pressed)


func press_start() -> void:
	if _start_button.visible and not _start_button.disabled:
		client.start_match()


func start_enabled() -> bool:
	return _start_button.visible and not _start_button.disabled


func status_text() -> String:
	return _status.text


## Create / Join pressed: remember the name and server, connect if needed, then send.
func submit() -> void:
	var url: String = Settings.normalize_url(_url_edit.text)
	if url.is_empty():
		_status.text = "Enter the game server address first\\n(see server/README.md)."
		return
	Settings.save_server_url(url)
	Session.player_name = _name_edit.text.strip_edges()
	Session.save()
	client.player_name = Session.player_name
	if intent == Intent.CREATE:
		_pending = client.create_room.bind(_team_size)
	else:
		var code: String = _code_edit.text.strip_edges().to_upper()
		if code.length() != 6:
			_status.text = "Room codes have 6 letters."
			return
		_pending = client.join_room.bind(code)
	if client.is_online():
		_send_pending()
	else:
		_status.text = "Connecting..."
		if client.connect_to(url) != OK:
			_status.text = "Can't reach that address."


## Takes our slot in a running match back (after a reload or a long drop).
func rejoin() -> void:
	if Session.reconnect_token.is_empty():
		return
	client.token = Session.reconnect_token
	client.player_name = Session.player_name
	_rejoining = true
	_status.text = "Rejoining..."
	if client.connect_to(Session.reconnect_url) != OK:
		_status.text = "Can't reach that address."


func choose_size(size: int) -> void:
	_team_size = size
	for i: int in _size_buttons.size():
		_size_buttons[i].button_pressed = i + 1 == size


func _send_pending() -> void:
	if _pending.is_valid():
		_status.text = ""
		_pending.call()
		_pending = Callable()


func _on_connection_changed(online: bool) -> void:
	if online:
		_send_pending()
	else:
		_status.text = "Disconnected from the server."
		_show_room(false)


func _on_welcomed(reconnected: bool) -> void:
	if not _rejoining:
		return
	_rejoining = false
	if not reconnected:
		_status.text = "That match has ended."
		Session.reconnect_token = ""
		Session.save()
		client.token = ""
		_rejoin_button.visible = false


func _on_error(text: String) -> void:
	_status.text = text


func _on_room_changed(room: Dictionary) -> void:
	_show_room(true)
	Session.room_code = room.get("code", "") as String
	Session.reconnect_token = client.token
	Session.reconnect_url = Settings.server_url
	Session.save()
	var size: int = room.get("team_size", 1) as int
	_code_label.text = "%s   (%dv%d)" % [Session.room_code, size, size]
	var members: Array = room.get("members", []) as Array
	for team: int in 2:
		var list: VBoxContainer = _team_lists[team]
		for child: Node in list.get_children():
			child.free()
		var count: int = 0
		for member: Dictionary in members:
			if member["team"] != team:
				continue
			count += 1
			var line: String = member["name"] as String
			if member["player_id"] == room.get("host", -1):
				line += " (host)"
			if member["player_id"] == client.player_id:
				line += " - you"
			line += "   READY" if member["ready"] else "   ..."
			list.add_child(_label(line, FONT, TEAM_COLORS[team]))
		for empty: int in size - count:
			list.add_child(_label("(open)", FONT, Color(1, 1, 1, 0.4)))
		_team_buttons[team].disabled = client.my_team() == team or count >= size
	var me_ready: bool = false
	for member: Dictionary in members:
		if member["player_id"] == client.player_id:
			me_ready = member["ready"] as bool
	_ready_button.button_pressed = me_ready
	_ready_button.text = "READY!" if me_ready else "Tap when you're ready"
	_start_button.visible = client.is_host()
	_start_button.disabled = not (room.get("can_start", false) as bool)


func _on_match_loading(_info: Dictionary) -> void:
	_status.text = "Loading the match..."
	if enter_match_on_start:
		get_tree().change_scene_to_file(MATCH_SCENE)


func _on_leave() -> void:
	client.leave_room()
	_rejoin_button.visible = false
	Session.reconnect_token = ""
	Session.save()
	_show_room(false)


func _on_back() -> void:
	if not client.room.is_empty():
		client.leave_room()
	client.close()
	get_tree().change_scene_to_file(TITLE_SCENE)


func _show_room(in_room: bool) -> void:
	_setup.visible = not in_room
	_room_box.visible = in_room


func _build() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.1, 0.09, 0.14)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	margin.add_theme_constant_override("margin_top", 96)
	margin.add_theme_constant_override("margin_bottom", 64)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	var top: HBoxContainer = HBoxContainer.new()
	column.add_child(top)
	top.add_child(_button("Back", _on_back))
	var title: Label = _label("CREATE ROOM" if intent == Intent.CREATE else "JOIN ROOM", 44)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_setup = VBoxContainer.new()
	_setup.add_theme_constant_override("separation", 14)
	column.add_child(_setup)
	_setup.add_child(_label("Game server", FONT))
	_url_edit = _edit(Settings.server_url, "wss://your-server.example.com")
	_setup.add_child(_url_edit)
	_setup.add_child(_label("Your name", FONT))
	_name_edit = _edit(Session.player_name, "Player")
	_name_edit.max_length = 12
	_setup.add_child(_name_edit)
	if intent == Intent.CREATE:
		_setup.add_child(_label("Mode", FONT))
		var sizes: HBoxContainer = HBoxContainer.new()
		sizes.add_theme_constant_override("separation", 12)
		_setup.add_child(sizes)
		for size: int in [1, 2, 3]:
			var button: Button = _button("%dv%d" % [size, size], choose_size.bind(size))
			_make_toggle(button)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sizes.add_child(button)
			_size_buttons.append(button)
		choose_size(1)
	else:
		_setup.add_child(_label("Room code", FONT))
		_code_edit = _edit("", "ABC234")
		_code_edit.max_length = 6
		_code_edit.add_theme_font_size_override("font_size", BIG_FONT)
		_code_edit.text_changed.connect(func(text: String) -> void:
			var caret: int = _code_edit.caret_column
			_code_edit.text = text.to_upper()
			_code_edit.caret_column = caret)
		_setup.add_child(_code_edit)
	_go_button = _button("CREATE" if intent == Intent.CREATE else "JOIN", submit)
	_go_button.custom_minimum_size = Vector2(0, 96)
	_setup.add_child(_go_button)
	_rejoin_button = _button("REJOIN LAST MATCH", rejoin)
	_rejoin_button.visible = not Session.reconnect_token.is_empty()
	_setup.add_child(_rejoin_button)
	_room_box = VBoxContainer.new()
	_room_box.add_theme_constant_override("separation", 14)
	column.add_child(_room_box)
	_room_box.add_child(_label("ROOM CODE - share it with your squad", FONT))
	_code_label = _label("", BIG_FONT, Color(1.0, 0.86, 0.3))
	_room_box.add_child(_code_label)
	for team: int in 2:
		var header: HBoxContainer = HBoxContainer.new()
		_room_box.add_child(header)
		var name_label: Label = _label(TEAM_NAMES[team], FONT, TEAM_COLORS[team])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.add_child(name_label)
		var join_team: Button = _button("Join", client.pick_team.bind(team))
		header.add_child(join_team)
		_team_buttons.append(join_team)
		var list: VBoxContainer = VBoxContainer.new()
		_room_box.add_child(list)
		_team_lists.append(list)
	_ready_button = _button("Tap when you're ready", func() -> void: client.set_ready(_ready_button.button_pressed))
	_make_toggle(_ready_button)
	_ready_button.custom_minimum_size = Vector2(0, 96)
	_room_box.add_child(_ready_button)
	_start_button = _button("START MATCH", client.start_match)
	_start_button.custom_minimum_size = Vector2(0, 96)
	_room_box.add_child(_start_button)
	_room_box.add_child(_button("Leave room", _on_leave))
	_status = _label("", FONT, Color(1.0, 0.75, 0.5))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	var gate: Node = (load("res://scenes/ui/orientation_gate.tscn") as PackedScene).instantiate()
	add_child(gate)


func _label(text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _edit(text: String, placeholder: String) -> LineEdit:
	var edit: LineEdit = LineEdit.new()
	edit.text = text
	edit.placeholder_text = placeholder
	edit.custom_minimum_size = Vector2(0, 72)
	edit.add_theme_font_size_override("font_size", FONT)
	return edit


## Toggle buttons light up yellow when on (like picked weapons).
func _make_toggle(button: Button) -> void:
	button.toggle_mode = true
	var on: StyleBoxFlat = BayabasTheme.button_box(WeaponPickScreen.PICKED_COLOR, true)
	button.add_theme_stylebox_override("pressed", on)
	button.add_theme_stylebox_override("hover_pressed", on)
	for state: String in ["font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, Color.BLACK)


func _button(text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 72)
	button.add_theme_font_size_override("font_size", FONT)
	button.pressed.connect(action)
	return button
