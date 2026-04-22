---
specId: oracle-point-system
title: 신탁 포인트 시스템 구현
status: ready
owner: partner
runnerProfile: developer
runnerExecution: assistant
createdAt: 2026-04-10
updatedAt: 2026-04-10
dependsOn: phase-1-infra-auth
---

# oracle-point-system: 신탁 포인트 시스템 구현

## 목표
신탁 포인트(Oracle Points)의 보유, 소모, 획득, 정산 규칙을 서버와 클라이언트에 구현한다.
포인트는 플레이어가 신탁을 보낼 때 소모되고, 경기 성적에 따라 보상받는다.

## 배경
- `oracle-ui-screens`의 CharacterCreateScreen, OracleStreamPanel, MatchResultScreen에서 포인트를 표시/소모/정산함
- 현재 서버에 포인트 관련 테이블/로직이 없음 — 구현 필요
- 신탁 버튼 활성화 조건(`phase-5-client-godot` AC)이 포인트 잔액 기반임

---

## 포인트 규칙

### 초기 보유량
| 상황 | 포인트 |
|------|--------|
| 신규 계정 첫 로그인 | 100pt |
| 매일 첫 로그인 보너스 | +10pt |

### 소모
| 행동 | 비용 |
|------|------|
| 신탁 전송 1회 | -10pt |
| 최소 보유 조건 | 10pt 이상 보유 시 신탁 버튼 활성화 |

### 획득 (경기 종료 시 정산)
| 성적 | 보상 |
|------|------|
| 우승 (1위) | +50pt |
| 상위 25% (예: 32명 중 1~8위) | +20pt |
| 참가 완주 (자진 취소 없이 경기 종료) | +5pt |
| NPC에게 탈락 | 0pt |

### 최대 보유량
- 상한선 없음 (MVP 단계)

---

## 구현 범위

### 파일 1: `server/migrations/005_oracle_points.sql`
```sql
-- 포인트 컬럼 추가
ALTER TABLE accounts ADD COLUMN IF NOT EXISTS oracle_points INTEGER NOT NULL DEFAULT 100;

-- 포인트 트랜잭션 로그 테이블
CREATE TABLE IF NOT EXISTS point_transactions (
  id SERIAL PRIMARY KEY,
  account_id INTEGER NOT NULL REFERENCES accounts(id),
  match_id INTEGER REFERENCES matches(id),
  delta INTEGER NOT NULL,          -- 양수: 획득, 음수: 소모
  reason VARCHAR(50) NOT NULL,     -- 'oracle_send' | 'win_bonus' | 'top25_bonus' | 'completion_bonus' | 'daily_login' | 'initial'
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX ON point_transactions(account_id);
```

### 파일 2: `server/src/oracle/points.js` (신규)
- `getPoints(accountId)` → 현재 잔액 조회
- `deductPoint(accountId, matchId, reason)` → -10pt, 잔액 < 10 시 에러 반환
- `awardPoints(accountId, matchId, reason, delta)` → 경기 종료 시 보상 지급
- `grantDailyBonus(accountId)` → 당일 첫 로그인 시 +10pt (중복 방지: `point_transactions` 당일 `daily_login` 레코드 확인)

### 파일 3: `server/src/oracle/oracle.js` (수정)
- 신탁 전송 전 `deductPoint()` 호출 → 잔액 부족 시 `{ error: 'insufficient_points' }` 반환
- 신탁 전송 성공 후 포인트 차감 확정

### 파일 4: `server/src/game/matchResult.js` (수정 또는 신규)
- 경기 종료 시 순위별 `awardPoints()` 호출
- 우승자: `win_bonus +50`, 상위 25%: `top25_bonus +20`, 완주자: `completion_bonus +5`

### 파일 5: `server/src/auth/` (수정)
- 로그인 성공 시 `grantDailyBonus()` 호출

### WebSocket 이벤트 추가
- 서버 → 클라이언트: `{ type: 'points_update', points: number }` — 잔액 변동 시 즉시 푸시
- 클라이언트가 접속 시 현재 포인트 초기 수신: `{ type: 'init', ..., points: number }`

---

## 완료 기준 (AC)

| AC | 내용 |
|----|------|
| AC1 | 신규 계정 생성 후 `accounts.oracle_points = 100` 확인 |
| AC2 | 포인트 10pt 미만 상태에서 신탁 전송 시 `insufficient_points` 에러 반환 |
| AC3 | 신탁 전송 성공 시 잔액 -10pt, `point_transactions` 레코드 생성 |
| AC4 | 경기 우승 시 +50pt, `point_transactions`에 `win_bonus` 레코드 생성 |
| AC5 | 로그인 시 당일 첫 1회만 +10pt (재로그인 시 중복 지급 없음) |
| AC6 | WS `points_update` 이벤트가 포인트 변동 즉시 클라이언트에 전달됨 |

---

## 테스트 방법
```bash
cd server && node test/points.test.js
```
- 신규 계정 포인트 초기화, deduct/award 단위 테스트, 중복 daily bonus 방지 케이스 포함
