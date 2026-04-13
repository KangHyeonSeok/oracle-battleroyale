## LeaderboardScreen.gd
## Displays top 20 players ranked by oracle (constellation) points.
## Accessible from CharacterListScreen; "돌아가기" returns there.
extends Control

signal back_requested

const BG_BASE       := Color(0.071, 0.071, 0.133)
const BG_CARD       := Color(1, 1, 1, 0.06)
const BORDER_CARD   := Color(1, 1, 1, 0.12)
const ACCENT_GOLD   := Color(1.0, 0.843, 0.0)
const ACCENT_PURPLE := Color(0.545, 0.361, 0.965)
const TEXT_PRIMARY  := Color(1, 1, 1)
const TEXT_SECONDARY := Color(1, 1, 1, 0.6)

## Set this before showing the screen so the player's own row can be highlighted.
var my_account_id: int = -1

var _font: FontFile = null
var _card_container: VBoxContainer
var _loading_lbl: Label

func _ready() -> void:
	_font = ResourceLoader.load("res://fonts/NotoSansKR.ttf") as FontFile
	_build_ui()
	_fetch_leaderboard()

func _apply_font(node: Control) -> void:
	if _font:
		node.add_theme_font_override("font", _font)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG_BASE
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	root.offset_left   = 20.0
	root.offset_top    = 20.0
	root.offset_right  = -20.0
	root.offset_bottom = -20.0
	add_child(root)

	# Header
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	root.add_child(header)

	var title := Label.new()
	title.text = "성좌 랭킹"
	title.modulate = TEXT_PRIMARY
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(title)
	header.add_child(title)

	# accent-gold underline
	var line := ColorRect.new()
	line.color = ACCENT_GOLD
	line.custom_minimum_size = Vector2(0, 2)
	header.add_child(line)

	# Column headings
	var headings := HBoxContainer.new()
	headings.add_theme_constant_override("separation", 8)
	root.add_child(headings)

	for col in ["순위", "성좌명", "포인트", "승률", "신탁"]:
		var lbl := Label.new()
		lbl.text = col
		lbl.modulate = TEXT_SECONDARY
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_apply_font(lbl)
		headings.add_child(lbl)

	# Scroll container for cards
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_card_container = VBoxContainer.new()
	_card_container.add_theme_constant_override("separation", 6)
	_card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_card_container)

	_loading_lbl = Label.new()
	_loading_lbl.text = "불러오는 중…"
	_loading_lbl.modulate = TEXT_SECONDARY
	_loading_lbl.add_theme_font_size_override("font_size", 14)
	_loading_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(_loading_lbl)
	_card_container.add_child(_loading_lbl)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "돌아가기"
	back_btn.custom_minimum_size = Vector2(0, 44)
	back_btn.add_theme_font_size_override("font_size", 15)
	_apply_font(back_btn)
	back_btn.pressed.connect(func() -> void: back_requested.emit())
	root.add_child(back_btn)

func _fetch_leaderboard() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_leaderboard_response)
	var server_url: String = OS.get_environment("SERVER_URL")
	if server_url.is_empty():
		server_url = "http://localhost:3000"
	http.request(server_url + "/leaderboard")

func _on_leaderboard_response(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if code != 200:
		_loading_lbl.text = "랭킹을 불러오지 못했습니다 (HTTP %d)" % code
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("entries"):
		_loading_lbl.text = "응답 형식이 올바르지 않습니다"
		return

	_render_entries(parsed["entries"] as Array)

func _render_entries(entries: Array) -> void:
	# Remove loading label
	_loading_lbl.queue_free()

	if entries.is_empty():
		var empty := Label.new()
		empty.text = "아직 랭킹 데이터가 없습니다"
		empty.modulate = TEXT_SECONDARY
		empty.add_theme_font_size_override("font_size", 14)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_apply_font(empty)
		_card_container.add_child(empty)
		return

	for entry in entries:
		_card_container.add_child(_make_card(entry as Dictionary))

func _make_card(entry: Dictionary) -> Control:
	var rank: int = entry.get("rank", 0)
	var is_mine: bool = entry.get("accountId", -1) == my_account_id
	var is_top3: bool = rank <= 3

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 52)

	var style := StyleBoxFlat.new()
	if is_top3:
		style.bg_color = Color(ACCENT_GOLD, 0.12)
		style.border_color = ACCENT_GOLD
	elif is_mine:
		style.bg_color = Color(ACCENT_PURPLE, 0.12)
		style.border_color = ACCENT_PURPLE
	else:
		style.bg_color = BG_CARD
		style.border_color = BORDER_CARD
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left   = 2 if (is_top3 or is_mine) else 1
	style.border_width_right  = 2 if (is_top3 or is_mine) else 1
	style.border_width_top    = 2 if (is_top3 or is_mine) else 1
	style.border_width_bottom = 2 if (is_top3 or is_mine) else 1
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	card.add_child(hbox)

	# Rank badge / number
	var rank_lbl := Label.new()
	if is_top3:
		rank_lbl.text = ["🥇", "🥈", "🥉"][rank - 1]
		rank_lbl.add_theme_font_size_override("font_size", 20)
	else:
		rank_lbl.text = str(rank)
		rank_lbl.modulate = TEXT_SECONDARY
		rank_lbl.add_theme_font_size_override("font_size", 14)
	rank_lbl.custom_minimum_size = Vector2(36, 0)
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_font(rank_lbl)
	hbox.add_child(rank_lbl)

	# Display name
	var name_lbl := Label.new()
	name_lbl.text = entry.get("displayName", "알 수 없음")
	name_lbl.modulate = ACCENT_GOLD if is_top3 else TEXT_PRIMARY
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(name_lbl)
	hbox.add_child(name_lbl)

	# Points
	var pts_lbl := Label.new()
	pts_lbl.text = str(entry.get("oraclePoints", 0))
	pts_lbl.modulate = ACCENT_GOLD
	pts_lbl.add_theme_font_size_override("font_size", 14)
	pts_lbl.custom_minimum_size = Vector2(60, 0)
	pts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(pts_lbl)
	hbox.add_child(pts_lbl)

	# Win rate
	var wr_lbl := Label.new()
	wr_lbl.text = "%d%%" % entry.get("winRate", 0)
	wr_lbl.modulate = TEXT_SECONDARY
	wr_lbl.add_theme_font_size_override("font_size", 13)
	wr_lbl.custom_minimum_size = Vector2(52, 0)
	wr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(wr_lbl)
	hbox.add_child(wr_lbl)

	# Oracle sent count
	var oracle_lbl := Label.new()
	oracle_lbl.text = str(entry.get("oracleSent", 0))
	oracle_lbl.modulate = TEXT_SECONDARY
	oracle_lbl.add_theme_font_size_override("font_size", 13)
	oracle_lbl.custom_minimum_size = Vector2(44, 0)
	oracle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(oracle_lbl)
	hbox.add_child(oracle_lbl)

	return card
