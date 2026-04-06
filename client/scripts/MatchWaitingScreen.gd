## MatchWaitingScreen.gd
## Matchmaking queue display. Auto-start when enough players join.
extends Control

signal match_found(match_id: int)
signal cancelled

const GOLD   := Color(1.0, 0.85, 0.0)
const BG     := Color(0.07, 0.07, 0.14)
const PURPLE := Color(0.55, 0.36, 0.96)

var _font: FontFile = null

var _char_name_lbl:  Label
var _char_stats_lbl: Label
var _count_lbl:      Label
var _timer_lbl:      Label
var _cancel_btn:     Button

var _elapsed: float = 0.0
var _waiting:  bool = false
var _current_count: int = 0
var _total_slots:   int = 32

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
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.offset_left   = -200.0
	root.offset_top    = -220.0
	root.offset_right  =  200.0
	root.offset_bottom =  220.0
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	# Title
	var title := Label.new()
	title.text = "매칭 대기 중"
	title.modulate = GOLD
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(title)
	root.add_child(title)

	# Character card
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.22)
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_color = GOLD
	card.add_theme_stylebox_override("panel", style)
	root.add_child(card)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 4)
	card.add_child(card_vbox)

	_char_name_lbl = Label.new()
	_char_name_lbl.text = "성좌명"
	_char_name_lbl.modulate = GOLD
	_char_name_lbl.add_theme_font_size_override("font_size", 16)
	_char_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(_char_name_lbl)
	card_vbox.add_child(_char_name_lbl)

	_char_stats_lbl = Label.new()
	_char_stats_lbl.text = "클래스: -"
	_char_stats_lbl.add_theme_font_size_override("font_size", 13)
	_char_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(_char_stats_lbl)
	card_vbox.add_child(_char_stats_lbl)

	# Participant count
	_count_lbl = Label.new()
	_count_lbl.text = "0 / 32"
	_count_lbl.modulate = GOLD
	_count_lbl.add_theme_font_size_override("font_size", 36)
	_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(_count_lbl)
	root.add_child(_count_lbl)

	var count_sub := Label.new()
	count_sub.text = "참가자"
	count_sub.modulate = Color(0.6, 0.6, 0.8)
	count_sub.add_theme_font_size_override("font_size", 13)
	count_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(count_sub)
	root.add_child(count_sub)

	# Timer
	_timer_lbl = Label.new()
	_timer_lbl.text = "대기 중... 00:00"
	_timer_lbl.modulate = PURPLE
	_timer_lbl.add_theme_font_size_override("font_size", 15)
	_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(_timer_lbl)
	root.add_child(_timer_lbl)

	# NPC notice
	var npc_lbl := Label.new()
	npc_lbl.text = "참가자 부족 시 NPC로 자동 충원됩니다"
	npc_lbl.modulate = Color(0.6, 0.6, 0.7)
	npc_lbl.add_theme_font_size_override("font_size", 12)
	npc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(npc_lbl)
	root.add_child(npc_lbl)

	# Cancel button
	_cancel_btn = Button.new()
	_cancel_btn.text = "취소"
	_cancel_btn.custom_minimum_size = Vector2(160, 40)
	_cancel_btn.add_theme_font_size_override("font_size", 14)
	_apply_font(_cancel_btn)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	root.add_child(_cancel_btn)

func start_waiting(character_data: Dictionary) -> void:
	_waiting = true
	_elapsed = 0.0
	_current_count = 0
	_char_name_lbl.text = character_data.get("name", "성좌명")
	var cls_str: String = (character_data.get("class", "?") as String).capitalize()
	_char_stats_lbl.text = "[%s]  HP:%d  ATK:%d  DEF:%d" % [
		cls_str,
		character_data.get("hp", 0),
		character_data.get("atk", 0),
		character_data.get("def", 0)
	]
	_count_lbl.text = "0 / %d" % _total_slots
	_cancel_btn.disabled = false

func _process(delta: float) -> void:
	if not _waiting:
		return
	_elapsed += delta
	var mins := int(_elapsed) / 60
	var secs := int(_elapsed) % 60
	_timer_lbl.text = "대기 중... %02d:%02d" % [mins, secs]

func _on_cancel_pressed() -> void:
	_waiting = false
	_cancel_btn.disabled = true
	WebSocketClient.send({"type": "cancel_match"})
	cancelled.emit()

func _on_ws_message(data: Dictionary) -> void:
	match data.get("type", ""):
		"queue_update":
			_current_count = data.get("count", _current_count)
			_total_slots   = data.get("total", _total_slots)
			_count_lbl.text = "%d / %d" % [_current_count, _total_slots]
		"match_found":
			_waiting = false
			match_found.emit(data.get("matchId", -1))
