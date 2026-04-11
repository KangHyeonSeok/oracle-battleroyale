# 성좌 배틀로얄 — UI Design

**Stitch Project:** `성좌 배틀로얄 - Oracle Battle Royale UI`  
**Project ID:** `6898713467318742401`  
**Design System:** Astraea Nexus (Cosmic Etherealism)  
**Created:** 2026-04-06  
**Updated:** 2026-04-12

---

## 색상 토큰 (Astraea Nexus)

| 토큰 | 값 | GDScript 상수 | 용도 |
|------|-----|--------------|------|
| `bg-base` | `#121222` | `Color(0.071, 0.071, 0.133)` | 전체 배경 (dark navy) |
| `bg-card` | `rgba(255,255,255,0.06)` | `Color(1,1,1,0.06)` | 글래스모픽 카드 배경 |
| `border-card` | `rgba(255,255,255,0.12)` | `Color(1,1,1,0.12)` | 카드 테두리 |
| `accent-gold` | `#FFD700` | `Color(1.0, 0.843, 0.0)` | 강조, 우승/포인트, CTA 버튼 |
| `accent-purple` | `#8B5CF6` | `Color(0.545, 0.361, 0.965)` | 신탁/마법 관련 요소, 보조 강조 |
| `text-primary` | `#FFFFFF` | `Color(1,1,1)` | 본문 텍스트 |
| `text-secondary` | `rgba(255,255,255,0.6)` | `Color(1,1,1,0.6)` | 보조 텍스트, 레이블 |
| `success` | `#10B981` | `Color(0.063, 0.725, 0.506)` | 성공 뱃지, 확인 상태 |
| `danger` | `#EF4444` | `Color(0.937, 0.267, 0.267)` | 실패 뱃지, 경고 |

---

## 타이포그래피

| 용도 | 폰트 | 크기 | 굵기 |
|------|------|------|------|
| 타이틀 | Space Grotesk / NotoSansKR (Godot) | 24–32px | 700 |
| 서브타이틀 | Space Grotesk / NotoSansKR | 18–20px | 600 |
| 본문 | Space Grotesk / NotoSansKR | 14–16px | 400 |
| 레이블/배지 | Space Grotesk / NotoSansKR | 12px | 500 |

> Godot 구현에서는 `res://fonts/NotoSansKR.ttf`를 사용한다.

---

## 컴포넌트 가이드

### 카드 (`StyleBoxFlat`)
```
bg_color       = bg-card
border_color   = border-card
border_width   = 1px
corner_radius  = 12px
backdrop_filter: blur(10px) — Godot에서 Panel 뒤 ColorRect로 구현
content_margin = 14–16px
```

### 기본 버튼 (accent-gold CTA)
```
bg_color       = accent-gold
font_color     = bg-base (#121222)
corner_radius  = 8px
font_weight    = 700
min_height     = 48px
```

### 보조 버튼 (accent-purple ghost)
```
bg_color       = transparent
border_color   = accent-purple
border_width   = 1px
font_color     = accent-purple
corner_radius  = 8px
```

### 입력 필드
```
bg_color       = rgba(255,255,255,0.08)
border_color   = rgba(255,255,255,0.2)
corner_radius  = 8px
font_color     = text-primary
```

### 배지 — 성공
```
bg_color       = rgba(16,185,129,0.15)
font_color     = success (#10B981)
corner_radius  = 4px
padding        = 3px 6px
```

### 배지 — 실패
```
bg_color       = rgba(239,68,68,0.15)
font_color     = danger (#EF4444)
corner_radius  = 4px
padding        = 3px 6px
```

---

## 화면 목록

### 1. 캐릭터 목록 (CharacterListScreen)
**Screen ID:** `670ede820b9f4c12a3ebfa921a8d9ee6`  
**Script:** `client/scripts/CharacterListScreen.gd`  
**설명:** 계정에 저장된 성좌 목록, 경기 참가 진입점

레이아웃: 세로 스크롤, 카드 그리드 (2열)

주요 요소:
- 상단 타이틀 "내 성좌" (`text-primary`, 24px bold) + "새 성좌 만들기" 버튼 (`accent-gold`)
- 글래스모픽 성좌 카드 (`bg-card`, `border-card`): 성좌명, 클래스 아이콘, 승률
- 출전 선택 시 카드에 `accent-purple` 1px 테두리 강조

![캐릭터 목록](https://lh3.googleusercontent.com/aida/ADBb0ugINqji_2VOdAhpAS4WMVEdAJvz0e6TqQUzpedUVcs7Wjsm3892c2YgBjC5e25ho4eM3fOagXg026nkDxT0vlZcYv0sGIapuj7ogl0omR1pll186Wir9mgpop4U7uRZATnK-gDbjtGIRyHkvNxtU9J5pcncU8E8IeW0TysPhVVzYcm1omoqjfMNZfdkeda8TBhxRaG2-4iDvk-Jx1axqc7ZU72qF2QMcnXXM10VglCzCL0am292U7Bs5C8)

---

### 2. 캐릭터 생성 (CharacterCreateScreen)
**Screen ID:** `71e2520e085f4c17a6469784ceb49b40`  
**Script:** `client/scripts/CharacterCreateScreen.gd`  
**설명:** 성좌명 입력 → 소환 주문 입력 → AI 스탯 추출 → 저장

레이아웃: 단일 컬럼 폼

주요 요소:
- 성좌명 입력 필드 (입력 필드 스타일)
- 챔피언 프롬프트 텍스트에어리어
- Gemini 분석 결과 미리보기 카드 (`bg-card`): 클래스 배지, HP/ATK/DEF, 행동 성향
- "성좌 저장하기" 버튼 (`accent-gold`, 전체 너비)

![캐릭터 생성](https://lh3.googleusercontent.com/aida/ADBb0ugUpR4v8au7ubZJwEUkDl9yDVbqp-llDG1TnfIra61G4gFbt2tMd_U0LWkVAVToaenEdl1GDo1PHZcGh2cn9-DrM7qi27w-xB-i8HNmdOhyzX-YTu3ruddI7iSlo6spWWUziIiFHoFdZRGF1bFwimT0erV8L9lzHfQEvgZUvecxEdGIHLdTa0-Jtob4-6cm2OwhOE3CXST2pUydj6ZjsXKMIW1jqNcefVHAgRBQQMClzeRq_Bv6Wb5gaeI)

---

### 3. 매칭 대기 (MatchmakingScreen)
**Screen ID:** `52a6ea91dfd2422184503b7964e7f08a`  
**Script:** `client/scripts/MatchWaitingScreen.gd`  
**설명:** 대기열 진입 후 자동 시작 대기 화면

레이아웃: 중앙 정렬, 원형 대기 애니메이션

주요 요소:
- 선택된 성좌 카드 (`bg-card`, `border-card`)
- 참가자 수: `n / 32` (`accent-gold`, 대형)
- 카운트다운 타이머 (`text-primary`, 대형)
- "참가자 부족 시 NPC 자동 충원" 안내 (`text-secondary`)
- "취소" 보조 버튼 (`accent-purple` 테두리)

![매칭 대기](https://lh3.googleusercontent.com/aida/ADBb0ujW89lej1VSJZTtwsEZSVSrU7d2k2ZjZ3-oQj2RR05y5D43ouSjJs7MFj5DQRA-1QdlLGORlkvGz2KFpkc3KGR2CKY6XaAuUUGN3eIhYooowXXUBL7yTnrzH5S5SmtDlLIUL0DbQmXttfC6yBRh-wLd0GIMfvgiT4u-VY3q4HQx8bzwaaWhAGXGTYpqgd02QcKjdaff9C7UmunAUg0lRMEC_mjvr6lgG2JEBuFoaEuumhmlyu-hNVcQ8Ns)

---

### 4. 신탁 스트림 (OracleStreamPanel)
**Screen ID:** `00285eb99040479b9516bf9b616fba46`  
**Script:** `client/scripts/OracleStreamPanel.gd`  
**설명:** 경기 중 신탁 메시지 피드. 참가자 + 관전자 모두 입력 가능

레이아웃: 우측 패널 or 풀스크린 (관전자 모드), 자동 스크롤 (하단 고정)

주요 요소:
- 신탁 메시지 아이템: 발신자 → 수신자, 신탁 내용, `success`/`danger` 배지
- LLM 서사 이벤트: 시스템 메시지 (`accent-purple` 레이블, 이탤릭)
- 관전자 메시지: 구분 색상
- 하단: 대상 선택 드롭다운 + 신탁 입력 필드 + "신탁 비용: 50pt" + 전송 버튼 (`accent-gold`)

![신탁 스트림](https://lh3.googleusercontent.com/aida/ADBb0ujvwAHCNVgz4Y7Z3fAMaDjSjI0a_gbgC466Dxc--rcjfvkKMHLjhjmSkLmpteSFiRgnNcez982MDoKBRdaeroYwjoM5yNl7e7ijahYM9J-kgitXo838GK8i-lfzegxu__DMWj7nxy6niPaKJWreguH1nKPFfNB3mEAYfdL-PcG0d8uuxN7rtSzYattOCHRhMBxEtsOcQM1HU_2QTw5UZkVdocidZlVJZD0VzDO1GaTfzPkNbdAfonNfqg)

---

### 5. 경기 결과 (GameResultScreen)
**Screen ID:** _(Stitch 미생성 — 직접 스펙 구현)_  
**Script:** `client/scripts/GameResultScreen.gd`  
**설명:** 우승자 발표, 순위 목록, 신탁 포인트 정산

레이아웃: 단일 컬럼, 중앙 정렬, 세로 스크롤

#### 섹션 1 — 우승자 배너
- 전체 너비 카드 (`bg-card` + `accent-gold` 1px border + `box-shadow: 0 0 20px rgba(255,215,0,0.3)` 글로우)
- 우승 성좌명: 32px bold, `text-primary`
- 클래스 레이블: 14px, `text-secondary`
- 진입 애니메이션: fade-in 0.4s

#### 섹션 2 — 순위 목록
- 1위~n위 행 리스트, 각 행:
  - 순위 번호: `accent-gold` (1위), silver (2위), bronze (3위), `text-secondary` (기타), 20px bold
  - 성좌명: `text-primary`, 16px
  - 탈락 시각: `text-secondary`, 12px, 우측 정렬
- 진입 애니메이션: stagger 0.08s/row

#### 섹션 3 — 포인트 정산
- 2열 그리드 (`GridContainer`):
  - 왼쪽: "신탁 사용 -10pt × n회" — `danger` 배지 스타일
  - 오른쪽: "우승 보너스 +50pt" — `success` 배지 스타일 (미우승 시 숨김)
- 하단 합계: `text-primary`, 20px bold

#### 버튼 행
- "다시 참가": `accent-gold` 기본 버튼, 전체 너비
- "메인으로": `accent-purple` 보조 버튼, 전체 너비

---

## 화면 플로우 요약

```
캐릭터 목록
  ├─ 새 성좌 만들기 → 캐릭터 생성 → 목록으로
  └─ 경기 참가 → 매칭 대기 → 경기 중(신탁 스트림) → 경기 결과
                                    ↑
                         관전자도 신탁 스트림 진입 가능
```

---

## HTML 소스 다운로드 (Stitch, 화면 1–4)

| 화면 | File ID |
|------|---------|
| 캐릭터 목록 | `projects/6898713467318742401/files/649f925c9d264fa8950a65ae5f10b32c` |
| 캐릭터 생성 | `projects/6898713467318742401/files/e19324b762a84f2ba7f5721e4c587cdf` |
| 매칭 대기 | `projects/6898713467318742401/files/6b146a2229c146bdb3fdb538939a34de` |
| 신탁 스트림 | `projects/6898713467318742401/files/3197f0b9259e4484920e722ad181edb6` |
