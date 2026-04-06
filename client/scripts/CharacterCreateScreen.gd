## CharacterCreateScreen.gd
## Two-step character creation: name input → AI prompt → preview → save.
extends Control

signal back_requested
signal character_created(data: Dictionary)

const GOLD   := Color(1.0, 0.85, 0.0)
const BG     := Color(0.07, 0.07, 0.14)
const PURPLE := Color(0.55, 0.36, 0.96)

var _font: FontFile = null

var _name_input:    LineEdit
var _prompt_input:  TextEdit
var _analyze_btn:   Button
var _loading_lbl:   Label
var _preview_panel: Control
var _preview_class: Label
var _preview_stats: Label
var _preview_tend:  Label
var _save_btn:      Button

var _pending_name:   String = ""
var _preview_data:   Dictionary = {}

func _ready() -> void:
	_font = ResourceLoader.load("res://fonts/NotoSansKR.ttf") as FontFile
	_build_ui()
	WebSocketClient.message_received.connect(_on_ws_message)

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
	root.add_theme_constant_override("separation", 16)
	root.offset_left   = 24.0
	root.offset_top    = 24.0
	root.offset_right  = -24.0
	root.offset_bottom = -24.0
	add_child(root)

	# Header
	var hdr := HBoxContainer.new()
	root.add_child(hdr)

	var back_btn := Button.new()
	back_btn.text = "← 돌아가기"
	back_btn.add_theme_font_size_override("font_size", 13)
	_apply_font(back_btn)
	back_btn.pressed.connect(func() -> void: back_requested.emit())
	hdr.add_child(back_btn)

	var title := Label.new()
	title.text = "새 성좌 만들기"
	title.modulate = GOLD
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(title)
	hdr.add_child(title)

	# Spacer (match back button width)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(100, 0)
	hdr.add_child(spacer)

	# Step 1: Name
	var step1_lbl := Label.new()
	step1_lbl.text = "STEP 1 — 성좌명을 입력하세요"
	step1_lbl.modulate = Color(0.7, 0.7, 1.0)
	step1_lbl.add_theme_font_size_override("font_size", 14)
	_apply_font(step1_lbl)
	root.add_child(step1_lbl)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "예: 철혈 검사, 불꽃 마도사 …"
	_name_input.custom_minimum_size = Vector2(0, 40)
	_name_input.add_theme_font_size_override("font_size", 15)
	_apply_font(_name_input)
	root.add_child(_name_input)

	# Step 2: Prompt
	var step2_lbl := Label.new()
	step2_lbl.text = "STEP 2 — 소환 주문을 입력하세요 (AI가 스탯을 추출합니다)"
	step2_lbl.modulate = Color(0.7, 0.7, 1.0)
	step2_lbl.add_theme_font_size_override("font_size", 14)
	_apply_font(step2_lbl)
	root.add_child(step2_lbl)

	_prompt_input = TextEdit.new()
	_prompt_input.placeholder_text = "예: 빛의 속도로 움직이며 적을 베는 검사. 민첩하고 치명적이나 방어는 약하다."
	_prompt_input.custom_minimum_size = Vector2(0, 100)
	_prompt_input.add_theme_font_size_override("font_size", 13)
	_apply_font(_prompt_input)
	root.add_child(_prompt_input)

	# Analyze button
	_analyze_btn = Button.new()
	_analyze_btn.text = "AI로 스탯 분석하기"
	_analyze_btn.custom_minimum_size = Vector2(0, 40)
	_analyze_btn.modulate = GOLD
	_analyze_btn.add_theme_font_size_override("font_size", 15)
	_apply_font(_analyze_btn)
	_analyze_btn.pressed.connect(_on_analyze_pressed)
	root.add_child(_analyze_btn)

	# Loading label
	_loading_lbl = Label.new()
	_loading_lbl.text = "AI 분석 중..."
	_loading_lbl.modulate = PURPLE
	_loading_lbl.add_theme_font_size_override("font_size", 14)
	_loading_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_lbl.visible = false
	_apply_font(_loading_lbl)
	root.add_child(_loading_lbl)

	# Preview panel (hidden until response)
	_preview_panel = _build_preview_panel()
	_preview_panel.visible = false
	root.add_child(_preview_panel)

	# Save button
	_save_btn = Button.new()
	_save_btn.text = "성좌 저장하기"
	_save_btn.custom_minimum_size = Vector2(0, 44)
	_save_btn.modulate = GOLD
	_save_btn.add_theme_font_size_override("font_size", 16)
	_save_btn.visible = false
	_apply_font(_save_btn)
	_save_btn.pressed.connect(_on_save_pressed)
	root.add_child(_save_btn)

func _build_preview_panel() -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.20)
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_color = GOLD
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var prev_title := Label.new()
	prev_title.text = "STEP 3 — 성좌 미리보기"
	prev_title.modulate = Color(0.7, 0.7, 1.0)
	prev_title.add_theme_font_size_override("font_size", 13)
	_apply_font(prev_title)
	vbox.add_child(prev_title)

	_preview_class = Label.new()
	_preview_class.text = "클래스: -"
	_preview_class.modulate = GOLD
	_preview_class.add_theme_font_size_override("font_size", 15)
	_apply_font(_preview_class)
	vbox.add_child(_preview_class)

	_preview_stats = Label.new()
	_preview_stats.text = "HP: -  ATK: -  DEF: -"
	_preview_stats.add_theme_font_size_override("font_size", 13)
	_apply_font(_preview_stats)
	vbox.add_child(_preview_stats)

	_preview_tend = Label.new()
	_preview_tend.text = "행동 성향: -"
	_preview_tend.modulate = Color(0.8, 0.8, 1.0)
	_preview_tend.add_theme_font_size_override("font_size", 13)
	_apply_font(_preview_tend)
	vbox.add_child(_preview_tend)

	return panel

func _on_analyze_pressed() -> void:
	var name_val := _name_input.text.strip_edges()
	var prompt_val := _prompt_input.text.strip_edges()
	if name_val.is_empty():
		return
	if prompt_val.is_empty():
		return

	_pending_name = name_val
	_analyze_btn.disabled = true
	_loading_lbl.visible = true
	_preview_panel.visible = false
	_save_btn.visible = false

	WebSocketClient.send({
		"type": "preview_character",
		"name": name_val,
		"prompt": prompt_val
	})

func _on_save_pressed() -> void:
	if _preview_data.is_empty():
		return
	WebSocketClient.send({
		"type": "create_character",
		"name": _pending_name,
		"prompt": _prompt_input.text.strip_edges()
	})
	_save_btn.disabled = true

func _on_ws_message(data: Dictionary) -> void:
	match data.get("type", ""):
		"character_preview":
			_loading_lbl.visible = false
			_analyze_btn.disabled = false
			_preview_data = data.get("character", {})
			_populate_preview(_preview_data)
			_preview_panel.visible = true
			_save_btn.visible = true
		"character_created":
			_save_btn.disabled = false
			character_created.emit(data.get("character", {}))

func _populate_preview(d: Dictionary) -> void:
	var cls_str: String = (d.get("class", "?") as String).capitalize()
	_preview_class.text = "클래스: " + cls_str
	_preview_stats.text = "HP: %d  ATK: %d  DEF: %d" % [
		d.get("hp", 0), d.get("atk", 0), d.get("def", 0)
	]
	_preview_tend.text = "행동 성향: " + d.get("tendency", "-")
