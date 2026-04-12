# Test Execution Log — oracle-battleroyale

---

## 2026-04-13 #2 (태연 스케줄 실행 — 2회차)

**실행 시각**: 2026-04-13  
**실행 환경**: Node.js v22.22.2, `/shared/oracle-battleroyale/server`

### 실행한 테스트 목록

| 파일 | 설명 |
|------|------|
| `test/matchmaker.test.js` | 매치메이커 큐 로직 (32플레이어, NPC 충원, 중복 방지, 이탈) |
| `test/combat.test.js` | 전투 시뮬레이션 (클래스 밸런스, NPC 프리셋, 마이그레이션 파일) |
| `test/points.test.js` | 포인트 시스템 (oracle_send 차감, win/completion 보너스, 일일 로그인, WS 이벤트) |
| `test/gemini-cost.test.js` | Gemini API 비용 검증 (게임당 $0.005 이하 예산 준수) |
| `test/load-32players.test.js` | 32플레이어 × 50턴 부하 테스트 (p99 < 1000ms SLA) |
| `test/e2e-flow.test.js` | 전체 E2E 흐름 (로그인 → 캐릭터 생성 → 매치 참가 → Oracle 전송 → 게임 종료 → 포인트 정산) |

### 결과

**전체: 6/6 통과, 실패 0건**

| 테스트 | 결과 | 주요 수치 |
|--------|------|-----------|
| matchmaker | ✅ 전체 통과 | 32플레이어 즉시 매칭, NPC 22명 충원, 중복/이탈 정상 |
| combat | ✅ 17/17 통과 | 클래스 5종 밸런스, NPC 프리셋, max_hp 마이그레이션 정상 |
| points | ✅ 18/18 통과 | oracle_send -10pt, win_bonus +50pt, 일일 로그인 중복 방지 정상 |
| gemini-cost | ✅ 통과 | 최악 $0.001416 / 일반 $0.000442 (예산 $0.005 이하) |
| load-32players | ✅ 통과 | p50=0.563ms, p95=2.772ms, p99=9.598ms, max=9.598ms (SLA 1000ms 이하) |
| e2e-flow | ✅ 7/7 단계 통과 | GEMINI_API_KEY 미설정 → keyword fallback 정상 동작 |

### 수정한 버그

없음 — 이번 실행에서 수정된 버그 없음.

### 미해결 이슈

| 이슈 | 내용 |
|------|------|
| GEMINI_API_KEY 미설정 | 환경변수 미설정 시 keyword fallback 동작 확인됨. 실제 서비스 배포 전 API 키 설정 필요. |
| package.json `test` 스크립트 없음 | `npm test` 미지원. 테스트 실행은 `node test/<file>.test.js` 직접 호출 필요. 스크립트 추가 권장. |

---

## 2026-04-13 (태연 스케줄 실행)

**실행 시각**: 2026-04-13  
**실행 환경**: Node.js v22.22.2, `/shared/oracle-battleroyale/server`

### 실행한 테스트 목록

| 파일 | 설명 |
|------|------|
| `test/matchmaker.test.js` | 매치메이커 큐 로직 (32플레이어, NPC 충원, 중복 방지, 이탈) |
| `test/combat.test.js` | 전투 시뮬레이션 (클래스 밸런스, NPC 프리셋, 마이그레이션 파일) |
| `test/points.test.js` | 포인트 시스템 (oracle_send 차감, win/completion 보너스, 일일 로그인, WS 이벤트) |
| `test/gemini-cost.test.js` | Gemini API 비용 검증 (게임당 $0.005 이하 예산 준수) |
| `test/load-32players.test.js` | 32플레이어 × 50턴 부하 테스트 (p99 < 1000ms SLA) |
| `test/e2e-flow.test.js` | 전체 E2E 흐름 (로그인 → 캐릭터 생성 → 매치 참가 → Oracle 전송 → 게임 종료 → 포인트 정산) |

### 결과

**전체: 6/6 통과, 실패 0건**

| 테스트 | 결과 | 주요 수치 |
|--------|------|-----------|
| matchmaker | ✅ 전체 통과 | 32플레이어 즉시 매칭, NPC 22명 충원, 중복/이탈 정상 |
| combat | ✅ 17/17 통과 | 클래스 5종 밸런스, NPC 프리셋, max_hp 마이그레이션 정상 |
| points | ✅ 18/18 통과 | oracle_send -10pt, win_bonus +50pt, 일일 로그인 중복 방지 정상 |
| gemini-cost | ✅ 통과 | 최악 $0.001416 / 일반 $0.000442 (예산 $0.005 이하) |
| load-32players | ✅ 통과 | p50=0.142ms, p95=1.348ms, p99=2.841ms, max=2.841ms |
| e2e-flow | ✅ 7/7 단계 통과 | GEMINI_API_KEY 미설정 → keyword fallback 정상 동작 |

### 수정한 버그

없음 — 이번 실행에서 수정된 버그 없음.

### 미해결 이슈

| 이슈 | 내용 |
|------|------|
| GEMINI_API_KEY 미설정 | 환경변수 미설정 시 keyword fallback 동작 확인됨. 실제 서비스 배포 전 API 키 설정 필요. |
| package.json `test` 스크립트 없음 | `npm test` 미지원. 테스트 실행은 `node test/<file>.test.js` 직접 호출 필요. 스크립트 추가 권장. |
