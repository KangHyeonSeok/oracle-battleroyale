---
specId: oracle-ranking-leaderboard
title: 성좌 랭킹 리더보드
status: ready
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
- `oracle-point-system`에서 `accounts.oracle_points` 및 `point_transactions` 테이블이 정의됨
- 현재 포인트 잔액은 있지만 플레이어 간 비교/랭킹 화면이 없음
- 승률·신탁 횟수를 함께 표시하면 게임 깊이가 생기고 재방문 동기가 생김

---

## 데이터 모델 추가

### 서버: `server/migrations/006_leaderboard.sql`

```sql
-- 경기 기록 집계를 위한 뷰 (매번 집계 쿼리 대신 캐시용)
CREATE TABLE IF NOT EXISTS player_stats (
  account_id INTEGER PRIMARY KEY REFERENCES accounts(id),
  total_matches INTEGER NOT NULL DEFAULT 0,
  total_wins    INTEGER NOT NULL DEFAULT 0,
  oracle_sent   INTEGER NOT NULL DEFAULT 0,  -- 누적 신탁 전송 횟수
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);
```

- `total_matches`, `total_wins`: 경기 종료 시 `matchResult.js`에서 업데이트
- `oracle_sent`: 신탁 전송 성공 시 `oracle.js`에서 +1

---

## 구현 범위

### 파일 1: `server/src/leaderboard/leaderboard.js` (신규)

```js
// GET /leaderboard?limit=20
async function getLeaderboard(limit = 20) {
  // accounts.oracle_points DESC 기준 상위 limit명
  // LEFT JOIN player_stats for win/match counts
  // 반환: [ { rank, accountId, displayName, oraclePoints, totalWins, totalMatches, winRate, oracleSent } ]
}
```

### 파일 2: `server/src/routes/leaderboard.js` (신규)

- `GET /leaderboard` → `getLeaderboard(20)` 호출, JSON 응답
- 인증 불필요 (공개 엔드포인트)
- 응답 예시:
```json
{
  "updatedAt": "2026-04-12T05:00:00Z",
  "entries": [
    {
      "rank": 1,
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

### 파일 3: `server/src/game/matchResult.js` (수정)

- 경기 종료 시 `player_stats` upsert (total_matches +1, 우승자 total_wins +1)

### 파일 4: `server/src/oracle/oracle.js` (수정)

- 신탁 전송 성공 시 `player_stats.oracle_sent +1`

### 파일 5: `client/scripts/LeaderboardScreen.gd` (신규)

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

### 파일 6: `client/scenes/LeaderboardScreen.tscn` (신규)

- Control → VBoxContainer (헤더 + ScrollContainer(VBox 카드 목록) + 하단 버튼)
- 카드 1개: HBoxContainer (rank_label, name_label, points_label, winrate_label, oracle_label)

---

## 화면 플로우 연결

```
캐릭터 목록 (CharacterListScreen)
  └─ "랭킹 보기" 버튼 → LeaderboardScreen
       └─ "돌아가기" → CharacterListScreen
```

- CharacterListScreen 우측 상단에 "랭킹 🏆" 버튼 추가 (accent-purple 보조 버튼 스타일)

---

## 완료 기준 (AC)

| AC | 내용 |
|----|------|
| AC1 | `GET /leaderboard` 응답에 oracle_points 내림차순 상위 20개 항목이 포함됨 |
| AC2 | 경기 우승 후 `player_stats.total_wins` +1, `total_matches` +1 증가 확인 |
| AC3 | 신탁 전송 성공 시 `player_stats.oracle_sent` +1 증가 확인 |
| AC4 | LeaderboardScreen에서 1위 항목이 accent-gold 배지로 표시됨 |
| AC5 | 로그인 플레이어 행이 accent-purple border로 강조 표시됨 |
| AC6 | CharacterListScreen의 "랭킹 보기" 버튼이 LeaderboardScreen으로 이동하고, "돌아가기" 버튼이 목록으로 복귀함 |

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
