## GameState.gd
## Autoload singleton — mirrors server-side match state and exposes oracle point tracking.
extends Node

signal characters_updated(characters: Array)
signal turn_advanced(turn: int, events: Array)
signal game_ended(winner_id: int, winner_name: String)
signal match_joined(match_id: int)
signal oracle_used(character_id: int, character_name: String)

# New signals for character management, matchmaking, and oracle stream
signal characters_loaded(chars: Array)
signal queue_updated(count: int, total: int)
signal match_found(match_id: int)
signal oracle_message_received(msg: Dictionary)
signal character_created(data: Dictionary)
signal character_preview_received(data: Dictionary)

var current_match_id: int = -1
var current_turn: int = 0
var characters: Array = []
var alive_count: int = 0

## Oracle points start at 100, cost 5 each; cooldown is 60 s (server: 1/min)
var oracle_points: int = 100
var oracle_cooldown_remaining: float = 0.0
const ORACLE_COST: int = 5
const ORACLE_COOLDOWN: float = 60.0

var is_in_game: bool = false

# Player's saved characters (account-level)
var my_characters: Array = []

# Oracle stream message history
var oracle_stream_messages: Array = []

# Matchmaking queue state
var queue_participant_count: int = 0

func _ready() -> void:
	WebSocketClient.message_received.connect(_on_message)
	WebSocketClient.connected_to_server.connect(_on_connected)

func _process(delta: float) -> void:
	if oracle_cooldown_remaining > 0.0:
		oracle_cooldown_remaining = maxf(0.0, oracle_cooldown_remaining - delta)

func _on_connected() -> void:
	print("[GameState] connected to server")

func _on_message(data: Dictionary) -> void:
	match data.get("type", ""):
		"connected":
			print("[GameState] server: ", data.get("message", ""))
		"joined_match":
			current_match_id = data.get("matchId", -1)
			is_in_game = true
			match_joined.emit(current_match_id)
		"state_sync":
			_apply_state(data.get("state", {}))
		"turn_result":
			current_turn = data.get("turn", 0)
			characters = data.get("characters", [])
			alive_count = data.get("aliveCount", 0)
			var events: Array = data.get("events", [])
			characters_updated.emit(characters)
			turn_advanced.emit(current_turn, events)
			_check_oracle_events(events)
		"game_over":
			is_in_game = false
			game_ended.emit(data.get("winnerId", -1), data.get("winnerName", ""))
		"pong":
			pass
		"error":
			push_error("[GameState] server error: " + data.get("message", ""))
		# ── New message types ────────────────────────────────────────────────
		"my_characters":
			my_characters = data.get("characters", [])
			characters_loaded.emit(my_characters)
		"queue_update":
			queue_participant_count = data.get("count", queue_participant_count)
			queue_updated.emit(data.get("count", 0), data.get("total", 32))
		"match_found":
			match_found.emit(data.get("matchId", -1))
		"character_created":
			var char_data: Dictionary = data.get("character", {})
			my_characters.append(char_data)
			character_created.emit(char_data)
		"character_preview":
			character_preview_received.emit(data.get("character", {}))
		"oracle_stream":
			var msg: Dictionary = data.get("message", {})
			oracle_stream_messages.append(msg)
			oracle_message_received.emit(msg)

func _apply_state(state: Dictionary) -> void:
	current_turn = state.get("turn", 0)
	characters = state.get("characters", [])
	alive_count = 0
	for c in characters:
		if c.get("alive", false):
			alive_count += 1
	characters_updated.emit(characters)

func _check_oracle_events(events: Array) -> void:
	for event in events:
		if event.get("type") == "oracle_override":
			oracle_used.emit(event.get("characterId", -1), event.get("name", ""))

# ── Helpers ──────────────────────────────────────────────────────────────────

func get_character_by_id(char_id: int) -> Dictionary:
	for c in characters:
		if c.get("id") == char_id:
			return c
	return {}

func can_use_oracle() -> bool:
	return oracle_points >= ORACLE_COST and oracle_cooldown_remaining <= 0.0

func use_oracle() -> bool:
	if not can_use_oracle():
		return false
	oracle_points -= ORACLE_COST
	oracle_cooldown_remaining = ORACLE_COOLDOWN
	return true
