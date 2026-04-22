## CharacterCreateScreen.gd
## Two-step character creation: name input → AI prompt → preview → save.
extends Control

signal back_requested
signal character_created(data: Dictionary)

const BG_BASE       := Color(0.071, 0.071, 0.133)
const BG_CARD       := Color(1, 1, 1, 0.06)
const BORDER_CARD   := Color(1, 1, 1, 0.12)
const ACCENT_GOLD   := Color(1.0, 0.843, 0.0)
const ACCENT_PURPLE := Color(0.545, 0.361, 0.965)
const TEXT_PRIMARY  := Color(1, 1, 1)
const TEXT_SECONDARY := Color(1, 1, 1, 0.6)
const SUCCESS       := Color(0.063, 0.725, 0.506)
const DANGER        := Color(0.937, 0.267, 0.267)

const CLASS_DATA := {
	"warrior":  { "label": "전사",  "spd": 1.0, "desc": "균형형 탱커. 가장 가까운 적에게 돌진." },
	"archer":   { "label": "궁수",  "spd": 1.5, "desc": "원거리 기동형. HP 50% 이하 시 후퇴 우선." },
	"mage":     { "label": "마법사","spd": 0.9, "desc": "고화력 원거리. 접근 시 즉시 후퇴." },
	"assassin": { "label": "암살자","spd": 1.6, "desc": "고속 돌격. 치명타 25% 확률(×2 데미지)." },
	"berserk":  { "label": "광전사","spd": 1.3, "desc": "무조건 돌격. HP 낮을수록 데미지 ×1.5." },
	"healer":   { "label": "힐러",  "spd": 1.0, "desc": "아군 회복 우선. 공격력 약하고 방어 강함." },
}

var _font: FontFile = null

var _name_input:    LineEdit
var _prompt_input:  TextEdit
var _analyze_btn:   Button
var _loading_lbl:   Label
var _preview_panel: Control
var _preview_class: Label
var _preview_stats: Label
var _preview_tend:  Label
var _guide_spd_lbl: Label
var _guide_desc_lbl: Label
var _save_btn:      Button

var _pending_name:        String = ""
var _preview_data:        Dictionary = {}
var _analyze_request_id:  int = 0

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
	bg.color = BG_BASE
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
	back_btn.add_theme_font_size_override("font_size", 16)
	_apply_font(back_btn)
	back_btn.pressed.connect(func() -> void: back_requested.emit())
	hdr.add_child(back_btn)

	var title := Label.new()
	title.text = "새 성좌 만들기"
	title.modulate = ACCENT_GOLD
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(title)
	hdr.add_child(title)

	# Spacer (match back button width)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(80, 0)
	hdr.add_child(spacer)

	# Step 1: Name
	var step1_lbl := Label.new()
	step1_lbl.text = "STEP 1 — 성좌명을 입력하세요"
	step1_lbl.modulate = TEXT_SECONDARY
	step1_lbl.add_theme_font_size_override("font_size", 18)
	_apply_font(step1_lbl)
	root.add_child(step1_lbl)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "예: 철혈 검사, 불꽃 마도사 …"
	_name_input.custom_minimum_size = Vector2(0, 52)
	_name_input.add_theme_font_size_override("font_size", 18)
	_apply_font(_name_input)
	root.add_child(_name_input)

	# Step 2: Prompt
	var step2_lbl := Label.new()
	step2_lbl.text = "STEP 2 — 소환 주문을 입력하세요 (AI가 스탯을 추출합니다)"
	step2_lbl.modulate = TEXT_SECONDARY
	step2_lbl.add_theme_font_size_override("font_size", 18)
	step2_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(step2_lbl)
	root.add_child(step2_lbl)

	_prompt_input = TextEdit.new()
	_prompt_input.placeholder_text = "예: 빛의 속도로 움직이며 적을 베는 검사. 민첩하고 치명적이나 방어는 약하다."
	_prompt_input.custom_minimum_size = Vector2(0, 120)
	_prompt_input.add_theme_font_size_override("font_size", 16)
	_apply_font(_prompt_input)
	root.add_child(_prompt_input)

	# Analyze button
	_analyze_btn = Button.new()
	_analyze_btn.text = "AI로 스탯 분석하기"
	_analyze_btn.custom_minimum_size = Vector2(0, 56)
	_analyze_btn.modulate = ACCENT_GOLD
	_analyze_btn.add_theme_font_size_override("font_size", 20)
	_apply_font(_analyze_btn)
	_analyze_btn.pressed.connect(_on_analyze_pressed)
	root.add_child(_analyze_btn)

	# Loading label
	_loading_lbl = Label.new()
	_loading_lbl.text = "AI 분석 중..."
	_loading_lbl.modulate = ACCENT_PURPLE
	_loading_lbl.add_theme_font_size_override("font_size", 18)
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
	_save_btn.custom_minimum_size = Vector2(0, 56)
	_save_btn.modulate = ACCENT_GOLD
	_save_btn.add_theme_font_size_override("font_size", 20)
	_save_btn.visible = false
	_apply_font(_save_btn)
	_save_btn.pressed.connect(_on_save_pressed)
	root.add_child(_save_btn)

func _build_preview_panel() -> Control:
	var panel := PanelContainer.new()
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
	style.border_color = ACCENT_GOLD
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var prev_title := Label.new()
	prev_title.text = "STEP 3 — 성좌 미리보기"
	prev_title.modulate = TEXT_SECONDARY
	prev_title.add_theme_font_size_override("font_size", 13)
	_apply_font(prev_title)
	vbox.add_child(prev_title)

	_preview_class = Label.new()
	_preview_class.text = "클래스: -"
	_preview_class.modulate = ACCENT_GOLD
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
	_preview_tend.modulate = TEXT_SECONDARY
	_preview_tend.add_theme_font_size_override("font_size", 13)
	_apply_font(_preview_tend)
	vbox.add_child(_preview_tend)

	# ── 클래스 가이드 추가 항목 ──
	var sep := HSeparator.new()
	vbox.add_child(sep)

	_guide_spd_lbl = Label.new()
	_guide_spd_lbl.add_theme_font_size_override("font_size", 13)
	_guide_spd_lbl.modulate = TEXT_SECONDARY
	_apply_font(_guide_spd_lbl)
	vbox.add_child(_guide_spd_lbl)

	_guide_desc_lbl = Label.new()
	_guide_desc_lbl.add_theme_font_size_override("font_size", 12)
	_guide_desc_lbl.modulate = TEXT_SECONDARY
	_guide_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(_guide_desc_lbl)
	vbox.add_child(_guide_desc_lbl)

	return panel

func _on_analyze_pressed() -> void:
	var name_val := _name_input.text.strip_edges()
	var prompt_val := _prompt_input.text.strip_edges()
	if name_val.is_empty():
		return
	if prompt_val.is_empty():
		return

	_analyze_request_id += 1
	_pending_name = name_val
	_analyze_btn.disabled = true
	_loading_lbl.text = "AI 분석 중..."
	_loading_lbl.modulate = ACCENT_PURPLE
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
		"error":
			_analyze_btn.disabled = false
			_save_btn.disabled = false
			_loading_lbl.text = "오류: " + data.get("message", "알 수 없는 오류")
			_loading_lbl.modulate = DANGER
			_loading_lbl.visible = true
			var _snap_id := _analyze_request_id
			await get_tree().create_timer(3.0).timeout
			if _analyze_request_id == _snap_id:
				_loading_lbl.text = "AI 분석 중..."
				_loading_lbl.modulate = ACCENT_PURPLE
				_loading_lbl.visible = false

func _populate_preview(d: Dictionary) -> void:
	var cls_str: String = (d.get("class", "?") as String).capitalize()
	_preview_class.text = "클래스: " + cls_str
	_preview_stats.text = "HP: %d  ATK: %d  DEF: %d" % [
		d.get("hp", 0), d.get("atk", 0), d.get("def", 0)
	]
	_preview_tend.text = "행동 성향: " + d.get("tendency", "-")
	_update_class_guide(d.get("class", ""))

func _update_class_guide(cls: String) -> void:
	if not CLASS_DATA.has(cls):
		_guide_spd_lbl.text  = ""
		_guide_desc_lbl.text = ""
		return
	var cd: Dictionary = CLASS_DATA[cls]
	_guide_spd_lbl.text  = "💨 속도: %.1f" % cd["spd"]
	_guide_desc_lbl.text = cd["desc"]
