---
specId: arena-character-hud
title: 아레나 캐릭터 상태 HUD
status: draft
owner: partner
runnerProfile: developer
runnerExecution: assistant
createdAt: 2026-04-13
updatedAt: 2026-04-13
dependsOn:
  - phase-3-game-server
  - phase-5-client-godot
  - oracle-ui-design
---

# arena-character-hud: 아레나 캐릭터 상태 HUD

## 목표
배틀로얄 진행 중 플레이어가 각 캐릭터의 HP와 생존 상태를 한눈에 파악하여 신탁(oracle) 내용을 전략적으로 결정할 수 있도록, 아레나 화면 하단에 캐릭터 상태 스트립을 추가한다.

## 배경
- 현재 HUD(`Main.gd:_hud`)는 포인트·턴·생존자 수만 표시 (pts_lbl, turn_lbl, alive_lbl)
- 신탁을 보낼 때 "어떤 캐릭터가 얼마나 위험한가"를 알 수 없어 전략적 판단이 어려움
- `GameState.characters` 배열에 `id, name, class, hp, max_hp, is_alive` 필드가 포함됨
- `GameState.characters_updated` 시그널은 매 턴 발생 → 실시간 갱신 가능
- 서버 변경 불필요. 클라이언트 HUD 확장만으로 구현 가능

---

## 구현 범위

### 파일: `client/scripts/Main.gd` (수정)

**변경 내용만 기술. 기존 코드 유지.**

#### 1. 캐릭터 HUD 스트립 변수 추가

```gdscript
var _char_hud_strip: HBoxContainer   # 캐릭터 카드 컨테이너
var _char_hud_cards: Dictionary = {} # character_id → Control
```

#### 2. `_build_ui()` — HUD 하단에 캐릭터 스트립 추가

`_hud` 기존 레이블 3개 이후 추가. 화면 하단 anchor 고정:

```gdscript
# ── 캐릭터 상태 스트립 ──
_char_hud_strip = HBoxContainer.new()
_char_hud_strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
_char_hud_strip.position.y = -90
_char_hud_strip.add_theme_constant_override("separation", 6)
_char_hud_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
_hud.add_child(_char_hud_strip)
```

#### 3. `_refresh_hud()` — 캐릭터 카드 갱신

`GameState.characters` 기준으로 카드 추가/갱신:

```gdscript
func _refresh_hud() -> void:
    # ... 기존 pts/turn/alive 갱신 코드 유지 ...
    _refresh_char_hud_strip()

func _refresh_char_hud_strip() -> void:
    var chars: Array = GameState.characters
    for char_data in chars:
        var cid: int = char_data.get("id", -1)
        if cid == -1:
            continue
        if not _char_hud_cards.has(cid):
            _char_hud_cards[cid] = _make_char_hud_card(char_data)
            _char_hud_strip.add_child(_char_hud_cards[cid])
        _update_char_hud_card(_char_hud_cards[cid], char_data)

func _make_char_hud_card(data: Dictionary) -> Control:
    var card := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = BG_CARD
    style.corner_radius_top_left = 4
    style.corner_radius_top_right = 4
    style.corner_radius_bottom_left = 4
    style.corner_radius_bottom_right = 4
    card.add_theme_stylebox_override("panel", style)
    card.custom_minimum_size = Vector2(80, 60)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 2)
    card.add_child(vbox)

    var name_lbl := Label.new()
    name_lbl.name = "NameLabel"
    name_lbl.add_theme_font_size_override("font_size", 10)
    name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(name_lbl)

    var hp_bar := ProgressBar.new()
    hp_bar.name = "HpBar"
    hp_bar.min_value = 0.0
    hp_bar.max_value = 1.0
    hp_bar.value = 1.0
    hp_bar.show_percentage = false
    hp_bar.custom_minimum_size = Vector2(70, 8)
    vbox.add_child(hp_bar)

    var class_lbl := Label.new()
    class_lbl.name = "ClassLabel"
    class_lbl.add_theme_font_size_override("font_size", 9)
    class_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    class_lbl.modulate = TEXT_SECONDARY
    vbox.add_child(class_lbl)

    return card

func _update_char_hud_card(card: Control, data: Dictionary) -> void:
    var is_alive: bool = data.get("is_alive", true)
    var hp: float = float(data.get("hp", 0))
    var max_hp: float = float(data.get("max_hp", 1))
    var ratio: float = hp / max_hp if max_hp > 0 else 0.0

    var name_lbl: Label = card.get_node("VBoxContainer/NameLabel")
    var hp_bar: ProgressBar = card.get_node("VBoxContainer/HpBar")
    var class_lbl: Label = card.get_node("VBoxContainer/ClassLabel")

    name_lbl.text = data.get("name", "?")
    class_lbl.text = data.get("class", "")

    hp_bar.value = ratio
    # HP 비율별 색상: 70%↑ GREEN, 30–70% YELLOW, 30%↓ DANGER
    var bar_color: Color
    if ratio > 0.7:
        bar_color = Color(0.2, 0.85, 0.4)    # SUCCESS
    elif ratio > 0.3:
        bar_color = Color(1.0, 0.82, 0.2)    # ACCENT_GOLD
    else:
        bar_color = Color(0.9, 0.3, 0.3)     # DANGER

    var hp_style := StyleBoxFlat.new()
    hp_style.bg_color = bar_color
    hp_bar.add_theme_stylebox_override("fill", hp_style)

    # 사망 시 카드 반투명 + 이름에 취소선
    card.modulate.a = 0.35 if not is_alive else 1.0

    # 내 캐릭터 하이라이트 (accent-purple border)
    var my_char_id: int = _selected_character.get("id", -1)
    if data.get("id", -1) == my_char_id:
        var style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
        style.border_color = Color(0.6, 0.4, 0.9)  # ACCENT_PURPLE
        style.border_width_top = 2
        style.border_width_bottom = 2
        style.border_width_left = 2
        style.border_width_right = 2
        card.add_theme_stylebox_override("panel", style)
```

---

## UI 레이아웃 (텍스트 목업)

```
┌─────────────────────────────────────────────────────────────┐
│  포인트: 120  턴: 14  생존: 3/8                              │  ← 기존 HUD
│                                                              │
│  [아레나 맵]                                                  │
│                                                              │
│ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐                         │  ← 신규
│ │오리온│ │시리│ │벨라│ │마르│ │NPC1│                          │
│ │████│ │████│ │▓▓░░│ │▓░░░│ │████│  ← HP bar               │
│ │warrior│ │mage│ │archer│ │berserk│ │warrior│               │
│ └────┘ └────┘ └────┘ └────┘ └────┘                         │
│  [신탁 입력창 ————————————————————————] [전송]              │  ← 기존 OraclePanel
└─────────────────────────────────────────────────────────────┘
```

- 카드 너비 80px 고정, 최대 8개까지 가로 나열 (ScrollContainer 래핑 권장)
- 사망 캐릭터: 반투명(alpha 0.35), HP bar 회색
- 내 캐릭터: accent-purple border

---

## 파일 목록

| 파일 | 변경 내용 |
|------|-----------|
| `client/scripts/Main.gd` | `_char_hud_strip`, `_char_hud_cards` 변수; `_refresh_char_hud_strip()`, `_make_char_hud_card()`, `_update_char_hud_card()` 함수 추가 |

서버 변경 없음. 씬 파일 변경 없음 (HUD는 GDScript로 빌드됨).

---

## 완료 기준 (AC)

| AC | 내용 |
|----|------|
| AC1 | 아레나 진입 시 HUD 하단에 참가 캐릭터 카드 목록이 표시됨 |
| AC2 | 매 턴 후 `characters_updated` 시그널 수신 시 HP bar가 실시간 갱신됨 |
| AC3 | HP 비율 70% 이상: 녹색, 30–70%: 황금색, 30% 이하: 빨간색으로 표시 |
| AC4 | 사망한 캐릭터 카드는 반투명(alpha 0.35)으로 표시 |
| AC5 | 내 캐릭터 카드에 accent-purple border 강조 표시 |
| AC6 | 아레나 화면이 아닐 때 캐릭터 스트립이 표시되지 않음 (HUD 가시성과 연동) |

---

## 엣지케이스

| 케이스 | 처리 |
|--------|------|
| 관전자 모드 (spectator) | `_selected_character` 없음 → 내 캐릭터 강조 없이 모든 카드 표시 |
| 캐릭터 8명 초과 | 카드 컨테이너를 ScrollContainer로 래핑하여 수평 스크롤 처리 |
| max_hp = 0 (데이터 오류) | ratio = 0으로 처리, 크래시 방지 |
| characters 배열 비어있음 | 카드 추가 없이 빈 스트립 유지 |

---

## 예상 기간
0.5일 (서버 변경 없음, Main.gd 단일 파일)
