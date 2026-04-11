## GameResultScreen.gd
## Displays end-of-game results: winner banner (Section 1), rankings (Section 2),
## and points settlement grid (Section 3) per the Astraea Nexus design spec.
extends Control

signal play_again_requested
signal main_menu_requested

# Astraea Nexus design tokens
const BG_BASE    := Color(0.071, 0.071, 0.133)          # #121222
const BG_CARD    := Color(1.0, 1.0, 1.0, 0.06)          # rgba(255,255,255,0.06)
const BORDER_CARD := Color(1.0, 1.0, 1.0, 0.12)         # rgba(255,255,255,0.12)
const ACCENT_GOLD   := Color(1.0, 0.843, 0.0)           # #FFD700
const ACCENT_PURPLE := Color(0.545, 0.361, 0.965)        # #8B5CF6
const TEXT_PRIMARY  := Color(1.0, 1.0, 1.0)             # #FFFFFF
const TEXT_SECONDARY := Color(1.0, 1.0, 1.0, 0.6)       # rgba(255,255,255,0.6)
const SUCCESS := Color(0.063, 0.725, 0.506)              # #10B981
const DANGER  := Color(0.937, 0.267, 0.267)              # #EF4444
const SILVER  := Color(0.75, 0.75, 0.80)
const BRONZE  := Color(0.80, 0.50, 0.20)

var _font: FontFile = null

var _winner_panel: PanelContainer
var _winner_lbl:     Label
var _rank_container: VBoxContainer
# Section 3 widgets
var _oracle_cost_lbl: Label
var _win_bonus_lbl:   Label
var _win_bonus_row:   HBoxContainer
var _total_lbl:       Label

func _ready() -> void:
	_font = ResourceLoader.load("res://fonts/NotoSansKR.ttf") as FontFile
	_build_ui()

func _apply_font(node: Control) -> void:
	if _font:
		node.add_theme_font_override("font", _font)

func _make_card_style(border_color: Color = BORDER_CARD, border_width: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = BG_CARD
	s.corner_radius_top_left     = 12
	s.corner_radius_top_right    = 12
	s.corner_radius_bottom_left  = 12
	s.corner_radius_bottom_right = 12
	s.border_width_left   = border_width
	s.border_width_right  = border_width
	s.border_width_top    = border_width
	s.border_width_bottom = border_width
	s.border_color = border_color
	s.content_margin_left   = 16.0
	s.content_margin_right  = 16.0
	s.content_margin_top    = 14.0
	s.content_margin_bottom = 14.0
	return s

func _make_badge_style(badge_color: Color, alpha: float = 0.15) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(badge_color.r, badge_color.g, badge_color.b, alpha)
	s.corner_radius_top_left     = 4
	s.corner_radius_top_right    = 4
	s.corner_radius_bottom_left  = 4
	s.corner_radius_bottom_right = 4
	s.content_margin_left   = 6.0
	s.content_margin_right  = 6.0
	s.content_margin_top    = 3.0
	s.content_margin_bottom = 3.0
	return s

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# bg-base background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG_BASE
	add_child(bg)

	var scroll_root := ScrollContainer.new()
	scroll_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll_root)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.offset_left   = 0.0
	root.offset_right  = 0.0
	scroll_root.add_child(root)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   20)
	margin.add_theme_constant_override("margin_right",  20)
	margin.add_theme_constant_override("margin_top",    24)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	margin.add_child(inner)

	# ── Section 1: Winner Banner ──────────────────────────────────────────────
	_winner_panel = PanelContainer.new()
	var winner_style := _make_card_style(ACCENT_GOLD, 1)
	# glow effect via shadow (Godot StyleBoxFlat shadow)
	winner_style.shadow_color = Color(1.0, 0.843, 0.0, 0.3)
	winner_style.shadow_size  = 20
	_winner_panel.add_theme_stylebox_override("panel", winner_style)
	_winner_panel.modulate = Color(1, 1, 1, 0)  # start transparent for fade-in
	inner.add_child(_winner_panel)

	var winner_vbox := VBoxContainer.new()
	winner_vbox.add_theme_constant_override("separation", 6)
	_winner_panel.add_child(winner_vbox)

	var crown_lbl := Label.new()
	crown_lbl.text = "★  경기 종료  ★"
	crown_lbl.modulate = ACCENT_GOLD
	crown_lbl.add_theme_font_size_override("font_size", 14)
	crown_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(crown_lbl)
	winner_vbox.add_child(crown_lbl)

	_winner_lbl = Label.new()
	_winner_lbl.text = "..."
	_winner_lbl.modulate = TEXT_PRIMARY
	_winner_lbl.add_theme_font_size_override("font_size", 32)
	_winner_lbl.add_theme_color_override("font_color", TEXT_PRIMARY)
	_winner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(_winner_lbl)
	winner_vbox.add_child(_winner_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "우승!"
	sub_lbl.modulate = TEXT_SECONDARY
	sub_lbl.add_theme_font_size_override("font_size", 14)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(sub_lbl)
	winner_vbox.add_child(sub_lbl)

	# ── Section 2: Rankings ───────────────────────────────────────────────────
	var rank_panel := PanelContainer.new()
	rank_panel.add_theme_stylebox_override("panel", _make_card_style())
	inner.add_child(rank_panel)

	var rank_vbox := VBoxContainer.new()
	rank_vbox.add_theme_constant_override("separation", 8)
	rank_panel.add_child(rank_vbox)

	var rank_title := Label.new()
	rank_title.text = "순위표"
	rank_title.modulate = TEXT_PRIMARY
	rank_title.add_theme_font_size_override("font_size", 18)
	_apply_font(rank_title)
	rank_vbox.add_child(rank_title)

	_rank_container = VBoxContainer.new()
	_rank_container.add_theme_constant_override("separation", 6)
	_rank_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_vbox.add_child(_rank_container)

	# ── Section 3: Points Settlement ─────────────────────────────────────────
	var pts_panel := PanelContainer.new()
	pts_panel.add_theme_stylebox_override("panel", _make_card_style())
	inner.add_child(pts_panel)

	var pts_vbox := VBoxContainer.new()
	pts_vbox.add_theme_constant_override("separation", 10)
	pts_panel.add_child(pts_vbox)

	var pts_title := Label.new()
	pts_title.text = "포인트 정산"
	pts_title.modulate = TEXT_PRIMARY
	pts_title.add_theme_font_size_override("font_size", 18)
	_apply_font(pts_title)
	pts_vbox.add_child(pts_title)

	# 2-column grid
	var pts_grid := GridContainer.new()
	pts_grid.columns = 2
	pts_grid.add_theme_constant_override("h_separation", 12)
	pts_grid.add_theme_constant_override("v_separation", 8)
	pts_vbox.add_child(pts_grid)

	# Left column: oracle cost badge
	var cost_badge := PanelContainer.new()
	cost_badge.add_theme_stylebox_override("panel", _make_badge_style(DANGER))
	pts_grid.add_child(cost_badge)
	_oracle_cost_lbl = Label.new()
	_oracle_cost_lbl.text = "신탁 사용 -0pt × 0회"
	_oracle_cost_lbl.modulate = DANGER
	_oracle_cost_lbl.add_theme_font_size_override("font_size", 12)
	_apply_font(_oracle_cost_lbl)
	cost_badge.add_child(_oracle_cost_lbl)

	# Right column: win bonus badge (hidden when not winner)
	_win_bonus_row = HBoxContainer.new()
	pts_grid.add_child(_win_bonus_row)
	var win_badge := PanelContainer.new()
	win_badge.add_theme_stylebox_override("panel", _make_badge_style(SUCCESS))
	_win_bonus_row.add_child(win_badge)
	_win_bonus_lbl = Label.new()
	_win_bonus_lbl.text = "우승 보너스 +50pt"
	_win_bonus_lbl.modulate = SUCCESS
	_win_bonus_lbl.add_theme_font_size_override("font_size", 12)
	_apply_font(_win_bonus_lbl)
	win_badge.add_child(_win_bonus_lbl)

	# Total
	var separator := HSeparator.new()
	pts_vbox.add_child(separator)

	_total_lbl = Label.new()
	_total_lbl.text = "합계: 계산 중..."
	_total_lbl.modulate = TEXT_PRIMARY
	_total_lbl.add_theme_font_size_override("font_size", 20)
	_apply_font(_total_lbl)
	pts_vbox.add_child(_total_lbl)

	# ── Button Row ────────────────────────────────────────────────────────────
	var btn_vbox := VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 8)
	inner.add_child(btn_vbox)

	var again_btn := Button.new()
	again_btn.text = "다시 참가"
	again_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again_btn.custom_minimum_size = Vector2(0, 48)
	again_btn.add_theme_font_size_override("font_size", 16)
	var again_style := StyleBoxFlat.new()
	again_style.bg_color = ACCENT_GOLD
	again_style.corner_radius_top_left     = 8
	again_style.corner_radius_top_right    = 8
	again_style.corner_radius_bottom_left  = 8
	again_style.corner_radius_bottom_right = 8
	again_btn.add_theme_stylebox_override("normal", again_style)
	again_btn.add_theme_color_override("font_color", BG_BASE)
	again_btn.add_theme_color_override("font_pressed_color", BG_BASE)
	again_btn.add_theme_color_override("font_hover_color", BG_BASE)
	_apply_font(again_btn)
	again_btn.pressed.connect(func() -> void: play_again_requested.emit())
	btn_vbox.add_child(again_btn)

	var main_btn := Button.new()
	main_btn.text = "메인으로"
	main_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_btn.custom_minimum_size = Vector2(0, 48)
	main_btn.add_theme_font_size_override("font_size", 16)
	var main_style := StyleBoxFlat.new()
	main_style.bg_color = Color(0, 0, 0, 0)
	main_style.border_color = ACCENT_PURPLE
	main_style.border_width_left   = 1
	main_style.border_width_right  = 1
	main_style.border_width_top    = 1
	main_style.border_width_bottom = 1
	main_style.corner_radius_top_left     = 8
	main_style.corner_radius_top_right    = 8
	main_style.corner_radius_bottom_left  = 8
	main_style.corner_radius_bottom_right = 8
	main_btn.add_theme_stylebox_override("normal", main_style)
	main_btn.add_theme_color_override("font_color", ACCENT_PURPLE)
	main_btn.add_theme_color_override("font_pressed_color", ACCENT_PURPLE)
	main_btn.add_theme_color_override("font_hover_color", ACCENT_PURPLE)
	_apply_font(main_btn)
	main_btn.pressed.connect(func() -> void: main_menu_requested.emit())
	btn_vbox.add_child(main_btn)

	# Trigger winner banner fade-in
	_animate_winner_banner()

func _animate_winner_banner() -> void:
	var tween := create_tween()
	tween.tween_property(_winner_panel, "modulate", Color(1, 1, 1, 1), 0.4)

func show_result(data: Dictionary) -> void:
	var winner_name: String = data.get("winner_name", "무승부")
	_winner_lbl.text = winner_name

	# Re-trigger winner banner animation
	_winner_panel.modulate = Color(1, 1, 1, 0)
	_animate_winner_banner()

	# Section 2: Rankings with stagger animation
	for child in _rank_container.get_children():
		child.queue_free()

	var rankings: Array = data.get("rankings", [])
	var stagger_tween := create_tween()
	stagger_tween.set_parallel(true)
	for i in rankings.size():
		var row := _make_rank_row(i + 1, rankings[i])
		row.modulate = Color(1, 1, 1, 0)
		_rank_container.add_child(row)
		var delay: float = i * 0.08
		stagger_tween.tween_property(row, "modulate", Color(1, 1, 1, 1), 0.2).set_delay(delay)

	# Section 3: Points settlement
	var pts: Dictionary = data.get("points_summary", {})
	var oracle_uses: int = pts.get("oracle_uses", 0)
	var cost_per_use: int = pts.get("cost_per_use", 10)
	var spent: int = pts.get("oracle_spent", oracle_uses * cost_per_use)
	var win_bonus: int = pts.get("winner_bonus", 0)
	var part_bonus: int = pts.get("participation_bonus", 0)

	_oracle_cost_lbl.text = "신탁 사용  -%dpt × %d회" % [cost_per_use, oracle_uses]
	if oracle_uses == 0 and spent > 0:
		_oracle_cost_lbl.text = "신탁 사용  -%dpt" % spent

	_win_bonus_row.visible = win_bonus > 0
	if win_bonus > 0:
		_win_bonus_lbl.text = "우승 보너스  +%dpt" % win_bonus

	var net: int = part_bonus + win_bonus - spent
	_total_lbl.text = "합계: %+dpt" % net

func _make_rank_row(rank: int, entry: Dictionary) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	var rank_lbl := Label.new()
	rank_lbl.text = "%d위" % rank
	rank_lbl.custom_minimum_size = Vector2(40, 0)
	rank_lbl.add_theme_font_size_override("font_size", 20)
	match rank:
		1: rank_lbl.modulate = ACCENT_GOLD
		2: rank_lbl.modulate = SILVER
		3: rank_lbl.modulate = BRONZE
		_: rank_lbl.modulate = TEXT_SECONDARY
	_apply_font(rank_lbl)
	hbox.add_child(rank_lbl)

	var name_lbl := Label.new()
	name_lbl.text = entry.get("name", "?")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.modulate = TEXT_PRIMARY
	_apply_font(name_lbl)
	hbox.add_child(name_lbl)

	var elim_lbl := Label.new()
	var elim_at: String = entry.get("eliminated_at", "")
	var elim_turn: int = entry.get("eliminated_turn", -1)
	if elim_at != "":
		elim_lbl.text = elim_at
	elif elim_turn >= 0:
		elim_lbl.text = "%d턴 탈락" % elim_turn
	else:
		elim_lbl.text = "생존"
	elim_lbl.modulate = TEXT_SECONDARY
	elim_lbl.add_theme_font_size_override("font_size", 12)
	elim_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_apply_font(elim_lbl)
	hbox.add_child(elim_lbl)

	return hbox
