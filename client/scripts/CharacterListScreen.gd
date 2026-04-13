## CharacterListScreen.gd
## Shows player's saved constellation characters.
## Emits signals to navigate to CharacterCreate or MatchWaiting.
extends Control

signal create_character_requested
signal join_match_requested(character_id: int)
signal leaderboard_requested
signal spectate_requested

const BG_BASE      := Color(0.071, 0.071, 0.133)
const BG_CARD      := Color(1, 1, 1, 0.06)
const BORDER_CARD  := Color(1, 1, 1, 0.12)
const ACCENT_GOLD  := Color(1.0, 0.843, 0.0)
const ACCENT_PURPLE := Color(0.545, 0.361, 0.965)
const TEXT_PRIMARY := Color(1, 1, 1)
const TEXT_SECONDARY := Color(1, 1, 1, 0.6)
const SUCCESS      := Color(0.063, 0.725, 0.506)
const DANGER       := Color(0.937, 0.267, 0.267)

var _font: FontFile = null
var _card_container: VBoxContainer
var _empty_lbl: Label

func _ready() -> void:
	_font = ResourceLoader.load("res://fonts/NotoSansKR.ttf") as FontFile
	_build_ui()

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
	root.offset_left   = 16.0
	root.offset_top    = 16.0
	root.offset_right  = -16.0
	root.offset_bottom = -16.0
	add_child(root)

	# Top row: title + ranking button
	var top_row := HBoxContainer.new()
	root.add_child(top_row)

	var title := Label.new()
	title.text = "나의 성좌"
	title.modulate = ACCENT_GOLD
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(title)
	top_row.add_child(title)

	var rank_btn := Button.new()
	rank_btn.text = "랭킹 🏆"
	rank_btn.custom_minimum_size = Vector2(90, 36)
	rank_btn.add_theme_font_size_override("font_size", 14)
	rank_btn.modulate = ACCENT_PURPLE
	_apply_font(rank_btn)
	rank_btn.pressed.connect(func() -> void: leaderboard_requested.emit())
	top_row.add_child(rank_btn)

	var spectate_btn := Button.new()
	spectate_btn.text = "관전하기 👁"
	spectate_btn.custom_minimum_size = Vector2(110, 36)
	spectate_btn.add_theme_font_size_override("font_size", 14)
	spectate_btn.modulate = ACCENT_PURPLE
	_apply_font(spectate_btn)
	spectate_btn.pressed.connect(func() -> void: spectate_requested.emit())
	top_row.add_child(spectate_btn)

	# Subtitle
	var sub := Label.new()
	sub.text = "출전할 성좌를 선택하거나 새 성좌를 만드세요"
	sub.modulate = TEXT_SECONDARY
	sub.add_theme_font_size_override("font_size", 13)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(sub)
	root.add_child(sub)

	# Scroll area for cards
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_card_container = VBoxContainer.new()
	_card_container.add_theme_constant_override("separation", 10)
	_card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_card_container)

	_empty_lbl = Label.new()
	_empty_lbl.text = "아직 성좌가 없습니다. 새 성좌를 만들어보세요!"
	_empty_lbl.modulate = TEXT_SECONDARY
	_empty_lbl.add_theme_font_size_override("font_size", 14)
	_empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_lbl.visible = false
	_apply_font(_empty_lbl)
	_card_container.add_child(_empty_lbl)

	# Bottom button
	var create_btn := Button.new()
	create_btn.text = "+ 새 성좌 만들기"
	create_btn.custom_minimum_size = Vector2(0, 44)
	create_btn.modulate = ACCENT_GOLD
	create_btn.add_theme_font_size_override("font_size", 16)
	_apply_font(create_btn)
	create_btn.pressed.connect(func() -> void: create_character_requested.emit())
	root.add_child(create_btn)

func refresh(chars: Array) -> void:
	# Clear existing cards (keep _empty_lbl)
	for child in _card_container.get_children():
		if child != _empty_lbl:
			child.queue_free()

	_empty_lbl.visible = chars.is_empty()

	for data in chars:
		_card_container.add_child(_make_card(data))

func _make_card(data: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 80)

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

	var name_lbl := Label.new()
	name_lbl.text = data.get("name", "알 수 없음")
	name_lbl.modulate = TEXT_PRIMARY
	name_lbl.add_theme_font_size_override("font_size", 16)
	_apply_font(name_lbl)
	info.add_child(name_lbl)

	var cls_str: String = (data.get("class", "?") as String).capitalize()
	var stats_lbl := Label.new()
	stats_lbl.text = "[%s]  HP:%d  ATK:%d  DEF:%d" % [
		cls_str,
		data.get("hp", 0),
		data.get("atk", 0),
		data.get("def", 0)
	]
	stats_lbl.modulate = TEXT_SECONDARY
	stats_lbl.add_theme_font_size_override("font_size", 13)
	_apply_font(stats_lbl)
	info.add_child(stats_lbl)

	var rate := data.get("win_rate", 0.0) as float
	var rate_lbl := Label.new()
	rate_lbl.text = "승률 %.0f%%" % (rate * 100.0)
	rate_lbl.modulate = SUCCESS
	rate_lbl.add_theme_font_size_override("font_size", 12)
	_apply_font(rate_lbl)
	info.add_child(rate_lbl)

	# Join button
	var join_btn := Button.new()
	join_btn.text = "경기 참가"
	join_btn.custom_minimum_size = Vector2(80, 0)
	join_btn.modulate = ACCENT_GOLD
	_apply_font(join_btn)
	var cid: int = data.get("id", -1)
	join_btn.pressed.connect(func() -> void: join_match_requested.emit(cid))
	hbox.add_child(join_btn)

	return card
