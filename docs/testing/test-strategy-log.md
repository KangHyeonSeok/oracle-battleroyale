# Test Strategy Log — oracle-battleroyale

---

## 2026-04-13 점검 16회차 (태연 스케줄 점검 — oracle-battleroyale 스펙 보강)

### 이번 회차 작업 내용

1. **`server-test-ci` draft spec 신규 생성** (`docs/flows/server-test-ci/`)
   - P0-2 블로커(15회 연속) → `.github/workflows/server-test.yml` 구현 명세 작성
   - push/PR 트리거, Node.js 20, Redis 7, PostgreSQL 15, AC 5개
   - `GEMINI_API_KEY` secret 불필요 확인 (정적 계산 테스트)
   - DevourerKing 핸드오프 대상, hyeonseok 착수 승인 항목

2. **`oracle-cooldown` spec 보강** — 단위 테스트 명세 추가 (P1-4)
   - `server/test/oracle-cooldown.test.js` 작성 가이드: 7개 테스트 케이스 명시
   - Redis TTL 60s mock, HTTP 429, TTL 잔여 초 응답, matchId 격리, 만료 후 재전송, 포인트 실패 시 키 갱신 없음, Redis 미연결 503
   - redis 의존성 주입 패턴 확인 착수 조건 명시

3. **`oracle-ranking-leaderboard` spec 보강** — tiebreak 테스트 명세 추가 (P1-5)
   - `server/test/leaderboard.test.js` 작성 가이드: 8개 테스트 케이스 명시
   - tiebreak(total_wins DESC → created_at ASC), LEFT JOIN NULL, limit 상한, displayName fallback

### 현재 테스트 커버리지 상태

| 구분 | 파일 | 실행 결과 | 비고 |
|------|------|-----------|------|
| 단위 — 전투 로직 | `test/combat.test.js` | ✅ 17/17 통과 | 커스텀 assert harness |
| 단위 — 포인트 시스템 | `test/points.test.js` | ✅ 18/18 통과 | 커스텀 assert harness |
| 단위 — 매치메이킹 | `test/matchmaker.test.js` | ✅ 전체 통과 | Node.js assert |
| 통합 — E2E 플로우 | `test/e2e-flow.test.js` | ✅ 7단계 통과 | Module stub 기반, 실 DB/Redis 없음 |
| 부하 — 32명 동시 | `test/load-32players.test.js` | ✅ p99 < 1,000ms | 실측 p99 ≈ 7.3ms |
| 비용 검증 — Gemini | `test/gemini-cost.test.js` | ✅ $0.005/게임 한도 내 | 정적 계산 ($0.001416 실측) |
| CI 서버 테스트 워크플로 | `.github/workflows/` | ❌ 미포함 | **P0-2 — 16회차 연속** (spec draft 생성됨) |
| oracle-cooldown 단위 테스트 | `test/oracle-cooldown.test.js` | ❌ 부재 | **P1-4** — 테스트 명세 spec에 추가됨 |
| oracle-ranking-leaderboard 단위 테스트 | `test/leaderboard.test.js` | ❌ 부재 | **P1-5** — 테스트 명세 spec에 추가됨 |
| 실 WebSocket 통합 테스트 | — | ❌ 부재 | P1-1 미착수 |
| DB 마이그레이션 스모크 테스트 | `migrations/` (9개) | ❌ 부재 | P1-2 미착수 |
| Godot 클라이언트 / Playwright E2E | — | ❌ 부재 | P2-1 — unstaged 11개 |

### 개선 제안 (우선순위)

| 우선순위 | 작업 | 상태 | 규모 |
|----------|------|------|------|
| **P0-2** | `.github/workflows/server-test.yml` — `server-test-ci` spec 기준 구현 | ⏳ **spec 생성됨, hyeonseok 착수 승인 대기** | ~30줄 |
| **P1-4** | `test/oracle-cooldown.test.js` — Redis TTL mock, 429, matchId 격리 | 🔴 spec 테스트 명세 추가됨, DevourerKing 작성 권고 | ~50줄 |
| **P1-5** | `test/leaderboard.test.js` — tiebreak, NULL, limit | 🔴 spec 테스트 명세 추가됨, DevourerKing 작성 권고 | ~50줄 |
| **P1-1** | 실 WebSocket 통합 테스트 | 🔲 미착수 | ~100줄 |
| **P1-2** | `pg-mem` 마이그레이션 스모크 테스트 | 🔲 미착수 | ~60줄 |
| **P2-1** | Playwright E2E — `playwright-debug-setup` spec 기준 구현 | 🔲 spec 있음, 미구현 | TBD |

**16회차 진단**: `server-test-ci` draft spec 생성으로 P0-2 구현 명세 완성. P1-4·P1-5 테스트 케이스를 각 spec에 명시 완료 → DevourerKing 즉시 착수 가능 상태. CI 워크플로 착수는 hyeonseok 승인 필요 — 16회차 연속 대기.

---

## 2026-04-13 점검 15회차 (태연 스케줄 점검 — oracle-battleroyale 테스트 전략)

### 현재 테스트 커버리지 상태

서버: Node.js / Express (26 모듈) · 클라이언트: Godot 4.3 WebAssembly (unstaged 11파일 지속)

| 구분 | 파일 | 실행 결과 | 비고 |
|------|------|-----------|------|
| 단위 — 전투 로직 | `test/combat.test.js` | ✅ 17/17 통과 | 커스텀 assert harness |
| 단위 — 포인트 시스템 | `test/points.test.js` | ✅ 18/18 통과 | 커스텀 assert harness |
| 단위 — 매치메이킹 | `test/matchmaker.test.js` | ✅ 전체 통과 | Node.js assert |
| 통합 — E2E 플로우 | `test/e2e-flow.test.js` | ✅ 7단계 통과 | Module stub 기반, 실 DB/Redis 없음 |
| 부하 — 32명 동시 | `test/load-32players.test.js` | ✅ p99 < 1,000ms | 실측 p99 ≈ 7.3ms |
| 비용 검증 — Gemini | `test/gemini-cost.test.js` | ✅ $0.005/게임 한도 내 | 정적 계산 ($0.001416 실측) |
| `npm test` 스크립트 | `package.json` | ✅ 유지 | P0-1 해소 상태 유지 |
| CI 서버 테스트 워크플로 | `.github/workflows/` | ❌ 미포함 | **P0-2 — 15회차 연속 미해결** |
| oracle-cooldown 단위 테스트 | — | ❌ 부재 | **P1-4 긴급** — Redis TTL 60s, 429 반환, matchId 격리 테스트 0개 |
| oracle-ranking-leaderboard 단위 테스트 | — | ❌ 부재 | **P1-5 긴급** — tiebreak 구현 완료, 테스트 여전히 없음 |
| 실 WebSocket 통합 테스트 | — | ❌ 부재 | P1-1 미착수 |
| DB 마이그레이션 스모크 테스트 | `migrations/` (9개) | ❌ 부재 | P1-2 미착수 |
| Godot 클라이언트 / Playwright E2E | — | ❌ 부재 | P2-1 — unstaged 11개, 위험 최고 |

### 발견한 문제점 (14회차 대비)

1. **P0-2 CI 워크플로 15회차 연속 미해결** — `server-test.yml` 부재 상태 유지. push/PR 트리거 없음. 승인 의사결정이 계속 블로킹.
2. **P1-4·P1-5 테스트 계속 미작성** — oracle-cooldown (Redis TTL 60s, 429 반환, matchId 격리), oracle-ranking-leaderboard (tiebreak, NULL 처리) 모두 구현 완료 상태에서 단위 테스트 0개. 14회차와 동일.
3. **Godot unstaged 11파일 무검증 지속** — 수정 7개 + 신규 4개 (LeaderboardScreen, SpectateListScreen) — 지속 누적.
4. **스텁 기반 통합 테스트 구조적 한계** — PostgreSQL, Redis, Gemini 전량 모킹. 실 서비스 회귀 감지 불가 상태 15회차 지속.
5. **P1-1·P1-2 미착수 지속** — 실 WebSocket 통합 테스트, DB 마이그레이션 스모크 테스트 모두 착수 없음.

### 개선 제안 (우선순위 포함)

| 우선순위 | 작업 | 상태 | 규모 |
|----------|------|------|------|
| **P0-2** | `.github/workflows/server-test.yml` 생성 — push/PR 트리거, `npm test` 실행, Node.js 20 매트릭스 | ⏳ hyeonseok 착수 승인 대기 (15회 연속) | ~20줄 |
| **P1-4** | `oracle-cooldown` 단위 테스트 — Redis TTL 60s mock, HTTP 429 응답, matchId별 격리 검증 | 🔴 **긴급** — DevourerKing 즉시 작성 권고 | ~40줄 |
| **P1-5** | `oracle-ranking-leaderboard` 정렬 단위 테스트 — tiebreak(total_wins DESC, created_at ASC), LEFT JOIN NULL 케이스, displayName NULLIF | 🔴 **긴급** — 구현 완료, 테스트 없이 라이브 위험 | ~40줄 |
| **P1-1** | 실 WebSocket 통합 테스트 — `ws` 클라이언트 + `redis-memory-server` | 🔲 미착수 | ~100줄 |
| **P1-2** | `pg-mem` 마이그레이션 스모크 테스트 — 9개 SQL 순서 적용 검증 | 🔲 미착수 | ~60줄 |
| **P1-3** | 커스텀 assert → `node:test` 표준화 | 🔲 낮은 긴급도 | ~50줄 |
| **P2-1** | Playwright E2E — 로그인→캐릭터 생성→신탁 전송 자동화 | 🔲 별도 스펙 필요 | TBD |
| **P2-2** | Gemini 응답 계약 테스트 (zod 스키마) | 🔲 미착수 | ~30줄 |
| **P2-3** | 부하 테스트 CI 기준선 등록 (p95 < 1,000ms) | 🔲 CI 워크플로 확장 후 | TBD |

**15회차 진단**: 14회차 대비 구조적 변화 없음. 서버 단위 테스트 6개 모두 통과 상태 유지. P0-2(CI 워크플로) 15회 연속 블로킹 — hyeonseok 승인 없이는 진전 불가. P1-4·P1-5 구현 완료 후 테스트 방치 패턴 지속 — DevourerKing 핸드오프가 반복적으로 필요하나 미착수. **P0-2 CI 승인 + P1-4·P1-5 DevourerKing 테스트 착수가 최우선 아이템.**

---

## 2026-04-13 점검 14회차 (태연 스케줄 점검 — oracle-battleroyale 테스트 전략)

### 현재 테스트 커버리지 상태

서버: Node.js / Express (26 모듈) · 클라이언트: Godot 4.3 WebAssembly (unstaged 11파일 지속)

| 구분 | 파일 | 실행 결과 | 비고 |
|------|------|-----------|------|
| 단위 — 전투 로직 | `test/combat.test.js` | ✅ 17/17 통과 | 커스텀 assert harness |
| 단위 — 포인트 시스템 | `test/points.test.js` | ✅ 18/18 통과 | 커스텀 assert harness |
| 단위 — 매치메이킹 | `test/matchmaker.test.js` | ✅ 전체 통과 | Node.js assert |
| 통합 — E2E 플로우 | `test/e2e-flow.test.js` | ✅ 7단계 통과 | Module stub 기반, 실 DB/Redis 없음 |
| 부하 — 32명 동시 | `test/load-32players.test.js` | ✅ p99 < 1,000ms | 실측 p99 ≈ 2.3ms |
| 비용 검증 — Gemini | `test/gemini-cost.test.js` | ✅ $0.005/게임 한도 내 | 정적 계산 ($0.001416 실측) |
| `npm test` 스크립트 | `package.json` | ✅ 유지 | P0-1 해소 상태 유지 |
| CI 서버 테스트 워크플로 | `.github/workflows/` | ❌ 미포함 | **P0-2 — 14회차 연속 미해결** |
| oracle-cooldown 단위 테스트 | — | ❌ 부재 | **P1-4 긴급** — 쿨다운 로직 테스트 계속 없음 |
| oracle-ranking-leaderboard 단위 테스트 | — | ❌ 부재 | **P1-5 긴급** — tiebreak 구현 완료, 테스트 여전히 없음 |
| 실 WebSocket 통합 테스트 | — | ❌ 부재 | P1-1 미착수 |
| DB 마이그레이션 스모크 테스트 | `migrations/` (9개) | ❌ 부재 | P1-2 미착수 |
| Godot 클라이언트 / Playwright E2E | — | ❌ 부재 | P2-1 — unstaged 11개, 위험 최고 |

### 발견한 문제점 (13회차 대비)

1. **P0-2 CI 워크플로 14회차 연속 미해결** — `server-test.yml` 부재 상태 유지. push/PR 트리거 없음. 승인 의사결정이 계속 블로킹.
2. **P1-4·P1-5 테스트 계속 미작성** — oracle-cooldown (Redis TTL 60s, 429 반환, matchId 격리), oracle-ranking-leaderboard (tiebreak, NULL 처리) 모두 구현 완료 상태에서 단위 테스트 0개. 13회차와 동일.
3. **Godot unstaged 11파일 무검증 지속** — 수정 7개 + 신규 4개 (LeaderboardScreen, SpectateListScreen). character-class-guide 완료 후 추가 수정 예상으로 누적 가속 가능.
4. **스텁 기반 통합 테스트 구조적 한계** — PostgreSQL, Redis, Gemini 전량 모킹. 실 서비스 회귀 감지 불가 상태 14회차 지속.
5. **P1-1·P1-2 미착수 지속** — 실 WebSocket 통합 테스트, DB 마이그레이션 스모크 테스트 모두 착수 없음.

### 개선 제안 (우선순위 포함)

| 우선순위 | 작업 | 상태 | 규모 |
|----------|------|------|------|
| **P0-2** | `.github/workflows/server-test.yml` 생성 — push/PR 트리거, `npm test` 실행, Node.js 20 매트릭스 | ⏳ hyeonseok 착수 승인 대기 (14회 연속) | ~20줄 |
| **P1-4** | `oracle-cooldown` 단위 테스트 — Redis TTL 60s mock, HTTP 429 응답, matchId별 격리 검증 | 🔴 **긴급** — DevourerKing 즉시 작성 권고 | ~40줄 |
| **P1-5** | `oracle-ranking-leaderboard` 정렬 단위 테스트 — tiebreak(total_wins DESC, created_at ASC), LEFT JOIN NULL 케이스, displayName NULLIF | 🔴 **긴급** — AC9 구현 완료, 테스트 없이 라이브 위험 | ~40줄 |
| **P1-1** | 실 WebSocket 통합 테스트 — `ws` 클라이언트 + `redis-memory-server` | 🔲 미착수 | ~100줄 |
| **P1-2** | `pg-mem` 마이그레이션 스모크 테스트 — 9개 SQL 순서 적용 검증 | 🔲 미착수 | ~60줄 |
| **P1-3** | 커스텀 assert → `node:test` 표준화 | 🔲 낮은 긴급도 | ~50줄 |
| **P2-1** | Playwright E2E — 로그인→캐릭터 생성→신탁 전송 자동화 | 🔲 별도 스펙 필요 | TBD |
| **P2-2** | Gemini 응답 계약 테스트 (zod 스키마) | 🔲 미착수 | ~30줄 |
| **P2-3** | 부하 테스트 CI 기준선 등록 (p95 < 1,000ms) | 🔲 CI 워크플로 확장 후 | TBD |

**14회차 진단**: 13회차 대비 구조적 변화 없음. 서버 단위 테스트 6개 모두 통과 상태 유지. P0-2(CI 워크플로) 14회 연속 블로킹 — 승인 의사결정이 최우선 아이템. P1-4·P1-5 구현 완료 후 테스트 방치 패턴 지속 — DevourerKing 핸드오프 즉시 필요. Godot unstaged 11파일 무검증 누적 위험 계속 증가. **P0-2 CI 승인 + P1-4·P1-5 DevourerKing 테스트 착수가 다음 액션 아이템.**

---

## 2026-04-13 점검 13회차 (태연 스케줄 점검 — oracle-battleroyale 테스트 전략)

### 현재 테스트 커버리지 상태

서버: Node.js / Express (26 모듈) · 클라이언트: Godot 4.3 WebAssembly (unstaged 11파일 지속)

| 구분 | 파일 | 실행 결과 | 비고 |
|------|------|-----------|------|
| 단위 — 전투 로직 | `test/combat.test.js` | ✅ 17/17 통과 | 커스텀 assert harness |
| 단위 — 포인트 시스템 | `test/points.test.js` | ✅ 18/18 통과 | 커스텀 assert harness |
| 단위 — 매치메이킹 | `test/matchmaker.test.js` | ✅ 전체 통과 | Node.js assert |
| 통합 — E2E 플로우 | `test/e2e-flow.test.js` | ✅ 7단계 통과 | Module stub 기반, 실 DB/Redis 없음 |
| 부하 — 32명 동시 | `test/load-32players.test.js` | ✅ p99 < 1,000ms | 실측 p99 ≈ 2.3ms |
| 비용 검증 — Gemini | `test/gemini-cost.test.js` | ✅ $0.005/게임 한도 내 | 정적 계산 ($0.001416 실측) |
| `npm test` 스크립트 | `package.json` | ✅ 유지 | P0-1 해소 상태 유지 |
| CI 서버 테스트 워크플로 | `.github/workflows/` | ❌ 미포함 | **P0-2 — 13회차 연속 미해결** |
| oracle-cooldown 단위 테스트 | — | ❌ 부재 | **P1-4 긴급** — status=done이나 테스트 없음 |
| oracle-ranking-leaderboard 단위 테스트 | — | ❌ 부재 | **P1-5 긴급 상승** — AC9 tiebreak 구현 완료, 테스트 여전히 없음 |
| 실 WebSocket 통합 테스트 | — | ❌ 부재 | P1-1 미착수 |
| DB 마이그레이션 스모크 테스트 | `migrations/` (9개) | ❌ 부재 | P1-2 미착수 (migration 파일 9개로 증가) |
| Godot 클라이언트 / Playwright E2E | — | ❌ 부재 | P2-1 — unstaged 11개, 위험 최고 |

### 발견한 문제점 (12회차 대비)

1. **P0-2 CI 워크플로 13회차 연속 미해결** — `client-web-export.yml`만 존재. `server-test.yml` 부재로 push/PR 시 서버 테스트 자동 실행 없음. 필요 코드 ~20줄.
2. **oracle-ranking-leaderboard AC9 구현됨, 테스트 없음** — `leaderboard.js` ORDER BY에 `total_wins DESC, created_at ASC` tiebreak 추가 완료. 구현 후에도 단위 테스트 0개. AC7(Main.gd 라우팅), AC8(my_account_id 주입)은 여전히 미구현. P1-5 긴급도 상승.
3. **oracle-cooldown P1-4 사후 보완 계속 미착수** — Redis TTL 60s 쿨다운 로직, HTTP 429 반환, matchId 격리 모두 수동 검증 미보장. status=done임에도 단위 테스트 0개. 13회차 연속 방치.
4. **character-class-guide runner in-flight** — CharacterCreateScreen.gd 클래스 선택 UI 수정 진행 중. 완료 후 클라이언트 변경이 unstaged에 추가될 가능성. 검증 기준(AC 5개) 정의되어 있으나 테스트 자동화 없음.
5. **arena-character-hud flow queued** — 아레나 HUD HP bar 추가 스펙 queued 전환. Main.gd 단일 파일 수정. Godot unstaged 누적 위험과 맞물려 클라이언트 변경 미검증 구조 반복.
6. **Godot unstaged 11파일 무검증 지속** — 수정 7개(Arena·CharacterCreate·CharacterList·GameState·Main·MatchWaiting·OracleStream) + 신규 4개(LeaderboardScreen.tscn·SpectateListScreen.tscn·LeaderboardScreen.gd·SpectateListScreen.gd). character-class-guide 완료 후 추가 수정 예상.
7. **스텁 기반 통합 테스트 구조적 한계** — PostgreSQL, Redis, Gemini 전량 모킹. 실 서비스 회귀 감지 불가 상태 13회차 지속.

### 개선 제안 (우선순위 포함)

| 우선순위 | 작업 | 상태 | 규모 |
|----------|------|------|------|
| **P0-2** | `.github/workflows/server-test.yml` 생성 — push/PR 트리거, `npm test` 실행, Node.js 20 매트릭스 | ⏳ hyeonseok 착수 승인 대기 (13회 연속) | ~20줄 |
| **P1-4** | `oracle-cooldown` 단위 테스트 — Redis TTL 60s mock, HTTP 429 응답, matchId별 격리 검증 | 🔴 **긴급** — DevourerKing 즉시 작성 권고 | ~40줄 |
| **P1-5** | `oracle-ranking-leaderboard` 정렬 단위 테스트 — tiebreak(total_wins DESC, created_at ASC), LEFT JOIN NULL 케이스, displayName NULLIF | 🔴 **긴급 상승** — AC9 구현 완료, 테스트 없이 라이브 위험 | ~40줄 |
| **P1-1** | 실 WebSocket 통합 테스트 — `ws` 클라이언트 + `redis-memory-server` | 🔲 미착수 | ~100줄 |
| **P1-2** | `pg-mem` 마이그레이션 스모크 테스트 — 9개 SQL 순서 적용 검증 | 🔲 미착수 | ~60줄 |
| **P1-3** | 커스텀 assert → `node:test` 표준화 | 🔲 낮은 긴급도 | ~50줄 |
| **P2-1** | Playwright E2E — 로그인→캐릭터 생성→신탁 전송 자동화 | 🔲 별도 스펙 필요 | TBD |
| **P2-2** | Gemini 응답 계약 테스트 (zod 스키마) | 🔲 미착수 | ~30줄 |
| **P2-3** | 부하 테스트 CI 기준선 등록 (p95 < 1,000ms) | 🔲 CI 워크플로 확장 후 | TBD |

**13회차 진단**: 12회차 대비 구조적 변화 없음. oracle-ranking-leaderboard AC9(tiebreak) 구현 완료는 진전이나, 단위 테스트 없이 구현이 앞서가는 패턴 재현 — P1-5 긴급도 상승. character-class-guide runner in-flight로 클라이언트 변경 추가 예정이나 E2E 커버리지는 여전히 없음. P0-2(CI 워크플로)는 13회차 연속 블로킹 — 승인 의사결정이 가장 시급. **P1-4·P1-5 테스트 작성(DevourerKing 핸드오프)과 P0-2 CI 워크플로 착수 결정이 다음 액션 아이템.**

---

## 2026-04-13 점검 12회차 (태연 스케줄 점검 — oracle-battleroyale 테스트 전략)

### 현재 테스트 커버리지 상태

서버: Node.js / Express (26 모듈) · 클라이언트: Godot 4.3 WebAssembly (unstaged 11파일 지속)

| 구분 | 파일 | 실행 결과 | 비고 |
|------|------|-----------|------|
| 단위 — 전투 로직 | `test/combat.test.js` | ✅ 17/17 통과 | 커스텀 assert harness |
| 단위 — 포인트 시스템 | `test/points.test.js` | ✅ 18/18 통과 | 커스텀 assert harness |
| 단위 — 매치메이킹 | `test/matchmaker.test.js` | ✅ 전체 통과 | Node.js assert |
| 통합 — E2E 플로우 | `test/e2e-flow.test.js` | ✅ 7단계 통과 | Module stub 기반, 실 DB/Redis 없음 |
| 부하 — 32명 동시 | `test/load-32players.test.js` | ✅ p99 < 1,000ms | 실측 p99 ≈ 2.3ms |
| 비용 검증 — Gemini | `test/gemini-cost.test.js` | ✅ $0.005/게임 한도 내 | 정적 계산 ($0.001416 실측) |
| `npm test` 스크립트 | `package.json` | ✅ 유지 | P0-1 해소 상태 유지 |
| CI 서버 테스트 워크플로 | `.github/workflows/` | ❌ 미포함 | **P0-2 — 12회차 연속 미해결** |
| oracle-cooldown 단위 테스트 | — | ❌ 부재 | **P1-4 긴급** — status=done이나 테스트 없음 |
| oracle-ranking-leaderboard 테스트 | — | ❌ 부재 | **P1-5** — AC7·AC8·AC9 구현 대기 |
| 실 WebSocket 통합 테스트 | — | ❌ 부재 | P1-1 미착수 |
| DB 마이그레이션 스모크 테스트 | `migrations/` (7개) | ❌ 부재 | P1-2 미착수 |
| Godot 클라이언트 / Playwright E2E | — | ❌ 부재 | P2-1 — unstaged 11개, 위험 최고 |

### 발견한 문제점 (11회차 대비)

1. **P0-2 CI 워크플로 12회차 연속 미해결** — `client-web-export.yml`만 존재. `server-test.yml` 부재로 push/PR 시 서버 테스트 자동 실행 없음. 필요 코드 ~20줄으로 규모 최소.
2. **oracle-cooldown P1-4 사후 보완 계속 미착수** — `oracle/routes.js` Redis TTL 60s 쿨다운 로직, HTTP 429 반환, matchId 격리 모두 수동 검증 미보장. status=done임에도 단위 테스트 0개.
3. **oracle-ranking-leaderboard AC7·AC8·AC9 구현 전 테스트 미작성** — tiebreak(`total_wins DESC → created_at ASC`), `displayName NULLIF` 패턴, LEFT JOIN 필수 케이스에 대한 단위 테스트가 구현보다 선행되어야 함.
4. **Godot unstaged 11파일 무검증 지속** — 수정 7개(Arena·CharacterCreate·CharacterList·GameState·Main·MatchWaiting·OracleStream) + 신규 4개(LeaderboardScreen.tscn·SpectateListScreen.tscn·LeaderboardScreen.gd·SpectateListScreen.gd). 실제 동작 보장 없음.
5. **`character-class-guide` 플로우 테스트 전략 미정** — draft→queued 전환 후에도 해당 플로우의 검증 기준(AC) 미정의.
6. **스텁 기반 통합 테스트 구조적 한계** — PostgreSQL, Redis, Gemini 전량 모킹. 실 서비스 회귀 감지 불가 상태 12회차 지속.

### 개선 제안 (우선순위 포함)

| 우선순위 | 작업 | 상태 | 규모 |
|----------|------|------|------|
| **P0-2** | `.github/workflows/server-test.yml` 생성 — push/PR 트리거, `npm test` 실행, Node.js 20 매트릭스 | ⏳ hyeonseok 착수 승인 대기 (12회 연속) | ~20줄 |
| **P1-4** | `oracle-cooldown` 단위 테스트 — Redis TTL 60s mock, HTTP 429 응답, matchId별 격리 검증 | 🔴 **긴급** — DevourerKing 즉시 작성 권고 | ~40줄 |
| **P1-5** | `oracle-ranking-leaderboard` 정렬 단위 테스트 — tiebreak, LEFT JOIN NULL 케이스, displayName NULLIF | 🔴 AC7·AC8·AC9 구현 전 선행 작성 필요 | ~40줄 |
| **P1-1** | 실 WebSocket 통합 테스트 — `ws` 클라이언트 + `redis-memory-server` | 🔲 미착수 | ~100줄 |
| **P1-2** | `pg-mem` 마이그레이션 스모크 테스트 — 7개 SQL 순서 적용 검증 | 🔲 미착수 | ~60줄 |
| **P1-3** | 커스텀 assert → `node:test` 표준화 | 🔲 낮은 긴급도 | ~50줄 |
| **P2-1** | Playwright E2E — 로그인→캐릭터 생성→신탁 전송 자동화 | 🔲 별도 스펙 필요 | TBD |
| **P2-2** | Gemini 응답 계약 테스트 (zod 스키마) | 🔲 미착수 | ~30줄 |
| **P2-3** | 부하 테스트 CI 기준선 등록 (p95 < 1,000ms) | 🔲 CI 워크플로 확장 후 | TBD |

**12회차 진단**: 11회차 대비 구조적 변화 없음. 6개 서버 테스트는 모두 정상(P0-1 유지)이나 CI 자동화(P0-2)는 12회차 연속 블로킹. P1-4(oracle-cooldown)와 P1-5(leaderboard tiebreak)는 기능이 존재하거나 구현 임박했음에도 테스트가 없어 회귀 위험 증가. Godot unstaged 11파일은 E2E 커버리지 없이 가장 높은 실질 위험. **P0-2 CI 워크플로 착수 결정과 P1-4 DevourerKing 사후 보완 착수가 가장 시급한 액션 아이템.**

---

## 2026-04-13 점검 11회차 (태연 스케줄 점검 — oracle-battleroyale 테스트 전략)

### 현재 테스트 커버리지 상태

서버: Node.js / Express · 클라이언트: Godot 4.3 WebAssembly (수정 7파일 + 신규 4파일 unstaged 지속)

| 구분 | 파일 | 실행 결과 | 비고 |
|------|------|-----------|------|
| 단위 — 전투 로직 | `test/combat.test.js` | ✅ 17/17 통과 | 커스텀 assert harness |
| 단위 — 포인트 시스템 | `test/points.test.js` | ✅ 18/18 통과 | 커스텀 assert harness |
| 단위 — 매치메이킹 | `test/matchmaker.test.js` | ✅ 전체 통과 | Node.js assert |
| 통합 — E2E 플로우 | `test/e2e-flow.test.js` | ✅ 7단계 통과 | Module stub 기반, 실 DB/Redis 없음 |
| 부하 — 32명 동시 | `test/load-32players.test.js` | ✅ p99 < 1,000ms | 실측 p99 ≈ 2.3ms |
| 비용 검증 — Gemini | `test/gemini-cost.test.js` | ✅ $0.005/게임 한도 내 | 정적 계산 ($0.001416 실측) |
| `npm test` 스크립트 | `package.json` | ✅ **해결** | node 직접 실행 6파일, P0-1 해소 유지 |
| CI 서버 테스트 워크플로 | `.github/workflows/` | ❌ 미포함 | **P0-2 — 11회차 연속 미해결** |
| oracle-cooldown 단위 테스트 | — | ❌ 부재 | **P1-4 긴급** — status=done이나 테스트 없이 머지된 상태 유지 |
| oracle-ranking-leaderboard 테스트 | — | ❌ 부재 | **P1-5** — in-flight, AC7(Main.gd 라우팅)·AC8(my_account_id)·AC9(tiebreak) 미구현 |
| 실 WebSocket 통합 테스트 | — | ❌ 부재 | P1-1 미착수 |
| DB 마이그레이션 스모크 테스트 | `migrations/` (7개) | ❌ 부재 | P1-2 미착수 |
| Godot 클라이언트 / Playwright E2E | — | ❌ 부재 | P2-1 — unstaged 파일 11개, 위험도 최고 |

### 발견한 문제점 (10회차 대비 신규 변동)

1. **CI 워크플로 계속 미생성** — P0-2가 11회차 연속 블로킹 상태. `client-web-export.yml`만 존재하며 서버 테스트 자동화 없음.
2. **oracle-cooldown 테스트 여전히 부재** — P1-4, status=done으로 완료됐으나 쿨다운 로직(Redis TTL 60s, HTTP 429, matchId 격리)에 대한 단위 테스트 없음. 사후 보완 미착수.
3. **oracle-ranking-leaderboard AC 미구현 지속** — spec.md에 AC 9개 확정(tiebreak: `total_wins DESC → created_at ASC`, displayName NULLIF 패턴, LEFT JOIN 필수 명시)됐으나 AC7·AC8·AC9 runner 처리 대기 중.
4. **Godot unstaged 파일 11개 유지** — 수정 7개(Arena.gd·CharacterCreateScreen.gd·CharacterListScreen.gd·GameState.gd·Main.gd·MatchWaitingScreen.gd·OracleStreamPanel.gd) + 신규 4개(LeaderboardScreen.tscn·SpectateListScreen.tscn·LeaderboardScreen.gd·SpectateListScreen.gd) 전량 무검증 지속. P2-1 위험 최고 수준.
5. **신규 플로우 추가** — `character-class-guide` 플로우가 draft→queued 전환됨(2a7249b). 해당 플로우 관련 테스트 전략 미정.
6. **스텁 기반 통합 테스트 구조적 한계 지속** — PostgreSQL, Redis, Gemini 모두 모킹. 실 서비스 회귀 감지 불가.

### 개선 제안 상태 (11회차 기준)

| 우선순위 | 작업 | 상태 | 구현 규모 |
|----------|------|------|-----------|
| P0-2 | `.github/workflows/server-test.yml` 생성 (push/PR 트리거, `npm test` 실행) | ⏳ hyeonseok 착수 승인 대기 (11회 연속) | ~20줄 |
| P1-1 | 실 WebSocket 통합 테스트 (`ws` 클라이언트 + `redis-memory-server`) | 🔲 미착수 | ~100줄 |
| P1-2 | `pg-mem` 마이그레이션 스모크 테스트 (7개 SQL 순서 적용) | 🔲 미착수 | ~60줄 |
| P1-3 | 커스텀 assert → `node:test` 표준화 | 🔲 미착수 | ~50줄 |
| P1-4 | `oracle-cooldown` 쿨다운 로직 단위 테스트 (Redis TTL 60s, HTTP 429, matchId 격리) | 🔴 **긴급** — status=done이나 테스트 없이 머지 상태 지속 | ~40줄 |
| P1-5 | `oracle-ranking-leaderboard` 정렬·집계 단위 테스트 (tiebreak, LEFT JOIN, displayName NULLIF) | 🔴 in-flight AC7/AC8/AC9 구현 전 작성 필요 | ~40줄 |
| P2-1 | Playwright E2E: 로그인→캐릭터 생성→신탁 전송 자동화 | 🔲 미착수 — unstaged 파일 11개 위험 최고 | 별도 스펙 필요 |
| P2-2 | Gemini 응답 계약 테스트 (zod 스키마) | 🔲 미착수 | ~30줄 |
| P2-3 | 부하 테스트 CI 기준선 등록 (p95 < 1,000ms) | 🔲 미착수 | CI 워크플로 확장 |

**11회차 진단**: 10회차 대비 구조적 변화 없음. `npm test` 정상 동작(P0-1 유지), CI 워크플로(P0-2) 11회차 연속 미해결로 단일 P0 블로커. oracle-cooldown은 done이나 P1-4 사후 보완 미착수, oracle-ranking-leaderboard는 spec 완성도 향상(AC 9개 확정)됐으나 AC7·AC8·AC9 구현 대기 중. Godot unstaged 11개 파일이 무검증 상태로 가장 높은 실질 위험. **hyeonseok에게 P0-2 착수 결정, P1-4 DevourerKing 사후 보완 착수 요청 시급.**

---

## 2026-04-13 점검 10회차 (태연 스케줄 점검 — oracle-battleroyale 테스트 전략)

### 현재 테스트 커버리지 상태

서버: Node.js v22.22.2 / Express (26 모듈) / 클라이언트: Godot 4.3 WebAssembly (수정 7파일 + 신규 4파일 unstaged)

| 구분 | 파일 | 실행 결과 | 비고 |
|------|------|-----------|------|
| 단위 — 전투 로직 | `test/combat.test.js` | ✅ 17/17 통과 | 커스텀 assert harness |
| 단위 — 포인트 시스템 | `test/points.test.js` | ✅ 18/18 통과 | 커스텀 assert harness |
| 단위 — 매치메이킹 | `test/matchmaker.test.js` | ✅ 전체 통과 | Node.js assert |
| 통합 — E2E 플로우 | `test/e2e-flow.test.js` | ✅ 7단계 통과 | Module stub 기반, 실 DB/Redis 없음 |
| 부하 — 32명 동시 | `test/load-32players.test.js` | ✅ p99 < 1,000ms | 실측 p99 ≈ 2.3ms |
| 비용 검증 — Gemini | `test/gemini-cost.test.js` | ✅ $0.005/게임 한도 내 | 정적 계산 ($0.001416 실측) |
| `npm test` 스크립트 | `package.json` | ✅ **해결** | **P0-1 해소** — node 직접 실행 6파일, Jest 충돌 제거 (4e51227) |
| CI 서버 테스트 워크플로 | `.github/workflows/` | ❌ 미포함 | **P0-2 — 10회차 연속 미해결** |
| oracle-cooldown 단위 테스트 | — | ❌ 부재 | **P1-4** — 기능은 done이나 테스트 없음 |
| oracle-ranking-leaderboard 테스트 | — | ❌ 부재 | **P1-5** — in-flight, AC7/AC8/AC9 미구현 |
| 실 WebSocket 통합 테스트 | — | ❌ 부재 | P1-1 미착수 |
| DB 마이그레이션 스모크 테스트 | `migrations/` (7개) | ❌ 부재 | P1-2 미착수 |
| Godot 클라이언트 / Playwright E2E | — | ❌ 부재 | P2-1 — unstaged 파일 11개로 위험도 최고 수준 |

### 발견한 문제점 (9회차 대비 신규 변동)

1. **`npm test` 해결** — P0-1 드디어 해소. `node` 직접 실행 방식으로 Jest `process.exit()` 충돌 우회. 6/6 통과 확인.
2. **CI 서버 테스트 워크플로 미생성** — P0-1 해소 후 P0-2가 단일 P0로 남음. `client-web-export.yml`만 존재. PR merge gate 없음 (P0-2)
3. **oracle-cooldown `done` — 테스트 없음** — 구현은 `server/src/oracle/routes.js` Redis TTL 60s 방식으로 완료. 하지만 쿨다운 로직 단위 테스트(P1-4) 미작성 상태로 머지됨.
4. **oracle-ranking-leaderboard `in-flight`** — AC7(Main.gd 라우팅), AC8(my_account_id 주입), AC9(tiebreak 정렬) 3건 미구현. 리더보드 테스트(P1-5) 부재.
5. **Godot 클라이언트 unstaged 파일 급증** — 수정 7개(Arena.gd·CharacterCreateScreen.gd·CharacterListScreen.gd·GameState.gd·Main.gd·MatchWaitingScreen.gd·OracleStreamPanel.gd) + 신규 4개(LeaderboardScreen.tscn·SpectateListScreen.tscn·LeaderboardScreen.gd·SpectateListScreen.gd) 전량 무검증. P2-1 위험도 최고 수준.
6. **스텁 기반 통합 테스트** — PostgreSQL, Redis, Gemini 모두 모킹. 실 서비스 회귀 감지 불가 (P1)
7. **WebSocket 프로토콜 실 검증 없음** — `ws/server.js` 핸들러 실 연결 미검증 (P1-1)
8. **커스텀 assert harness** — CI 표준 출력 파싱 불가 (P1-3)

### 개선 제안 상태 (10회차 기준)

| 우선순위 | 작업 | 상태 | 구현 규모 |
|----------|------|------|-----------|
| P0-2 | `.github/workflows/server-test.yml` 생성 (push/PR 트리거) | ⏳ hyeonseok 착수 승인 대기 (10회 연속) | ~20줄 |
| P1-1 | 실 WebSocket 통합 테스트 (`ws` 클라이언트 + `redis-memory-server`) | 🔲 미착수 | ~100줄 |
| P1-2 | `pg-mem` 마이그레이션 스모크 테스트 (7개 SQL 순서 적용) | 🔲 미착수 | ~60줄 |
| P1-3 | 커스텀 assert → `node:test` 표준화 | 🔲 미착수 | ~50줄 |
| P1-4 | `oracle-cooldown` 쿨다운 로직 단위 테스트 (Redis TTL, 429 응답, matchId 격리) | 🔴 **긴급** — 기능 done이나 테스트 없이 머지됨 | ~40줄 |
| P1-5 | `oracle-ranking-leaderboard` 정렬·집계 단위 테스트 (tiebreak, LEFT JOIN, displayName fallback) | 🔴 in-flight AC 미구현 중 — 머지 전 필요 | ~40줄 |
| P2-1 | Playwright E2E: 로그인→캐릭터 생성→신탁 전송 자동화 | 🔲 미착수 — unstaged 클라이언트 파일 11개로 위험도 최고 | 별도 스펙 필요 |
| P2-2 | Gemini 응답 계약 테스트 (zod 스키마) | 🔲 미착수 | ~30줄 |
| P2-3 | 부하 테스트 CI 기준선 등록 (p95 < 1,000ms) | 🔲 미착수 | CI 워크플로 확장 |

**10회차 진단**: P0-1(npm test) 9회 만에 해소. 이제 `npm test`로 6개 파일 일괄 실행 가능. 단, P0-2(CI 워크플로)가 없어 자동 게이트가 여전히 없음. oracle-cooldown은 테스트 없이 머지 완료(P1-4 사후 보완 필요). oracle-ranking-leaderboard는 AC7/AC8/AC9 미구현 중 in-flight 상태(P1-5 머지 전 작성 필요). Godot 클라이언트 unstaged 파일이 11개로 늘어 P2-1 위험도가 가장 높은 상태. **hyeonseok에게 P0-2 착수 결정, P1-4 사후 보완 및 P2-1 Godot 파일 커밋 전 수동 검증 요청 필요.**

---

## 2026-04-13 점검 9회차 (태연 스케줄 점검 — oracle-battleroyale 테스트 전략)

### 현재 테스트 커버리지 상태

서버: Node.js v22.22.2 / Express (26 모듈) / 클라이언트: Godot 4.3 WebAssembly (14 스크립트, Arena.gd·CharacterCreateScreen.gd·CharacterListScreen.gd 수정 중)

| 구분 | 파일 | 실행 결과 | 비고 |
|------|------|-----------|------|
| 단위 — 전투 로직 | `test/combat.test.js` | ✅ 17/17 통과 | 커스텀 assert harness |
| 단위 — 포인트 시스템 | `test/points.test.js` | ✅ 18/18 통과 | 커스텀 assert harness |
| 단위 — 매치메이킹 | `test/matchmaker.test.js` | ✅ 전체 통과 | Node.js assert |
| 통합 — E2E 플로우 | `test/e2e-flow.test.js` | ✅ 7단계 통과 | Module stub 기반, 실 DB/Redis 없음 |
| 부하 — 32명 동시 | `test/load-32players.test.js` | ✅ p99 < 1,000ms | 실측 p99 ≈ 2.3ms |
| 비용 검증 — Gemini | `test/gemini-cost.test.js` | ✅ $0.005/게임 한도 내 | 정적 계산 ($0.001416 실측) |
| `npm test` 스크립트 | `package.json` | ❌ 미정의 | **P0-1 — 9회차 연속 미해결** |
| CI 서버 테스트 워크플로 | `.github/workflows/` | ❌ 미포함 | **P0-2 — 9회차 연속 미해결** |
| oracle-cooldown 단위 테스트 | — | ❌ 부재 | **P1-4 — in-flight 전환으로 긴급 격상** |
| oracle-ranking-leaderboard 테스트 | — | ❌ 부재 | **P1-5 신규 — in-flight 전환 확인** |
| 실 WebSocket 통합 테스트 | — | ❌ 부재 | P1-1 미착수 |
| DB 마이그레이션 스모크 테스트 | `migrations/` (7개) | ❌ 부재 | P1-2 미착수 |
| Godot 클라이언트 / Playwright E2E | — | ❌ 부재 | P2-1 — 미수정 클라이언트 파일 증가로 위험도 상승 |

### 발견한 문제점 (8회차 대비 신규 변동)

1. **`npm test` 미정의** — 6개 테스트 파일을 개별 `node`로만 실행 가능. CI 집계 불가 (P0-1)
2. **CI 서버 테스트 워크플로 미생성** — `client-web-export.yml`만 존재. PR merge gate 없음 (P0-2)
3. **스텁 기반 통합 테스트** — PostgreSQL, Redis, Gemini 모두 모킹. 실 서비스 회귀 감지 불가 (P1)
4. **WebSocket 프로토콜 실 검증 없음** — `ws/server.js` 핸들러 실 연결 미검증 (P1-1)
5. **Godot 클라이언트 테스트 완전 부재** — Arena.gd·CharacterCreateScreen.gd·CharacterListScreen.gd 수정 사항이 unstaged 상태로 존재하며 무검증 (P2-1, 위험도 상승)
6. **커스텀 assert harness** — CI 표준 출력 파싱 불가 (P1-3)
7. **🆕 oracle-cooldown `in-flight` 전환 확인** — `feat(oracle-cooldown)` 브랜치가 queued → in-flight 상태. DevourerKing 구현 중. P1-4 테스트 없이 머지될 경우 회귀 위험 현실화.
8. **🆕 oracle-ranking-leaderboard `in-flight` 전환 확인** — 별도 플로우(`oracle-ranking-leaderboard`)가 in-flight 진입. 리더보드 정렬·집계 로직 단위 테스트 부재 (P1-5 신규).

### 개선 제안 상태 (9회차 기준)

| 우선순위 | 작업 | 상태 | 구현 규모 |
|----------|------|------|-----------|
| P0-1 | `package.json`에 `"test": "node --test test/**/*.test.js"` 추가 | ⏳ hyeonseok 착수 승인 대기 (9회 연속) | ~1줄 |
| P0-2 | `.github/workflows/server-test.yml` 생성 (push/PR 트리거) | ⏳ hyeonseok 착수 승인 대기 (9회 연속) | ~20줄 |
| P1-1 | 실 WebSocket 통합 테스트 (`ws` 클라이언트 + `redis-memory-server`) | 🔲 미착수 | ~100줄 |
| P1-2 | `pg-mem` 마이그레이션 스모크 테스트 (7개 SQL 순서 적용) | 🔲 미착수 | ~60줄 |
| P1-3 | 커스텀 assert → `node:test` 표준화 | 🔲 미착수 | ~50줄 |
| P1-4 | `oracle-cooldown` 쿨다운 로직 단위 테스트 | 🔴 **긴급** — in-flight 전환 확인, 머지 전 필요 | ~40줄 |
| P1-5 | `oracle-ranking-leaderboard` 정렬·집계 단위 테스트 | 🆕 신규 — in-flight 전환 확인 | ~40줄 |
| P2-1 | Playwright E2E: 로그인→캐릭터 생성→신탁 전송 자동화 | 🔲 미착수 (클라이언트 변경 증가로 위험도 상승) | 별도 스펙 필요 |
| P2-2 | Gemini 응답 계약 테스트 (zod 스키마) | 🔲 미착수 | ~30줄 |
| P2-3 | 부하 테스트 CI 기준선 등록 (p95 < 1,000ms) | 🔲 미착수 | CI 워크플로 확장 |

**9회차 진단**: P0-1·P0-2가 9회 연속 미해결인 상태에서 `oracle-cooldown`과 `oracle-ranking-leaderboard` 두 기능이 동시에 in-flight 진입. P1-4·P1-5 테스트 없이 두 기능이 머지될 경우 회귀 감지 불가. 또한 Godot 클라이언트 3개 파일이 unstaged 수정 상태로 검증 없이 커밋될 위험이 있음. **hyeonseok에게 P0-1·P0-2 착수 결정 및 P1-4 긴급 작성 여부 명시적 확인 필요.**

---

## 2026-04-13 점검 8회차 (태연 스케줄 점검 — oracle-battleroyale 테스트 전략)

### 현재 테스트 커버리지 상태

서버: Node.js v22.22.2 / Express (26 모듈) / 클라이언트: Godot 4.3 WebAssembly (14 스크립트)

| 구분 | 파일 | 실행 결과 | 비고 |
|------|------|-----------|------|
| 단위 — 전투 로직 | `test/combat.test.js` | ✅ 17/17 통과 | 커스텀 assert harness |
| 단위 — 포인트 시스템 | `test/points.test.js` | ✅ 18/18 통과 | 커스텀 assert harness |
| 단위 — 매치메이킹 | `test/matchmaker.test.js` | ✅ 전체 통과 | Node.js assert |
| 통합 — E2E 플로우 | `test/e2e-flow.test.js` | ✅ 7단계 통과 | Module stub 기반, 실 DB/Redis 없음 |
| 부하 — 32명 동시 | `test/load-32players.test.js` | ✅ p99 < 1,000ms | 실측 p99 ≈ 8ms 수준 |
| 비용 검증 — Gemini | `test/gemini-cost.test.js` | ✅ $0.005/게임 한도 내 | 정적 계산 ($0.001416 실측) |
| `npm test` 스크립트 | `package.json` | ❌ 미정의 | **P0-1 — 8회차 연속 미해결** |
| CI 서버 테스트 워크플로 | `.github/workflows/` | ❌ 미포함 | **P0-2 — 8회차 연속 미해결** |
| 실 WebSocket 통합 테스트 | — | ❌ 부재 | P1-1 미착수 |
| DB 마이그레이션 스모크 테스트 | `migrations/` (7개) | ❌ 부재 | P1-2 미착수 |
| oracle-cooldown 단위 테스트 | — | ❌ 부재 | P1-4 신규 — `feat(oracle-cooldown)` 머지 후 즉시 필요 |
| Godot 클라이언트 / Playwright E2E | — | ❌ 부재 | P2-1 미착수 |

### 발견한 문제점 (7회차 대비 변동 없음)

1. **`npm test` 미정의** — 6개 테스트 파일을 개별 `node`로만 실행 가능. CI 집계 불가 (P0-1)
2. **CI 서버 테스트 워크플로 미생성** — `client-web-export.yml`만 존재. PR merge gate 없음 (P0-2)
3. **스텁 기반 통합 테스트** — PostgreSQL, Redis, Gemini 모두 모킹. 실 서비스 회귀 감지 불가 (P1)
4. **WebSocket 프로토콜 실 검증 없음** — `ws/server.js` 핸들러(queue_join, oracle_send 등) 실 연결 미검증 (P1-1)
5. **Godot 클라이언트 테스트 완전 부재** — 14개 GDScript 파일 무검증 (P2-1)
6. **커스텀 assert harness** — `combat.test.js`, `points.test.js` CI 표준 출력 파싱 불가 (P1-3)
7. **`oracle-cooldown` 기능 queued 상태** — `feat(oracle-cooldown): draft → queued 전환` (eb6c118). 구현 완료 시 P1-4 테스트 없이 머지될 위험 존재.

### 개선 제안 상태 (8회차 기준)

| 우선순위 | 작업 | 상태 | 구현 규모 |
|----------|------|------|-----------|
| P0-1 | `package.json`에 `"test": "node --test test/**/*.test.js"` 추가 | ⏳ hyeonseok 착수 승인 대기 | ~1줄 |
| P0-2 | `.github/workflows/server-test.yml` 생성 (push/PR 트리거) | ⏳ hyeonseok 착수 승인 대기 | ~20줄 |
| P1-1 | 실 WebSocket 통합 테스트 (`ws` 클라이언트 + `redis-memory-server`) | 🔲 미착수 | ~100줄 |
| P1-2 | `pg-mem` 마이그레이션 스모크 테스트 (7개 SQL 순서 적용) | 🔲 미착수 | ~60줄 |
| P1-3 | 커스텀 assert → `node:test` 표준화 | 🔲 미착수 | ~50줄 |
| P1-4 | `oracle-cooldown` 쿨다운 로직 단위 테스트 | 🔲 신규 — `feat(oracle-cooldown)` 머지 전 필요 | ~40줄 |
| P2-1 | Playwright E2E: 로그인→캐릭터 생성→신탁 전송 자동화 | 🔲 미착수 | 별도 스펙 필요 |
| P2-2 | Gemini 응답 계약 테스트 (zod 스키마) | 🔲 미착수 | ~30줄 |
| P2-3 | 부하 테스트 CI 기준선 등록 (p95 < 1,000ms) | 🔲 미착수 | CI 워크플로 확장 |

**8회차 진단**: P0-1·P0-2 8회 연속 미해결. 승인 대기 교착 상태 지속 중. P1-4(`oracle-cooldown` 단위 테스트)는 `feat(oracle-cooldown)` 브랜치 머지 전 선제 작성이 필요하며, 이미 queued 상태이므로 타이밍이 좁아지고 있음. 다음 회차 전 hyeonseok 명시적 확인 또는 P0/P1 일괄 착수 결정 권장.

---

## 2026-04-13 점검 7회차 (태연 스케줄 점검 — oracle-battleroyale 테스트 전략)

### 현재 테스트 커버리지 상태

서버: Node.js v22.22.2 / Express (25 모듈) / 클라이언트: Godot 4.3 WebAssembly (14 스크립트)

| 구분 | 파일 | 실행 결과 | 비고 |
|------|------|-----------|------|
| 단위 — 전투 로직 | `test/combat.test.js` | ✅ 17/17 통과 | 커스텀 assert harness |
| 단위 — 포인트 시스템 | `test/points.test.js` | ✅ 18/18 통과 | 커스텀 assert harness |
| 단위 — 매치메이킹 | `test/matchmaker.test.js` | ✅ 전체 통과 | Node.js assert |
| 통합 — E2E 플로우 | `test/e2e-flow.test.js` | ✅ 7단계 통과 | Module stub 기반, 실 DB/Redis 없음 |
| 부하 — 32명 동시 | `test/load-32players.test.js` | ✅ p99 < 1,000ms | 실측 p99 ≈ 5ms 수준 |
| 비용 검증 — Gemini | `test/gemini-cost.test.js` | ✅ $0.005/게임 한도 내 | 정적 계산 |
| `npm test` 스크립트 | `package.json` | ❌ 미정의 | **P0-1 — 7회차 연속 미해결** |
| CI 서버 테스트 워크플로 | `.github/workflows/` | ❌ 미포함 | **P0-2 — 7회차 연속 미해결** |
| 실 WebSocket 통합 테스트 | — | ❌ 부재 | P1-1 미착수 |
| DB 마이그레이션 스모크 테스트 | `migrations/` (7개) | ❌ 부재 | P1-2 미착수 |
| Godot 클라이언트 / Playwright E2E | — | ❌ 부재 | P2-1 미착수 |

### 발견한 문제점 (6회차 대비 변동 없음)

1. **`npm test` 미정의** — 6개 테스트 파일을 개별 `node`로만 실행 가능. CI 집계 불가 (P0-1)
2. **CI 서버 테스트 워크플로 미생성** — `client-web-export.yml`만 존재. PR merge gate 없음 (P0-2)
3. **스텁 기반 통합 테스트** — PostgreSQL, Redis, Gemini 모두 모킹. 실 서비스 회귀 감지 불가 (P1)
4. **WebSocket 프로토콜 실 검증 없음** — `ws/server.js` 핸들러(queue_join, oracle_send 등) 실 연결 미검증 (P1-1)
5. **Godot 클라이언트 테스트 완전 부재** — 14개 GDScript 파일 무검증 (P2-1)
6. **커스텀 assert harness** — `combat.test.js`, `points.test.js` CI 표준 출력 파싱 불가 (P1-3)
7. **최신 커밋 `oracle-cooldown` 플로우 추가** — `feat(oracle-cooldown): draft → queued 전환` (eb6c118). 신탁 쿨다운 로직이 queued 상태로 구현 대기 중이나, 해당 기능에 대한 테스트 계획 없음.

### 개선 제안 상태 (7회차 기준)

| 우선순위 | 작업 | 상태 | 구현 규모 |
|----------|------|------|-----------|
| P0-1 | `package.json`에 `"test": "node --test test/**/*.test.js"` 추가 | ⏳ hyeonseok 착수 승인 대기 | ~1줄 |
| P0-2 | `.github/workflows/server-test.yml` 생성 (push/PR 트리거) | ⏳ hyeonseok 착수 승인 대기 | ~20줄 |
| P1-1 | 실 WebSocket 통합 테스트 (`ws` 클라이언트 + `redis-memory-server`) | 🔲 미착수 | ~100줄 |
| P1-2 | `pg-mem` 마이그레이션 스모크 테스트 (7개 SQL 순서 적용) | 🔲 미착수 | ~60줄 |
| P1-3 | 커스텀 assert → `node:test` 표준화 | 🔲 미착수 | ~50줄 |
| P1-4 | `oracle-cooldown` 쿨다운 로직 단위 테스트 | 🔲 신규 — 구현 완료 후 즉시 필요 | ~40줄 |
| P2-1 | Playwright E2E: 로그인→캐릭터 생성→신탁 전송 자동화 | 🔲 미착수 | 별도 스펙 필요 |
| P2-2 | Gemini 응답 계약 테스트 (zod 스키마) | 🔲 미착수 | ~30줄 |
| P2-3 | 부하 테스트 CI 기준선 등록 (p95 < 1,000ms) | 🔲 미착수 | CI 워크플로 확장 |

**7회차 진단**: P0-1·P0-2는 각각 1~20줄 규모로 7회 연속 미해결. hyeonseok 착수 승인이 유일한 블로커. 신규: `oracle-cooldown` 기능이 queued 진입 → 구현 완료 시점에 맞춰 P1-4(쿨다운 단위 테스트) 선제 준비 권장.

---

## 2026-04-13 점검 6회차 (태연 스케줄 점검 — oracle-battleroyale 테스트 전략)

### 현재 테스트 커버리지 상태

서버: Node.js/Express (25 모듈) / 클라이언트: Godot 4.3 WebAssembly (14 스크립트)

| 구분 | 파일 | 실행 결과 | 비고 |
|------|------|-----------|------|
| 단위 — 전투 로직 | `test/combat.test.js` | ✅ 17/17 통과 | 커스텀 assert harness |
| 단위 — 포인트 시스템 | `test/points.test.js` | ✅ 18/18 통과 | 커스텀 assert harness |
| 단위 — 매치메이킹 | `test/matchmaker.test.js` | ✅ 전체 통과 | Node.js assert |
| 통합 — E2E 플로우 | `test/e2e-flow.test.js` | ✅ 7단계 통과 | Module stub 기반, 실 DB/Redis 없음 |
| 부하 — 32명 동시 | `test/load-32players.test.js` | ✅ p99 < 1,000ms | 실측 p99 ≈ 5ms 수준 |
| 비용 검증 — Gemini | `test/gemini-cost.test.js` | ✅ $0.005/게임 한도 내 | 정적 계산 |
| `npm test` 스크립트 | `package.json` | ❌ 미정의 | **P0-1 — 6회차 연속 미해결** |
| CI 서버 테스트 워크플로 | `.github/workflows/` | ❌ 미포함 | **P0-2 — 6회차 연속 미해결** |
| 실 WebSocket 통합 테스트 | — | ❌ 부재 | P1-1 미착수 |
| DB 마이그레이션 스모크 테스트 | `migrations/` (7개) | ❌ 부재 | P1-2 미착수 |
| Godot 클라이언트 / Playwright E2E | — | ❌ 부재 | P2-1 미착수 |

### 발견한 문제점 (5회차 대비 변동 없음)

1. **`npm test` 미정의** — 6개 테스트 파일을 개별 `node`로만 실행 가능. CI 집계 불가 (P0-1)
2. **CI 서버 테스트 워크플로 미생성** — `client-web-export.yml`만 존재. PR merge gate 없음 (P0-2)
3. **스텁 기반 통합 테스트** — PostgreSQL, Redis, Gemini 모두 모킹. 실 서비스 회귀 감지 불가 (P1)
4. **WebSocket 프로토콜 실 검증 없음** — `ws/server.js` 핸들러(queue_join, oracle_send 등) 실 연결 미검증 (P1-1)
5. **Godot 클라이언트 테스트 완전 부재** — 14개 GDScript 파일 무검증 (P2-1)
6. **커스텀 assert harness** — `combat.test.js`, `points.test.js` CI 표준 출력 파싱 불가 (P1-3)

### 개선 제안 상태 (6회차 기준)

| 우선순위 | 작업 | 상태 | 구현 규모 |
|----------|------|------|-----------|
| P0-1 | `package.json`에 `"test": "node --test test/**/*.test.js"` 추가 | ⏳ hyeonseok 착수 승인 대기 | ~1줄 |
| P0-2 | `.github/workflows/server-test.yml` 생성 (push/PR 트리거) | ⏳ hyeonseok 착수 승인 대기 | ~20줄 |
| P1-1 | 실 WebSocket 통합 테스트 (`ws` 클라이언트 + `redis-memory-server`) | 🔲 미착수 | ~100줄 |
| P1-2 | `pg-mem` 마이그레이션 스모크 테스트 (7개 SQL 순서 적용) | 🔲 미착수 | ~60줄 |
| P1-3 | 커스텀 assert → `node:test` 표준화 | 🔲 미착수 | ~50줄 |
| P2-1 | Playwright E2E: 로그인→캐릭터 생성→신탁 전송 자동화 | 🔲 미착수 | 별도 스펙 필요 |
| P2-2 | Gemini 응답 계약 테스트 (zod 스키마) | 🔲 미착수 | ~30줄 |
| P2-3 | 부하 테스트 CI 기준선 등록 (p95 < 1,000ms) | 🔲 미착수 | CI 워크플로 확장 |

**6회차 진단**: P0-1·P0-2는 각각 1~20줄 규모로 매우 작음. 6회 연속 미해결 — hyeonseok 착수 승인이 유일한 블로커. 미착수가 지속될 경우 태양소녀/먹마 프로젝트 개발 가속 후 일괄 처리 방안도 검토 필요.

---

## 2026-04-13 점검 5회차 (태연 스케줄 점검 — oracle-battleroyale 테스트 전략)

### 현재 테스트 커버리지 상태

서버: Node.js v22.22.2 / Express (24 모듈) / 클라이언트: Godot 4.x WebAssembly

| 구분 | 파일 | 실행 결과 | 비고 |
|------|------|-----------|------|
| 단위 — 전투 로직 | `test/combat.test.js` | ✅ 17/17 통과 | 커스텀 assert harness |
| 단위 — 포인트 시스템 | `test/points.test.js` | ✅ 18/18 통과 | 커스텀 assert harness |
| 단위 — 매치메이킹 | `test/matchmaker.test.js` | ✅ 전체 통과 | Node.js assert |
| 통합 — E2E 플로우 | `test/e2e-flow.test.js` | ✅ 7단계 통과 | Module stub 기반 |
| 부하 — 32명 동시 | `test/load-32players.test.js` | ✅ p95 통과 | 실측 CPU+I/O ≈ 6.9ms |
| 비용 검증 — Gemini | `test/gemini-cost.test.js` | ✅ 통과 | 헤드룸 112 오라클 호출 |
| `npm test` 스크립트 | `package.json` | ❌ 미정의 | **P0-1 — 5회차 연속 미해결** |
| CI 서버 테스트 워크플로 | `.github/workflows/` | ❌ 미포함 | **P0-2 — 5회차 연속 미해결** |
| 실 WebSocket 통합 테스트 | — | ❌ 부재 | P1-1 미착수 |
| DB 마이그레이션 스모크 테스트 | — | ❌ 부재 | P1-2 미착수 |
| Godot 클라이언트 / Playwright E2E | — | ❌ 부재 | P2-1 미착수 |

### 발견한 문제점 (1~4회차 대비 변동 없음)

1. **`npm test` 미정의** — 6개 파일 개별 `node` 실행만 가능. 집계·파이프라인 연동 불가 (P0-1)
2. **CI 서버 테스트 워크플로 미생성** — PR merge gate 없음 (P0-2)
3. **스텁 기반 통합 테스트** — PostgreSQL, Redis, Gemini 모두 모킹 (P1)
4. **WebSocket 프로토콜 실 검증 없음** — `ws/server.js` 메시지 핸들러 실 연결 테스트 없음 (P1-1)
5. **Godot 클라이언트 테스트 완전 부재** (P2-1)
6. **커스텀 assert harness** — CI 표준 출력 파싱 불가 (P1-3)

### 개선 제안 상태 (5회차 기준)

| 우선순위 | 작업 | 상태 | 규모 |
|----------|------|------|------|
| P0-1 | `package.json` `"test"` 스크립트 추가 | ⏳ hyeonseok 확인 대기 | ~1줄 |
| P0-2 | `server-test.yml` GitHub Actions 생성 | ⏳ hyeonseok 확인 대기 | ~20줄 |
| P1-1 | 실 WS 통합 테스트 (`redis-memory-server` 활용) | 🔲 미착수 | ~100줄 |
| P1-2 | `pg-mem` 마이그레이션 스모크 테스트 | 🔲 미착수 | ~60줄 |
| P1-3 | 커스텀 assert → `node:test` 표준화 | 🔲 미착수 | ~50줄 |
| P2-1~3 | Playwright E2E / Gemini 계약 / 부하 CI 기준선 | 🔲 미착수 | 별도 스펙 필요 |

**5회차 진단**: P0-1·P0-2는 구현 규모가 각 1~20줄로 매우 작음. 5회 연속 미해결로 hyeonseok 착수 승인이 유일한 블로커.

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

## 2026-04-13 점검 2회차 (태연 스케줄 점검 — oracle-battleroyale 테스트 전략)

### 현재 테스트 커버리지 상태

서버: Node.js/Express (24 모듈, 3,264 LOC) / 클라이언트: Godot 4.x WebAssembly (13 스크립트, 2,418 LOC)

| 구분 | 파일 | 실행 가능 | 비고 |
|------|------|-----------|------|
| 단위 — 전투 로직 | `test/combat.test.js` | ✅ node 직접 실행 | 커스텀 assert harness |
| 단위 — 포인트 시스템 | `test/points.test.js` | ✅ node 직접 실행 | 커스텀 assert harness |
| 단위 — 매치메이킹 | `test/matchmaker.test.js` | ✅ node 직접 실행 | Node.js assert 사용 |
| 통합 — E2E 플로우 | `test/e2e-flow.test.js` | ✅ node 직접 실행 | Module stub 기반, 실 DB/Redis 없음 |
| 부하 — 32명 동시 | `test/load-32players.test.js` | ✅ node 직접 실행 | p95 < 1,000ms SLA |
| 비용 검증 — Gemini | `test/gemini-cost.test.js` | ✅ node 직접 실행 | 정적 계산, 실 API 호출 없음 |
| `npm test` 스크립트 | `package.json` | ❌ 미정의 | start/dev/migrate만 존재 |
| CI 서버 테스트 | `.github/workflows/` | ❌ 미포함 | 클라이언트 export/deploy만 자동화 |
| 실 WebSocket 통합 | — | ❌ 부재 | queue_join, oracle_send 프로토콜 미검증 |
| DB 마이그레이션 검증 | `migrations/*.sql` (7개) | ❌ 부재 | 스키마 정합성 테스트 없음 |
| Godot 클라이언트 | — | ❌ 부재 | UI, WS 송수신, WebAssembly 렌더링 무검증 |
| Playwright E2E | — | ❌ 부재 | `playwright-debug-setup` 스펙 존재하나 미실행 |

### 발견한 문제점 (1회차 대비 변경 없음, 상태 유지)

1. **테스트 러너 미정의**: `npm test` 스크립트 없음 → 6개 파일을 개별 `node`로만 실행 가능, 집계 불가
2. **CI 파이프라인 서버 테스트 제외**: `server-test.yml` 워크플로 미생성 상태. PR merge gate 없음
3. **스텁 기반 통합 테스트**: DB(PostgreSQL), Redis, Gemini 모두 모킹 — 마이그레이션 스키마 변경·Redis 연결·Gemini 응답 포맷 변화에 무방비
4. **WebSocket 프로토콜 무검증**: `ws/server.js` 메시지 핸들러 실 연결 테스트 없음. 프로토콜 변경 시 회귀 감지 불가
5. **Godot 클라이언트 테스트 완전 부재**: WebAssembly 빌드 후 스모크 테스트·UI 렌더링·WS 시나리오 모두 없음
6. **커스텀 assert harness**: `combat.test.js`, `points.test.js`는 자체 pass/fail 카운터 사용 — CI 결과 파싱 어려움

### 개선 제안 (우선순위 재확인)

#### P0 — 즉시 (미해결, DevourerKing 핸드오프 권장)

| # | 작업 | 완료 기준 |
|---|------|----------|
| P0-1 | `package.json`에 `"test": "node --test test/**/*.test.js"` 추가 | `npm test`로 6개 파일 일괄 실행·통과 |
| P0-2 | `.github/workflows/server-test.yml` 생성 (push/PR 트리거) | GitHub Actions에서 서버 테스트 자동 실행 확인 |

#### P1 — 단기 2주 (미착수)

| # | 작업 | 완료 기준 |
|---|------|----------|
| P1-1 | 실 WebSocket 통합 테스트 (`ws` 클라이언트 + `redis-memory-server`) | queue_join→oracle_send→game_over 시나리오 통과 |
| P1-2 | `pg-mem` 활용 마이그레이션 스모크 테스트 | 7개 migration 파일 순서 적용 후 스키마 검증 통과 |
| P1-3 | 커스텀 assert → `node:test` 표준화 | CI 결과 JUnit/TAP 형식 출력 가능 |

#### P2 — 중기 1개월 (미착수)

| # | 작업 | 완료 기준 |
|---|------|----------|
| P2-1 | Playwright E2E: Godot WebAssembly ↔ 서버 시나리오 | 로그인→캐릭터 생성→신탁 전송 자동 통과 |
| P2-2 | Gemini 응답 계약 테스트 (zod 스키마 선언) | API 응답 포맷 변경 시 즉시 실패 |
| P2-3 | 부하 테스트 CI 기준선 등록 | p95 < 1,000ms 회귀 감지 자동화 |

### 다음 액션

- **P0-1, P0-2** DevourerKing 핸드오프 대기 — hyeonseok 확인 후 착수 여부 결정 권장
- 1회차 대비 신규 이슈 없음. 6개 테스트 파일 수동 실행 시 모두 통과 상태 유지

---

## 2026-04-13 점검 3회차 (태연 스케줄 점검 — oracle-battleroyale 테스트 전략)

### 현재 테스트 커버리지 상태

서버: Node.js/Express (24 모듈) / 클라이언트: Godot 4.x WebAssembly (13 스크립트)

| 구분 | 상태 | 비고 |
|------|------|------|
| 단위 — 전투/포인트/매칭 (3개 파일) | ✅ 존재·통과 | 커스텀 assert harness 사용 |
| 통합 — E2E 플로우 | ✅ 존재·통과 | Module stub 기반, 실 DB/Redis 없음 |
| 부하 — 32명 동시 (p95 < 1,000ms) | ✅ 존재·통과 | 실제 p99=9.6ms 수준 |
| 비용 검증 — Gemini | ✅ 존재·통과 | 정적 계산 ($0.001416 최악 기준) |
| `npm test` 스크립트 | ❌ 미정의 | P0-1 미해결 — 3회차 연속 |
| CI 서버 테스트 워크플로 | ❌ 미포함 | P0-2 미해결 — 3회차 연속 |
| 실 WebSocket 통합 테스트 | ❌ 부재 | P1-1 미착수 |
| DB 마이그레이션 스모크 테스트 | ❌ 부재 | P1-2 미착수 |
| Godot 클라이언트 / Playwright E2E | ❌ 부재 | P2-1 미착수 |

### 발견한 문제점 (1·2회차 대비 변동 없음)

1. `npm test` 스크립트 미정의 — 6개 테스트 파일 수동 실행만 가능, 집계 불가 (P0-1)
2. CI 서버 테스트 워크플로 미생성 — PR merge gate 없음 (P0-2)
3. 모든 통합 테스트가 스텁 기반 — DB/Redis/Gemini 실 연결 회귀 감지 불가 (P1)
4. WebSocket 프로토콜 실 검증 없음 — 메시지 핸들러 변경 시 회귀 감지 불가 (P1-1)
5. Godot 클라이언트·Playwright E2E 완전 부재 (P2-1)

### 개선 제안 상태 (3회차 기준)

| 우선순위 | 작업 | 상태 |
|----------|------|------|
| P0-1 | `package.json` `"test"` 스크립트 추가 | ⏳ DevourerKing 핸드오프 대기 |
| P0-2 | `.github/workflows/server-test.yml` 생성 | ⏳ DevourerKing 핸드오프 대기 |
| P1-1 | 실 WebSocket 통합 테스트 (`redis-memory-server` 활용) | 🔲 미착수 |
| P1-2 | `pg-mem` 마이그레이션 스모크 테스트 | 🔲 미착수 |
| P1-3 | 커스텀 assert → `node:test` 표준화 | 🔲 미착수 |
| P2-1~3 | Playwright E2E / Gemini 계약 테스트 / 부하 CI 기준선 | 🔲 미착수 |

**권장 즉시 액션**: P0-1·P0-2는 구현 범위가 작음 (각 10줄 내외). hyeonseok 확인 후 DevourerKing 착수 지시 필요.

---

## 2026-04-13 점검 4회차 (태연 스케줄 점검 — oracle-battleroyale 테스트 전략)

### 현재 테스트 커버리지 상태

서버: Node.js/Express (26 모듈, ~3,300 LOC) / 클라이언트: Godot 4.x WebAssembly (14 스크립트)

| 구분 | 상태 | 비고 |
|------|------|------|
| 단위 — 전투 로직 (`combat.test.js`, 17건) | ✅ 통과 | 커스텀 assert harness, 1,329 LOC |
| 단위 — 포인트 시스템 (`points.test.js`, 18건) | ✅ 통과 | 커스텀 assert harness |
| 단위 — 매치메이킹 (`matchmaker.test.js`, 18건+) | ✅ 통과 | Node.js assert |
| 통합 — E2E 플로우 (`e2e-flow.test.js`, 7단계) | ✅ 통과 | Module stub 기반, 실 DB/Redis 없음 |
| 부하 — 32명 동시 (`load-32players.test.js`, p99<1,000ms) | ✅ 통과 | 실측 p99 ≈ 9.6ms |
| 비용 검증 — Gemini (`gemini-cost.test.js`, $0.005/게임 한도) | ✅ 통과 | 정적 계산 |
| `npm test` 스크립트 | ❌ 미정의 | **P0-1 — 4회차 연속 미해결** |
| CI 서버 테스트 워크플로 | ❌ 미포함 | **P0-2 — 4회차 연속 미해결** |
| 실 WebSocket 통합 테스트 | ❌ 부재 | P1-1 미착수 |
| DB 마이그레이션 스모크 테스트 | ❌ 부재 | P1-2 미착수 (migrations/ 7개 파일) |
| Godot 클라이언트 / Playwright E2E | ❌ 부재 | P2-1 미착수 |

### 발견한 문제점 (1~3회차 대비 변동 없음)

1. **`npm test` 미정의** — 6개 테스트 파일 개별 `node` 실행만 가능. 집계·파이프라인 연동 불가 (P0-1)
2. **CI 서버 테스트 워크플로 미생성** — `.github/workflows/`에 클라이언트 export 워크플로만 존재. PR merge gate 없음 (P0-2)
3. **스텁 기반 통합 테스트** — PostgreSQL, Redis, Gemini API 모두 모킹. 스키마 변경·API 포맷 변화 무방비 (P1)
4. **WebSocket 프로토콜 실 검증 없음** — `ws/server.js` 메시지 핸들러(queue_join, oracle_send 등) 실 연결 테스트 없음 (P1-1)
5. **Godot 클라이언트 테스트 완전 부재** — WebAssembly 빌드 스모크·UI·WS 시나리오 모두 없음 (P2-1)
6. **커스텀 assert harness** — `combat.test.js`, `points.test.js`는 자체 pass/fail 카운터 사용. CI 표준 출력 파싱 불가 (P1-3)

### 개선 제안 상태 (4회차 기준)

| 우선순위 | 작업 | 상태 | 구현 규모 |
|----------|------|------|-----------|
| P0-1 | `package.json`에 `"test": "node --test test/**/*.test.js"` 추가 | ⏳ DevourerKing 핸드오프 대기 | ~1줄 |
| P0-2 | `.github/workflows/server-test.yml` 생성 (push/PR 트리거) | ⏳ DevourerKing 핸드오프 대기 | ~20줄 |
| P1-1 | 실 WebSocket 통합 테스트 (`ws` 클라이언트 + `redis-memory-server`) | 🔲 미착수 | ~100줄 |
| P1-2 | `pg-mem` 활용 마이그레이션 스모크 테스트 (7개 SQL 파일) | 🔲 미착수 | ~60줄 |
| P1-3 | 커스텀 assert → `node:test` 표준화 | 🔲 미착수 | ~50줄 변경 |
| P2-1 | Playwright E2E: 로그인→캐릭터 생성→신탁 전송 시나리오 | 🔲 미착수 | 별도 스펙 필요 |
| P2-2 | Gemini 응답 계약 테스트 (zod 스키마 선언) | 🔲 미착수 | ~30줄 |
| P2-3 | 부하 테스트 CI 기준선 등록 (p95 < 1,000ms) | 🔲 미착수 | CI 워크플로 확장 |

### 4회차 진단 요약

P0 항목이 4회 연속 미해결 상태. 구현 규모가 각각 1~20줄로 매우 작음에도 착수되지 않고 있어 **hyeonseok 의사결정이 블로커**임. 다음 액션:

- hyeonseok에게 P0-1·P0-2 DevourerKing 착수 승인 요청
- 승인 시 즉시 핸드오프 문서 작성 가능 (입력/출력/검증 기준 준비됨)

---
