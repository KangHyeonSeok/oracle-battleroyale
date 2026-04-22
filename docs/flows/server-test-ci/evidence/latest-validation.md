# server-test-ci Validation

- Status: review-required
- Action: completed-spec
- UpdatedAt: 2026-04-13T10:03:10.068Z
- Detail: test-validator: 워크플로 파일 구조(AC1/AC3/AC4/AC5)는 모두 통과 확인. AC2는 server-unit-tests-expansion 미완료로 leaderboard/oracle-cooldown 테스트가 부재하여 partial 상태. 스펙이 이 의존성을 명시하고 있으나 AC2가 완전히 충족되지 않은 상태에서 done 처리는 부적절 — needs-review로 전환하여 의존 스펙 완료 후 재검토 권장.

## Acceptance Criteria Review

1. AC1: server/** 경로 push/PR 시 워크플로 자동 트리거
Status: passed
Evidence: on.push.paths 및 on.pull_request.paths 모두 'server/**'와 '.github/workflows/server-test.yml' 포함 — 트리거 조건 충족

2. AC2: npm test 전체 통과 (leaderboard 8, oracle-cooldown 6 포함)
Status: partial
Evidence: 기존 6개 파일(combat 17, points 18, matchmaker, e2e-flow 7, load, gemini-cost)은 통과 예상. leaderboard/oracle-cooldown 테스트는 server-unit-tests-expansion 완료 전까지 미존재 — AC2 완전 충족 불가

3. AC3: 테스트 실패 시 PR 머지 blocking
Status: passed
Evidence: npm test 실패 시 job 종료 코드 비정상 → GitHub 필수 상태 체크 연동으로 머지 차단 동작

4. AC4: Node.js 20, Redis 7, PostgreSQL 15 서비스 컨테이너 및 헬스체크 통과
Status: passed
Evidence: redis:7-alpine(redis-cli ping)과 postgres:15-alpine(pg_isready -U testuser) 모두 health-retries 5 구성 확인

5. AC5: server/** 외 경로만 변경 시 워크플로 미실행
Status: passed
Evidence: push/pull_request 양쪽 모두 paths 필터 적용 — 해당 경로 외 변경은 워크플로 스킵

