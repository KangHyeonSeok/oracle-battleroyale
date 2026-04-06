## NotificationManager.gd
## VBoxContainer that spawns temporary toast-style notification labels.
## Oldest notification is auto-removed when the queue is full.
extends VBoxContainer

const MAX_ITEMS       := 5
const DEFAULT_SECS    := 3.5
const FADE_IN_SECS    := 0.18
const FADE_OUT_SECS   := 0.38
const FONT_SIZE       := 14

var _font: FontFile = null

func _ready() -> void:
	_font = ResourceLoader.load("res://fonts/NotoSansKR.ttf") as FontFile

func show_notification(text: String, duration: float = DEFAULT_SECS) -> void:
	# Drop oldest if at capacity
	if get_child_count() >= MAX_ITEMS:
		get_child(0).queue_free()

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", FONT_SIZE)
	if _font != null:
		lbl.add_theme_font_override("font", _font)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.modulate.a = 0.0
	add_child(lbl)

	var tw := create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, FADE_IN_SECS)
	tw.tween_interval(duration)
	tw.tween_property(lbl, "modulate:a", 0.0, FADE_OUT_SECS)
	tw.tween_callback(lbl.queue_free)
