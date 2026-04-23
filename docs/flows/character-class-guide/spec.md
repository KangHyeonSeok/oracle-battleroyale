---
specId: character-class-guide
title: 캐릭터 클래스 가이드 패널
status: queued
owner: partner
runnerProfile: developer
runnerExecution: assistant
createdAt: 2026-04-13
updatedAt: 2026-04-13
dependsOn:
  - phase-2-character-ai
  - class-balance
---

# character-class-guide: 캐릭터 클래스 가이드 패널

## 목표
캐릭터 생성 화면에서 AI 분석 결과로 클래스가 결정된 뒤, 해당 클래스의 플레이 스타일 설명과 이동 속도를 프리뷰 패널에 추가 표시한다. 현재는 클래스 이름·HP/ATK/DEF만 표시되어 신규 플레이어가 클래스의 특성을 파악하기 어렵다.

## 배경
- `CharacterCreateScreen.gd`의 캐릭터 생성 플로우:
  1. 이름 + 성격 프롬프트 입력
  2. "AI로 스탯 분석하기" 버튼 클릭 → WS `preview_character` 전송
  3. 서버 응답 `character_preview` 수신 → `_populate_preview(d)` 호출 (`:232–249`)
  4. 프리뷰 패널 표시 (클래스명·HP/ATK/DEF·행동 성향)
  5. "성좌 저장하기" 버튼으로 확정
- **클래스 선택 버튼 없음** — 클래스는 AI가 결정, 유저가 직접 선택하는 UI 없음
- 서버 응답에 `class, hp, atk, def`는 있으나 **speed(이동속도)**와 **플레이 스타일 설명**은 없음
- `class-balance` 스펙에서 6개 클래스 speed + 특성 확정 → 클라이언트 하드코딩으로 보강

---

## 클래스 데이터 (클라이언트 하드코딩 — speed + desc 보강용)

| 클래스 | 이름(표시) | Speed | 특성 |
|--------|-----------|-------|------|
| warrior  | 전사 | 1.0 | 균형형 탱커. 가장 가까운 적에게 돌진 |
| archer   | 궁수 | 1.5 | 원거리 기동형. HP 50% 이하 시 후퇴 우선 |
| mage     | 마법사 | 0.9 | 고화력 원거리. 접근 시 즉시 후퇴 |
| assassin | 암살자 | 1.6 | 고속 돌격. 치명타 25% 확률(×2 데미지) |
| berserk  | 광전사 | 1.3 | 무조건 돌격. HP 낮을수록 데미지 ×1.5 |
| healer   | 힐러 | 1.0 | 아군 회복 우선. 공격력 약하고 방어 강함 |

> HP/ATK/DEF는 서버 응답에서 직접 수신 (중복 하드코딩 불필요)

---

## 구현 범위

### 파일: `client/scripts/CharacterCreateScreen.gd` (수정)

**변경 내용만 기술. 기존 코드 유지.**

#### 1. 클래스 데이터 상수 추가 (스크립트 상단)

```gdscript
const CLASS_DATA := {
    "warrior":  { "label": "전사",  "spd": 1.0, "desc": "균형형 탱커. 가장 가까운 적에게 돌진." },
    "archer":   { "label": "궁수",  "spd": 1.5, "desc": "원거리 기동형. HP 50% 이하 시 후퇴 우선." },
    "mage":     { "label": "마법사","spd": 0.9, "desc": "고화력 원거리. 접근 시 즉시 후퇴." },
    "assassin": { "label": "암살자","spd": 1.6, "desc": "고속 돌격. 치명타 25% 확률(×2 데미지)." },
    "berserk":  { "label": "광전사","spd": 1.3, "desc": "무조건 돌격. HP 낮을수록 데미지 ×1.5." },
    "healer":   { "label": "힐러",  "spd": 1.0, "desc": "아군 회복 우선. 공격력 약하고 방어 강함." },
}
```

#### 2. 클래스 가이드 라벨 변수 추가

```gdscript
var _guide_spd_lbl:  Label
var _guide_desc_lbl: Label
```

#### 3. `_build_ui()` — 기존 `_preview_panel` VBoxContainer에 가이드 라벨 추가

> **훅 포인트**: `_preview_panel`은 `_populate_preview()` 호출 시 visible=true가 됨.
> 기존 `_preview_class`(`:176`), `_preview_stats`(통계 라벨), `_preview_tend`(행동 성향) 아래에 추가.

기존 `_preview_panel` 내부의 VBoxContainer(이하 `pvbox`) 아래에 추가:

```gdscript
# ── 클래스 가이드 추가 항목 ──
var sep := HSeparator.new()
pvbox.add_child(sep)

_guide_spd_lbl = Label.new()
_guide_spd_lbl.add_theme_font_size_override("font_size", 13)
_guide_spd_lbl.modulate = TEXT_SECONDARY
_apply_font(_guide_spd_lbl)
pvbox.add_child(_guide_spd_lbl)

_guide_desc_lbl = Label.new()
_guide_desc_lbl.add_theme_font_size_override("font_size", 12)
_guide_desc_lbl.modulate = TEXT_SECONDARY
_guide_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
_apply_font(_guide_desc_lbl)
pvbox.add_child(_guide_desc_lbl)
```

#### 4. `_populate_preview()` 수정 — 가이드 업데이트 한 줄 추가

> **훅 포인트**: `_populate_preview(d: Dictionary)` → `:241` (서버 `character_preview` 수신 시 호출됨)

```gdscript
func _populate_preview(d: Dictionary) -> void:
    var cls_str: String = (d.get("class", "?") as String).capitalize()
    _preview_class.text = "클래스: " + cls_str
    _preview_stats.text = "HP: %d  ATK: %d  DEF: %d" % [
        d.get("hp", 0), d.get("atk", 0), d.get("def", 0)
    ]
    _preview_tend.text = "행동 성향: " + d.get("tendency", "-")
    _update_class_guide(d.get("class", ""))  # ← 추가 (한 줄)

func _update_class_guide(cls: String) -> void:
    if not CLASS_DATA.has(cls):
        _guide_spd_lbl.text  = ""
        _guide_desc_lbl.text = ""
        return
    var cd: Dictionary = CLASS_DATA[cls]
    _guide_spd_lbl.text  = "💨 속도: %.1f" % cd["spd"]
    _guide_desc_lbl.text = cd["desc"]
```

---

## 파일 목록

| 파일 | 변경 내용 |
|------|-----------|
| `client/scripts/CharacterCreateScreen.gd` | CLASS_DATA 상수, `_guide_spd_lbl`/`_guide_desc_lbl` 변수, `_build_ui()` 라벨 추가, `_populate_preview()`에 `_update_class_guide()` 호출 한 줄 추가 |

서버 변경 없음. 씬 파일 변경 없음 (UI는 GDScript로 빌드됨).

---

## UI 레이아웃 (텍스트 목업)

```
┌─────────────────────────────────────────────────┐
│  캐릭터 생성                                     │
│                                                   │
│  이름: [____________]                             │
│  성격: [________________________]                 │
│                                                   │
│  [AI로 스탯 분석하기]                             │
│                                                   │
│  ┌─────────────────────────────────────────────┐ │
│  │ 클래스: 궁수                                 │ │
│  │ HP: 85  ATK: 12  DEF: 4                      │ │
│  │ 행동 성향: 민첩하고 신중한 전술가             │ │
│  │ ───────────────────────────────────────────  │ │
│  │ 💨 속도: 1.5                                 │ │  ← 신규
│  │ 원거리 기동형. HP 50% 이하 시 후퇴 우선.     │ │  ← 신규
│  └─────────────────────────────────────────────┘ │
│                                                   │
│  [성좌 저장하기]                                  │
└─────────────────────────────────────────────────┘
```

---

## 완료 기준 (AC)

| AC | 내용 |
|----|------|
| AC1 | AI 분석 결과 수신(`character_preview`) 후 프리뷰 패널에 `💨 속도: X.X` 표시 |
| AC2 | 프리뷰 패널 하단에 클래스 특성 설명 텍스트 표시 (자동 줄바꿈 적용) |
| AC3 | 알 수 없는 클래스 키(`CLASS_DATA.has` 실패) 시 가이드 라벨 빈 문자열 처리 (크래시 없음) |
| AC4 | 기존 캐릭터 생성 플로우(이름+프롬프트 → AI 분석 → 저장) 정상 동작 유지 |
| AC5 | `TEXT_SECONDARY` 색상 및 `_apply_font()` 적용 (디자인 시스템 일치) |

---

## 엣지케이스

| 케이스 | 처리 |
|--------|------|
| 알 수 없는 클래스 키 | `CLASS_DATA.has(cls)` 실패 → `_guide_spd_lbl.text = ""`, `_guide_desc_lbl.text = ""` |
| AI 분석 재시도 | `_populate_preview()` 재호출 → 가이드 라벨 덮어쓰기 (정상) |
| 저장 전 프리뷰 패널 숨김 상태 | 가이드 라벨은 `_preview_panel` 자식 → 패널 가시성과 연동됨 |

---

## 예상 기간
0.5일 미만 (변경 최소화: `_populate_preview` 한 줄 추가 + 라벨 2개 빌드)
