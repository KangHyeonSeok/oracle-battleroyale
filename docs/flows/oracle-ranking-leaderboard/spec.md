---
specId: oracle-ranking-leaderboard
title: 성좌 랭킹 리더보드
status: queued
owner: partner
runnerProfile: developer
runnerExecution: assistant
createdAt: 2026-04-12
updatedAt: 2026-04-13
dependsOn: oracle-point-system
---

# oracle-ranking-leaderboard: 성좌 랭킹 리더보드

## 목표
신탁 포인트 기준 상위 20명을 보여주는 리더보드 API와 Godot 클라이언트 화면을 구현한다.
플레이어는 캐릭터 목록 화면에서 리더보드로 진입할 수 있다.

## 배경
- `oracle-point-system`에서 `users.constellation_points` 및 포인트 트랜잭션이 정의됨 (실제 컬럼명 `constellation_points`, 응답 alias `oracle_points`)
- 현재 포인트 잔액은 있지만 플레이어 간 비교/랭킹 화면이 없음
- 승률·신탁 횟수를 함께 표시하면 게임 깊이가 생기고 재방문 동기가 생김

---

## 데이터 모델 추가

### 서버: `server/migrations/007_leaderboard.sql` (✅ 구현 완료)

```sql
-- 경기 기록 집계를 위한 뷰 (매번 집계 쿼리 대신 캐시용)
CREATE TABLE IF NOT EXISTS player_stats (
  account_id INTEGER PRIMARY KEY REFERENCES users(id),
  total_matches INTEGER NOT NULL DEFAULT 0,
  total_wins    INTEGER NOT NULL DEFAULT 0,
  oracle_sent   INTEGER NOT NULL DEFAULT 0,  -- 누적 신탁 전송 횟수
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);
```

- `total_matches`, `total_wins`: 경기 종료 시 `server/src/game/turn-scheduler.js`에서 upsert (✅ 구현됨)
- `oracle_sent`: 신탁 전송 성공 시 `server/src/oracle/routes.js`에서 +1 (✅ 구현됨)

---

## 구현 범위

### 파일 1: `server/src/leaderboard/leaderboard.js` (✅ 구현 완료)

- `users.constellation_points DESC` 기준 상위 limit명
- `LEFT JOIN player_stats ps ON ps.account_id = u.id`
- 반환: `[ { rank, accountId, displayName, oraclePoints, totalWins, totalMatches, winRate, oracleSent } ]`
- ⚠️ **tiebreak 미구현**: 현재 `ORDER BY constellation_points DESC` 단일 정렬. 스펙 정의(`total_wins DESC → created_at ASC`) 미적용. 동점자 처리 수정 필요.

### 파일 2: `server/src/leaderboard/routes.js` (✅ 구현 완료)

- `GET /leaderboard?limit=N` → 최대 100명, 기본 20명
- 인증 불필요 (공개 엔드포인트)
- `app.js`에 `/leaderboard` 등록 완료
- 응답 예시 (실제 구현 기준):
```json
{
  "updatedAt": "2026-04-12T05:00:00Z",
  "entries": [
    {
      "rank": 1,
      "accountId": 42,
      "displayName": "별자리 사냥꾼",
      "oraclePoints": 450,
      "totalWins": 8,
      "totalMatches": 15,
      "winRate": 53,
      "oracleSent": 42
    }
  ]
}
```

### 파일 3: `server/src/game/turn-scheduler.js` (✅ 구현 완료)

- 경기 종료 시 `player_stats` upsert (total_matches +1, 우승자 total_wins +1) — `:258` 위치

### 파일 4: `server/src/oracle/routes.js` (✅ 구현 완료)

- 신탁 전송 성공 시 `player_stats.oracle_sent +1` — `:143` 위치

### 파일 5: `client/scripts/LeaderboardScreen.gd` (✅ 구현 완료)

**화면 구성 (Astraea Nexus 디자인 시스템 적용)**

| 영역 | 내용 |
|------|------|
| 헤더 | "성좌 랭킹" 타이틀 (Space Grotesk 28px Bold), accent-gold 강조선 |
| 순위 카드 | 1–3위: accent-gold 배지 + 크기 확대. 4위 이하: 기본 bg-card |
| 카드 컬럼 | 순위 / 성좌명 / 포인트(accent-gold) / 승률 / 신탁 횟수 |
| 내 순위 | 로그인한 플레이어의 행은 accent-purple border로 강조 |
| 하단 버튼 | "돌아가기" → CharacterListScreen |

**GDScript 주요 흐름**
```gdscript
func _ready():
    _fetch_leaderboard()

func _fetch_leaderboard():
    var http = HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_leaderboard_response)
    http.request("http://SERVER_URL/leaderboard")

func _on_leaderboard_response(result, code, headers, body):
    var data = JSON.parse_string(body.get_string_from_utf8())
    _render_entries(data["entries"])
```

### 파일 6: `client/scenes/LeaderboardScreen.tscn` (✅ 구현 완료)

- Control → VBoxContainer (헤더 + ScrollContainer(VBox 카드 목록) + 하단 버튼)
- 카드 1개: HBoxContainer (rank_label, name_label, points_label, winrate_label, oracle_label)

---

## 화면 플로우 연결

```
캐릭터 목록 (CharacterListScreen)
  └─ "랭킹 보기" 버튼 → LeaderboardScreen
       └─ "돌아가기" → CharacterListScreen
```

- CharacterListScreen: "랭킹 🏆" 버튼 및 `leaderboard_requested` 시그널 이미 구현됨
- Main.gd에 아래 코드 추가 필요 (AC7):

```gdscript
# 상단 상수 선언
const LEADERBOARD_SCRIPT := preload("res://scripts/LeaderboardScreen.gd")

# 변수 선언
var _leaderboard_screen: Control

# _build_ui() 내 SpectateListScreen 블록 다음에 추가
# ── LeaderboardScreen ──
_leaderboard_screen = Control.new()
_leaderboard_screen.set_script(LEADERBOARD_SCRIPT)
_leaderboard_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
_leaderboard_screen.visible = false
ui.add_child(_leaderboard_screen)
_leaderboard_screen.back_requested.connect(_on_leaderboard_back)

# _char_list_screen 시그널 연결 블록에 추가
_char_list_screen.leaderboard_requested.connect(_on_leaderboard_requested)

# _show_screen() 함수에 추가
_leaderboard_screen.visible = name == "leaderboard"

# 핸들러 함수 추가
func _on_leaderboard_requested() -> void:
    _show_screen("leaderboard")

func _on_leaderboard_back() -> void:
    _show_screen("char_list")
```

---

## 완료 기준 (AC)

| AC | 내용 | 상태 |
|----|------|------|
| AC1 | `GET /leaderboard` 응답에 constellation_points(alias: oracle_points) 내림차순 상위 20개 항목이 포함됨 | ✅ 구현됨 |
| AC2 | 경기 우승 후 `player_stats.total_wins` +1, `total_matches` +1 증가 확인 | ✅ 구현됨 |
| AC3 | 신탁 전송 성공 시 `player_stats.oracle_sent` +1 증가 확인 | ✅ 구현됨 |
| AC4 | LeaderboardScreen에서 1위 항목이 accent-gold 배지로 표시됨 | ✅ 구현됨 |
| AC5 | 로그인 플레이어 행이 accent-purple border로 강조 표시됨 | ⚠️ 부분 — `my_account_id` 미설정 시 강조 없음 (AC8 참조) |
| AC6 | CharacterListScreen의 "랭킹 🏆" 버튼이 LeaderboardScreen으로 이동하고, "돌아가기" 버튼이 목록으로 복귀함 | ⚠️ 버튼은 있으나 Main.gd 라우팅 미연결 (AC7) |
| AC7 | **[미구현]** `Main.gd`에서 LeaderboardScreen 인스턴스 초기화 + `leaderboard_requested` 시그널 연결 + `_show_screen("leaderboard")` 라우팅 동작 | ❌ 미구현 |
| AC8 | **[미구현]** `Main.gd → LeaderboardScreen.my_account_id` 설정: `/me` API 호출 또는 WS session 응답에서 `accountId` 추출하여 주입, 미로그인 시 -1 유지 | ❌ 미구현 |
| AC9 | `leaderboard.js` ORDER BY에 동점 tiebreak 적용: `constellation_points DESC → total_wins DESC → created_at ASC` | ❌ 미구현 |

---

## 테스트 방법

```bash
# 서버 단위 테스트
cd server && node test/leaderboard.test.js
# 검증 항목: 빈 DB 응답, 20개 초과 데이터 시 limit 적용, 정렬 순서
```

- Godot: LeaderboardScreen 씬을 직접 실행하고 목 데이터 주입으로 렌더링 확인

---

## 엣지케이스

| 케이스 | 서버 처리 | 클라이언트 처리 |
|--------|-----------|-----------------|
| 리더보드 데이터 없음 (경기 미진행) | `{ "entries": [] }` 반환 | "아직 랭킹 데이터가 없습니다" 빈 상태 메시지 표시 |
| oracle_points 동점 | `total_wins DESC` → 동점 시 `accounts.created_at ASC` (먼저 가입한 순) 로 tiebreak | 동점 처리는 서버 정렬 결과 그대로 표시 |
| `player_stats` 행 없는 계정 (경기 미참가) | LEFT JOIN 사용 → total_matches=0, total_wins=0, oracle_sent=0, winRate=0 으로 처리 | 표시상 변화 없음 |
| 로그인하지 않은 상태에서 내 순위 강조 | `myAccountId` 없음 → `isMe=false` 로 모든 행 처리 | accent-purple 강조 행 없음 |
| displayName 미설정 계정 | `accounts.name` NULL 시 `"(이름 없음)"` fallback | 이탤릭체·dimmed 색상으로 표시 |

---

## 제약

- 인증 불필요 (공개 엔드포인트) — MVP 단계에서 rate limit 없음
- `player_stats` 집계는 실시간 쿼리 대신 경기 종료 시점 upsert (성능 단순화)
- `player_stats` 행이 없는 계정에 대해 LEFT JOIN 사용 필수 (신규 계정 오류 방지)
- displayName은 `accounts` 테이블의 기존 name 또는 Google OAuth 프로필 이름 사용
- Web Export 환경 고려: `HTTPRequest` 노드 사용 (fetch API 아님)
- tiebreak 정렬 기준: oracle_points DESC → total_wins DESC → created_at ASC
