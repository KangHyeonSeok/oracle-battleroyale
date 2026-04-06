## Character.gd
## Represents one combatant on the arena.
## Receives position/HP updates from GameState and animates movement.
## Emits character_clicked when the player clicks on this node.
extends Node2D

signal character_clicked(char_id: int)

var char_id:    int    = -1
var char_name:  String = ""
var char_class: String = ""
var current_hp: int    = 100
var max_hp:     int    = 100
var is_alive:   bool   = true

const RADIUS       := 16.0
const HP_W         := 42.0
const HP_H         :=  6.0
const HP_OFFSET_Y  := -30.0
const MOVE_SECS    :=  0.45

## Per-class body colours
const CLASS_COLORS := {
	"warrior": Color(0.85, 0.22, 0.22),
	"mage":    Color(0.25, 0.45, 0.95),
	"archer":  Color(0.20, 0.72, 0.25),
	"rogue":   Color(0.62, 0.18, 0.82),
	"healer":  Color(0.92, 0.80, 0.10),
}

var _name_label: Label
var _area:       Area2D
var _tween:      Tween

func _ready() -> void:
	# Click detection via Area2D + CircleShape2D
	_area = Area2D.new()
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	col.shape = shape
	_area.add_child(col)
	add_child(_area)
	_area.input_pickable = true
	_area.input_event.connect(_on_area_input)

	# Name label above the character
	_name_label = Label.new()
	_name_label.position = Vector2(-22, -50)
	_name_label.custom_minimum_size = Vector2(44, 14)
	_name_label.add_theme_font_size_override("font_size", 10)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.modulate = Color(0.9, 0.9, 0.9)
	add_child(_name_label)

func setup(data: Dictionary) -> void:
	char_id    = data.get("id",    -1)
	char_name  = data.get("name",  "?")
	char_class = (data.get("class", "warrior") as String).to_lower()
	max_hp     = 100
	_name_label.text = char_name
	# Immediately place character without animation on first spawn
	position = Vector2(data.get("x", 400.0), data.get("y", 400.0))

func update_from_data(data: Dictionary) -> void:
	var tx: float = data.get("x", position.x)
	var ty: float = data.get("y", position.y)
	current_hp = data.get("hp",    0)
	is_alive   = data.get("alive", false)

	# Smooth movement tween
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "position", Vector2(tx, ty), MOVE_SECS)

	modulate.a = 1.0 if is_alive else 0.28
	queue_redraw()

func _draw() -> void:
	var body_color: Color = CLASS_COLORS.get(char_class, Color(0.5, 0.5, 0.5))
	if not is_alive:
		body_color = Color(0.30, 0.30, 0.30)

	# Shadow
	draw_circle(Vector2(2, 3), RADIUS, Color(0, 0, 0, 0.35))
	# Body
	draw_circle(Vector2.ZERO, RADIUS, body_color)
	# Rim highlight
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, Color(1, 1, 1, 0.30), 1.5)

	# HP bar background
	draw_rect(
		Rect2(Vector2(-HP_W / 2, HP_OFFSET_Y), Vector2(HP_W, HP_H)),
		Color(0.08, 0.08, 0.08)
	)
	# HP bar fill
	var ratio := clampf(float(current_hp) / float(max_hp), 0.0, 1.0)
	var hp_color := Color.GREEN
	if ratio < 0.30:
		hp_color = Color.RED
	elif ratio < 0.60:
		hp_color = Color.YELLOW
	draw_rect(
		Rect2(Vector2(-HP_W / 2, HP_OFFSET_Y), Vector2(HP_W * ratio, HP_H)),
		hp_color
	)
	# HP bar border
	draw_rect(
		Rect2(Vector2(-HP_W / 2, HP_OFFSET_Y), Vector2(HP_W, HP_H)),
		Color(1, 1, 1, 0.20), false, 1.0
	)

func _on_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		character_clicked.emit(char_id)
