# 성좌 배틀로얄 — UI Design

**Stitch Project:** `성좌 배틀로얄 - Oracle Battle Royale UI`  
**Project ID:** `6898713467318742401`  
**Design System:** Astraea Nexus (Cosmic Etherealism)  
**Created:** 2026-04-06

---

## Design System 개요

| 항목 | 값 |
|------|-----|
| 배경색 | `#121222` (Deep Cosmic Navy) |
| Primary | `#FFD700` (Gold) |
| Secondary | `#8B5CF6` (Mystic Purple) |
| Font | Space Grotesk (headline) / Manrope (body) |
| 스타일 | Glassmorphism, glow effects, no solid borders |
| Device | Mobile |

---

## 화면 목록

### 1. 캐릭터 목록 (나의 성좌 목록)
**Screen ID:** `670ede820b9f4c12a3ebfa921a8d9ee6`  
**설명:** 계정에 저장된 성좌 목록, 경기 참가 진입점

주요 요소:
- 글래스모픽 캐릭터 카드 (이름, 클래스, 승률, HP/ATK/DEF)
- 상단: "경기 참가" 버튼
- 하단: "새 성좌 만들기" 골드 그라디언트 CTA

![캐릭터 목록](https://lh3.googleusercontent.com/aida/ADBb0ugINqji_2VOdAhpAS4WMVEdAJvz0e6TqQUzpedUVcs7Wjsm3892c2YgBjC5e25ho4eM3fOagXg026nkDxT0vlZcYv0sGIapuj7ogl0omR1pll186Wir9mgpop4U7uRZATnK-gDbjtGIRyHkvNxtU9J5pcncU8E8IeW0TysPhVVzYcm1omoqjfMNZfdkeda8TBhxRaG2-4iDvk-Jx1axqc7ZU72qF2QMcnXXM10VglCzCL0am292U7Bs5C8)

---

### 2. 캐릭터 생성 (새 성좌 만들기)
**Screen ID:** `71e2520e085f4c17a6469784ceb49b40`  
**설명:** 성좌명 입력 → 소환 주문 입력 → AI 스탯 추출 → 저장

주요 요소:
- STEP 1: 성좌명 텍스트 입력 (골드 글로우)
- STEP 2: 소환 주문 textarea (AI 스탯 추출 트리거)
- STEP 3: 미리보기 카드 (클래스 배지, HP/ATK/DEF 진행바, 행동 성향)
- "성좌 저장하기" 골드 버튼

![캐릭터 생성](https://lh3.googleusercontent.com/aida/ADBb0ugUpR4v8au7ubZJwEUkDl9yDVbqp-llDG1TnfIra61G4gFbt2tMd_U0LWkVAVToaenEdl1GDo1PHZcGh2cn9-DrM7qi27w-xB-i8HNmdOhyzX-YTu3ruddI7iSlo6spWWUziIiFHoFdZRGF1bFwimT0erV8L9lzHfQEvgZUvecxEdGIHLdTa0-Jtob4-6cm2OwhOE3CXST2pUydj6ZjsXKMIW1jqNcefVHAgRBQQMClzeRq_Bv6Wb5gaeI)

---

### 3. 매칭 대기
**Screen ID:** `52a6ea91dfd2422184503b7964e7f08a`  
**설명:** 대기열 진입 후 자동 시작 대기 화면

주요 요소:
- 선택된 성좌 카드 (글래스모픽)
- 참가자 수: "9 / 32" 대형 골드 텍스트
- 카운트다운 링: "02:43"
- "참가자 부족 시 NPC 자동 충원" 안내
- "취소" 고스트 버튼

![매칭 대기](https://lh3.googleusercontent.com/aida/ADBb0ujW89lej1VSJZTtwsEZSVSrU7d2k2ZjZ3-oQj2RR05y5D43ouSjJs7MFj5DQRA-1QdlLGORlkvGz2KFpkc3KGR2CKY6XaAuUUGN3eIhYooowXXUBL7yTnrzH5S5SmtDlLIUL0DbQmXttfC6yBRh-wLd0GIMfvgiT4u-VY3q4HQx8bzwaaWhAGXGTYpqgd02QcKjdaff9C7UmunAUg0lRMEC_mjvr6lgG2JEBuFoaEuumhmlyu-hNVcQ8Ns)

---

### 4. 신탁 스트림 (Oracle Chat Feed)
**Screen ID:** `00285eb99040479b9516bf9b616fba46`  
**설명:** 경기 중 신탁 메시지 피드. 참가자 + 관전자 모두 입력 가능

주요 요소:
- 신탁 메시지 (보낸이 → 대상, 성공/실패 배지)
- [시스템] 서사 이벤트 메시지 (보라색 이탤릭)
- [관전] 관전자 메시지 (구분 색상)
- 하단 입력: 대상 선택 드롭다운 + 신탁 텍스트 + "신탁 비용: 50pt" + 전송 버튼

![신탁 스트림](https://lh3.googleusercontent.com/aida/ADBb0ujvwAHCNVgz4Y7Z3fAMaDjSjI0a_gbgC466Dxc--rcjfvkKMHLjhjmSkLmpteSFiRgnNcez982MDoKBRdaeroYwjoM5yNl7e7ijahYM9J-kgitXo838GK8i-lfzegxu__DMWj7nxy6niPaKJWreguH1nKPFfNB3mEAYfdL-PcG0d8uuxN7rtSzYattOCHRhMBxEtsOcQM1HU_2QTw5UZkVdocidZlVJZD0VzDO1GaTfzPkNbdAfonNfqg)

---

### 5. 경기 결과 화면
**Screen ID:** _(생성 대기 중 — Stitch 타임아웃)_  
**설명:** 우승자 발표, 순위 목록, 신탁 포인트 정산

계획된 요소:
- 우승 성좌명 대형 골드 텍스트 + 방사형 글로우
- 순위 목록 (금/은/동 + 탈락 시간)
- 내 포인트 정산 카드 (-신탁pt / +참가pt / +우승보너스pt)
- "다시 참가" | "메인으로" 버튼

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

## HTML 소스 다운로드

| 화면 | File ID |
|------|---------|
| 캐릭터 목록 | `projects/6898713467318742401/files/649f925c9d264fa8950a65ae5f10b32c` |
| 캐릭터 생성 | `projects/6898713467318742401/files/e19324b762a84f2ba7f5721e4c587cdf` |
| 매칭 대기 | `projects/6898713467318742401/files/6b146a2229c146bdb3fdb538939a34de` |
| 신탁 스트림 | `projects/6898713467318742401/files/3197f0b9259e4484920e722ad181edb6` |
