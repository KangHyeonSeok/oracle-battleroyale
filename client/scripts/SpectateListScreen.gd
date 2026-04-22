## SpectateListScreen.gd
## Lists active matches that can be spectated.
## Fetches GET /spectate, shows match cards, emits spectate_match_requested on selection.
extends Control

signal back_requested
signal spectate_match_requested(match_id: int)

const BG_BASE       := Color(0.071, 0.071, 0.133)
const BG_CARD       := Color(1, 1, 1, 0.06)
const BORDER_CARD   := Color(1, 1, 1, 0.12)
const ACCENT_GOLD   := Color(1.0, 0.843, 0.0)
const ACCENT_PURPLE := Color(0.545, 0.361, 0.965)
const TEXT_PRIMARY  := Color(1, 1, 1)
const TEXT_SECONDARY := Color(1, 1, 1, 0.6)

var _font: FontFile = null
var _card_container: VBoxContainer
var _empty_lbl: Label
var _error_lbl: Label
var _retry_btn: Button
var _http: HTTPRequest = null

func _ready() -> void:
	_font = ResourceLoader.load("res://fonts/NotoSansKR.ttf") as FontFile
	_build_ui()

func _apply_font(node: Control) -> void:
	if _font:
		node.add_theme_font_override("font", _font)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG_BASE
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	root.offset_left   = 16.0
	root.offset_top    = 16.0
	root.offset_right  = -16.0
	root.offset_bottom = -16.0
	add_child(root)

	# Top row: title + back button
	var top_row := HBoxContainer.new()
	root.add_child(top_row)

	var title := Label.new()
	title.text = "진행 중인 경기"
	title.modulate = ACCENT_GOLD
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(title)
	top_row.add_child(title)

	var back_btn := Button.new()
	back_btn.text = "돌아가기"
	back_btn.custom_minimum_size = Vector2(90, 36)
	back_btn.add_theme_font_size_override("font_size", 14)
	_apply_font(back_btn)
	back_btn.pressed.connect(func() -> void: back_requested.emit())
	top_row.add_child(back_btn)

	# Subtitle
	var sub := Label.new()
	sub.text = "경기를 선택하여 실시간으로 관전하세요"
	sub.modulate = TEXT_SECONDARY
	sub.add_theme_font_size_override("font_size", 13)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(sub)
	root.add_child(sub)

	# Error label + retry (hidden by default)
	_error_lbl = Label.new()
	_error_lbl.text = "경기 목록을 불러오지 못했습니다."
	_error_lbl.modulate = Color(0.93, 0.27, 0.27)
	_error_lbl.add_theme_font_size_override("font_size", 14)
	_error_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_lbl.visible = false
	_apply_font(_error_lbl)
	root.add_child(_error_lbl)

	_retry_btn = Button.new()
	_retry_btn.text = "다시 시도"
	_retry_btn.custom_minimum_size = Vector2(100, 36)
	_retry_btn.visible = false
	_apply_font(_retry_btn)
	_retry_btn.pressed.connect(func() -> void: fetch_matches())
	root.add_child(_retry_btn)

	# Scroll area for match cards
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_card_container = VBoxContainer.new()
	_card_container.add_theme_constant_override("separation", 10)
	_card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_card_container)

	_empty_lbl = Label.new()
	_empty_lbl.text = "현재 진행 중인 경기가 없습니다."
	_empty_lbl.modulate = TEXT_SECONDARY
	_empty_lbl.add_theme_font_size_override("font_size", 14)
	_empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_lbl.visible = false
	_apply_font(_empty_lbl)
	_card_container.add_child(_empty_lbl)

## Called by Main.gd when this screen becomes visible.
func fetch_matches() -> void:
	_error_lbl.visible = false
	_retry_btn.visible = false
	_clear_cards()

	if _http != null:
		_http.queue_free()
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

	var url := _get_api_url() + "/spectate"
	var err := _http.request(url, [], HTTPClient.METHOD_GET)
	if err != OK:
		_show_error()

func _get_api_url() -> String:
	# Derive HTTP base URL from the WebSocket URL (strip /ws suffix, replace scheme)
	var ws_url: String = WebSocketClient.url
	return ws_url.replace("wss://", "https://").replace("ws://", "http://").replace("/ws", "")

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _http != null:
		_http.queue_free()
		_http = null

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_show_error()
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	if data == null or not data.has("matches"):
		_show_error()
		return

	_refresh_list(data.get("matches", []))

func _show_error() -> void:
	_error_lbl.visible = true
	_retry_btn.visible = true
	_empty_lbl.visible = false

func _refresh_list(matches: Array) -> void:
	_clear_cards()
	_empty_lbl.visible = matches.is_empty()
	for match_data in matches:
		_card_container.add_child(_make_card(match_data))

func _clear_cards() -> void:
	for child in _card_container.get_children():
		if child != _empty_lbl:
			child.queue_free()

func _make_card(data: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 70)

	var style := StyleBoxFlat.new()
	style.bg_color = BG_CARD
	style.corner_radius_top_left     = 12
	style.corner_radius_top_right    = 12
	style.corner_radius_bottom_left  = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_color = BORDER_CARD
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	# Info column
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	hbox.add_child(info)

	var match_id: int = data.get("matchId", -1)
	var started_at: String = data.get("startedAt", "")
	var participant_count: int = data.get("participantCount", 0)
	var turn_count: int = data.get("turnCount", 0)
	var spectator_count: int = data.get("spectatorCount", 0)

	var title_lbl := Label.new()
	title_lbl.text = "경기 #%d" % match_id
	title_lbl.modulate = TEXT_PRIMARY
	title_lbl.add_theme_font_size_override("font_size", 16)
	_apply_font(title_lbl)
	info.add_child(title_lbl)

	var stats_lbl := Label.new()
	stats_lbl.text = "참가자 %d명  ·  턴 %d  ·  관전자 %d명" % [participant_count, turn_count, spectator_count]
	stats_lbl.modulate = TEXT_SECONDARY
	stats_lbl.add_theme_font_size_override("font_size", 12)
	_apply_font(stats_lbl)
	info.add_child(stats_lbl)

	if not started_at.is_empty():
		var time_lbl := Label.new()
		time_lbl.text = "시작: " + started_at.left(19).replace("T", " ")
		time_lbl.modulate = TEXT_SECONDARY
		time_lbl.add_theme_font_size_override("font_size", 11)
		_apply_font(time_lbl)
		info.add_child(time_lbl)

	# Watch button
	var watch_btn := Button.new()
	watch_btn.text = "관전"
	watch_btn.custom_minimum_size = Vector2(70, 0)
	watch_btn.modulate = ACCENT_GOLD
	_apply_font(watch_btn)
	watch_btn.pressed.connect(func() -> void: spectate_match_requested.emit(match_id))
	hbox.add_child(watch_btn)

	return card
