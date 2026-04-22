---
specId: spectator-mode
title: 관전 모드 (진행 중인 경기 실시간 관람)
status: done
runnerProfile: developer
runnerExecution: assistant
createdAt: 2026-04-13
updatedAt: 2026-04-13
dependsOn:
  - phase-3-game-server
  - phase-5-client-godot
---

# spectator-mode: 관전 모드

## 목표
로그인한 플레이어가 현재 진행 중인 경기를 실시간으로 관전할 수 있게 한다.
직접 참가하지 않아도 캐릭터 AI 전투와 신탁 메시지를 실시간으로 볼 수 있어 재방문 동기를 높인다.

## 배경
- 현재 경기 참가자만 WebSocket 방에 join하여 상태를 수신함
- `MatchWaitingScreen` 화면에서 자신의 캐릭터를 골라 참가하는 경로만 존재
- 관전자는 신탁을 전송하지 못하지만 실시간 상태(캐릭터 HP/위치, 신탁 피드)는 볼 수 있어야 함
- 관전자 존재는 서버 게임 루프에 영향을 주지 않아야 함

---

## 서버 변경

### WebSocket — 관전자 join 메시지

기존 `join` 메시지 외에 `spectate` 메시지 타입 추가:

```json
{ "type": "spectate", "matchId": "uuid" }
```

- `matchId`에 해당하는 진행 중(`status = 'active'`) 경기에 해당 WS 소켓을 spectator로 추가
- spectator 소켓은 해당 match room의 브로드캐스트를 그대로 수신
- spectator는 `oracle`, `join` 메시지 전송 불가 (무시 또는 `403` 반환)
- 경기 종료 시 spectator 소켓에도 `game_over` 브로드캐스트

### REST API

#### `GET /spectate`
- 현재 `status = 'active'` 인 경기 목록 반환
- 응답:
```json
{
  "matches": [
    {
      "matchId": "uuid",
      "startedAt": "ISO8601",
      "participantCount": 12,
      "turnCount": 5,
      "spectatorCount": 3
    }
  ]
}
```

#### `spectatorCount` 추적
- 서버 메모리 내 Map으로 `matchId → Set<socketId>` 관리 (DB 저장 불필요)
- spectator disconnect 시 Set에서 제거

---

## 파일 목록

### 서버

| 파일 | 내용 |
|------|------|
| `server/src/ws/spectate.js` | spectate 메시지 핸들러, room join/leave 로직 |
| `server/src/ws/index.js` | `spectate` 메시지 타입 라우팅 추가 |
| `server/src/game/routes.js` | `GET /spectate` 엔드포인트 추가 |
| `server/src/app.js` | spectate 라우터 등록 |

### 클라이언트 (Godot)

| 파일 | 내용 |
|------|------|
| `client/scenes/SpectateListScreen.tscn` | 관전 가능 경기 목록 씬 |
| `client/scripts/SpectateListScreen.gd` | GET /spectate 호출, 경기 카드 목록, 선택 → Arena 진입 |
| `client/scripts/Arena.gd` | `@export var spectator_mode: bool = false` 추가. `_ready()` 시 true면 OraclePanel 숨김, "관전 중" 레이블 표시. WS `game_over` 수신 시 spectator_mode=true이면 `Main.show_screen("spectate_list")` 호출 |
| `client/scripts/SpectateListScreen.gd` — 관전 경기 선택 시 `Main.gd`의 `show_arena_spectate(match_id)` 호출 |
| `client/scripts/Main.gd` | `spectate_list` 화면 전환 추가, `show_arena_spectate(match_id: String)` 메서드 추가 — `current_spectate_match_id` 저장 후 Arena 씬 로드, `Arena.spectator_mode = true` 설정 |
| `client/scripts/CharacterListScreen.gd` | "관전하기" 버튼 추가 → `Main.show_screen("spectate_list")` 호출 |

---

## UI 구성

### SpectateListScreen
- 상단: "진행 중인 경기" 타이틀 + "돌아가기" 버튼 → CharacterListScreen
- 경기 카드: `[시작 시간] [참가자 수] [턴 수] [관전자 수]`
- 경기 없을 때: "현재 진행 중인 경기가 없습니다" 빈 상태
- 카드 클릭 → Arena 씬으로 이동 (spectator_mode = true)

### Arena (관전 모드)
- OraclePanel(신탁 전송 UI) 숨김 처리
- 화면 상단에 "👁 관전 중" 레이블 표시 (ACCENT_PURPLE)
- 경기 종료 시 `game_over` 수신 → GameResultScreen 대신 SpectateListScreen으로 복귀

---

## 완료 기준 (Acceptance Criteria)

1. **AC1** — `GET /spectate` 호출 시 status=active 경기 목록 반환. 없으면 빈 배열.
2. **AC2** — WS `spectate` 메시지 전송 시 해당 match의 브로드캐스트를 수신 시작 (join과 동일 이벤트 수신)
3. **AC3** — 관전자가 `oracle` 메시지 전송 시 서버가 무시 (점수 차감 없음)
4. **AC4** — SpectateListScreen에서 경기 선택 후 Arena 화면에서 실시간 캐릭터 상태(HP, 위치, 신탁 피드) 수신
5. **AC5** — Arena 관전 모드: OraclePanel 비표시, "👁 관전 중" 레이블 표시
6. **AC6** — 경기 종료 시 관전자는 SpectateListScreen으로 복귀 (참가자와 다른 종료 흐름)
7. **AC7** — CharacterListScreen에 "관전하기" 버튼 추가 → SpectateListScreen 진입
8. **AC8** — spectatorCount가 `/spectate` 응답에 실시간 반영됨 (WS 연결/해제 기준)

---

## 엣지케이스

| 케이스 | 서버 응답 | 클라이언트 처리 |
|--------|-----------|-----------------|
| 관전 중 경기 종료 | `game_over` 브로드캐스트 | Arena → SpectateListScreen 복귀 |
| 없는 matchId로 spectate | WS 오류 메시지 `{ type: "error", code: "not_found" }` | Arena 진입 없이 SpectateListScreen 유지 |
| 비인증 관전 요청 | HTTP 401 / WS 연결 거부 | LoginScreen 리다이렉트 |
| 경기 목록 API 실패 | HTTP 500 | 에러 레이블 + "다시 시도" 버튼 |

---

## 제약
- 관전자는 서버 게임 루프(AI 턴 처리)에 영향 없음
- spectatorCount는 DB 저장 없이 메모리만 사용
- 관전자 수 상한 없음 (브로드캐스트 팬아웃 방식 유지)

## 예상 기간
0.5주
