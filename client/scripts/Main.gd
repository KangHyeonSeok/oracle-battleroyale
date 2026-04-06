## Main.gd
## Top-level scene controller.
## Creates all UI programmatically to avoid Godot binary packer mis-assignment bugs.
## Screen flow:
##   CharacterListScreen
##     → CharacterCreateScreen → CharacterListScreen
##     → MatchWaitingScreen → Arena + OracleStreamPanel → GameResultScreen
##     → CharacterListScreen
extends Node2D

@onready var _arena:       Node2D   = $Arena
@onready var _chars_layer: Node2D   = $CharactersLayer
@onready var _camera:      Camera2D = $Camera2D

const CHARACTER_SCENE := preload("res://scenes/Character.tscn")

const CHAR_LIST_SCRIPT   := preload("res://scripts/CharacterListScreen.gd")
const CHAR_CREATE_SCRIPT := preload("res://scripts/CharacterCreateScreen.gd")
const MATCH_WAIT_SCRIPT  := preload("res://scripts/MatchWaitingScreen.gd")
const ORACLE_STREAM_SCRIPT := preload("res://scripts/OracleStreamPanel.gd")
const GAME_RESULT_SCRIPT := preload("res://scripts/GameResultScreen.gd")
const NOTIF_SCRIPT       := preload("res://scripts/NotificationManager.gd")

var _char_nodes: Dictionary = {}
var _korean_font: FontFile = null

# UI screens
var _char_list_screen:   Control
var _char_create_screen: Control
var _match_wait_screen:  Control
var _oracle_stream:      Control
var _game_result_screen: Control

# HUD
var _hud:       Control
var _pts_lbl:   Label
var _turn_lbl:  Label
var _alive_lbl: Label

# Notifications
var _notifs: VBoxContainer

# Connection status label
var _conn_lbl: Label

# Current selected character for match
var _selected_character: Dictionary = {}

func _ready() -> void:
	_korean_font = ResourceLoader.load("res://fonts/NotoSansKR.ttf") as FontFile
	_build_ui()

	WebSocketClient.connected_to_server.connect(_on_ws_connected)
	WebSocketClient.disconnected_from_server.connect(_on_ws_disconnected)
	GameState.characters_updated.connect(_on_chars_updated)
	GameState.turn_advanced.connect(_on_turn_advanced)
	GameState.game_ended.connect(_on_game_ended)
	GameState.match_joined.connect(_on_match_joined)
	GameState.characters_loaded.connect(_on_characters_loaded)

	_camera.position = Vector2(400, 400)
	_camera.zoom     = Vector2(1.0, 1.0)

	_show_screen("char_list")

# ── UI builder ────────────────────────────────────────────────────────────────

func _apply_font(node: Control) -> void:
	if _korean_font:
		node.add_theme_font_override("font", _korean_font)

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	# ── Connection status bar ──
	var status_bar := HBoxContainer.new()
	status_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	status_bar.offset_bottom = 28.0
	ui.add_child(status_bar)

	_conn_lbl = Label.new()
	_conn_lbl.text = "● 연결 중…"
	_conn_lbl.modulate = Color(0.9, 0.3, 0.3)
	_conn_lbl.add_theme_font_size_override("font_size", 13)
	_apply_font(_conn_lbl)
	status_bar.add_child(_conn_lbl)

	# ── CharacterListScreen ──
	_char_list_screen = Control.new()
	_char_list_screen.set_script(CHAR_LIST_SCRIPT)
	_char_list_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(_char_list_screen)
	_char_list_screen.create_character_requested.connect(_on_create_character_requested)
	_char_list_screen.join_match_requested.connect(_on_join_match_requested)

	# ── CharacterCreateScreen ──
	_char_create_screen = Control.new()
	_char_create_screen.set_script(CHAR_CREATE_SCRIPT)
	_char_create_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(_char_create_screen)
	_char_create_screen.back_requested.connect(_on_create_back)
	_char_create_screen.character_created.connect(_on_character_created)

	# ── MatchWaitingScreen ──
	_match_wait_screen = Control.new()
	_match_wait_screen.set_script(MATCH_WAIT_SCRIPT)
	_match_wait_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(_match_wait_screen)
	_match_wait_screen.match_found.connect(_on_match_found)
	_match_wait_screen.cancelled.connect(_on_match_cancelled)

	# ── HUD (shown during arena) ──
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.visible = false
	ui.add_child(_hud)

	_pts_lbl = Label.new()
	_pts_lbl.set_position(Vector2(10, 32))
	_pts_lbl.set_size(Vector2(200, 20))
	_pts_lbl.text = "신탁 포인트: 100"
	_pts_lbl.add_theme_font_size_override("font_size", 13)
	_apply_font(_pts_lbl)
	_hud.add_child(_pts_lbl)

	_turn_lbl = Label.new()
	_turn_lbl.set_position(Vector2(10, 50))
	_turn_lbl.set_size(Vector2(110, 18))
	_turn_lbl.text = "턴: 0"
	_turn_lbl.add_theme_font_size_override("font_size", 13)
	_apply_font(_turn_lbl)
	_hud.add_child(_turn_lbl)

	_alive_lbl = Label.new()
	_alive_lbl.set_position(Vector2(10, 68))
	_alive_lbl.set_size(Vector2(150, 18))
	_alive_lbl.text = "생존: 0명"
	_alive_lbl.add_theme_font_size_override("font_size", 13)
	_apply_font(_alive_lbl)
	_hud.add_child(_alive_lbl)

	# ── OracleStreamPanel (right side, shown during arena) ──
	_oracle_stream = Control.new()
	_oracle_stream.set_script(ORACLE_STREAM_SCRIPT)
	_oracle_stream.visible = false
	ui.add_child(_oracle_stream)

	# ── GameResultScreen ──
	_game_result_screen = Control.new()
	_game_result_screen.set_script(GAME_RESULT_SCRIPT)
	_game_result_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_result_screen.visible = false
	ui.add_child(_game_result_screen)
	_game_result_screen.play_again_requested.connect(_on_play_again)
	_game_result_screen.main_menu_requested.connect(_on_main_menu)

	# ── Notification manager ──
	_notifs = VBoxContainer.new()
	_notifs.set_script(NOTIF_SCRIPT)
	_notifs.anchor_top    = 1.0
	_notifs.anchor_bottom = 1.0
	_notifs.offset_left   =  10.0
	_notifs.offset_top    = -220.0
	_notifs.offset_right  =  400.0
	_notifs.offset_bottom =  -10.0
	_notifs.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui.add_child(_notifs)

# ── Screen transitions ────────────────────────────────────────────────────────

func _show_screen(name: String) -> void:
	_char_list_screen.visible   = name == "char_list"
	_char_create_screen.visible = name == "char_create"
	_match_wait_screen.visible  = name == "match_wait"
	_hud.visible                = name == "arena"
	_oracle_stream.visible      = name == "arena"
	_game_result_screen.visible = name == "result"

# ── Connection ────────────────────────────────────────────────────────────────

func _on_ws_connected() -> void:
	_update_conn_label(true)
	_notifs.show_notification("서버에 연결되었습니다")
	WebSocketClient.send({"type": "get_characters"})

func _on_ws_disconnected() -> void:
	_update_conn_label(false)
	_notifs.show_notification("연결이 끊어졌습니다. 재연결 중…")

func _update_conn_label(connected: bool) -> void:
	if connected:
		_conn_lbl.text     = "● 연결됨"
		_conn_lbl.modulate = Color.GREEN
	else:
		_conn_lbl.text     = "● 연결 중…"
		_conn_lbl.modulate = Color(0.9, 0.3, 0.3)

# ── CharacterList ─────────────────────────────────────────────────────────────

func _on_characters_loaded(chars: Array) -> void:
	_char_list_screen.call("refresh", chars)

func _on_create_character_requested() -> void:
	_show_screen("char_create")

func _on_join_match_requested(character_id: int) -> void:
	var data := GameState.get_character_by_id(character_id)
	if data.is_empty():
		# Fall back to my_characters lookup
		for c in GameState.my_characters:
			if c.get("id", -1) == character_id:
				data = c
				break
	_selected_character = data
	_show_screen("match_wait")
	_match_wait_screen.call("start_waiting", data)
	WebSocketClient.send({"type": "find_match", "characterId": character_id})

# ── CharacterCreate ───────────────────────────────────────────────────────────

func _on_create_back() -> void:
	_show_screen("char_list")

func _on_character_created(_data: Dictionary) -> void:
	_char_list_screen.call("refresh", GameState.my_characters)
	_show_screen("char_list")
	_notifs.show_notification("새 성좌가 저장되었습니다!")

# ── MatchWaiting ──────────────────────────────────────────────────────────────

func _on_match_found(match_id: int) -> void:
	_show_screen("arena")
	_oracle_stream.call("clear_messages")
	_notifs.show_notification("매치 #%d 에 입장하였습니다" % match_id)

func _on_match_cancelled() -> void:
	_show_screen("char_list")
	_notifs.show_notification("매칭이 취소되었습니다")

# ── Game state ────────────────────────────────────────────────────────────────

func _on_match_joined(match_id: int) -> void:
	_show_screen("arena")
	_notifs.show_notification("매치 #%d 입장" % match_id)

func _on_chars_updated(chars: Array) -> void:
	_sync_char_nodes(chars)
	_refresh_hud()

func _on_turn_advanced(turn: int, events: Array) -> void:
	_turn_lbl.text = "턴: %d" % turn
	for ev in events:
		match ev.get("type", ""):
			"death":
				_notifs.show_notification("💀 %s 가 탈락하였습니다" % ev.get("name", "?"))
			"oracle_override":
				_notifs.show_notification("🔮 신탁이 %s 에게 개입하였습니다" % ev.get("name", "?"))

func _on_game_ended(winner_id: int, winner_name: String) -> void:
	# Build result data for GameResultScreen
	var result := {
		"winner_name": winner_name if winner_id >= 0 else "무승부",
		"rankings": [],
		"points_summary": {
			"oracle_spent": 100 - GameState.oracle_points,
			"participation_bonus": 50,
			"winner_bonus": 200 if winner_id >= 0 else 0
		}
	}
	_game_result_screen.call("show_result", result)
	_show_screen("result")
	_clear_char_nodes()

# ── Result screen ─────────────────────────────────────────────────────────────

func _on_play_again() -> void:
	_char_list_screen.call("refresh", GameState.my_characters)
	_show_screen("char_list")

func _on_main_menu() -> void:
	_char_list_screen.call("refresh", GameState.my_characters)
	_show_screen("char_list")

# ── Character nodes ───────────────────────────────────────────────────────────

func _sync_char_nodes(chars: Array) -> void:
	var seen: Dictionary = {}
	for data in chars:
		var cid: int = data.get("id", -1)
		if cid < 0:
			continue
		seen[cid] = true
		if not _char_nodes.has(cid):
			_spawn_character(data)
		else:
			(_char_nodes[cid] as Node2D).call("update_from_data", data)

	for cid in _char_nodes.keys():
		if not seen.has(cid):
			_char_nodes[cid].queue_free()
			_char_nodes.erase(cid)

func _spawn_character(data: Dictionary) -> void:
	var cid: int = data.get("id", -1)
	var node: Node2D = CHARACTER_SCENE.instantiate()
	_chars_layer.add_child(node)
	node.call("setup", data)
	_char_nodes[cid] = node

func _clear_char_nodes() -> void:
	for cid in _char_nodes.keys():
		_char_nodes[cid].queue_free()
	_char_nodes.clear()

# ── HUD ───────────────────────────────────────────────────────────────────────

func _refresh_hud() -> void:
	_pts_lbl.text = "신탁 포인트: %d" % GameState.oracle_points
	_pts_lbl.modulate = Color.WHITE if GameState.can_use_oracle() else Color(0.45, 0.45, 0.45)
	_alive_lbl.text = "생존: %d명" % GameState.alive_count

func _process(_delta: float) -> void:
	if _hud.visible:
		_refresh_hud()
