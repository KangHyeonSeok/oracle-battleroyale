---
specId: oracle-ui-design
title: 성좌 배틀로얄 UI 디자인 스펙
status: ready
owner: partner
runnerProfile: developer
runnerExecution: assistant
createdAt: 2026-04-06
updatedAt: 2026-04-10
---

# Goal

성좌 배틀로얄 게임의 5개 화면에 적용할 디자인 시스템을 정의한다.
Stitch로 생성된 스크린 디자인(Astraea Nexus 디자인 시스템 기반)을 코드 구현 가이드 수준으로 스펙화한다.

---

## Design System: Astraea Nexus

### 색상

| 토큰 | 값 | 용도 |
|------|-----|------|
| `bg-base` | `#121222` | 전체 배경 (dark navy) |
| `bg-card` | `rgba(255,255,255,0.06)` | 글래스모픽 카드 배경 |
| `border-card` | `rgba(255,255,255,0.12)` | 카드 테두리 |
| `accent-gold` | `#FFD700` | 강조, 우승/포인트, CTA 버튼 |
| `accent-purple` | `#8B5CF6` | 신탁/마법 관련 요소, 보조 강조 |
| `text-primary` | `#FFFFFF` | 본문 텍스트 |
| `text-secondary` | `rgba(255,255,255,0.6)` | 보조 텍스트, 레이블 |
| `success` | `#10B981` | 성공 뱃지, 확인 상태 |
| `danger` | `#EF4444` | 실패 뱃지, 경고 |

### 타이포그래피

| 용도 | 폰트 | 크기 | 굵기 |
|------|------|------|------|
| 타이틀 | Space Grotesk | 24–32px | 700 |
| 서브타이틀 | Space Grotesk | 18–20px | 600 |
| 본문 | Space Grotesk | 14–16px | 400 |
| 레이블/배지 | Space Grotesk | 12px | 500 |

### 컴포넌트

| 컴포넌트 | 스타일 |
|----------|--------|
| 카드 | `bg-card`, `border-card 1px solid`, `border-radius 12px`, `backdrop-filter blur(10px)` |
| 기본 버튼 | `bg: accent-gold`, `color: #121222`, `border-radius 8px`, `font-weight 700` |
| 보조 버튼 | `bg: transparent`, `border: 1px solid accent-purple`, `color: accent-purple` |
| 입력 필드 | `bg: rgba(255,255,255,0.08)`, `border: 1px solid rgba(255,255,255,0.2)`, `border-radius 8px`, `color: white` |
| 배지 (성공) | `bg: rgba(16,185,129,0.15)`, `color: #10B981`, `border-radius 4px` |
| 배지 (실패) | `bg: rgba(239,68,68,0.15)`, `color: #EF4444`, `border-radius 4px` |

---

## 화면별 디자인 스펙

### 1. 캐릭터 목록 화면 (CharacterListScreen)
- Screen ID (Stitch): `670ede820b9f4c12a3ebfa921a8d9ee6`
- 레이아웃: 세로 스크롤, 카드 그리드 (2열)
- 상단: 타이틀 "내 성좌" + "새 성좌 만들기" 버튼 (accent-gold)
- 카드: 성좌명(text-primary), 클래스 아이콘, 승률(text-secondary)
- 출전 선택 시 카드에 accent-purple 테두리 강조

### 2. 캐릭터 생성 화면 (CharacterCreateScreen)
- Screen ID (Stitch): `71e2520e085f4c17a6469784ceb49b40`
- 레이아웃: 단일 컬럼 폼
- 성좌명 입력 필드 + 챔피언 프롬프트 텍스트에어리어
- Gemini 분석 결과 미리보기 카드: 클래스, HP/ATK/DEF, 행동 성향
- 저장 버튼 (accent-gold, 전체 너비)

### 3. 매칭 대기 화면 (MatchmakingScreen)
- Screen ID (Stitch): `52a6ea91dfd2422184503b7964e7f08a`
- 레이아웃: 중앙 정렬, 원형 대기 애니메이션
- 참가자 수 표시: `n / 32` (accent-gold 강조)
- 카운트다운 타이머 (text-primary, 대형)
- NPC 충원 안내 텍스트 (text-secondary)
- 취소 버튼 (보조 버튼 스타일)

### 4. 신탁 스트림 화면 (OracleStreamPanel)
- Screen ID (Stitch): `00285eb99040479b9516bf9b616fba46`
- 레이아웃: 우측 패널 or 풀스크린 (관전자 모드)
- 메시지 아이템: 발신자 → 수신자, 신탁 내용, 성공/실패 배지
- LLM 서사 이벤트: 시스템 메시지 (accent-purple 레이블)
- 자동 스크롤 (하단 고정)
- 하단: 신탁 입력 필드 + 전송 버튼

### 5. 경기 결과 화면 (GameResultScreen)
- Screen ID (Stitch): 없음 — 직접 구현 스펙으로 대체
- 레이아웃: 단일 컬럼, 중앙 정렬, 세로 스크롤
- **섹션 1 — 우승자 배너**: 전체 너비 카드, `bg-card` + `accent-gold` 1px border + `box-shadow: 0 0 20px rgba(255,215,0,0.3)` 글로우. 우승 성좌명 32px bold text-primary, 아래 클래스 레이블 14px text-secondary
- **섹션 2 — 순위 목록**: 1위~n위 행 리스트. 각 행: 순위 번호(accent-gold, 20px bold) + 성좌명(text-primary, 16px) + 탈락 시각(text-secondary, 12px, 우측 정렬)
- **섹션 3 — 포인트 정산**: 2열 그리드. 왼쪽: "신탁 사용 `-10pt × n회`" (danger 배지). 오른쪽: "우승 보너스 `+50pt`" (success 배지, 미우승 시 숨김). 하단: 최종 정산 합계(text-primary, 20px bold)
- **버튼 행**: "다시 참가" (accent-gold 기본 버튼, 전체 너비) / "메인으로" (보조 버튼, 전체 너비)
- 진입 애니메이션: 우승자 배너 fade-in 0.4s, 순위 행 stagger 0.08s/row

---

## Acceptance Criteria

1. 5개 화면 모두 Astraea Nexus 디자인 시스템 토큰(`bg-base`, `bg-card`, `accent-gold`, `accent-purple`, `text-primary`, `text-secondary`, `success`, `danger`)을 사용한다.
2. 경기 결과 화면(GameResultScreen)이 섹션 1/2/3 레이아웃대로 구현되고, 순위·포인트 정산이 표시된다.
3. `docs/ui/README.md`에 모든 스크린, 색상 토큰, 컴포넌트 가이드가 반영된다.

## Constraints

- 디자인 토큰은 Godot Theme Resource로 구현 가능한 형태로 정의한다.
- Stitch 스크린(화면 1~4)은 참고용이며, 실제 구현은 Godot GDScript/Control 노드로 한다.
- 경기 결과 화면은 Stitch 없이 위 직접 스펙으로 구현한다.

## Notes

- Stitch Screen IDs (화면 1–4만 존재): CharacterList `670ede820b9f4c12a3ebfa921a8d9ee6`, CharacterCreate `71e2520e085f4c17a6469784ceb49b40`, Matchmaking `52a6ea91dfd2422184503b7964e7f08a`, OracleStream `00285eb99040479b9516bf9b616fba46`
- 경기 결과 화면(화면 5)은 Stitch 타임아웃으로 미생성 → 직접 스펙으로 대체 완료 (2026-04-10)
