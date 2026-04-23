---
specId: connection-resilience
title: WebSocket 자동 재연결 & 세션 복구
status: queued
owner: partner
runnerProfile: developer
runnerExecution: assistant
createdAt: 2026-04-15
updatedAt: 2026-04-15
dependsOn:
  - phase-5-client-godot
  - phase-3-game-server
---

# connection-resilience: WebSocket 자동 재연결 & 세션 복구

## 목표
게임 중 네트워크 단절 시 자동으로 재연결하여 플레이어가 경기에 복귀할 수 있도록 한다. 현재는 WS 연결이 끊기면 복구 방법이 없어 게임 포기 또는 새로고침 필요.

## 배경
- `WebSocketClient.gd`는 연결 실패 시 별도 재연결 로직 없음
- 모바일/불안정 환경에서 일시적 단절 후 자동 복구가 없으면 플레이어 이탈
- 서버는 이미 세션/게임 상태를 Redis에 저장 중 — 재연결 후 상태 재수신 가능
- 재연결은 클라이언트 단 처리로 충분 (서버 추가 엔드포인트 불필요)

---

## 구현 범위

### 파일: `client/scripts/WebSocketClient.gd` (수정)

#### 1. 재연결 상수 및 변수 추가

```gdscript
const MAX_RETRY = 5
const RETRY_BASE_SEC = 2.0  # 지수 백오프: 2, 4, 8, 16, 32초

var _retry_count: int = 0
var _retry_timer: SceneTreeTimer = null
var _intentional_close: bool = false
```

#### 2. `_on_connection_closed()` 수정 — 자동 재연결 트리거

```gdscript
func _on_connection_closed() -> void:
    emit_signal("disconnected")
    if _intentional_close:
        _intentional_close = false
        return
    if _retry_count >= MAX_RETRY:
        emit_signal("reconnect_failed")
        return
    var delay := RETRY_BASE_SEC * pow(2.0, _retry_count)
    _retry_count += 1
    _retry_timer = get_tree().create_timer(delay)
    _retry_timer.timeout.connect(_attempt_reconnect)

func _attempt_reconnect() -> void:
    connect_to_server(GameState.server_url)
```

#### 3. `connect_to_server()` 수정 — 연결 성공 시 retry 카운터 초기화

```gdscript
func _on_connection_established() -> void:
    _retry_count = 0
    emit_signal("connected")
```

#### 4. `disconnect_from_server()` — 의도적 종료 플래그

```gdscript
func disconnect_from_server() -> void:
    _intentional_close = true
    _ws.close()
```

#### 5. 시그널 추가

```gdscript
signal reconnect_failed   # MAX_RETRY 초과 시 Main.gd에서 에러 화면 전환
signal reconnecting(attempt: int, max_attempt: int)  # UI에 재연결 시도 표시용
```

---

### 파일: `client/scripts/Main.gd` (수정)

#### 재연결 실패 시 에러 팝업

```gdscript
func _ready() -> void:
    # 기존 연결 코드 아래에 추가
    WebSocketClient.reconnect_failed.connect(_on_ws_reconnect_failed)

func _on_ws_reconnect_failed() -> void:
    var dialog := AcceptDialog.new()
    dialog.title = "연결 실패"
    dialog.dialog_text = "서버와의 연결이 끊겼습니다.\n페이지를 새로고침하거나 잠시 후 다시 시도해 주세요."
    add_child(dialog)
    dialog.popup_centered()
```

---

## 파일 목록

| 파일 | 변경 내용 |
|------|-----------|
| `client/scripts/WebSocketClient.gd` | 지수 백오프 재연결 로직, reconnect_failed/reconnecting 시그널 추가 |
| `client/scripts/Main.gd` | reconnect_failed 시그널 연결, 에러 팝업 추가 |

서버 변경 없음.

---

## 완료 기준 (AC)

| AC | 내용 |
|----|------|
| AC1 | 게임 중 WS 연결 끊김 시 2초 후 자동 재연결 시도 |
| AC2 | 재연결 성공 시 게임 화면 유지, 상태는 서버 다음 WS 메시지로 복구 |
| AC3 | 재연결 실패 시 지수 백오프 적용 (2→4→8→16→32초) |
| AC4 | 5회 재연결 실패 시 `reconnect_failed` 시그널 발생 → 에러 팝업 표시 |
| AC5 | 의도적 disconnect (화면 전환 등)는 재연결 트리거하지 않음 |

---

## 엣지케이스

| 케이스 | 처리 |
|--------|------|
| 재연결 도중 화면 전환 | `_intentional_close = true` 후 `close()` → 재연결 루프 중단 |
| 재연결 타이머 중복 생성 | `_retry_timer != null` 체크 후 기존 타이머 무효화 |
| 서버 재시작으로 세션 소멸 | 재연결 후 서버 WS 에러 수신 → 기존 에러 처리 경로 유지 |

---

## 예상 기간
0.5일 (클라이언트 단 변경, 서버 없음)
