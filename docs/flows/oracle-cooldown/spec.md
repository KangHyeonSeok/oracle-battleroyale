---
specId: oracle-cooldown
title: 신탁 쿨다운 (Oracle Rate Limit)
status: queued
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
경기당 플레이어 1인 기준 30초 쿨다운을 서버에서 강제하고, 클라이언트에 남은 시간을 표시한다.

## 배경
- 현재 WS `oracle` 메시지 핸들러에 rate-limit 로직이 없음
- 스팸 신탁은 Gemini AI 비용을 올리고 게임 밸런스를 파괴할 수 있음
- phase-4-oracle-system에서 credulity 점수가 낮아지는 패널티가 있으나 쿨다운은 별도 구현 필요
- oracle-point-system에서 포인트 차감은 경기 종료 시 반영되므로 실시간 제한과 무관

---

## 서버 변경

### WS `oracle` 메시지 핸들러 (`server/src/oracle/handler.js`)

쿨다운 상태를 서버 메모리 Map으로 관리:

```js
// Map<`${accountId}:${matchId}`, timestamp>
const cooldownMap = new Map();
const COOLDOWN_MS = 30_000;
```

oracle 메시지 수신 시:
1. `cooldownMap.get(`${accountId}:${matchId}`)` 확인
2. 현재 시각 - last_sent < 30,000ms 이면 오류 응답:
   ```json
   { "type": "error", "code": "oracle_cooldown", "remainingMs": 12400 }
   ```
3. 통과 시 `cooldownMap.set(...)` 갱신 후 기존 로직 실행

match `game_over` 이벤트 시 해당 `matchId` 관련 키를 모두 정리 (메모리 누수 방지):
```js
for (const key of cooldownMap.keys()) {
  if (key.endsWith(`:${matchId}`)) cooldownMap.delete(key);
}
```

---

## 파일 목록

### 서버

| 파일 | 내용 |
|------|------|
| `server/src/oracle/handler.js` | 쿨다운 Map 추가, oracle 수신 시 체크/갱신, game_over 시 정리 |

### 클라이언트 (Godot)

| 파일 | 내용 |
|------|------|
| `client/scripts/OraclePanel.gd` | `oracle_cooldown` 오류 응답 처리: 전송 버튼 비활성화 + 남은 초 카운트다운 레이블 표시 |

---

## UI 구성

### OraclePanel (쿨다운 중)
- 전송 버튼 (`Button`): `disabled = true`, 색상 dimmed
- 버튼 텍스트: `"신탁 전송 (12초)"` → 1초마다 감소
- 쿨다운 종료 시 버튼 텍스트 복원 `"신탁 전송"` + 활성화
- 카운트다운은 서버 응답의 `remainingMs` 기준으로 시작

---

## 완료 기준 (Acceptance Criteria)

1. **AC1** — oracle 전송 후 30초 이내 재전송 시 서버가 `{ type: "error", code: "oracle_cooldown", remainingMs: N }` 응답
2. **AC2** — 쿨다운 중 OraclePanel 전송 버튼 비활성화, 남은 초 표시
3. **AC3** — 30초 경과 후 버튼 정상 활성화되어 재전송 가능
4. **AC4** — 쿨다운은 경기(matchId)별로 독립 적용 (다른 경기에서 초기화됨)
5. **AC5** — game_over 이벤트 시 서버 메모리에서 해당 경기 쿨다운 항목 제거 (누수 없음)
6. **AC6** — 스팸 전송 시도 시 Gemini API 호출 없음 (핸들러 조기 반환)

---

## 엣지케이스

| 케이스 | 서버 처리 | 클라이언트 처리 |
|--------|-----------|-----------------|
| 서버 재시작 시 쿨다운 Map 초기화 | 재시작 후 첫 oracle은 허용됨 (의도된 동작) | 없음 |
| 관전자가 oracle 전송 시도 | spectate.js 핸들러에서 무시 (기존 AC3) — 쿨다운 Map 갱신 없음 | 없음 |
| `remainingMs` 값 음수 반환 시 | max(0, remainingMs)로 clamp | 즉시 버튼 활성화 |
| 서버 응답 지연으로 클라이언트 쿨다운 먼저 만료 | 서버가 최종 판단, 클라이언트 카운트다운은 UX 힌트 역할 | 재전송 시 서버 재확인 |
| 쿨다운 중 플레이어 WS 재연결 | 재연결 후 첫 oracle 수신 시 `cooldownMap`의 기존 타임스탬프로 재검증 — 30초 미경과 시 동일하게 차단 | 재연결 시 쿨다운 상태 서버에서 재수신 (WS 재연결 시 `oracle_cooldown` 잔여시간 브로드캐스트 없음 → 클라이언트는 재전송 시도 후 서버 응답으로 확인) |
| 포인트 부족으로 oracle 거부된 경우 | oracle-point-system에서 처리 (별도 오류 코드 `oracle_insufficient_points`) — 쿨다운 Map 갱신 없음 (전송 실패이므로) | 포인트 부족 오류 별도 표시, 쿨다운 타이머 시작하지 않음 |

---

## 제약
- 쿨다운 상태는 DB 저장 없이 메모리만 사용 (서버 재시작 시 초기화 허용)
- NPC 캐릭터에게는 쿨다운 미적용 (AI 내부 oracle은 별도 경로)
- 쿨다운 값(30초)은 상수로 관리, 추후 클래스별 차등 적용 검토 가능

## 예상 기간
0.5일
