## Arena.gd
## Draws the 800×800 colosseum arena floor, walls, and procedurally-placed pillars/debris.
## Uses a fixed RNG seed so the layout is deterministic across all clients.
extends Node2D

const MAP_SIZE    := 800.0
const WALL_SIZE   := 20.0

## Obstacle settings
const OBS_COUNT   := 14
const OBS_MIN     := 22.0
const OBS_MAX     := 52.0
const RNG_SEED    := 42_195   # fixed → all clients see the same map

## Colors
const C_FLOOR     := Color(0.10, 0.10, 0.13)
const C_GRID      := Color(0.14, 0.14, 0.17)
const C_WALL      := Color(0.28, 0.28, 0.33)
const C_OBSTACLE  := Color(0.22, 0.22, 0.27)
const C_OBS_EDGE  := Color(1.0, 1.0, 1.0, 0.18)
const C_BORDER    := Color(1.0, 1.0, 1.0, 0.25)

## Set to true when the local player is watching as a spectator (not a participant).
var spectator_mode: bool = false

var _obstacles: Array[Rect2] = []

func _ready() -> void:
	_generate_obstacles()
	queue_redraw()

func _generate_obstacles() -> void:
	_obstacles.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED

	var margin    := 60.0
	var center_ex := Rect2(MAP_SIZE / 2 - 90, MAP_SIZE / 2 - 90, 180, 180)
	var attempts  := 0

	while _obstacles.size() < OBS_COUNT and attempts < 400:
		attempts += 1
		var sz := rng.randf_range(OBS_MIN, OBS_MAX)
		var x  := rng.randf_range(margin, MAP_SIZE - margin - sz)
		var y  := rng.randf_range(margin, MAP_SIZE - margin - sz)
		var r  := Rect2(x, y, sz, sz)

		if center_ex.intersects(r):
			continue
		var overlap := false
		for ex in _obstacles:
			if ex.grow(10.0).intersects(r):
				overlap = true
				break
		if not overlap:
			_obstacles.append(r)

func _draw() -> void:
	# Floor
	draw_rect(Rect2(0, 0, MAP_SIZE, MAP_SIZE), C_FLOOR)

	# Subtle grid
	var step := 80.0
	var g := step
	while g < MAP_SIZE:
		draw_line(Vector2(g, 0),        Vector2(g, MAP_SIZE),  C_GRID, 1.0)
		draw_line(Vector2(0, g),        Vector2(MAP_SIZE, g),  C_GRID, 1.0)
		g += step

	# Walls (4 edges)
	draw_rect(Rect2(0, 0,                   MAP_SIZE, WALL_SIZE), C_WALL)  # top
	draw_rect(Rect2(0, MAP_SIZE - WALL_SIZE, MAP_SIZE, WALL_SIZE), C_WALL)  # bottom
	draw_rect(Rect2(0, 0,                   WALL_SIZE, MAP_SIZE), C_WALL)  # left
	draw_rect(Rect2(MAP_SIZE - WALL_SIZE, 0, WALL_SIZE, MAP_SIZE), C_WALL)  # right

	# Obstacles (pillars / debris)
	for obs in _obstacles:
		draw_rect(obs, C_OBSTACLE)
		draw_rect(obs, C_OBS_EDGE, false, 1.5)
		# Bevel highlights
		draw_rect(Rect2(obs.position,                  Vector2(obs.size.x, 3)), Color(1,1,1,0.08))
		draw_rect(Rect2(obs.position,                  Vector2(3, obs.size.y)), Color(1,1,1,0.08))

	# Outer border
	draw_rect(Rect2(0, 0, MAP_SIZE, MAP_SIZE), C_BORDER, false, 2.0)

## Returns obstacle rects so Character collision avoidance can use them if needed.
func get_obstacle_rects() -> Array[Rect2]:
	return _obstacles
