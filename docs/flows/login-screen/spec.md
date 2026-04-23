---
specId: login-screen
title: Google 로그인 화면
status: queued
owner: partner
runnerProfile: developer
runnerExecution: assistant
createdAt: 2026-04-22
updatedAt: 2026-04-22
dependsOn: []
---

# login-screen: Google 로그인 화면

## 목표

앱 진입 시 세션 상태를 확인하여, 미인증 사용자에게 Google OAuth 로그인 화면을 표시한다.
로그인 완료 후 CharacterListScreen으로 자동 진입한다.

## 배경

- 서버에 Google OAuth (passport-google-oauth20) + Redis 세션 스토어가 이미 구현되어 있음
- `GET /auth/me` → 401 (미인증) / 200 + user JSON (인증됨)
- `GET /auth/google` → OAuth 플로우 시작, 성공 시 `CLIENT_ORIGIN`으로 리다이렉트
- 현재 Godot 클라이언트는 인증 확인 없이 바로 CharacterListScreen 표시 → WS 연결 시 "Not authenticated" 에러 발생
- WebSocketClient.gd가 서버 URL을 `window.location.host`에서 자동 유도하는 패턴을 그대로 사용 가능

## 환경 변수 (서버, 기존 미설정 시 필요)

| 변수 | 예시 |
|------|------|
| `GOOGLE_CLIENT_ID` | Google Cloud Console에서 발급 |
| `GOOGLE_CLIENT_SECRET` | Google Cloud Console에서 발급 |
| `GOOGLE_CALLBACK_URL` | `https://<server-domain>/auth/google/callback` |
| `CLIENT_ORIGIN` | `https://oracle-battleroyale.vercel.app` |

서버 코드 변경 없음. 환경변수만 필요.

---

## 구현 범위

### 파일 1: `client/scripts/LoginScreen.gd` (신규)

```gdscript
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
		# 서버 URL을 현재 페이지 host에서 자동 유도 (WebSocketClient와 동일 패턴)
		var protocol: String = JavaScriptBridge.eval("window.location.protocol")
		var host: String     = JavaScriptBridge.eval("window.location.host")
		var scheme: String   = "https" if protocol == "https:" else "http"
		var auth_url: String = "%s://%s/auth/google" % [scheme, host]
		JavaScriptBridge.eval("window.location.href = '%s'" % auth_url)
	else:
		# 로컬 개발 환경 폴백
		emit_signal("login_requested")
```

**주의**: 서버와 클라이언트가 같은 도메인에 서빙되는 경우 (`window.location.host` = 서버 host).
Vercel + 별도 서버 구조라면 `window.WS_URL`에서 서버 host를 유도해야 함 (아래 참고).

서버가 별도 도메인인 경우 `_on_login_pressed` 내 `host` 유도 코드:
```gdscript
# WS_URL (wss://server-host/ws) → https://server-host
var ws_url: String = JavaScriptBridge.eval(
    "(function(){ return window.WS_URL || ''; })()"
)
if ws_url != "":
    # wss://host/ws → https://host
    var http_url := ws_url.replace("wss://", "https://").replace("ws://", "http://")
    http_url = http_url.split("/ws")[0]
    auth_url = http_url + "/auth/google"
```

---

### 파일 2: `client/scripts/GameState.gd` (수정)

`GameState.gd` 상단 변수 선언 영역에 추가:

```gdscript
## 현재 로그인된 사용자 정보. /auth/me 응답 저장. 비로그인 시 빈 Dictionary.
var current_user: Dictionary = {}
```

---

### 파일 3: `client/scripts/Main.gd` (수정)

#### 3-1. 상수/변수 추가

스크립트 상단 변수 영역에 추가:

```gdscript
const LOGIN_SCRIPT := preload("res://scripts/LoginScreen.gd")

var _login_screen: Control
var _http_auth: HTTPRequest
```

#### 3-2. `_build_ui()` 수정

`_build_ui()` 내부에서 `_char_list_screen` 초기화 블록 **위에** LoginScreen 초기화 추가:

```gdscript
# ── LoginScreen ──
_login_screen = Control.new()
_login_screen.set_script(LOGIN_SCRIPT)
_login_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
_login_screen.visible = false
ui.add_child(_login_screen)
_login_screen.login_requested.connect(func(): _show_screen("login"))  # 데스크탑 폴백용
```

#### 3-3. `_ready()` 수정

기존 `_show_screen("char_list")` 줄을 제거하고 `_check_auth()` 호출로 교체:

```gdscript
# 변경 전
_show_screen("char_list")

# 변경 후
_check_auth()
```

#### 3-4. `_check_auth()` 함수 추가

```gdscript
func _check_auth() -> void:
	_http_auth = HTTPRequest.new()
	add_child(_http_auth)
	_http_auth.request_completed.connect(_on_auth_check_completed)

	var server_base := _get_server_http_base()
	var headers := ["Content-Type: application/json"]
	# credentials: include — Godot HTTPRequest는 쿠키를 자동 전송하지 않으므로
	# 웹 빌드에서는 JS fetch를 쓰거나, Godot 4.3+ HTTPRequest에 credentials 추가 필요.
	# 현재는 Godot HTTPRequest 사용; 쿠키 자동 전송 동작 확인 후 필요 시 JS fetch로 대체.
	var err := _http_auth.request(server_base + "/auth/me", headers, HTTPClient.METHOD_GET)
	if err != OK:
		push_error("[Auth] HTTPRequest failed: %d" % err)
		_show_screen("login")

func _get_server_http_base() -> String:
	if OS.has_feature("web"):
		var ws_url: String = JavaScriptBridge.eval(
			"(function(){ return window.WS_URL || ''; })()"
		)
		if ws_url != "":
			var base := ws_url.replace("wss://", "https://").replace("ws://", "http://")
			return base.split("/ws")[0]
		var protocol: String = JavaScriptBridge.eval("window.location.protocol")
		var host: String     = JavaScriptBridge.eval("window.location.host")
		var scheme: String   = "https" if protocol == "https:" else "http"
		return "%s://%s" % [scheme, host]
	return "http://localhost:3000"

func _on_auth_check_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code == 401:
		_show_screen("login")
		return
	if response_code == 200:
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			GameState.current_user = json.data as Dictionary
		_show_screen("char_list")
	else:
		# 예상치 못한 상태 코드 — 로그인 화면으로 폴백
		_show_screen("login")
```

#### 3-5. `_show_screen()` 수정

`_show_screen()` 함수에 `"login"` case 추가:

```gdscript
func _show_screen(name: String) -> void:
	_login_screen.visible        = (name == "login")
	_char_list_screen.visible    = (name == "char_list")
	_char_create_screen.visible  = (name == "char_create")
	_match_wait_screen.visible   = (name == "match_wait")
	_game_result_screen.visible  = (name == "game_result")
	_spectate_list_screen.visible = (name == "spectate_list")
	_match_history_screen.visible = (name == "match_history")
	_match_detail_screen.visible  = (name == "match_detail")
	_leaderboard_screen.visible   = (name == "leaderboard")
	_hud.visible                  = (name == "arena")
	_oracle_stream.visible        = (name == "arena")
```

> `_show_screen`이 현재 어떻게 구현되어 있는지 확인 후 동일한 패턴으로 login case를 추가할 것.

---

## 검증 기준 (Acceptance Criteria)

| # | 조건 | 검증 방법 |
|---|------|-----------|
| AC1 | 미인증 상태로 앱 로드 시 LoginScreen이 표시됨 | `/auth/me` mock 401 후 `_login_screen.visible == true` 확인 |
| AC2 | 인증 상태로 앱 로드 시 CharacterListScreen이 바로 표시됨 | `/auth/me` mock 200 후 `_char_list_screen.visible == true` 확인 |
| AC3 | LoginScreen에 "Google로 로그인" 버튼이 표시됨 | 씬 트리에서 버튼 텍스트 확인 |
| AC4 | 웹 빌드에서 버튼 클릭 시 `/auth/google` 경로로 리다이렉트 됨 | `JavaScriptBridge.eval` 호출 확인 (로컬에서는 console.log 패치로 검증) |
| AC5 | 로그인 성공 후 `GameState.current_user`에 displayName, constellationPoints 저장됨 | `/auth/me` 200 응답 mock 후 `GameState.current_user["displayName"]` 비어있지 않음 |
| AC6 | 서버가 별도 도메인일 때(`window.WS_URL` 설정 시) 올바른 서버 URL로 auth 요청 | `WS_URL = "wss://api.example.com/ws"` → auth 요청이 `https://api.example.com/auth/me`로 감 |

---

## 주의 사항

1. **Godot HTTPRequest 쿠키 전송**: Godot 4 WebAssembly 빌드에서 HTTPRequest가 브라우저 쿠키를 자동 포함하는지 확인 필요. 포함 안 되면 `JavaScriptBridge.eval`로 `fetch('/auth/me', {credentials: 'include'})`를 직접 호출하는 방식으로 교체.
2. **`_show_screen()` 기존 구현 확인**: 현재 `_show_screen` 함수 내 visibility 목록에 `_login_screen` case를 추가해야 함. 존재하지 않으면 신규 작성.
3. **서버 환경변수**: `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_CALLBACK_URL`, `CLIENT_ORIGIN`이 서버에 설정되어 있어야 OAuth가 작동함.
