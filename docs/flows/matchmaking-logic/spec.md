---
specId: matchmaking-logic
title: 자동 매칭 시스템 구현
status: ready
owner: partner
runnerProfile: developer
runnerExecution: assistant
createdAt: 2026-04-10
updatedAt: 2026-04-10
dependsOn:
  - phase-3-game-server
  - phase-2-character-ai
---

# matchmaking-logic: 자동 매칭 시스템 구현

## 목표
플레이어가 대기열에 진입한 뒤, 조건이 충족되면 자동으로 매치를 생성하고 시작하는 서버 로직을 구현한다.
플레이어가 부족할 경우 NPC로 빈 슬롯을 채운다.

## 배경
- `oracle-ui-screens` MatchWaitScreen은 대기열 진입 → 실시간 참가자 수 표시 → 자동 매치 시작 흐름이 필요함
- 현재 서버에 자동 매칭 로직 없음 — 매치 ID를 수동 입력하는 방식만 존재 (`phase-5-client-godot` 레거시)
- 매칭 조건, NPC 충원 기준, 대기 시간 상한이 기획에서 미정이었음

---

## 매칭 규칙

### 대기열 진입 조건
- 로그인 상태의 계정이 캐릭터를 선택하고 "경기 참가" 버튼을 누름
- 동일 계정의 중복 대기열 진입 불가 (기존 대기열 자동 취소 후 재진입)

### 매치 시작 조건 (OR)
| 조건 | 값 |
|------|-----|
| 실제 플레이어 모집 완료 | 32명 도달 |
| 대기 시간 초과 | 60초 경과 |

- 60초 후 실제 플레이어 수가 32명 미만이면 NPC로 나머지 슬롯을 채워 시작

### NPC 충원
- NPC 프리셋 풀: `npc-presets.js`의 5개 클래스 NPC
- 충원 순서: 랜덤 셔플 후 부족한 슬롯 수만큼 선택
- NPC에게는 포인트 시스템 미적용 (account_id = null)

### 매치 취소
- 매치 시작 전(대기 중)에만 취소 가능
- 취소 시 대기열에서 제거, 포인트 차감 없음
- 경기 시작 이후 중도 이탈 시 탈락 처리 (포인트 정산 제외)

### 동시 매치
- 서버는 여러 매치를 동시에 처리할 수 있음
- 대기열은 전역 단일 큐 (MVP 단계, 분리 없음)

---

## 구현 범위

### 파일 1: `server/src/game/matchmaker.js` (신규)

```js
class Matchmaker {
  constructor() {
    this.queue = [];          // { accountId, characterId, joinedAt }
    this.matchTimerRef = null;
  }

  enqueue(accountId, characterId) { ... }  // 중복 제거 후 진입, WS broadcast
  dequeue(accountId) { ... }               // 취소
  tryStartMatch() { ... }                  // 32명 도달 시 즉시, 또는 60초 타이머 만료 시
  fillWithNPCs(slots) { ... }              // NPC 프리셋에서 랜덤 선택
  startMatch(players) { ... }              // match 레코드 생성 → game loop 시작
}
```

### 파일 2: `server/migrations/006_matchmaking.sql`
```sql
CREATE TABLE IF NOT EXISTS match_queue (
  id SERIAL PRIMARY KEY,
  account_id INTEGER NOT NULL REFERENCES accounts(id),
  character_id INTEGER NOT NULL REFERENCES characters(id),
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(account_id)
);
```

### 파일 3: `server/src/ws/handlers.js` (수정)
- `{ type: 'queue_join', characterId }` → `matchmaker.enqueue()` 호출
- `{ type: 'queue_leave' }` → `matchmaker.dequeue()` 호출
- WS 브로드캐스트: `{ type: 'queue_update', count: number, waitSeconds: number }`

### WebSocket 이벤트

| 방향 | 타입 | 내용 |
|------|------|------|
| 클 → 서 | `queue_join` | `{ characterId }` |
| 클 → 서 | `queue_leave` | — |
| 서 → 클(전체) | `queue_update` | `{ count, waitSeconds }` |
| 서 → 클(전체) | `match_starting` | `{ matchId, playerCount, npcCount, startsIn: 5 }` — 5초 카운트다운 |
| 서 → 클(참가자) | `match_started` | `{ matchId }` → 아레나로 화면 전환 |

---

## 완료 기준 (AC)

| AC | 내용 |
|----|------|
| AC1 | 32명 대기열 진입 시 즉시 매치 시작, `match_starting` 이벤트 브로드캐스트 |
| AC2 | 대기 시작 60초 후 실제 플레이어 n명 + NPC (32-n)명으로 매치 시작 |
| AC3 | 동일 계정 중복 진입 시 기존 대기 자동 취소 후 재진입 (queue에 1개만 존재) |
| AC4 | `queue_leave` 전송 시 대기열에서 제거, `queue_update` 브로드캐스트 |
| AC5 | `queue_update` 이벤트가 진입/이탈마다 실시간으로 전체 대기자에게 전달됨 |
| AC6 | 매치 생성 후 `matches` 테이블에 레코드 존재 확인 |

---

## 테스트 방법
```bash
cd server && node test/matchmaker.test.js
```
- 32명 진입 즉시 매치 시작 케이스
- 10명만 진입 + 60초 후 NPC 22명 충원 케이스
- 중복 진입 방지 케이스
