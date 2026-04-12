# Test Strategy Log — oracle-battleroyale

---

## 2026-04-13 점검 (태연 자동 점검)

### 현재 테스트 커버리지 상태

| 구분 | 파일 | 프레임워크 | 상태 |
|------|------|-----------|------|
| 단위 — 전투 로직 | `server/test/combat.test.js` | 커스텀 assert | ✅ 존재 |
| 단위 — 포인트 시스템 | `server/test/points.test.js` | 커스텀 assert | ✅ 존재 |
| 단위 — 매치메이킹 | `server/test/matchmaker.test.js` | Node.js assert | ✅ 존재 |
| 통합 — E2E 전체 플로우 | `server/test/e2e-flow.test.js` | Node.js assert + Module stub | ✅ 존재 (실 DB/Redis 미사용) |
| 부하 — 32명 동시 턴 | `server/test/load-32players.test.js` | Node.js assert | ✅ 존재 |
| 비용 검증 — Gemini | `server/test/gemini-cost.test.js` | 정적 계산 | ✅ 존재 |
| 클라이언트 (Godot WebAssembly) | — | — | ❌ 완전 부재 |
| 실 WebSocket 통신 | — | — | ❌ 부재 |
| DB/Redis 통합 (마이그레이션 포함) | — | — | ❌ 부재 |
| UI E2E (Playwright) | — | — | ❌ 미구현 |
| CI 테스트 자동 실행 | — | — | ❌ 미포함 |

### 발견한 문제점

1. **테스트 러너 미설정**: `package.json`에 `"test"` 스크립트 없음. 각 테스트를 `node test/xxx.test.js`로 수동 실행해야 하며, 일관된 실행/집계 방법이 없음.
2. **CI 파이프라인에 테스트 미포함**: `.github/workflows/`에 클라이언트 빌드/배포 워크플로만 존재. 서버 단위·통합 테스트를 자동 실행하는 워크플로 없음.
3. **모든 테스트가 스텁 기반**: DB(PostgreSQL), Redis, Gemini AI 호출이 모두 모킹됨. 실제 마이그레이션 스키마 정합성, Redis 연결 상태, Gemini API 응답 포맷 변화에 무방비.
4. **Godot 클라이언트 테스트 완전 부재**: WebAssembly 빌드 결과물에 대한 스모크 테스트, UI 렌더링 검증, WS 메시지 송수신 시나리오가 전혀 없음.
5. **실 WebSocket 연결 테스트 없음**: `ws/server.js`의 메시지 프로토콜(queue_join, oracle_send 등)을 실제 WS 클라이언트로 검증하는 테스트 없음.
6. **커스텀 assert 하네스**: `combat.test.js`, `points.test.js`는 자체 `passed/failed` 카운터를 사용. 표준 프레임워크 출력 형식과 달라 CI 결과 파싱 어려움.

### 개선 제안 (우선순위 포함)

#### P0 — 즉시 (CI 신뢰성 확보)

| # | 제안 | 상세 |
|---|------|------|
| P0-1 | `npm test` 스크립트 추가 | `package.json`에 `"test": "node --test test/**/*.test.js"` 추가 (Node.js 18+ built-in test runner 활용) 또는 `jest`/`vitest` 도입 |
| P0-2 | GitHub Actions 서버 테스트 워크플로 추가 | `.github/workflows/server-test.yml` 생성: push/PR 트리거, `node test/**/*.test.js` 실행 |

#### P1 — 단기 (2주 내)

| # | 제안 | 상세 |
|---|------|------|
| P1-1 | 실 WebSocket 통합 테스트 | `ws` npm 클라이언트로 `queue_join → oracle_send → game_over` 시나리오 실제 서버 프로세스 대상 검증. `testcontainers` 또는 `redis-memory-server`(이미 devDep) 활용 |
| P1-2 | DB 마이그레이션 스모크 테스트 | `migrations/` 파일 전체를 in-memory PostgreSQL(`pg-mem`)에 순서대로 적용하고 스키마 정합성 확인 |
| P1-3 | 커스텀 harness → 표준화 | `combat.test.js`, `points.test.js`의 커스텀 assert를 Node.js 내장 `assert` + `node:test`로 교체 |

#### P2 — 중기 (1개월 내)

| # | 제안 | 상세 |
|---|------|------|
| P2-1 | Playwright E2E (브라우저 ↔ 서버) | Godot WebAssembly 빌드를 로컬 HTTP 서버로 서빙 후 Playwright로 로그인→캐릭터 생성→신탁 전송 시나리오 자동화. `docs/flows/playwright-debug-setup` 스펙 참조 |
| P2-2 | AI 응답 계약 테스트 | Gemini `extractOracleIntent`, `extractRulesTable` 반환 JSON 스키마를 `zod` 등으로 선언하고 응답 포맷 회귀 검출 |
| P2-3 | 부하 테스트 자동 기준선 | `load-32players.test.js` p95 < 1,000 ms 기준을 CI에서 회귀 감지용으로 자동 실행 |

### 다음 단계 (권장 실행 순서)

1. **P0-1**: `package.json` `test` 스크립트 추가 → DevourerKing 작업 단위로 핸드오프
2. **P0-2**: `server-test.yml` CI 워크플로 추가 → PR merge gate 설정
3. **P1-1**: 실 WS 통합 테스트 설계 → `redis-memory-server` 이미 설치되어 있으므로 Redis 스텁 제거 가능
4. **P2-1**: Playwright 세팅은 Godot 클라이언트 Phase 5 완료 후 진행

---
