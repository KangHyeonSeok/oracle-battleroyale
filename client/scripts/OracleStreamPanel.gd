## OracleStreamPanel.gd
## Full oracle chat stream panel. Shows history of all oracle messages.
## Both participants and spectators can send oracles.
extends Control

const GOLD    := Color(1.0, 0.85, 0.0)
const PURPLE  := Color(0.55, 0.36, 0.96)
const SUCCESS := Color(0.3, 0.9, 0.5)
const FAIL    := Color(0.9, 0.3, 0.3)
const SPECTATOR_COLOR := Color(0.5, 0.8, 1.0)

var is_spectator: bool = false

var _font: FontFile = null
var _msg_container: VBoxContainer
var _scroll: ScrollContainer
var _target_option: OptionButton
var _oracle_input: LineEdit
var _cost_lbl: Label
var _send_btn: Button

func _ready() -> void:
	_font = ResourceLoader.load("res://fonts/NotoSansKR.ttf") as FontFile
	_build_ui()
	WebSocketClient.message_received.connect(_on_ws_message)
	GameState.characters_updated.connect(_on_characters_updated)

func _apply_font(node: Control) -> void:
	if _font:
		node.add_theme_font_override("font", _font)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	offset_left   = -300.0
	offset_right  = 0.0

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.12, 0.92)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	root.offset_left   = 6.0
	root.offset_top    = 6.0
	root.offset_right  = -6.0
	root.offset_bottom = -6.0
	add_child(root)

	# Header
	var header := Label.new()
	header.text = "신탁 스트림"
	header.modulate = GOLD
	header.add_theme_font_size_override("font_size", 15)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(header)
	root.add_child(header)

	# Message scroll area
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = false
	root.add_child(_scroll)

	_msg_container = VBoxContainer.new()
	_msg_container.add_theme_constant_override("separation", 4)
	_msg_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_msg_container)

	# Divider
	var sep := HSeparator.new()
	root.add_child(sep)

	# Target selector
	var target_row := HBoxContainer.new()
	target_row.add_theme_constant_override("separation", 6)
	root.add_child(target_row)

	var target_lbl := Label.new()
	target_lbl.text = "대상:"
	target_lbl.add_theme_font_size_override("font_size", 12)
	_apply_font(target_lbl)
	target_row.add_child(target_lbl)

	_target_option = OptionButton.new()
	_target_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_option.add_theme_font_size_override("font_size", 12)
	_apply_font(_target_option)
	target_row.add_child(_target_option)

	# Oracle input
	_oracle_input = LineEdit.new()
	_oracle_input.placeholder_text = "신탁 메시지 입력..."
	_oracle_input.custom_minimum_size = Vector2(0, 32)
	_oracle_input.add_theme_font_size_override("font_size", 12)
	_apply_font(_oracle_input)
	_oracle_input.text_submitted.connect(func(_t: String) -> void: _on_send_pressed())
	root.add_child(_oracle_input)

	# Send row
	var send_row := HBoxContainer.new()
	send_row.add_theme_constant_override("separation", 6)
	root.add_child(send_row)

	_cost_lbl = Label.new()
	_cost_lbl.text = "신탁 비용: 50pt"
	_cost_lbl.modulate = Color(0.7, 0.7, 0.9)
	_cost_lbl.add_theme_font_size_override("font_size", 12)
	_cost_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(_cost_lbl)
	send_row.add_child(_cost_lbl)

	_send_btn = Button.new()
	_send_btn.text = "신탁 전송"
	_send_btn.custom_minimum_size = Vector2(80, 32)
	_send_btn.modulate = GOLD
	_send_btn.add_theme_font_size_override("font_size", 12)
	_apply_font(_send_btn)
	_send_btn.pressed.connect(_on_send_pressed)
	send_row.add_child(_send_btn)

func add_message(msg: Dictionary) -> void:
	var row := _make_message_row(msg)
	_msg_container.add_child(row)
	# Auto-scroll to bottom
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

func _make_message_row(msg: Dictionary) -> Control:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var msg_type: String = msg.get("type", "oracle")

	match msg_type:
		"system":
			var lbl := Label.new()
			lbl.text = "[시스템] " + msg.get("text", "")
			lbl.modulate = PURPLE
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_apply_font(lbl)
			container.add_child(lbl)

		"spectator":
			var sender: String = msg.get("sender", "관전자")
			var target: String = msg.get("target", "")
			var text: String   = msg.get("text", "")
			var header_lbl := Label.new()
			header_lbl.text = "[관전] %s → %s" % [sender, target]
			header_lbl.modulate = SPECTATOR_COLOR
			header_lbl.add_theme_font_size_override("font_size", 11)
			_apply_font(header_lbl)
			container.add_child(header_lbl)

			var body_lbl := Label.new()
			body_lbl.text = text
			body_lbl.modulate = Color(0.8, 0.9, 1.0)
			body_lbl.add_theme_font_size_override("font_size", 12)
			body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_apply_font(body_lbl)
			container.add_child(body_lbl)

		_: # "oracle"
			var sender: String  = msg.get("sender", "?")
			var target: String  = msg.get("target", "?")
			var text: String    = msg.get("text", "")
			var success: bool   = msg.get("success", false)

			var hbox := HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 6)
			container.add_child(hbox)

			var route_lbl := Label.new()
			route_lbl.text = "%s → %s" % [sender, target]
			route_lbl.modulate = GOLD
			route_lbl.add_theme_font_size_override("font_size", 12)
			route_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_apply_font(route_lbl)
			hbox.add_child(route_lbl)

			var badge := Label.new()
			badge.text = "성공" if success else "실패"
			badge.modulate = SUCCESS if success else FAIL
			badge.add_theme_font_size_override("font_size", 11)
			_apply_font(badge)
			hbox.add_child(badge)

			var body_lbl := Label.new()
			body_lbl.text = text
			body_lbl.modulate = Color(0.85, 0.85, 1.0)
			body_lbl.add_theme_font_size_override("font_size", 12)
			body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_apply_font(body_lbl)
			container.add_child(body_lbl)

	return container

func _on_send_pressed() -> void:
	var text := _oracle_input.text.strip_edges()
	if text.is_empty():
		return
	if _target_option.item_count == 0:
		return
	var target_id: int = _target_option.get_item_metadata(_target_option.selected) if _target_option.selected >= 0 else -1
	if target_id < 0:
		return

	WebSocketClient.send({
		"type": "oracle_send",
		"targetId": target_id,
		"text": text,
		"spectator": is_spectator
	})
	_oracle_input.text = ""

func _on_characters_updated(chars: Array) -> void:
	_target_option.clear()
	for c in chars:
		if c.get("alive", false):
			var idx := _target_option.item_count
			_target_option.add_item(c.get("name", "?"), idx)
			_target_option.set_item_metadata(idx, c.get("id", -1))

func _on_ws_message(data: Dictionary) -> void:
	if data.get("type", "") == "oracle_stream":
		add_message(data.get("message", {}))

func clear_messages() -> void:
	for child in _msg_container.get_children():
		child.queue_free()
