---
specId: character-class-guide
title: 캐릭터 클래스 가이드 패널
status: in-flight
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
캐릭터 생성 화면에서 클래스를 선택할 때, 해당 클래스의 스탯(HP/ATK/DEF/Speed)과 플레이 스타일 설명을 우측 패널에 표시한다. 현재는 클래스 이름만 표시되어 신규 플레이어가 클래스 선택의 의미를 모른 채 생성하는 UX 문제가 있다.

## 배경
- `class-balance` 스펙에서 6개 클래스 스탯 확정됨 (warrior/archer/mage/assassin/berserk/healer)
- `npc-presets.js`에 동일 스탯 정의됨 (HP/ATK/DEF/Speed + ai_persona 설명)
- `CharacterCreateScreen.gd`는 현재 클래스 선택 시 "클래스: warrior" 텍스트만 표시
- 추가 서버 API 불필요 — 클라이언트 하드코딩으로 충분 (스탯은 이미 class-balance에서 확정됨)

---

## 클래스 데이터 (클라이언트 하드코딩)

| 클래스 | 이름(표시) | Max HP | ATK | DEF | Speed | 특성 |
|--------|-----------|--------|-----|-----|-------|------|
| warrior  | 전사 | 150 | 10 | 10 | 1.0 | 균형형 탱커. 가장 가까운 적에게 돌진 |
| archer   | 궁수 |  85 | 12 |  4 | 1.5 | 원거리 기동형. HP 50% 이하 시 후퇴 우선 |
| mage     | 마법사 |  70 | 16 |  2 | 0.9 | 고화력 원거리. 접근 시 즉시 후퇴 |
| assassin | 암살자 |  90 | 14 |  4 | 1.6 | 고속 돌격. 치명타 25% 확률(×2 데미지) |
| berserk  | 광전사 | 100 | 18 |  3 | 1.3 | 무조건 돌격. HP 낮을수록 데미지 ×1.5 |
| healer   | 힐러 | 120 |  6 |  8 | 1.0 | 아군 회복 우선. 공격력 약하고 방어 강함 |

---

## 구현 범위

### 파일: `client/scripts/CharacterCreateScreen.gd` (수정)

**변경 내용만 기술. 기존 코드 유지.**

#### 1. 클래스 데이터 상수 추가 (스크립트 상단)

```gdscript
const CLASS_DATA := {
    "warrior":  { "label": "전사",  "hp": 150, "atk": 10, "def": 10, "spd": 1.0, "desc": "균형형 탱커. 가장 가까운 적에게 돌진." },
    "archer":   { "label": "궁수",  "hp": 85,  "atk": 12, "def": 4,  "spd": 1.5, "desc": "원거리 기동형. HP 50% 이하 시 후퇴 우선." },
    "mage":     { "label": "마법사","hp": 70,  "atk": 16, "def": 2,  "spd": 0.9, "desc": "고화력 원거리. 접근 시 즉시 후퇴." },
    "assassin": { "label": "암살자","hp": 90,  "atk": 14, "def": 4,  "spd": 1.6, "desc": "고속 돌격. 치명타 25% 확률(×2 데미지)." },
    "berserk":  { "label": "광전사","hp": 100, "atk": 18, "def": 3,  "spd": 1.3, "desc": "무조건 돌격. HP 낮을수록 데미지 ×1.5." },
    "healer":   { "label": "힐러",  "hp": 120, "atk": 6,  "def": 8,  "spd": 1.0, "desc": "아군 회복 우선. 공격력 약하고 방어 강함." },
}
```

#### 2. 클래스 가이드 패널 변수 추가

```gdscript
var _class_guide_panel: PanelContainer
var _guide_hp_lbl:   Label
var _guide_atk_lbl:  Label
var _guide_def_lbl:  Label
var _guide_spd_lbl:  Label
var _guide_desc_lbl: Label
```

#### 3. `_build_ui()` — 클래스 선택 영역 우측에 가이드 패널 추가

클래스 버튼 목록 컨테이너와 가이드 패널을 `HBoxContainer`로 감싸 좌우 분할 레이아웃 구성:

```
HBoxContainer (SIZE_EXPAND_FILL)
  ├─ VBoxContainer (클래스 버튼 목록, min_width 130px)
  │     warrior / archer / mage / assassin / berserk / healer 버튼
  └─ PanelContainer (가이드 패널, SIZE_EXPAND_FILL)
        VBoxContainer
          Label "클래스 정보" (헤더, ACCENT_GOLD)
          Label "❤ HP: —"
          Label "⚔ 공격: —"
          Label "🛡 방어: —"
          Label "💨 속도: —"
          Separator
          Label 특성 설명 (autowrap, TEXT_SECONDARY)
```

#### 4. `_on_class_selected(cls: String)` 함수 수정/추가

클래스 버튼 pressed 시 호출. 기존 `_preview_class.text` 업데이트에 추가:

```gdscript
func _on_class_selected(cls: String) -> void:
    _preview_class.text = "클래스: " + cls.capitalize()
    _update_class_guide(cls)

func _update_class_guide(cls: String) -> void:
    if not CLASS_DATA.has(cls):
        return
    var d: Dictionary = CLASS_DATA[cls]
    _guide_hp_lbl.text   = "❤ HP: %d" % d["hp"]
    _guide_atk_lbl.text  = "⚔ 공격: %d" % d["atk"]
    _guide_def_lbl.text  = "🛡 방어: %d" % d["def"]
    _guide_spd_lbl.text  = "💨 속도: %.1f" % d["spd"]
    _guide_desc_lbl.text = d["desc"]
```

---

## 파일 목록

| 파일 | 변경 내용 |
|------|-----------|
| `client/scripts/CharacterCreateScreen.gd` | CLASS_DATA 상수, 가이드 패널 UI, `_update_class_guide()` 추가 |

서버 변경 없음. 씬 파일(`CharacterCreateScreen.tscn`) 변경 없음 (UI는 GDScript로 빌드됨).

---

## UI 레이아웃 (텍스트 목업)

```
┌─────────────────────────────────────────────────┐
│  캐릭터 생성                                     │
│                                                   │
│  이름: [____________]                             │
│                                                   │
│  클래스 선택:                                     │
│  ┌─────────────┬──────────────────────────────┐  │
│  │ [전사]      │  클래스 정보                  │  │
│  │ [궁수]      │  ❤ HP: 85                    │  │
│  │ [마법사]    │  ⚔ 공격: 12                  │  │
│  │ [암살자]    │  🛡 방어: 4                   │  │
│  │ [광전사]    │  💨 속도: 1.5                 │  │
│  │ [힐러]      │  ─────────────────────────   │  │
│  │             │  원거리 기동형.               │  │
│  │             │  HP 50% 이하 시 후퇴 우선.   │  │
│  └─────────────┴──────────────────────────────┘  │
│                                                   │
│  [취소]                            [생성]         │
└─────────────────────────────────────────────────┘
```

---

## 완료 기준 (AC)

| AC | 내용 |
|----|------|
| AC1 | CharacterCreateScreen에서 클래스 버튼 클릭 시 우측 패널에 HP/ATK/DEF/Speed 수치 업데이트 |
| AC2 | 특성 설명 텍스트가 패널 하단에 표시 (자동 줄바꿈 적용) |
| AC3 | 초기 진입 시 첫 번째 클래스(warrior)가 기본 선택 상태로 가이드 패널에 표시 |
| AC4 | 기존 캐릭터 생성 플로우(이름 입력 → 클래스 선택 → 생성 버튼) 정상 동작 유지 |
| AC5 | Astraea Nexus 디자인 시스템 색상 상수 사용 (BG_CARD, ACCENT_GOLD, TEXT_PRIMARY, TEXT_SECONDARY) |

---

## 엣지케이스

| 케이스 | 처리 |
|--------|------|
| 알 수 없는 클래스 키 | `CLASS_DATA.has(cls)` 체크 → 가이드 패널 업데이트 스킵 (기존 표시 유지) |
| 클래스 미선택 상태에서 생성 버튼 클릭 | 기존 validation 동작 유지 (spec 범위 외) |

---

## 예상 기간
0.5일 (서버 변경 없음, 클라이언트 단일 파일)
