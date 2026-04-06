## OraclePanel.gd
## Slide-in panel shown when a player clicks a character.
## Builds its own child nodes in _ready() to avoid Godot binary packer bugs.
extends Control

signal oracle_action_requested(char_id: int)

const SLIDE_IN_SECS  := 0.28
const SLIDE_OUT_SECS := 0.22
const PANEL_WIDTH    := 280.0

var _panel:      PanelContainer
var _name_lbl:   Label
var _class_lbl:  Label
var _hp_lbl:     Label
var _oracle_btn: Button
var _cd_lbl:     Label
var _close_btn:  Button

var _current_char_id: int  = -1
var _panel_tween:     Tween
var _font:            FontFile = null

func _load_font() -> void:
	_font = ResourceLoader.load("res://fonts/NotoSansKR.ttf") as FontFile

func _apply_font(node: Control) -> void:
	if _font != null:
		node.add_theme_font_override("font", _font)

func _ready() -> void:
	_load_font()
	_build_ui()
	visible = false
	_panel.position.x = PANEL_WIDTH

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	_panel.add_child(vbox)

	_name_lbl = Label.new()
	_name_lbl.text = "성좌 이름"
	_name_lbl.add_theme_font_size_override("font_size", 16)
	_apply_font(_name_lbl)
	vbox.add_child(_name_lbl)

	_class_lbl = Label.new()
	_class_lbl.text = "클래스: -"
	_class_lbl.add_theme_font_size_override("font_size", 13)
	_apply_font(_class_lbl)
	vbox.add_child(_class_lbl)

	_hp_lbl = Label.new()
	_hp_lbl.text = "HP: - / 100"
	_hp_lbl.add_theme_font_size_override("font_size", 13)
	_apply_font(_hp_lbl)
	vbox.add_child(_hp_lbl)

	_oracle_btn = Button.new()
	_oracle_btn.text = "신탁 발동 (-5 포인트)"
	_oracle_btn.custom_minimum_size = Vector2(0, 36)
	_apply_font(_oracle_btn)
	_oracle_btn.pressed.connect(_on_oracle_pressed)
	vbox.add_child(_oracle_btn)

	_cd_lbl = Label.new()
	_cd_lbl.text = "쿨다운: 0s"
	_cd_lbl.visible = false
	_cd_lbl.add_theme_font_size_override("font_size", 12)
	_apply_font(_cd_lbl)
	vbox.add_child(_cd_lbl)

	_close_btn = Button.new()
	_close_btn.text = "닫기"
	_close_btn.custom_minimum_size = Vector2(0, 32)
	_apply_font(_close_btn)
	_close_btn.pressed.connect(hide_panel)
	vbox.add_child(_close_btn)

func show_for_character(data: Dictionary) -> void:
	_current_char_id = data.get("id", -1)
	_name_lbl.text   = data.get("name",  "Unknown")
	_class_lbl.text  = "클래스: " + (data.get("class", "?") as String).capitalize()
	_hp_lbl.text     = "HP: %d / 100" % data.get("hp", 0)
	visible = true
	_slide_in()
	_refresh_button()

func hide_panel() -> void:
	_slide_out()

func _slide_in() -> void:
	if _panel_tween:
		_panel_tween.kill()
	_panel_tween = create_tween()
	_panel_tween.tween_property(_panel, "position:x", 0.0, SLIDE_IN_SECS)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _slide_out() -> void:
	if _panel_tween:
		_panel_tween.kill()
	_panel_tween = create_tween()
	_panel_tween.tween_property(_panel, "position:x", PANEL_WIDTH, SLIDE_OUT_SECS)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_panel_tween.tween_callback(func() -> void: visible = false)

func _refresh_button() -> void:
	var can_use := GameState.can_use_oracle()
	_oracle_btn.disabled = not can_use

	var cd := GameState.oracle_cooldown_remaining
	if cd > 0.0:
		_cd_lbl.text    = "쿨다운: %ds" % ceili(cd)
		_cd_lbl.visible = true
	else:
		_cd_lbl.visible = false

	if GameState.oracle_points < GameState.ORACLE_COST:
		_oracle_btn.text = "신탁 (포인트 부족)"
	else:
		_oracle_btn.text = "신탁 발동 (-%d 포인트)" % GameState.ORACLE_COST

func _on_oracle_pressed() -> void:
	if _current_char_id < 0:
		return
	if GameState.use_oracle():
		oracle_action_requested.emit(_current_char_id)
		_refresh_button()

func _process(_delta: float) -> void:
	if visible:
		_refresh_button()
