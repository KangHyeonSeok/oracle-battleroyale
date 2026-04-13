# Test Execution Log — oracle-battleroyale

---

## 2026-04-13 #12 (태연 스케줄 실행 — 12회차)

**실행 시각**: 2026-04-13  
**실행 환경**: Node.js v22.22.2, `/shared/oracle-battleroyale/server`

### 실행한 테스트 목록

| 파일 | 설명 |
|------|------|
| `test/combat.test.js` | 전투 시뮬레이션 (클래스 밸런스, NPC 프리셋, max_hp 마이그레이션) |
| `test/points.test.js` | 포인트 시스템 (oracle_send 차감, win/completion 보너스, 일일 로그인, WS 이벤트) |
| `test/e2e-flow.test.js` | 전체 E2E 흐름 (로그인 → 캐릭터 생성 → 매치 참가 → Oracle 전송 → 게임 종료 → 포인트 정산) |
| `test/matchmaker.test.js` | 매치메이커 큐 로직 (32플레이어, NPC 충원, 중복 방지, 이탈) |
| `test/load-32players.test.js` | 32플레이어 × 50턴 부하 테스트 (p99 < 1000ms SLA) |
| `test/gemini-cost.test.js` | Gemini API 비용 검증 (게임당 $0.005 이하 예산 준수) |

### 결과

**전체: 6/6 통과, 실패 0건**

| 테스트 | 결과 | 주요 수치 |
|--------|------|-----------|
| combat | ✅ 17/17 통과 | 클래스 5종 밸런스, NPC 프리셋, max_hp 마이그레이션 정상 |
| points | ✅ 18/18 통과 | oracle_send -10pt, win_bonus +50pt, 일일 로그인 중복 방지 정상 |
| e2e-flow | ✅ 7/7 단계 통과 | GEMINI_API_KEY 미설정 → keyword fallback 정상 동작 |
| matchmaker | ✅ 전체 통과 | 32플레이어 즉시 매칭, NPC 22명 충원, 중복/이탈 정상 |
| load-32players | ✅ 통과 | p50=0.368ms, p95=3.102ms, p99=6.525ms, max=6.525ms (SLA 1000ms 이하) |
| gemini-cost | ✅ 통과 | 최악 $0.001416 / 일반 $0.000442 (예산 $0.005 이하) |

### 수정한 버그

없음 — 전 회차 수정 사항 유지, 신규 버그 없음.

### 미해결 이슈

| 이슈 | 내용 |
|------|------|
| GEMINI_API_KEY 미설정 | 환경변수 미설정 시 keyword fallback 동작 확인됨. 실제 서비스 배포 전 API 키 설정 필요. |

---

## 2026-04-13 #11 (태연 스케줄 실행 — 11회차)

**실행 시각**: 2026-04-13  
**실행 환경**: Node.js v22.22.2, `/shared/oracle-battleroyale/server`

### 실행한 테스트 목록

| 파일 | 설명 |
|------|------|
| `test/combat.test.js` | 전투 시뮬레이션 (클래스 밸런스, NPC 프리셋, max_hp 마이그레이션) |
| `test/points.test.js` | 포인트 시스템 (oracle_send 차감, win/completion 보너스, 일일 로그인, WS 이벤트) |
| `test/e2e-flow.test.js` | 전체 E2E 흐름 (로그인 → 캐릭터 생성 → 매치 참가 → Oracle 전송 → 게임 종료 → 포인트 정산) |
| `test/matchmaker.test.js` | 매치메이커 큐 로직 (32플레이어, NPC 충원, 중복 방지, 이탈) |
| `test/load-32players.test.js` | 32플레이어 × 50턴 부하 테스트 (p99 < 1000ms SLA) |
| `test/gemini-cost.test.js` | Gemini API 비용 검증 (게임당 $0.005 이하 예산 준수) |

### 결과

**전체: 6/6 통과, 실패 0건**

| 테스트 | 결과 | 주요 수치 |
|--------|------|-----------|
| combat | ✅ 17/17 통과 | 클래스 5종 밸런스, NPC 프리셋, max_hp 마이그레이션 정상 |
| points | ✅ 18/18 통과 | oracle_send -10pt, win_bonus +50pt, 일일 로그인 중복 방지 정상 |
| e2e-flow | ✅ 7/7 단계 통과 | GEMINI_API_KEY 미설정 → keyword fallback 정상 동작 |
| matchmaker | ✅ 전체 통과 | 32플레이어 즉시 매칭, NPC 22명 충원, 중복/이탈 정상 |
| load-32players | ✅ 통과 | p50=0.358ms, p95=1.997ms, p99=5.452ms, max=5.452ms (SLA 1000ms 이하) |
| gemini-cost | ✅ 통과 | 최악 $0.001416 / 일반 $0.000442 (예산 $0.005 이하) |

### 수정한 버그

없음 — 전 회차 수정 사항 유지, 신규 버그 없음.

### 미해결 이슈

| 이슈 | 내용 |
|------|------|
| GEMINI_API_KEY 미설정 | 환경변수 미설정 시 keyword fallback 동작 확인됨. 실제 서비스 배포 전 API 키 설정 필요. |

---

## 2026-04-13 #10 (태연 스케줄 실행 — 10회차)

**실행 시각**: 2026-04-13  
**실행 환경**: Node.js v22.22.2, `/shared/oracle-battleroyale/server`

### 실행한 테스트 목록

| 파일 | 설명 |
|------|------|
| `test/combat.test.js` | 전투 시뮬레이션 (클래스 밸런스, NPC 프리셋, max_hp 마이그레이션) |
| `test/points.test.js` | 포인트 시스템 (oracle_send 차감, win/completion 보너스, 일일 로그인, WS 이벤트) |
| `test/e2e-flow.test.js` | 전체 E2E 흐름 (로그인 → 캐릭터 생성 → 매치 참가 → Oracle 전송 → 게임 종료 → 포인트 정산) |
| `test/matchmaker.test.js` | 매치메이커 큐 로직 (32플레이어, NPC 충원, 중복 방지, 이탈) |
| `test/load-32players.test.js` | 32플레이어 × 50턴 부하 테스트 (p99 < 1000ms SLA) |
| `test/gemini-cost.test.js` | Gemini API 비용 검증 (게임당 $0.005 이하 예산 준수) |

### 결과

**전체: 6/6 통과, 실패 0건**

| 테스트 | 결과 | 주요 수치 |
|--------|------|-----------|
| combat | ✅ 17/17 통과 | 클래스 5종 밸런스, NPC 프리셋, max_hp 마이그레이션 정상 |
| points | ✅ 18/18 통과 | oracle_send -10pt, win_bonus +50pt, 일일 로그인 중복 방지 정상 |
| e2e-flow | ✅ 7/7 단계 통과 | GEMINI_API_KEY 미설정 → keyword fallback 정상 동작 |
| matchmaker | ✅ 전체 통과 | 32플레이어 즉시 매칭, NPC 22명 충원, 중복/이탈 정상 |
| load-32players | ✅ 통과 | p50=0.634ms, p95=4.201ms, p99=7.499ms, max=7.499ms (SLA 1000ms 이하) |
| gemini-cost | ✅ 통과 | 최악 $0.001416 / 일반 $0.000442 (예산 $0.005 이하) |

### 수정한 버그

| 파일 | 수정 내용 |
|------|-----------|
| `server/package.json` | `"test"` 스크립트 추가 — Jest로 실행 시 `process.exit()` 패턴 충돌로 6개 테스트 전체 실패하던 문제를 `node` 직접 실행 방식으로 전환. `npm test`로 6개 전체 통과 확인. |

### 미해결 이슈

| 이슈 | 내용 |
|------|------|
| GEMINI_API_KEY 미설정 | 환경변수 미설정 시 keyword fallback 동작 확인됨. 실제 서비스 배포 전 API 키 설정 필요. |

---

## 2026-04-13 #9 (태연 스케줄 실행 — 9회차)

**실행 시각**: 2026-04-13  
**실행 환경**: Node.js v22.22.2, `/shared/oracle-battleroyale/server`

### 실행한 테스트 목록

| 파일 | 설명 |
|------|------|
| `test/combat.test.js` | 전투 시뮬레이션 (클래스 밸런스, NPC 프리셋, max_hp 마이그레이션) |
| `test/matchmaker.test.js` | 매치메이커 큐 로직 (32플레이어, NPC 충원, 중복 방지, 이탈) |
| `test/points.test.js` | 포인트 시스템 (oracle_send 차감, win/completion 보너스, 일일 로그인, WS 이벤트) |
| `test/gemini-cost.test.js` | Gemini API 비용 검증 (게임당 $0.005 이하 예산 준수) |
| `test/load-32players.test.js` | 32플레이어 × 50턴 부하 테스트 (p99 < 1000ms SLA) |
| `test/e2e-flow.test.js` | 전체 E2E 흐름 (로그인 → 캐릭터 생성 → 매치 참가 → Oracle 전송 → 게임 종료 → 포인트 정산) |

### 결과

**전체: 6/6 통과, 실패 0건**

| 테스트 | 결과 | 주요 수치 |
|--------|------|-----------|
| combat | ✅ 17/17 통과 | 클래스 5종 밸런스, NPC 프리셋, max_hp 마이그레이션 정상 |
| matchmaker | ✅ 전체 통과 | 32플레이어 즉시 매칭, NPC 22명 충원, 중복/이탈 정상 |
| points | ✅ 18/18 통과 | oracle_send -10pt, win_bonus +50pt, 일일 로그인 중복 방지 정상 |
| gemini-cost | ✅ 통과 | 최악 $0.001416 / 일반 $0.000442 (예산 $0.005 이하) |
| load-32players | ✅ 통과 | p50=0.179ms, p95=1.363ms, p99=2.353ms, max=2.353ms (SLA 1000ms 이하) |
| e2e-flow | ✅ 7/7 단계 통과 | GEMINI_API_KEY 미설정 → keyword fallback 정상 동작 |

### 수정한 버그

없음 — 이번 실행에서 수정된 버그 없음.

### 미해결 이슈

| 이슈 | 내용 |
|------|------|
| GEMINI_API_KEY 미설정 | 환경변수 미설정 시 keyword fallback 동작 확인됨. 실제 서비스 배포 전 API 키 설정 필요. |
| package.json `test` 스크립트 없음 | `npm test` 미지원. 테스트 실행은 `node test/<file>.test.js` 직접 호출 필요. |

---

## 2026-04-13 #8 (태연 스케줄 실행 — 8회차)

**실행 시각**: 2026-04-13  
**실행 환경**: Node.js v22.22.2, `/shared/oracle-battleroyale/server`

### 실행한 테스트 목록

| 파일 | 설명 |
|------|------|
| `test/combat.test.js` | 전투 시뮬레이션 (클래스 밸런스, NPC 프리셋, max_hp 마이그레이션) |
| `test/points.test.js` | 포인트 시스템 (oracle_send 차감, win/completion 보너스, 일일 로그인, WS 이벤트) |
| `test/matchmaker.test.js` | 매치메이커 큐 로직 (32플레이어, NPC 충원, 중복 방지, 이탈) |
| `test/gemini-cost.test.js` | Gemini API 비용 검증 (게임당 $0.005 이하 예산 준수) |
| `test/e2e-flow.test.js` | 전체 E2E 흐름 (로그인 → 캐릭터 생성 → 매치 참가 → Oracle 전송 → 게임 종료 → 포인트 정산) |
| `test/load-32players.test.js` | 32플레이어 × 50턴 부하 테스트 (p99 < 1000ms SLA) |

### 결과

**전체: 6/6 통과, 실패 0건**

| 테스트 | 결과 | 주요 수치 |
|--------|------|-----------|
| combat | ✅ 17/17 통과 | 클래스 5종 밸런스, NPC 프리셋, max_hp 마이그레이션 정상 |
| points | ✅ 18/18 통과 | oracle_send -10pt, win_bonus +50pt, 일일 로그인 중복 방지 정상 |
| matchmaker | ✅ 전체 통과 | 32플레이어 즉시 매칭, NPC 22명 충원, 중복/이탈 정상 |
| gemini-cost | ✅ 통과 | 최악 $0.001416 / 일반 $0.000442 (예산 $0.005 이하) |
| e2e-flow | ✅ 7/7 단계 통과 | GEMINI_API_KEY 미설정 → keyword fallback 정상 동작 |
| load-32players | ✅ 통과 | p50=0.351ms, p95=5.049ms, p99=8.465ms, max=8.465ms (SLA 1000ms 이하) |

### 수정한 버그

없음 — 이번 실행에서 수정된 버그 없음.

### 미해결 이슈

| 이슈 | 내용 |
|------|------|
| GEMINI_API_KEY 미설정 | 환경변수 미설정 시 keyword fallback 동작 확인됨. 실제 서비스 배포 전 API 키 설정 필요. |
| package.json `test` 스크립트 없음 | `npm test` 미지원. 테스트 실행은 `node test/<file>.test.js` 직접 호출 필요. |

---

## 2026-04-13 #7 (태연 스케줄 실행 — 7회차)

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
| load-32players | ✅ 통과 | p50=0.308ms, p95=4.009ms, p99=8.089ms, max=8.089ms (SLA 1000ms 이하) |
| e2e-flow | ✅ 7/7 단계 통과 | GEMINI_API_KEY 미설정 → keyword fallback 정상 동작 |

### 수정한 버그

없음 — 이번 실행에서 수정된 버그 없음.

### 미해결 이슈

| 이슈 | 내용 |
|------|------|
| GEMINI_API_KEY 미설정 | 환경변수 미설정 시 keyword fallback 동작 확인됨. 실제 서비스 배포 전 API 키 설정 필요. |
| package.json `test` 스크립트 없음 | `npm test` 미지원. 테스트 실행은 `node test/<file>.test.js` 직접 호출 필요. 스크립트 추가 권장. |

---

## 2026-04-13 #6 (태연 스케줄 실행 — 6회차)

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
| load-32players | ✅ 통과 | p50=0.200ms, p95=3.021ms, p99=4.352ms, max=4.352ms (SLA 1000ms 이하) |
| e2e-flow | ✅ 7/7 단계 통과 | GEMINI_API_KEY 미설정 → keyword fallback 정상 동작 |

### 수정한 버그

없음 — 이번 실행에서 수정된 버그 없음.

### 미해결 이슈

| 이슈 | 내용 |
|------|------|
| GEMINI_API_KEY 미설정 | 환경변수 미설정 시 keyword fallback 동작 확인됨. 실제 서비스 배포 전 API 키 설정 필요. |
| package.json `test` 스크립트 없음 | `npm test` 미지원. 테스트 실행은 `node test/<file>.test.js` 직접 호출 필요. 스크립트 추가 권장. |

---

## 2026-04-13 #5 (태연 스케줄 실행 — 5회차)

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
| load-32players | ✅ 통과 | p50=0.343ms, p95=2.082ms, p99=4.917ms, max=4.917ms (SLA 1000ms 이하) |
| e2e-flow | ✅ 7/7 단계 통과 | GEMINI_API_KEY 미설정 → keyword fallback 정상 동작 |

### 수정한 버그

없음 — 이번 실행에서 수정된 버그 없음.

### 미해결 이슈

| 이슈 | 내용 |
|------|------|
| GEMINI_API_KEY 미설정 | 환경변수 미설정 시 keyword fallback 동작 확인됨. 실제 서비스 배포 전 API 키 설정 필요. |
| package.json `test` 스크립트 없음 | `npm test` 미지원. 테스트 실행은 `node test/<file>.test.js` 직접 호출 필요. 스크립트 추가 권장. |

---

## 2026-04-13 #4 (태연 스케줄 실행 — 4회차)

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
| load-32players | ✅ 통과 | p50=0.258ms, p95=3.264ms, p99=5.136ms, max=5.136ms (SLA 1000ms 이하) |
| e2e-flow | ✅ 7/7 단계 통과 | GEMINI_API_KEY 미설정 → keyword fallback 정상 동작 |

### 수정한 버그

없음 — 이번 실행에서 수정된 버그 없음.

### 미해결 이슈

| 이슈 | 내용 |
|------|------|
| GEMINI_API_KEY 미설정 | 환경변수 미설정 시 keyword fallback 동작 확인됨. 실제 서비스 배포 전 API 키 설정 필요. |
| package.json `test` 스크립트 없음 | `npm test` 미지원. 테스트 실행은 `node test/<file>.test.js` 직접 호출 필요. 스크립트 추가 권장. |

---

## 2026-04-13 #3 (태연 스케줄 실행 — 3회차)

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
| load-32players | ✅ 통과 | p50=0.640ms, p95=5.381ms, p99=6.358ms, max=6.358ms (SLA 1000ms 이하) |
| e2e-flow | ✅ 7/7 단계 통과 | GEMINI_API_KEY 미설정 → keyword fallback 정상 동작 |

### 수정한 버그

없음 — 이번 실행에서 수정된 버그 없음.

### 미해결 이슈

| 이슈 | 내용 |
|------|------|
| GEMINI_API_KEY 미설정 | 환경변수 미설정 시 keyword fallback 동작 확인됨. 실제 서비스 배포 전 API 키 설정 필요. |
| package.json `test` 스크립트 없음 | `npm test` 미지원. 테스트 실행은 `node test/<file>.test.js` 직접 호출 필요. 스크립트 추가 권장. |

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
