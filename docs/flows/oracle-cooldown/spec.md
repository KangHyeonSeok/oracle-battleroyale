---
specId: oracle-cooldown
title: 신탁 쿨다운 (Oracle Rate Limit)
status: done
owner: partner
runnerProfile: developer
runnerExecution: assistant
createdAt: 2026-04-13
updatedAt: 2026-04-13
dependsOn:
  - phase-4-oracle-system
---

# oracle-cooldown: 신탁 메시지 쿨다운

## 목표
플레이어가 같은 경기에서 신탁(oracle) 메시지를 연속 스팸 전송하는 것을 방지한다.
경기당 플레이어 1인 기준 60초 쿨다운을 서버에서 강제하고, 클라이언트에 남은 시간을 표시한다.

## 배경
- `server/src/oracle/routes.js` POST /oracle 핸들러에 Redis 기반 rate-limit이 구현됨
- 스팸 신탁은 Gemini AI 비용을 올리고 게임 밸런스를 파괴할 수 있음
- phase-4-oracle-system에서 credulity 점수가 낮아지는 패널티와 함께 쿨다운 병행 적용
- `GameState.oracle_cooldown_remaining`로 클라이언트 측 카운트다운도 병행 관리

---

## 구현 방식 (실제 구현 기준)

### 서버: `server/src/oracle/routes.js`

Redis 기반 쿨다운 (서버 재시작 시에도 TTL 유지):

```js
const COOLDOWN_TTL_SECONDS = 60;

function cooldownKey(userId, matchId) {
  return `oracle:cooldown:${userId}:${matchId}`;
}
```

POST /oracle 수신 시:
1. `_redisClient.get(cooldownKey(userId, matchId))` 확인
2. 키 존재 시 HTTP 429 응답:
   ```json
   { "error": "Cooldown active. Try again in Ns" }
   ```
   (N = Redis TTL 잔여 초)
3. 통과 시 oracle 파이프라인 실행 후 `SET cooldownKey 1 EX 60`

### 클라이언트: `client/scripts/GameState.gd` + `OraclePanel.gd`

- `GameState.ORACLE_COOLDOWN = 60` (초)
- `use_oracle()` 호출 시 `oracle_cooldown_remaining = ORACLE_COOLDOWN` 설정
- `_process(delta)`: `oracle_cooldown_remaining` 매 프레임 감소
- `OraclePanel.gd`: `_refresh_button()` 에서 `oracle_cooldown_remaining > 0` 일 때 버튼 비활성화 + `"쿨다운: Ns"` 표시

---

## 파일 목록

### 서버

| 파일 | 내용 |
|------|------|
| `server/src/oracle/routes.js` | 쿨다운 체크 (line 87), 쿨다운 설정 (line 129), Redis TTL 60초 |

### 클라이언트 (Godot)

| 파일 | 내용 |
|------|------|
| `client/scripts/GameState.gd` | `oracle_cooldown_remaining`, `ORACLE_COOLDOWN = 60`, `use_oracle()`, `_process()` |
| `client/scripts/OraclePanel.gd` | `_refresh_button()` — 쿨다운 중 버튼 비활성화 + 잔여 초 표시 |

---

## UI 구성

### OraclePanel (쿨다운 중)
- 전송 버튼 (`_oracle_btn`): `disabled = true`
- `_cd_lbl` 레이블: `"쿨다운: Ns"` → 1초마다 감소 (GameState._process 기반)
- 쿨다운 종료 시 버튼 활성화, `_cd_lbl` 숨김

---

## 완료 기준 (Acceptance Criteria)

1. **AC1** — oracle POST 후 60초 이내 재전송 시 서버가 HTTP 429 + TTL 잔여 초 응답
2. **AC2** — 쿨다운 중 OraclePanel 전송 버튼 비활성화, 남은 초 표시
3. **AC3** — 60초 경과 후 버튼 정상 활성화되어 재전송 가능
4. **AC4** — 쿨다운은 경기(matchId)별로 독립 적용 (`oracle:cooldown:{userId}:{matchId}` 키)
5. **AC5** — 쿨다운 중 재전송 시도 시 Gemini API 호출 없음 (핸들러 조기 반환)

---

## 엣지케이스

| 케이스 | 서버 처리 | 클라이언트 처리 |
|--------|-----------|-----------------|
| 서버 재시작 | Redis TTL 유지 → 쿨다운 만료 전까지 차단 유지 | 없음 |
| 포인트 부족으로 oracle 거부 | 포인트 체크(1단계)가 쿨다운 체크(2단계) 보다 먼저 수행 → 쿨다운 키 갱신 없음 | 포인트 부족 오류 별도 표시, 클라이언트 `use_oracle()` 호출 안 됨 |
| 관전자가 oracle 전송 시도 | routes.js 인증 체크에서 차단 | 없음 |
| Redis 미연결 | HTTP 503 응답 | 에러 레이블 표시 |

---

## 단위 테스트 명세 (P1-4 — 미작성)

> 구현은 완료됐으나 단위 테스트 0개. `test/oracle-cooldown.test.js` 신규 작성 필요.

### 파일: `server/test/oracle-cooldown.test.js`

테스트 환경: Node.js `node:test` + `ioredis-mock` (Redis mock)

| # | 테스트 케이스 | 검증 내용 |
|---|--------------|-----------|
| 1 | 첫 oracle POST → 쿨다운 키 설정 | `cooldownKey(userId, matchId)` 키가 Redis에 TTL=60으로 설정됨 확인 |
| 2 | 쿨다운 중 재전송 → HTTP 429 | `GET cooldownKey` 존재 시 응답 `{ "error": "Cooldown active. Try again in Ns" }` + 상태코드 429 |
| 3 | TTL 잔여 초 응답 포함 | 429 응답 body의 N이 Redis TTL 잔여 값과 일치 (mock TTL 30 → "Try again in 30s") |
| 4 | matchId 격리 | `userId=1, matchId=A` 쿨다운 중에 `userId=1, matchId=B` oracle은 정상 통과 (별도 키 `oracle:cooldown:1:B`) |
| 5 | 쿨다운 만료 후 재전송 가능 | Redis TTL 만료(mock: key 삭제) 후 동일 userId+matchId POST → 200 응답, Gemini 파이프라인 호출 |
| 6 | 포인트 부족 시 쿨다운 키 갱신 없음 | 포인트 체크 실패(403) 시 `SET cooldownKey` 호출 없음 확인 |
| 7 | Redis 미연결 시 HTTP 503 | `redis.get()` throw 시 응답 503 + 쿨다운 키 미설정 |

```js
// 테스트 구조 예시
import { test, mock } from 'node:test';
import assert from 'node:assert/strict';

// redis mock: ioredis-mock 또는 jest-redis-mock 패턴
// routes.js에서 redis 의존성 주입 가능하도록 구조 확인 필요
test('POST /oracle: 60초 이내 재전송 → 429', async () => {
  // mock redis: cooldownKey 존재
  // POST /oracle → 응답 status 429
  // body.error에 "Cooldown active" 포함 확인
});

test('matchId 격리: 다른 matchId는 쿨다운 독립', async () => {
  // matchId=A 쿨다운 중
  // matchId=B POST → 200 (쿨다운 미적용)
});
```

> **착수 조건**: `server/src/oracle/routes.js`의 redis 의존성 주입 구조 확인 필요.
> 현재 모듈 최상단에서 redis 클라이언트를 직접 import하는 경우 테스트 시 mock 주입을 위해
> 의존성 주입 패턴 또는 모듈 교체(`proxyquire`, `--import` flag) 필요.

---

## 제약
- 쿨다운 값(60초)은 서버/클라이언트 양측 상수로 관리
- NPC 캐릭터에게는 쿨다운 미적용 (AI 내부 oracle은 별도 경로)
- Redis TTL 기반이므로 서버 재시작 후에도 쿨다운 유지됨 (in-memory Map 방식과 차이)
