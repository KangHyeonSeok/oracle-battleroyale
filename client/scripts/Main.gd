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

const LOGIN_SCRIPT          := preload("res://scripts/LoginScreen.gd")
const CHAR_LIST_SCRIPT      := preload("res://scripts/CharacterListScreen.gd")
const CHAR_CREATE_SCRIPT    := preload("res://scripts/CharacterCreateScreen.gd")
const MATCH_WAIT_SCRIPT     := preload("res://scripts/MatchWaitingScreen.gd")
const ORACLE_STREAM_SCRIPT  := preload("res://scripts/OracleStreamPanel.gd")
const GAME_RESULT_SCRIPT    := preload("res://scripts/GameResultScreen.gd")
const NOTIF_SCRIPT          := preload("res://scripts/NotificationManager.gd")
const SPECTATE_LIST_SCRIPT  := preload("res://scripts/SpectateListScreen.gd")
const MATCH_HISTORY_SCRIPT  := preload("res://scripts/MatchHistoryScreen.gd")
const MATCH_DETAIL_SCRIPT   := preload("res://scripts/MatchDetailScreen.gd")
const LEADERBOARD_SCRIPT    := preload("res://scripts/LeaderboardScreen.gd")
const ONBOARDING_SCRIPT     := preload("res://scripts/OnboardingOverlay.gd")

const BG_CARD        := Color(1, 1, 1, 0.06)
const ACCENT_PURPLE  := Color(0.545, 0.361, 0.965)
const TEXT_SECONDARY := Color(1, 1, 1, 0.6)

var _char_nodes: Dictionary = {}
var _korean_font: FontFile = null

# UI screens
var _login_screen:        Control
var _char_list_screen:    Control
var _char_create_screen:  Control
var _match_wait_screen:   Control
var _oracle_stream:       Control
var _game_result_screen:  Control
var _spectate_list_screen: Control
var _match_history_screen: Control
var _match_detail_screen:  Control
var _leaderboard_screen:   Control

# Auth
var _http_auth: HTTPRequest

# Spectator state
var _is_spectating: bool = false

# HUD
var _hud:            Control
var _pts_lbl:        Label
var _turn_lbl:       Label
var _alive_lbl:      Label
var _spectator_badge: Label

# Character HUD strip
var _char_hud_scroll: ScrollContainer
var _char_hud_strip: HBoxContainer
var _char_hud_cards: Dictionary = {}

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
	WebSocketClient.reconnect_failed.connect(_on_ws_reconnect_failed)
	GameState.characters_updated.connect(_on_chars_updated)
	GameState.turn_advanced.connect(_on_turn_advanced)
	GameState.game_ended.connect(_on_game_ended)
	GameState.match_joined.connect(_on_match_joined)
	GameState.characters_loaded.connect(_on_characters_loaded)

	_camera.position = Vector2(400, 400)
	_camera.zoom     = Vector2(1.0, 1.0)

	_check_auth()

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

	# ── LoginScreen ──
	_login_screen = Control.new()
	_login_screen.set_script(LOGIN_SCRIPT)
	_login_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_login_screen.visible = false
	ui.add_child(_login_screen)
	_login_screen.login_requested.connect(func(): _show_screen("login"))  # 데스크탑 폴백용

	# ── CharacterListScreen ──
	_char_list_screen = Control.new()
	_char_list_screen.set_script(CHAR_LIST_SCRIPT)
	_char_list_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(_char_list_screen)
	_char_list_screen.create_character_requested.connect(_on_create_character_requested)
	_char_list_screen.join_match_requested.connect(_on_join_match_requested)
	_char_list_screen.spectate_requested.connect(_on_spectate_requested)
	_char_list_screen.history_requested.connect(_on_history_requested)
	_char_list_screen.leaderboard_requested.connect(_on_leaderboard_requested)

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

	# Spectator badge (shown only in spectator mode)
	_spectator_badge = Label.new()
	_spectator_badge.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_spectator_badge.offset_top    = 4.0
	_spectator_badge.offset_bottom = 28.0
	_spectator_badge.text = "👁 관전 중"
	_spectator_badge.modulate = ACCENT_PURPLE
	_spectator_badge.add_theme_font_size_override("font_size", 15)
	_spectator_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spectator_badge.visible = false
	_apply_font(_spectator_badge)
	_hud.add_child(_spectator_badge)

	# ── 캐릭터 상태 스트립 (ScrollContainer 래핑) ──
	_char_hud_scroll = ScrollContainer.new()
	_char_hud_scroll.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_char_hud_scroll.offset_top = -90
	_char_hud_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_char_hud_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_DISABLED
	_hud.add_child(_char_hud_scroll)

	_char_hud_strip = HBoxContainer.new()
	_char_hud_strip.add_theme_constant_override("separation", 6)
	_char_hud_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_char_hud_scroll.add_child(_char_hud_strip)

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

	# ── SpectateListScreen ──
	_spectate_list_screen = Control.new()
	_spectate_list_screen.set_script(SPECTATE_LIST_SCRIPT)
	_spectate_list_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spectate_list_screen.visible = false
	ui.add_child(_spectate_list_screen)
	_spectate_list_screen.back_requested.connect(_on_spectate_back)
	_spectate_list_screen.spectate_match_requested.connect(_on_spectate_match_requested)

	# ── MatchHistoryScreen ──
	_match_history_screen = Control.new()
	_match_history_screen.set_script(MATCH_HISTORY_SCRIPT)
	_match_history_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_match_history_screen.visible = false
	ui.add_child(_match_history_screen)
	_match_history_screen.back_requested.connect(_on_match_history_back)
	_match_history_screen.detail_requested.connect(_on_match_detail_requested)

	# ── MatchDetailScreen ──
	_match_detail_screen = Control.new()
	_match_detail_screen.set_script(MATCH_DETAIL_SCRIPT)
	_match_detail_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_match_detail_screen.visible = false
	ui.add_child(_match_detail_screen)
	_match_detail_screen.back_requested.connect(_on_match_detail_back)

	# ── LeaderboardScreen ──
	_leaderboard_screen = Control.new()
	_leaderboard_screen.set_script(LEADERBOARD_SCRIPT)
	_leaderboard_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_leaderboard_screen.visible = false
	ui.add_child(_leaderboard_screen)
	_leaderboard_screen.back_requested.connect(_on_leaderboard_back)

	_fetch_my_account_id()

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
	_login_screen.visible         = name == "login"
	_char_list_screen.visible     = name == "char_list"
	_char_create_screen.visible   = name == "char_create"
	_match_wait_screen.visible    = name == "match_wait"
	_hud.visible                  = name == "arena"
	_oracle_stream.visible        = name == "arena"
	_game_result_screen.visible   = name == "result"
	_spectate_list_screen.visible = name == "spectate_list"
	_match_history_screen.visible = name == "match_history"
	_match_detail_screen.visible  = name == "match_detail"
	_leaderboard_screen.visible   = name == "leaderboard"
	_update_debug_state(name)

func _update_debug_state(screen: String) -> void:
	if OS.has_feature("web"):
		var js := "window.gameDebug = window.gameDebug || {}; window.gameDebug.currentScreen = '%s'; window.gameDebug.ready = true;" % screen
		JavaScriptBridge.eval(js)

# ── Connection ────────────────────────────────────────────────────────────────

func _on_ws_connected() -> void:
	_update_conn_label(true)
	_notifs.show_notification("서버에 연결되었습니다")
	WebSocketClient.send({"type": "get_characters"})
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameDebug = window.gameDebug || {}; window.gameDebug.wsStatus = 'connected';")

func _on_ws_disconnected() -> void:
	_update_conn_label(false)
	_notifs.show_notification("연결이 끊어졌습니다. 재연결 중…")
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameDebug = window.gameDebug || {}; window.gameDebug.wsStatus = 'disconnected';")

func _on_ws_reconnect_failed() -> void:
	_update_conn_label(false)
	var dialog := AcceptDialog.new()
	dialog.title = "연결 실패"
	dialog.dialog_text = "서버와의 연결이 끊겼습니다.\n페이지를 새로고침하거나 잠시 후 다시 시도해 주세요."
	add_child(dialog)
	dialog.popup_centered()

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
	if _is_spectating:
		_oracle_stream.call("set_spectator_mode", true)
		_spectator_badge.visible = true
		_notifs.show_notification("경기 #%d 관전 시작" % match_id)
	else:
		_oracle_stream.call("set_spectator_mode", false)
		_spectator_badge.visible = false
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
	# Build rankings: winner first, then eliminated in reverse order (last out = 2nd, etc.)
	var rankings: Array = []
	# Winner row
	if winner_id >= 0:
		var winner_cls := "?"
		for c in GameState.characters:
			if c.get("id", -1) == winner_id:
				winner_cls = c.get("class", "?")
				break
		rankings.append({
			"name": winner_name,
			"class": winner_cls,
			"eliminated_turn": -1,
		})
	# Eliminated in reverse order (later deaths = better rank)
	var deaths := GameState.death_log.duplicate()
	deaths.reverse()
	for entry in deaths:
		rankings.append(entry)

	var result := {
		"winner_name": winner_name if winner_id >= 0 else "무승부",
		"rankings": rankings,
		"points_summary": {
			"oracle_spent": 100 - GameState.oracle_points,
			"participation_bonus": 50,
			"winner_bonus": 200 if winner_id >= 0 else 0
		}
	}
	# Spectators return to spectate list; participants see the result screen
	if _is_spectating:
		_is_spectating = false
		_spectator_badge.visible = false
		_oracle_stream.call("set_spectator_mode", false)
		_clear_char_nodes()
		_show_screen("spectate_list")
		_spectate_list_screen.call("fetch_matches")
		_notifs.show_notification("경기가 종료되었습니다. 목록으로 복귀합니다.")
		return

	_game_result_screen.call("show_result", result)
	_show_screen("result")
	_clear_char_nodes()

# ── Spectate ─────────────────────────────────────────────────────────────────

func _on_spectate_requested() -> void:
	_show_screen("spectate_list")
	_spectate_list_screen.call("fetch_matches")

func _on_spectate_back() -> void:
	_show_screen("char_list")

func _on_spectate_match_requested(match_id: int) -> void:
	_is_spectating = true
	WebSocketClient.send({"type": "spectate", "matchId": match_id})

# ── Match History ─────────────────────────────────────────────────────────────

func _on_history_requested() -> void:
	_show_screen("match_history")
	_match_history_screen.call("fetch_history")

func _on_match_history_back() -> void:
	_show_screen("char_list")

func _on_match_detail_requested(match_id: int) -> void:
	_match_detail_screen.call("load_match", match_id)
	_show_screen("match_detail")

func _on_match_detail_back() -> void:
	_show_screen("match_history")

# ── Leaderboard ───────────────────────────────────────────────────────────────

func _on_leaderboard_requested() -> void:
	_show_screen("leaderboard")

func _on_leaderboard_back() -> void:
	_show_screen("char_list")

func _check_auth() -> void:
	_http_auth = HTTPRequest.new()
	add_child(_http_auth)
	_http_auth.request_completed.connect(_on_auth_check_completed)

	var server_base := _get_server_http_base()
	var headers := ["Content-Type: application/json"]
	var err := _http_auth.request(server_base + "/auth/me", headers, HTTPClient.METHOD_GET)
	if err != OK:
		push_error("[Auth] HTTPRequest failed: %d" % err)
		_show_screen("login")

func _get_server_http_base() -> String:
	if OS.has_feature("web"):
		var ws_url: String = JavaScriptBridge.eval(
			"(function(){ return window.WS_URL || ''; })()"
		)
		if ws_url != "":
			var base := ws_url.replace("wss://", "https://").replace("ws://", "http://")
			return base.split("/ws")[0]
		var protocol: String = JavaScriptBridge.eval("window.location.protocol")
		var host: String     = JavaScriptBridge.eval("window.location.host")
		var scheme: String   = "https" if protocol == "https:" else "http"
		return "%s://%s" % [scheme, host]
	return "http://localhost:3000"

func _on_auth_check_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code == 401:
		_show_screen("login")
		return
	if response_code == 200:
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			GameState.current_user = json.data as Dictionary
		_show_screen("char_list")
	else:
		# 예상치 못한 상태 코드 — 로그인 화면으로 폴백
		_show_screen("login")

func _fetch_my_account_id() -> void:
	var server_url: String = OS.get_environment("SERVER_URL")
	if server_url.is_empty():
		server_url = "http://localhost:3000"
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_me_response)
	http.request(server_url + "/auth/me")

func _on_me_response(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if code == 200:
		var data = JSON.parse_string(body.get_string_from_utf8())
		_leaderboard_screen.my_account_id = data.get("id", -1)
		if not data.get("onboardingDone", true):
			_show_onboarding()
	else:
		_leaderboard_screen.my_account_id = -1

func _show_onboarding() -> void:
	var overlay := Control.new()
	overlay.set_script(ONBOARDING_SCRIPT)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.onboarding_completed.connect(func():
		_http_post_onboarding_done()
	)
	# Add to CanvasLayer (first child of this node)
	get_child(0).add_child(overlay)

func _http_post_onboarding_done() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
			fetch('/auth/onboarding-done', {method:'POST', credentials:'include'})
			  .catch(function() {
			    localStorage.setItem('onboardingDone', '1');
			  });
		""")
	else:
		var server_url: String = OS.get_environment("SERVER_URL")
		if server_url.is_empty():
			server_url = "http://localhost:3000"
		var http := HTTPRequest.new()
		add_child(http)
		http.request_completed.connect(func(_r, _c, _h, _b): http.queue_free())
		http.request(server_url + "/auth/onboarding-done", [], HTTPClient.METHOD_POST)

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
	for cid in _char_hud_cards.keys():
		_char_hud_cards[cid].queue_free()
	_char_hud_cards.clear()

# ── HUD ───────────────────────────────────────────────────────────────────────

func _refresh_hud() -> void:
	_pts_lbl.text = "신탁 포인트: %d" % GameState.oracle_points
	_pts_lbl.modulate = Color.WHITE if GameState.can_use_oracle() else Color(0.45, 0.45, 0.45)
	_alive_lbl.text = "생존: %d명" % GameState.alive_count
	_refresh_char_hud_strip()

func _refresh_char_hud_strip() -> void:
	var chars: Array = GameState.characters
	for char_data in chars:
		var cid: int = char_data.get("id", -1)
		if cid == -1:
			continue
		if not _char_hud_cards.has(cid):
			_char_hud_cards[cid] = _make_char_hud_card(char_data)
			_char_hud_strip.add_child(_char_hud_cards[cid])
		_update_char_hud_card(_char_hud_cards[cid], char_data)

func _make_char_hud_card(data: Dictionary) -> Control:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BG_CARD
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(80, 60)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(name_lbl)
	vbox.add_child(name_lbl)

	var hp_bar := ProgressBar.new()
	hp_bar.name = "HpBar"
	hp_bar.min_value = 0.0
	hp_bar.max_value = 1.0
	hp_bar.value = 1.0
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(70, 8)
	vbox.add_child(hp_bar)

	var class_lbl := Label.new()
	class_lbl.name = "ClassLabel"
	class_lbl.add_theme_font_size_override("font_size", 9)
	class_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_lbl.modulate = TEXT_SECONDARY
	_apply_font(class_lbl)
	vbox.add_child(class_lbl)

	return card

func _update_char_hud_card(card: Control, data: Dictionary) -> void:
	var is_alive: bool = data.get("is_alive", true)
	var hp: float = float(data.get("hp", 0))
	var max_hp: float = float(data.get("max_hp", 1))
	var ratio: float = hp / max_hp if max_hp > 0 else 0.0

	var name_lbl: Label = card.get_node("VBoxContainer/NameLabel")
	var hp_bar: ProgressBar = card.get_node("VBoxContainer/HpBar")
	var class_lbl: Label = card.get_node("VBoxContainer/ClassLabel")

	name_lbl.text = data.get("name", "?")
	class_lbl.text = data.get("class", "")

	hp_bar.value = ratio
	var bar_color: Color
	if ratio > 0.7:
		bar_color = Color(0.2, 0.85, 0.4)
	elif ratio > 0.3:
		bar_color = Color(1.0, 0.82, 0.2)
	else:
		bar_color = Color(0.9, 0.3, 0.3)

	var hp_style := StyleBoxFlat.new()
	hp_style.bg_color = bar_color
	hp_bar.add_theme_stylebox_override("fill", hp_style)

	card.modulate.a = 0.35 if not is_alive else 1.0

	var my_char_id: int = _selected_character.get("id", -1)
	if data.get("id", -1) == my_char_id:
		var border_style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
		border_style.border_color = Color(0.6, 0.4, 0.9)
		border_style.border_width_top = 2
		border_style.border_width_bottom = 2
		border_style.border_width_left = 2
		border_style.border_width_right = 2
		card.add_theme_stylebox_override("panel", border_style)

func _process(_delta: float) -> void:
	if _hud.visible:
		_refresh_hud()
