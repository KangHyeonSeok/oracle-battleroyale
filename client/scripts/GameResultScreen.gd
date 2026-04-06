## GameResultScreen.gd
## Displays end-of-game results: winner, rankings, and points summary.
extends Control

signal play_again_requested
signal main_menu_requested

const GOLD   := Color(1.0, 0.85, 0.0)
const BG     := Color(0.07, 0.07, 0.14)
const PURPLE := Color(0.55, 0.36, 0.96)
const SILVER := Color(0.75, 0.75, 0.80)
const BRONZE := Color(0.80, 0.50, 0.20)

var _font: FontFile = null

var _winner_lbl:     Label
var _rank_container: VBoxContainer
var _pts_lbl:        Label

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
	bg.color = BG
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)
	root.offset_left   = 24.0
	root.offset_top    = 24.0
	root.offset_right  = -24.0
	root.offset_bottom = -24.0
	add_child(root)

	# Winner section
	var winner_panel := PanelContainer.new()
	var winner_style := StyleBoxFlat.new()
	winner_style.bg_color = Color(0.12, 0.10, 0.04)
	winner_style.corner_radius_top_left     = 10
	winner_style.corner_radius_top_right    = 10
	winner_style.corner_radius_bottom_left  = 10
	winner_style.corner_radius_bottom_right = 10
	winner_style.border_width_left   = 2
	winner_style.border_width_right  = 2
	winner_style.border_width_top    = 2
	winner_style.border_width_bottom = 2
	winner_style.border_color = GOLD
	winner_panel.add_theme_stylebox_override("panel", winner_style)
	root.add_child(winner_panel)

	var winner_vbox := VBoxContainer.new()
	winner_vbox.add_theme_constant_override("separation", 6)
	winner_panel.add_child(winner_vbox)

	var crown_lbl := Label.new()
	crown_lbl.text = "★  경기 종료  ★"
	crown_lbl.modulate = GOLD
	crown_lbl.add_theme_font_size_override("font_size", 14)
	crown_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(crown_lbl)
	winner_vbox.add_child(crown_lbl)

	_winner_lbl = Label.new()
	_winner_lbl.text = "..."
	_winner_lbl.modulate = GOLD
	_winner_lbl.add_theme_font_size_override("font_size", 28)
	_winner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(_winner_lbl)
	winner_vbox.add_child(_winner_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "우승!"
	sub_lbl.modulate = Color(1.0, 0.95, 0.5)
	sub_lbl.add_theme_font_size_override("font_size", 16)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(sub_lbl)
	winner_vbox.add_child(sub_lbl)

	# Rankings
	var rank_title := Label.new()
	rank_title.text = "순위표"
	rank_title.modulate = Color(0.8, 0.8, 1.0)
	rank_title.add_theme_font_size_override("font_size", 16)
	_apply_font(rank_title)
	root.add_child(rank_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_rank_container = VBoxContainer.new()
	_rank_container.add_theme_constant_override("separation", 6)
	_rank_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rank_container)

	# Points summary
	_pts_lbl = Label.new()
	_pts_lbl.text = "신탁 포인트: 계산 중..."
	_pts_lbl.modulate = Color(0.7, 0.9, 0.7)
	_pts_lbl.add_theme_font_size_override("font_size", 13)
	_apply_font(_pts_lbl)
	root.add_child(_pts_lbl)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	root.add_child(btn_row)

	var again_btn := Button.new()
	again_btn.text = "다시 참가"
	again_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again_btn.custom_minimum_size = Vector2(0, 44)
	again_btn.modulate = GOLD
	again_btn.add_theme_font_size_override("font_size", 15)
	_apply_font(again_btn)
	again_btn.pressed.connect(func() -> void: play_again_requested.emit())
	btn_row.add_child(again_btn)

	var main_btn := Button.new()
	main_btn.text = "메인으로"
	main_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_btn.custom_minimum_size = Vector2(0, 44)
	main_btn.add_theme_font_size_override("font_size", 15)
	_apply_font(main_btn)
	main_btn.pressed.connect(func() -> void: main_menu_requested.emit())
	btn_row.add_child(main_btn)

func show_result(data: Dictionary) -> void:
	var winner_name: String = data.get("winner_name", "무승부")
	_winner_lbl.text = winner_name

	# Rankings
	for child in _rank_container.get_children():
		child.queue_free()

	var rankings: Array = data.get("rankings", [])
	for i in rankings.size():
		_rank_container.add_child(_make_rank_row(i + 1, rankings[i]))

	# Points summary
	var pts: Dictionary = data.get("points_summary", {})
	var spent: int   = pts.get("oracle_spent", 0)
	var part_bonus: int = pts.get("participation_bonus", 0)
	var win_bonus: int  = pts.get("winner_bonus", 0)
	var net: int = part_bonus + win_bonus - spent
	_pts_lbl.text = "신탁 소모: -%dpt  참가 보너스: +%dpt  우승 보너스: +%dpt  합계: %+dpt" % [
		spent, part_bonus, win_bonus, net
	]

func _make_rank_row(rank: int, entry: Dictionary) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	var rank_lbl := Label.new()
	rank_lbl.text = "%d위" % rank
	rank_lbl.custom_minimum_size = Vector2(36, 0)
	rank_lbl.add_theme_font_size_override("font_size", 14)
	match rank:
		1: rank_lbl.modulate = GOLD
		2: rank_lbl.modulate = SILVER
		3: rank_lbl.modulate = BRONZE
		_: rank_lbl.modulate = Color(0.7, 0.7, 0.8)
	_apply_font(rank_lbl)
	hbox.add_child(rank_lbl)

	var name_lbl := Label.new()
	name_lbl.text = entry.get("name", "?")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 14)
	_apply_font(name_lbl)
	hbox.add_child(name_lbl)

	var cls_lbl := Label.new()
	cls_lbl.text = (entry.get("class", "?") as String).capitalize()
	cls_lbl.modulate = Color(0.7, 0.7, 1.0)
	cls_lbl.add_theme_font_size_override("font_size", 12)
	cls_lbl.custom_minimum_size = Vector2(60, 0)
	_apply_font(cls_lbl)
	hbox.add_child(cls_lbl)

	var elim_lbl := Label.new()
	var elim_turn: int = entry.get("eliminated_turn", -1)
	elim_lbl.text = "생존" if elim_turn < 0 else "%d턴 탈락" % elim_turn
	elim_lbl.modulate = Color(0.6, 0.6, 0.7)
	elim_lbl.add_theme_font_size_override("font_size", 12)
	_apply_font(elim_lbl)
	hbox.add_child(elim_lbl)

	return hbox
