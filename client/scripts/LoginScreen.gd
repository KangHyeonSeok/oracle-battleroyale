## LoginScreen.gd
## 미인증 사용자에게 Google 로그인 버튼을 표시하는 화면.
## Main.gd에서 /auth/me 확인 후 401이면 이 화면을 show.
extends Control

signal login_requested

const ACCENT_PURPLE := Color(0.545, 0.361, 0.965)
const BG_DARK       := Color(0.07, 0.07, 0.12)

var _korean_font: FontFile = null

func _ready() -> void:
	_korean_font = ResourceLoader.load("res://fonts/NotoSansKR.ttf") as FontFile
	_build_ui()

func _build_ui() -> void:
	# 전체 배경
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG_DARK
	add_child(bg)

	# 중앙 컨테이너
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.add_theme_constant_override("separation", 24)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(center)

	# 게임 제목
	var title_lbl := Label.new()
	title_lbl.text = "성좌 배틀로얄"
	title_lbl.add_theme_font_size_override("font_size", 36)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _korean_font:
		title_lbl.add_theme_font_override("font", _korean_font)
	center.add_child(title_lbl)

	# 부제
	var sub_lbl := Label.new()
	sub_lbl.text = "AI 성좌들의 콜로세움"
	sub_lbl.add_theme_font_size_override("font_size", 16)
	sub_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _korean_font:
		sub_lbl.add_theme_font_override("font", _korean_font)
	center.add_child(sub_lbl)

	# 간격
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	center.add_child(spacer)

	# Google 로그인 버튼
	var btn := Button.new()
	btn.text = "Google로 로그인"
	btn.custom_minimum_size = Vector2(240, 56)
	btn.add_theme_font_size_override("font_size", 18)
	if _korean_font:
		btn.add_theme_font_override("font", _korean_font)

	var style := StyleBoxFlat.new()
	style.bg_color = ACCENT_PURPLE
	style.corner_radius_top_left    = 12
	style.corner_radius_top_right   = 12
	style.corner_radius_bottom_left  = 12
	style.corner_radius_bottom_right = 12
	btn.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.65, 0.46, 1.0)
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.pressed.connect(_on_login_pressed)
	center.add_child(btn)

func _on_login_pressed() -> void:
	if OS.has_feature("web"):
		# WS_URL (wss://server-host/ws) → https://server-host
		var ws_url: String = JavaScriptBridge.eval(
			"(function(){ return window.WS_URL || ''; })()"
		)
		var auth_url: String
		if ws_url != "":
			var http_url := ws_url.replace("wss://", "https://").replace("ws://", "http://")
			http_url = http_url.split("/ws")[0]
			auth_url = http_url + "/auth/google"
		else:
			# 서버와 클라이언트가 같은 도메인인 경우
			var protocol: String = JavaScriptBridge.eval("window.location.protocol")
			var host: String     = JavaScriptBridge.eval("window.location.host")
			var scheme: String   = "https" if protocol == "https:" else "http"
			auth_url = "%s://%s/auth/google" % [scheme, host]
		JavaScriptBridge.eval("window.location.href = '%s'" % auth_url)
	else:
		# 로컬 개발 환경 폴백
		emit_signal("login_requested")
