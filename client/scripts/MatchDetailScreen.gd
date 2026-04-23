## MatchDetailScreen.gd
## Shows detail for a single completed match:
##   left panel — participants ranking table
##   right panel — oracle feed
## Signal: back_requested → MatchHistoryScreen
## Method: load_match(match_id: int) — fetches and renders detail
extends Control

signal back_requested

const BG_BASE        := Color(0.071, 0.071, 0.133)
const BG_CARD        := Color(1, 1, 1, 0.06)
const BORDER_CARD    := Color(1, 1, 1, 0.12)
const ACCENT_GOLD    := Color(1.0, 0.843, 0.0)
const ACCENT_PURPLE  := Color(0.545, 0.361, 0.965)
const TEXT_PRIMARY   := Color(1, 1, 1)
const TEXT_SECONDARY := Color(1, 1, 1, 0.6)
const DANGER         := Color(0.937, 0.267, 0.267)

var _font: FontFile = null

# UI references built in _build_ui
var _date_lbl:         Label
var _error_lbl:        Label
var _participants_box: VBoxContainer
var _oracle_box:       VBoxContainer
var _oracle_header:    Label
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
	root.add_theme_constant_override("separation", 10)
	root.offset_left   = 16.0
	root.offset_top    = 16.0
	root.offset_right  = -16.0
	root.offset_bottom = -16.0
	add_child(root)

	# Top row: date + back button
	var top_row := HBoxContainer.new()
	root.add_child(top_row)

	_date_lbl = Label.new()
	_date_lbl.text = "경기 상세"
	_date_lbl.modulate = ACCENT_GOLD
	_date_lbl.add_theme_font_size_override("font_size", 20)
	_date_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(_date_lbl)
	top_row.add_child(_date_lbl)

	var back_btn := Button.new()
	back_btn.text = "돌아가기"
	back_btn.custom_minimum_size = Vector2(90, 36)
	back_btn.add_theme_font_size_override("font_size", 14)
	_apply_font(back_btn)
	back_btn.pressed.connect(func() -> void: back_requested.emit())
	top_row.add_child(back_btn)

	# Error label
	_error_lbl = Label.new()
	_error_lbl.text = "경기 정보를 불러오지 못했습니다."
	_error_lbl.modulate = DANGER
	_error_lbl.add_theme_font_size_override("font_size", 14)
	_error_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_lbl.visible = false
	_apply_font(_error_lbl)
	root.add_child(_error_lbl)

	# Two-panel row: participants (left) + oracle feed (right)
	var panels := HBoxContainer.new()
	panels.add_theme_constant_override("separation", 12)
	panels.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(panels)

	# Left panel — participants
	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_stretch_ratio = 1.0
	panels.add_child(left_scroll)

	var left_wrap := VBoxContainer.new()
	left_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_wrap.add_theme_constant_override("separation", 4)
	left_scroll.add_child(left_wrap)

	var part_title := Label.new()
	part_title.text = "참가자 순위"
	part_title.modulate = ACCENT_GOLD
	part_title.add_theme_font_size_override("font_size", 15)
	_apply_font(part_title)
	left_wrap.add_child(part_title)

	_participants_box = VBoxContainer.new()
	_participants_box.add_theme_constant_override("separation", 4)
	_participants_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_wrap.add_child(_participants_box)

	# Right panel — oracle feed
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_stretch_ratio = 1.5
	panels.add_child(right_scroll)

	var right_wrap := VBoxContainer.new()
	right_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_wrap.add_theme_constant_override("separation", 4)
	right_scroll.add_child(right_wrap)

	_oracle_header = Label.new()
	_oracle_header.text = "신탁 피드"
	_oracle_header.modulate = ACCENT_GOLD
	_oracle_header.add_theme_font_size_override("font_size", 15)
	_apply_font(_oracle_header)
	right_wrap.add_child(_oracle_header)

	_oracle_box = VBoxContainer.new()
	_oracle_box.add_theme_constant_override("separation", 6)
	_oracle_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_wrap.add_child(_oracle_box)

## Called by Main.gd before switching to this screen.
func load_match(match_id: int) -> void:
	_error_lbl.visible = false
	_date_lbl.text     = "경기 상세"
	_oracle_header.text = "신탁 피드"
	_clear_panels()

	if _http != null:
		_http.queue_free()
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

	var url := _get_api_url() + "/history/%d" % match_id
	var err := _http.request(url, [], HTTPClient.METHOD_GET)
	if err != OK:
		_show_error("경기 정보를 불러오지 못했습니다.")

func _get_api_url() -> String:
	var ws_url: String = WebSocketClient.url
	return ws_url.replace("wss://", "https://").replace("ws://", "http://").replace("/ws", "")

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _http != null:
		_http.queue_free()
		_http = null

	if result != HTTPRequest.RESULT_SUCCESS:
		_show_error("경기 정보를 불러오지 못했습니다.")
		return

	if response_code == 403 or response_code == 404:
		_show_error("접근할 수 없는 경기입니다.")
		return

	if response_code != 200:
		_show_error("경기 정보를 불러오지 못했습니다.")
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	if data == null:
		_show_error("경기 정보를 불러오지 못했습니다.")
		return

	_render(data)

func _show_error(msg: String) -> void:
	_error_lbl.text = msg
	_error_lbl.visible = true
	# Return to history after brief display (user clicks back)

func _clear_panels() -> void:
	for child in _participants_box.get_children():
		child.queue_free()
	for child in _oracle_box.get_children():
		child.queue_free()

func _render(data: Dictionary) -> void:
	# Update date label
	var ended_at: String = data.get("endedAt", "")
	if not ended_at.is_empty():
		_date_lbl.text = "경기 — " + ended_at.left(19).replace("T", " ")

	# Participants
	var participants: Array = data.get("participants", [])
	for p in participants:
		_participants_box.add_child(_make_participant_row(p))

	# Oracle feed
	var oracles: Array = data.get("oracles", [])
	var oracle_count: int = data.get("oracleCount", 0)

	# Update oracle header with total count
	_oracle_header.text = "신탁 피드 (총 %d건)" % oracle_count
	if oracle_count > oracles.size() and oracles.size() > 0:
		var notice_lbl := Label.new()
		notice_lbl.text = "총 %d건 중 최근 %d건 표시" % [oracle_count, oracles.size()]
		notice_lbl.modulate = TEXT_SECONDARY
		notice_lbl.add_theme_font_size_override("font_size", 11)
		notice_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_apply_font(notice_lbl)
		_oracle_box.add_child(notice_lbl)

	if oracles.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "이 경기에서 신탁이 사용되지 않았습니다"
		empty_lbl.modulate = TEXT_SECONDARY
		empty_lbl.add_theme_font_size_override("font_size", 13)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_apply_font(empty_lbl)
		_oracle_box.add_child(empty_lbl)
	else:
		for o in oracles:
			_oracle_box.add_child(_make_oracle_card(o))

func _make_participant_row(p: Dictionary) -> Control:
	var rank: int       = p.get("rank", 0)
	var is_npc: bool    = p.get("isNpc", false)
	var is_me: bool     = p.get("isMe", false)
	var char_name: String = p.get("characterName", "?")
	var cls: String       = (p.get("class", "") as String).capitalize()

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 32)

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	# AC5: my row = accent-purple, rank-1 row = accent-gold highlight
	if is_me:
		style.bg_color = Color(ACCENT_PURPLE, 0.2)
	elif rank == 1:
		style.bg_color = Color(ACCENT_GOLD, 0.15)
	else:
		style.bg_color = BG_CARD
	row.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)

	var rank_lbl := Label.new()
	rank_lbl.text = "%d위" % rank if rank > 0 else "?위"
	rank_lbl.modulate = ACCENT_GOLD if rank == 1 else TEXT_PRIMARY
	rank_lbl.add_theme_font_size_override("font_size", 13)
	rank_lbl.custom_minimum_size = Vector2(36, 0)
	_apply_font(rank_lbl)
	hbox.add_child(rank_lbl)

	var name_lbl := Label.new()
	var display: String = char_name
	if cls.length() > 0:
		display += " (%s)" % cls
	if is_npc:
		display += " [NPC]"
	if is_me:
		display += " ★"
	name_lbl.text = display
	name_lbl.modulate = ACCENT_PURPLE if is_me else TEXT_PRIMARY
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(name_lbl)
	hbox.add_child(name_lbl)

	return row

func _make_oracle_card(o: Dictionary) -> Control:
	var is_me: bool        = o.get("isMe", false)
	var sender: String     = o.get("senderName", "?")
	var content: String    = o.get("content", "")
	var result_str: String = o.get("actionResult", "")
	var sent_at: String    = o.get("sentAt", "")
	var credulity          = o.get("credulity", null)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 50)

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	# AC8: isMe messages get accent-purple background
	style.bg_color = Color(ACCENT_PURPLE, 0.18) if is_me else BG_CARD
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	# Header row: sender + time + credulity
	var header_row := HBoxContainer.new()
	vbox.add_child(header_row)

	var sender_lbl := Label.new()
	var me_mark: String = " (나)" if is_me else ""
	sender_lbl.text = sender + me_mark
	sender_lbl.modulate = ACCENT_PURPLE if is_me else TEXT_SECONDARY
	sender_lbl.add_theme_font_size_override("font_size", 11)
	sender_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(sender_lbl)
	header_row.add_child(sender_lbl)

	if credulity != null:
		var cred_lbl := Label.new()
		cred_lbl.text = "신뢰도 %.0f%%" % (float(credulity) * 100.0)
		cred_lbl.modulate = TEXT_SECONDARY
		cred_lbl.add_theme_font_size_override("font_size", 11)
		_apply_font(cred_lbl)
		header_row.add_child(cred_lbl)

	if not sent_at.is_empty():
		var time_lbl := Label.new()
		time_lbl.text = sent_at.left(19).replace("T", " ").right(8)
		time_lbl.modulate = TEXT_SECONDARY
		time_lbl.add_theme_font_size_override("font_size", 11)
		_apply_font(time_lbl)
		header_row.add_child(time_lbl)

	# Content
	var content_lbl := Label.new()
	content_lbl.text = content
	content_lbl.modulate = TEXT_PRIMARY
	content_lbl.add_theme_font_size_override("font_size", 13)
	content_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(content_lbl)
	vbox.add_child(content_lbl)

	# Action result
	if not result_str.is_empty():
		var result_lbl := Label.new()
		result_lbl.text = "→ " + result_str
		result_lbl.modulate = TEXT_SECONDARY
		result_lbl.add_theme_font_size_override("font_size", 11)
		result_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_apply_font(result_lbl)
		vbox.add_child(result_lbl)

	return card
