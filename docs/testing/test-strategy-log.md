# 테스트 전략 로그 — oracle-battleroyale

---

## 2026-04-13 (태연 점검)

### 현재 테스트 커버리지 상태

| 영역 | 파일 수 | 테스트 | 커버리지 |
|------|---------|--------|----------|
| 서버 (Node.js/ws) | 0 | 없음 | 0% |
| 클라이언트 (Godot GDScript) | 10 | 없음 | 0% |
| 통합/E2E | — | 없음 | 0% |
| CI | GitHub Actions | Godot Web Export + Vercel 배포 검증만 | — |

**전체 코드 테스트 없음. Phase 1~6 전부 `queued` 상태 — 서버 코드 미존재.**

---

### 발견한 문제점

#### 1. 서버 코드 자체가 없음
- `/server` 폴더 비어 있음. Phase 1 인프라 미착수.
- 테스트 작성 전에 구현 착수가 선행 조건.

#### 2. Godot WebAssembly 클라이언트 테스트 환경 없음
- GDScript 단위 테스트 프레임워크(GUT 등) 미설치.
- WebSocketClient.gd의 재연결 로직, 메시지 파싱 등 핵심 로직이 무검증 상태.
- `JavaScriptBridge.eval()` 의존 코드는 Godot headless에서 실행 불가 → 별도 목킹 전략 필요.

#### 3. AI 행동 엔진(Gemini Flash) 비결정적
- 동일 입력에 다른 출력 가능 → 단위 테스트 어려움.
- 규칙 테이블 추출 파이프라인(Phase 2-2)의 JSON 스키마 준수 여부를 검증할 수단 없음.

#### 4. WebSocket 통신 테스트 격리 어려움
- 60초 턴 스케줄러, 룸 입장/퇴장 이벤트 등 시간 의존 로직이 실시간 연결을 전제.
- Redis 없이는 상태 복원 테스트 불가.

#### 5. 32명 부하 테스트 인프라 미정
- Phase 6 완료 기준에 "32명 동시 WS, 60초 턴 1,000ms 이내" 명시되어 있으나 도구 미선정.

---

### 개선 제안 (우선순위 순)

#### P0 — 서버 구현 착수와 동시에 테스트 프레임워크 세팅

- **도구**: Jest + `ws` 모의 서버 (`jest-websocket-mock` 또는 `ws` 직접 사용)
- **대상**: Phase 3 게임 서버 코어 — 전투 판정 함수, 사거리 계산, HP 처리는 순수 함수로 추출해 단위 테스트 가능하게 설계
- **완료 기준**: `npm test` 실행 시 전투 판정 유닛 커버리지 80% 이상

#### P0 — AI 행동 엔진: 결정론적 래퍼 분리

- Gemini 호출 결과를 "규칙 테이블 JSON"으로 변환하는 파싱/검증 레이어를 AI 호출과 분리
- 고정 JSON 픽스처를 입력으로 행동 결정 엔진만 단위 테스트
- 실제 Gemini 호출은 E2E/smoke 테스트에서만 수행 (비용·속도 이슈 방지)

#### P1 — Godot 클라이언트: GUT 설치 + WebSocketClient 단위 테스트

- [GUT (Godot Unit Test)](https://github.com/bitwes/Gut) 설치
- `WebSocketClient.gd` 테스트 대상:
  - `_drain_packets()`: 유효 JSON / 깨진 JSON 처리
  - `send()`: 미연결 상태에서 호출 시 경고 발생 여부
  - 재연결 타이머 로직
- `JavaScriptBridge` 의존 분기는 `OS.has_feature("web")` 기반 → 테스트 환경에서 우회 가능하도록 헬퍼 분리 권장

#### P1 — 통합 테스트: Docker Compose 기반 로컬 환경

- `docker-compose.yml`에 Redis + 서버 컨테이너 포함 (현재 미구성)
- GitHub Actions CI에 `docker compose up -d && jest --testPathPattern=integration` 단계 추가
- Phase 1 완료 후 바로 적용 가능

#### P2 — 부하 테스트: k6 선정

- [k6](https://k6.io/) WebSocket 시나리오로 32명 동시 접속 시뮬레이션
- 목표: 60초 턴 처리 응답 1,000ms 이내 (Phase 6 완료 기준 그대로)
- Phase 5 이후 staging 환경에서 실행

#### P2 — E2E: Playwright (서버→클라이언트 풀 플로우)

- Vercel preview URL + WebSocket 서버 동시 기동 후 Playwright로 브라우저 자동화
- 커버 범위: 로그인 → 캐릭터 생성 → 매치 참가 → 신탁 전송 → 게임 종료 → 포인트 정산
- Godot WebAssembly 특성상 DOM 이벤트 직접 접근 불가 → WebSocket 메시지 스니핑 방식 병행 권장

---

### 다음 액션

| 우선순위 | 액션 | 담당 | 조건 |
|----------|------|------|------|
| P0 | Phase 1 착수 시 Jest 세팅 + 전투 판정 순수 함수 추출 | DevourerKing | Phase 1 착수 후 즉시 |
| P0 | AI 행동 엔진 파싱 레이어 분리 설계 | 태연(스펙) → DevourerKing | Phase 2 설계 시 |
| P1 | GUT 설치 + WebSocketClient 테스트 2건 이상 | DevourerKing | Phase 5 착수 시 |
| P1 | docker-compose에 Redis 포함 + CI 통합 테스트 단계 추가 | DevourerKing | Phase 1 완료 후 |
| P2 | k6 부하 테스트 시나리오 작성 | DevourerKing | Phase 5 완료 후 |
| P2 | Playwright E2E 시나리오 작성 | DevourerKing | Phase 6 초입 |
