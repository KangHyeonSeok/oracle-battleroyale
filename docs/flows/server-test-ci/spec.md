---
specId: server-test-ci
title: 서버 CI 테스트 워크플로
status: done
owner: partner
runnerProfile: developer
runnerExecution: assistant
createdAt: 2026-04-13
updatedAt: 2026-04-13
---

# server-test-ci: 서버 CI 테스트 워크플로

## 목표
GitHub Actions에서 push/PR 트리거 시 서버 단위 테스트(`npm test`)를 자동 실행하여,
코드 변경이 기존 테스트를 깨뜨리지 않는지 자동으로 검증한다.

## 배경
- `server/package.json`의 `npm test` 스크립트가 존재하고 6개 테스트 파일이 통과 상태
- push/PR 시 자동 CI 트리거가 없어 수동 검증에만 의존 중 — **15회차 연속 미해결**
- 기존 통과 테스트: combat(17/17), points(18/18), matchmaker, e2e-flow(7단계), load-32players, gemini-cost
- `oracle-cooldown`, `leaderboard` 단위 테스트는 별도 구현 필요 (P1-4, P1-5)
- `playwright-debug-setup` flow에 별도 Playwright 워크플로 존재 → 이 스펙은 서버 단위 테스트 전용

---

## 구현 범위

### 파일: `.github/workflows/server-test.yml` (신규)

```yaml
name: Server Tests

on:
  push:
    branches: [ main, develop ]
    paths:
      - 'server/**'
      - '.github/workflows/server-test.yml'
  pull_request:
    branches: [ main, develop ]
    paths:
      - 'server/**'

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_USER: testuser
          POSTGRES_PASSWORD: testpass
          POSTGRES_DB: oracle_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd "pg_isready -U testuser"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: server/package-lock.json

      - name: Install dependencies
        working-directory: server
        run: npm ci

      - name: Run server tests
        working-directory: server
        env:
          NODE_ENV: test
          REDIS_URL: redis://localhost:6379
          DATABASE_URL: postgres://testuser:testpass@localhost:5432/oracle_test
        run: npm test
```

> **참고**: `gemini-cost.test.js`는 정적 계산 기반으로 실제 Gemini API 호출 없음 → `GEMINI_API_KEY` secret 불필요.

---

## 파일 목록

| 파일 | 내용 |
|------|------|
| `.github/workflows/server-test.yml` | push/PR 트리거, Node.js 20, Redis 7, PostgreSQL 15 환경에서 `npm test` 실행 |

서버 테스트 코드 변경 없음. 기존 `test/` 디렉토리 그대로 사용.

---

## 완료 기준 (AC)

| AC | 내용 |
|----|------|
| AC1 | `server/**` 경로 변경 push 시 워크플로 자동 트리거 확인 |
| AC2 | `npm test` 실행 결과 전체 통과 — combat(17), points(18), matchmaker, e2e-flow(7단계), load, gemini-cost, **leaderboard(8)**, **oracle-cooldown(6)** (`server-unit-tests-expansion` 완료 후) |
| AC3 | 테스트 실패 시 GitHub PR 상태 체크 blocking (머지 차단) |
| AC4 | Node.js 20, Redis 7, PostgreSQL 15 서비스 컨테이너 정상 기동 및 헬스체크 통과 |
| AC5 | `server/**` 외 경로만 변경 시 워크플로 미실행 (`paths` 필터 동작 확인) |

---

## 엣지케이스

| 케이스 | 처리 |
|--------|------|
| `server/**` 외 경로만 변경 | `paths` 필터로 워크플로 미실행 (불필요한 CI 리소스 낭비 방지) |
| gemini-cost 테스트 키 없음 | 정적 계산 기반 — 실제 Gemini API 미호출. `GEMINI_API_KEY` 없어도 통과 |
| Redis/PostgreSQL 헬스체크 실패 | 5회 재시도 후 워크플로 실패 처리 — 서비스 기동 실패 원인 로그 확인 |
| 기존 e2e-flow 스텁 기반 테스트 | 실 DB/Redis 없이도 통과하는 모킹 구조 유지 — 서비스 컨테이너는 향후 실통합 테스트 추가 시 활용 |
| `npm ci` 캐시 미스 | 첫 실행 시 캐시 없음 → 정상 설치. 이후 `package-lock.json` 기준 캐시 활용 |

---

## 제약
- `GEMINI_API_KEY` GitHub secret 불필요 (정적 테스트만 존재하는 현 시점 기준)
- Slack 알림은 포함하지 않음 (`ci-deploy-notify` 별도 처리)
- `main`, `develop` 브랜치 대상 — feature 브랜치는 `develop` PR 시 트리거
- hyeonseok 착수 승인 필요 — 15회차 연속 대기 항목

## 예상 기간
0.5일 (YAML 작성 ~30줄)
