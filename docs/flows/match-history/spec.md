---
specId: match-history
title: 경기 기록 조회
status: in-flight
owner: partner
runnerProfile: developer
runnerExecution: assistant
createdAt: 2026-04-12
updatedAt: 2026-04-13
dependsOn:
  - phase-3-game-server
  - oracle-ui-screens
---

# match-history: 경기 기록 조회

## 목표
로그인한 플레이어가 자신이 참가한 최근 경기 목록을 조회하고,
각 경기의 결과·참가자·신탁 로그를 확인할 수 있는 API와 Godot 화면을 구현한다.

## 배경
- `matches`, `match_participants`, `oracle_messages` 테이블은 phase-3에서 이미 생성됨
- `player_stats`(총 경기수·승수·신탁 횟수)는 oracle-ranking-leaderboard에서 추가됨
- 현재 경기 종료 후 결과 화면은 표시되지만, 이전 경기 기록을 다시 볼 방법이 없음
- 히스토리 조회는 재방문 동기를 높이고 자신의 신탁 전략을 복기할 수 있게 함

---

## 데이터 모델 (추가 없음)

기존 테이블로 충분:

| 테이블 | 사용 컬럼 |
|--------|-----------|
| `matches` | id, status, started_at, ended_at, winner_character_id |
| `match_participants` | match_id, character_id, account_id, final_rank, is_npc |
| `characters` | id, name, class, account_id |
| `oracle_messages` | match_id, sender_account_id, content, created_at, credulity, action_result |

---

## 서버 API

### `GET /history?limit=20&offset=0`
- 인증 필수 (session middleware)
- `limit` 최대 50, 초과 시 50으로 clamp. `offset` 음수 시 0으로 clamp.
- `matches.status = 'done'` 인 완료된 경기만 반환 (진행 중·대기 중 경기 제외)
- 자신의 `account_id`가 포함된 `match_participants` 기준으로 최근 경기 목록 반환 (ended_at DESC 정렬)
- 응답 형식:

```json
{
  "total": 42,
  "matches": [
    {
      "matchId": "uuid",
      "startedAt": "ISO8601",
      "endedAt": "ISO8601",
      "participantCount": 12,
      "myCharacter": { "name": "오리온", "class": "warrior" },
      "myRank": 3,
      "winner": { "name": "시리우스", "class": "mage" },
      "oracleSentCount": 2
    }
  ]
}
```

### `GET /history/:matchId`
- 특정 경기 상세: 전체 참가자 순위표 + 신탁 메시지 목록 (시간순)
- 응답 형식:

```json
{
  "matchId": "uuid",
  "startedAt": "ISO8601",
  "endedAt": "ISO8601",
  "participants": [
    { "rank": 1, "characterName": "시리우스", "class": "mage", "isNpc": false, "isMe": false }
  ],
  "oracles": [
    {
      "senderName": "플레이어A",
      "content": "공격해라",
      "credulity": 0.82,
      "actionResult": "오리온이 돌진했다",
      "sentAt": "ISO8601"
    }
  ]
}
```

---

## 파일 목록

### 서버

| 파일 | 내용 |
|------|------|
| `server/src/history/routes.js` | GET /history, GET /history/:matchId 라우트 |
| `server/src/history/queries.js` | SQL 쿼리 (match list, match detail) |
| `server/src/app.js` | `/history` 라우터 등록 추가 |

### 클라이언트 (Godot)

| 파일 | 내용 |
|------|------|
| `client/scenes/MatchHistoryScreen.tscn` | 경기 목록 씬 |
| `client/scripts/MatchHistoryScreen.gd` | 목록 로드, 페이지네이션, 상세 화면 전환 |
| `client/scenes/MatchDetailScreen.tscn` | 경기 상세 씬 (참가자 표 + 신탁 피드) |
| `client/scripts/MatchDetailScreen.gd` | 상세 데이터 렌더링 |
| `client/scripts/CharacterListScreen.gd` | "경기 기록" 버튼 추가 → `Main.show_screen("match_history")` 호출 |
| `client/scripts/Main.gd` | `match_history`, `match_detail` 화면 전환 추가 |

---

## UI 구성

### MatchHistoryScreen
- 상단: "내 경기 기록" 타이틀 + "돌아가기" 버튼 → CharacterListScreen
- 목록: 카드 형태, 1줄당 — `[날짜] [내 캐릭터명/클래스] [내 순위/전체인원] [우승자명] [신탁 횟수]`
- 순위 1위 달성 카드: 좌측에 accent-gold 세로바
- 하단: "더 보기" 버튼 (20개 단위 페이지네이션, offset 증가)

### MatchDetailScreen
- 상단: 날짜/시간, "돌아가기" 버튼 → MatchHistoryScreen
- 좌측 패널: 참가자 순위표 (rank, 이름, 클래스, NPC 뱃지)
  - 내 캐릭터 행: accent-purple 하이라이트
  - 1등 행: accent-gold 하이라이트
- 우측 패널: 신탁 메시지 피드 (시간순, 각 메시지에 credulity % + action_result)

---

## 완료 기준 (Acceptance Criteria)

1. **AC1** — `GET /history` 호출 시 로그인한 계정의 최근 경기 최대 20개 반환, 각 항목에 matchId·myRank·participantCount·winner 포함
2. **AC2** — `GET /history/:matchId` 호출 시 전체 참가자 순위표와 신탁 메시지 목록 반환 (oracle_messages 시간순 정렬)
3. **AC3** — MatchHistoryScreen에서 경기 카드 목록이 표시되고, "더 보기" 클릭 시 다음 20개 추가 로드
4. **AC4** — MatchHistoryScreen에서 카드 클릭 → MatchDetailScreen으로 이동하여 참가자 표와 신탁 피드 표시
5. **AC5** — 1등 달성 경기 카드는 accent-gold 강조 표시, 내 참가자 행은 accent-purple 강조 표시
6. **AC6** — CharacterListScreen에 "경기 기록" 버튼 추가 → MatchHistoryScreen 진입 가능
7. **AC7** — 경기 기록이 없을 때 "아직 경기 기록이 없습니다" 빈 상태 메시지 표시 (목록 대신)

---

## 엣지케이스

| 케이스 | 서버 응답 | 클라이언트 처리 |
|--------|-----------|-----------------|
| 경기 기록 없음 | `{ "total": 0, "matches": [] }` | 빈 상태 메시지 표시 (AC7) |
| 존재하지 않는 matchId | HTTP 404 `{ "error": "not_found" }` | 에러 라벨 표시 후 MatchHistoryScreen으로 복귀 |
| 본인이 참가하지 않은 matchId 접근 | HTTP 403 `{ "error": "forbidden" }` | 동일 처리 |
| 세션 미인증 | HTTP 401 | Main.gd → LoginScreen 리다이렉트 (기존 auth 미들웨어 동작) |
| 캐릭터 삭제 후 기록 조회 | 삭제된 캐릭터는 `characters` LEFT JOIN으로 처리, name=`"(삭제됨)"`, class=`""` 반환 | UI에서 이탤릭체·dimmed 색상으로 표시 |

---

## 예상 기간
0.5주
