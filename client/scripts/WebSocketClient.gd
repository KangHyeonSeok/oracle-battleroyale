## WebSocketClient.gd
## Autoload singleton — manages WebSocket connection to the Oracle Battle Royale server.
## Reconnects automatically every 5 seconds on disconnect.
extends Node

signal connected_to_server
signal disconnected_from_server
signal message_received(data: Dictionary)

## Default URL; overridden at runtime from JS window.WS_URL or query param ws_url.
var url: String = "ws://localhost:3000/ws"

var _socket: WebSocketPeer
var _reconnect_timer: Timer
var _is_connected: bool = false
var _ping_timer: Timer

func _ready() -> void:
	# Allow runtime URL override when running in the browser
	if OS.has_feature("web"):
		var js_val: String = JavaScriptBridge.eval(
			"(function(){ return window.WS_URL || new URLSearchParams(window.location.search).get('ws_url') || ''; })()"
		)
		if js_val != "":
			url = js_val
		else:
			# Derive from page host: https://host → wss://host/ws
			var host: String = JavaScriptBridge.eval("window.location.host")
			if host != "":
				var scheme: String = "wss" if JavaScriptBridge.eval("window.location.protocol") == "https:" else "ws"
				url = "%s://%s/ws" % [scheme, host]

	_reconnect_timer = Timer.new()
	_reconnect_timer.wait_time = 5.0
	_reconnect_timer.one_shot = true
	_reconnect_timer.timeout.connect(_attempt_connect)
	add_child(_reconnect_timer)

	_ping_timer = Timer.new()
	_ping_timer.wait_time = 30.0
	_ping_timer.one_shot = false
	_ping_timer.timeout.connect(_send_ping)
	add_child(_ping_timer)

	_attempt_connect()

func _attempt_connect() -> void:
	_socket = WebSocketPeer.new()
	var err := _socket.connect_to_url(url)
	if err != OK:
		push_error("[WS] connect error %d — retrying in 5s" % err)
		_reconnect_timer.start()

func _process(_delta: float) -> void:
	if _socket == null:
		return
	_socket.poll()
	var state := _socket.get_ready_state()
	match state:
		WebSocketPeer.STATE_OPEN:
			if not _is_connected:
				_is_connected = true
				_ping_timer.start()
				connected_to_server.emit()
			_drain_packets()
		WebSocketPeer.STATE_CLOSING:
			pass
		WebSocketPeer.STATE_CLOSED:
			if _is_connected:
				_is_connected = false
				_ping_timer.stop()
				disconnected_from_server.emit()
				_reconnect_timer.start()

func _drain_packets() -> void:
	while _socket.get_available_packet_count() > 0:
		var raw := _socket.get_packet()
		var text := raw.get_string_from_utf8()
		var json := JSON.new()
		if json.parse(text) == OK:
			message_received.emit(json.data as Dictionary)
		else:
			push_warning("[WS] failed to parse: " + text)

func send(data: Dictionary) -> void:
	if _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.send_text(JSON.stringify(data))
	else:
		push_warning("[WS] send called while not connected")

func _send_ping() -> void:
	send({"type": "ping"})

# ── Convenience helpers ──────────────────────────────────────────────────────

func join_match(match_id: int, character_id: int = -1) -> void:
	var msg := {"type": "join_match", "matchId": match_id}
	if character_id >= 0:
		msg["characterId"] = character_id
	send(msg)

func leave_match(match_id: int) -> void:
	send({"type": "leave_match", "matchId": match_id})

func is_open() -> bool:
	return _is_connected
