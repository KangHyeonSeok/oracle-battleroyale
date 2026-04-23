## MatchHistoryScreen.gd
## Shows paginated list of the player's completed matches.
## Signals: back_requested → CharacterListScreen
##          detail_requested(match_id) → MatchDetailScreen
extends Control

signal back_requested
signal detail_requested(match_id: int)

const BG_BASE        := Color(0.071, 0.071, 0.133)
const BG_CARD        := Color(1, 1, 1, 0.06)
const BORDER_CARD    := Color(1, 1, 1, 0.12)
const ACCENT_GOLD    := Color(1.0, 0.843, 0.0)
const ACCENT_PURPLE  := Color(0.545, 0.361, 0.965)
const TEXT_PRIMARY   := Color(1, 1, 1)
const TEXT_SECONDARY := Color(1, 1, 1, 0.6)
const DANGER         := Color(0.937, 0.267, 0.267)

var _font: FontFile = null
var _card_container: VBoxContainer
var _empty_lbl: Label
var _error_lbl: Label
var _more_btn: Button
var _http: HTTPRequest = null

var _offset: int = 0
var _total:  int = 0
const PAGE_SIZE := 20

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
	title.text = "내 경기 기록"
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

	# Error label (hidden by default)
	_error_lbl = Label.new()
	_error_lbl.text = "경기 기록을 불러오지 못했습니다."
	_error_lbl.modulate = DANGER
	_error_lbl.add_theme_font_size_override("font_size", 14)
	_error_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_lbl.visible = false
	_apply_font(_error_lbl)
	root.add_child(_error_lbl)

	# Scroll area
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_card_container = VBoxContainer.new()
	_card_container.add_theme_constant_override("separation", 10)
	_card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_card_container)

	_empty_lbl = Label.new()
	_empty_lbl.text = "아직 경기 기록이 없습니다."
	_empty_lbl.modulate = TEXT_SECONDARY
	_empty_lbl.add_theme_font_size_override("font_size", 14)
	_empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_lbl.visible = false
	_apply_font(_empty_lbl)
	_card_container.add_child(_empty_lbl)

	# More button (load next page)
	_more_btn = Button.new()
	_more_btn.text = "더 보기"
	_more_btn.custom_minimum_size = Vector2(0, 40)
	_more_btn.add_theme_font_size_override("font_size", 14)
	_more_btn.modulate = ACCENT_PURPLE
	_more_btn.visible = false
	_apply_font(_more_btn)
	_more_btn.pressed.connect(_on_more_pressed)
	root.add_child(_more_btn)

## Called when this screen becomes visible (from Main.gd).
func fetch_history() -> void:
	_offset = 0
	_total  = 0
	_clear_cards()
	_error_lbl.visible = false
	_more_btn.visible  = false
	_empty_lbl.visible = false
	_load_page()

func _on_more_pressed() -> void:
	_more_btn.disabled = true
	_load_page()

func _load_page() -> void:
	if _http != null:
		_http.queue_free()
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

	var url := _get_api_url() + "/history?limit=%d&offset=%d" % [PAGE_SIZE, _offset]
	var err := _http.request(url, [], HTTPClient.METHOD_GET)
	if err != OK:
		_show_error()

func _get_api_url() -> String:
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

	_total = data.get("total", 0)
	var matches: Array = data.get("matches", [])

	if _offset == 0 and matches.is_empty():
		_empty_lbl.visible = true
		_more_btn.visible  = false
		return

	for match_data in matches:
		_card_container.add_child(_make_card(match_data))

	_offset += matches.size()
	_more_btn.disabled = false
	_more_btn.visible  = _offset < _total

func _show_error() -> void:
	_error_lbl.visible  = true
	_more_btn.disabled  = false
	_more_btn.visible   = false

func _clear_cards() -> void:
	for child in _card_container.get_children():
		if child != _empty_lbl:
			child.queue_free()

func _make_card(data: Dictionary) -> Control:
	var my_rank: int = data.get("myRank", 0)
	var is_winner: bool = my_rank == 1

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 72)

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
	# AC5: 1등 달성 카드는 accent-gold 세로바
	if is_winner:
		style.border_width_left = 4
		style.border_color = ACCENT_GOLD
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	# Info
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	hbox.add_child(info)

	# Date
	var ended_at: String = data.get("endedAt", "")
	var date_str: String = ended_at.left(10) if not ended_at.is_empty() else "날짜 없음"
	var date_lbl := Label.new()
	date_lbl.text = date_str
	date_lbl.modulate = TEXT_SECONDARY
	date_lbl.add_theme_font_size_override("font_size", 11)
	_apply_font(date_lbl)
	info.add_child(date_lbl)

	# My character + rank
	var my_char: Dictionary  = data.get("myCharacter", {})
	var char_name: String    = my_char.get("name",  "알 수 없음")
	var char_class: String   = (my_char.get("class", "") as String).capitalize()
	var participant_count: int = data.get("participantCount", 0)
	var rank_lbl := Label.new()
	rank_lbl.text = "%s (%s)  —  %d위 / %d명" % [char_name, char_class, my_rank, participant_count]
	rank_lbl.modulate = TEXT_PRIMARY
	rank_lbl.add_theme_font_size_override("font_size", 14)
	_apply_font(rank_lbl)
	info.add_child(rank_lbl)

	# Winner + oracle count
	var winner: Dictionary = data.get("winner", {})
	var winner_str: String
	if winner == null or winner.is_empty():
		winner_str = "우승자 없음"
	else:
		winner_str = "우승: %s (%s)" % [winner.get("name", "?"), (winner.get("class", "") as String).capitalize()]
	var oracle_count: int = data.get("oracleSentCount", 0)
	var sub_lbl := Label.new()
	sub_lbl.text = "%s  ·  신탁 %d회" % [winner_str, oracle_count]
	sub_lbl.modulate = TEXT_SECONDARY
	sub_lbl.add_theme_font_size_override("font_size", 12)
	_apply_font(sub_lbl)
	info.add_child(sub_lbl)

	# Make entire card clickable
	var btn := Button.new()
	btn.flat = true
	btn.text = "상세"
	btn.custom_minimum_size = Vector2(60, 0)
	btn.modulate = ACCENT_PURPLE
	_apply_font(btn)
	var match_id: int = data.get("matchId", -1)
	btn.pressed.connect(func() -> void: detail_requested.emit(match_id))
	hbox.add_child(btn)

	return card
