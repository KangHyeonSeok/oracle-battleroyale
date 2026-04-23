---
specId: game-onboarding
title: 신규 유저 온보딩 (신탁 시스템 안내)
status: queued
owner: partner
runnerProfile: developer
runnerExecution: assistant
createdAt: 2026-04-15
updatedAt: 2026-04-15
dependsOn:
  - phase-5-client-godot
  - phase-1-infra-auth
  - character-class-guide
---

# game-onboarding: 신규 유저 온보딩

## 목표
신규 플레이어가 신탁 시스템과 배틀로얄 규칙을 이해하고 첫 게임에 자신 있게 참여할 수 있도록 간단한 인게임 안내를 제공한다.

## 배경
- 현재 게임 진입 후 캐릭터 생성→대기→게임 순서로 진행되지만 규칙 설명이 없음
- "신탁(Oracle)"이라는 개념이 생소할 수 있음 — 첫 방문자 이탈 원인
- 서버에 계정별 `onboarding_done` 플래그 추가 후 최초 1회만 표시
- 이후 로그인 시에는 표시하지 않음 (localStorage 백업)

---

## 구현 범위

### 파일: `server/src/characters/routes.js` (수정)

#### `/auth/me` 응답에 `onboardingDone` 추가

```js
// GET /auth/me
router.get('/me', requireAuth, async (req, res) => {
    const { rows } = await pool.query(
        'SELECT id, display_name, oracle_points, onboarding_done FROM accounts WHERE id = $1',
        [req.user.id]
    );
    const account = rows[0];
    res.json({
        id: account.id,
        displayName: account.display_name,
        oraclePoints: account.oracle_points,
        onboardingDone: account.onboarding_done ?? false
    });
});

// POST /auth/onboarding-done
router.post('/onboarding-done', requireAuth, async (req, res) => {
    await pool.query(
        'UPDATE accounts SET onboarding_done = TRUE WHERE id = $1',
        [req.user.id]
    );
    res.json({ ok: true });
});
```

> `accounts` 테이블에 `onboarding_done BOOLEAN DEFAULT FALSE` 컬럼 추가 마이그레이션 필요.

### 파일: `server/src/db/migrate.js` (수정)

```js
await pool.query(`
    ALTER TABLE accounts
    ADD COLUMN IF NOT EXISTS onboarding_done BOOLEAN DEFAULT FALSE;
`);
```

---

### 파일: `client/scripts/OnboardingOverlay.gd` (신규)

신탁 시스템 3단계 슬라이드 오버레이:

```gdscript
extends Control

signal onboarding_completed

const SLIDES = [
    {
        "title": "성좌 배틀로얄에 오신 것을 환영합니다!",
        "body": "AI 캐릭터들이 콜로세움에서 싸우는 배틀로얄입니다.\n당신은 신(神)으로서 신탁으로 결과에 개입합니다.",
        "icon": "⚔️"
    },
    {
        "title": "신탁(Oracle)이란?",
        "body": "채팅창에 명령을 입력하면 Gemini AI가 해석해\n당신의 캐릭터 행동에 영향을 줍니다.\n예: \"적진을 피해 도망쳐라\" / \"가장 약한 적을 공격해\"",
        "icon": "🔮"
    },
    {
        "title": "포인트와 랭킹",
        "body": "신탁을 보낼 때마다 성좌 포인트가 소모됩니다.\n캐릭터가 살아남을수록 포인트를 획득합니다.\n전략적으로 신탁을 사용해 리더보드 1위를 노리세요!",
        "icon": "🏆"
    }
]

var _current_slide: int = 0
var _slide_title: Label
var _slide_body: Label
var _slide_icon: Label
var _next_btn: Button
var _skip_btn: Button
var _dots: HBoxContainer

func _ready() -> void:
    _build_ui()
    _show_slide(0)

func _build_ui() -> void:
    # 반투명 배경
    var bg := ColorRect.new()
    bg.color = Color(0, 0, 0, 0.75)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    # 카드 컨테이너
    var card := PanelContainer.new()
    card.set_anchors_preset(Control.PRESET_CENTER)
    card.custom_minimum_size = Vector2(420, 300)
    add_child(card)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 16)
    card.add_child(vbox)

    _slide_icon = Label.new()
    _slide_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _slide_icon.add_theme_font_size_override("font_size", 48)
    vbox.add_child(_slide_icon)

    _slide_title = Label.new()
    _slide_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _slide_title.add_theme_font_size_override("font_size", 18)
    vbox.add_child(_slide_title)

    _slide_body = Label.new()
    _slide_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _slide_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _slide_body.add_theme_font_size_override("font_size", 13)
    vbox.add_child(_slide_body)

    # 페이지 도트
    _dots = HBoxContainer.new()
    _dots.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_child(_dots)

    # 버튼
    var btn_row := HBoxContainer.new()
    btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_child(btn_row)

    _skip_btn = Button.new()
    _skip_btn.text = "건너뛰기"
    _skip_btn.pressed.connect(_on_finish)
    btn_row.add_child(_skip_btn)

    _next_btn = Button.new()
    _next_btn.text = "다음 >"
    _next_btn.pressed.connect(_on_next)
    btn_row.add_child(_next_btn)

    # 도트 초기화
    for i in SLIDES.size():
        var dot := Label.new()
        dot.text = "●"
        _dots.add_child(dot)

func _show_slide(idx: int) -> void:
    _current_slide = idx
    var s := SLIDES[idx]
    _slide_icon.text = s["icon"]
    _slide_title.text = s["title"]
    _slide_body.text = s["body"]
    _next_btn.text = "시작하기!" if idx == SLIDES.size() - 1 else "다음 >"

    for i in _dots.get_child_count():
        _dots.get_child(i).modulate.a = 1.0 if i == idx else 0.35

func _on_next() -> void:
    if _current_slide < SLIDES.size() - 1:
        _show_slide(_current_slide + 1)
    else:
        _on_finish()

func _on_finish() -> void:
    emit_signal("onboarding_completed")
    queue_free()
```

---

### 파일: `client/scripts/Main.gd` (수정)

#### `/auth/me` 응답에서 `onboardingDone` 확인 후 오버레이 표시

```gdscript
func _on_auth_me_response(data: Dictionary) -> void:
    # 기존 처리 유지 ...
    if not data.get("onboardingDone", true):
        _show_onboarding()

func _show_onboarding() -> void:
    var overlay := preload("res://scripts/OnboardingOverlay.gd").new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.onboarding_completed.connect(func():
        # 서버에 onboarding 완료 기록
        _http_post("/auth/onboarding-done", {}, func(_data): pass)
    )
    add_child(overlay)
```

---

## 파일 목록

| 파일 | 변경 내용 |
|------|-----------|
| `server/src/db/migrate.js` | `accounts.onboarding_done` 컬럼 추가 마이그레이션 |
| `server/src/characters/routes.js` (또는 auth/routes.js) | `/auth/me`에 `onboardingDone` 추가, `POST /auth/onboarding-done` 신규 |
| `client/scripts/OnboardingOverlay.gd` | 3단계 슬라이드 오버레이 신규 |
| `client/scripts/Main.gd` | `/auth/me` 응답 후 onboarding 조건부 표시 |

---

## 완료 기준 (AC)

| AC | 내용 |
|----|------|
| AC1 | 최초 로그인 후 `/auth/me` 응답의 `onboardingDone: false` 시 오버레이 자동 표시 |
| AC2 | 3개 슬라이드 (환영/신탁 설명/포인트 안내) 순차 표시, "다음" 버튼으로 이동 |
| AC3 | 마지막 슬라이드에서 "시작하기!" 또는 언제든 "건너뛰기" 클릭 시 오버레이 닫힘 |
| AC4 | 오버레이 닫힘 시 `POST /auth/onboarding-done` 호출 → DB에 `onboarding_done = TRUE` 저장 |
| AC5 | 두 번째 로그인부터는 오버레이 표시되지 않음 |
| AC6 | 오버레이 표시 중에도 배경 게임 화면(CharacterListScreen 등)이 렌더링됨 |

---

## 엣지케이스

| 케이스 | 처리 |
|--------|------|
| `/auth/onboarding-done` 요청 실패 | 클라이언트에서 `localStorage.setItem("onboardingDone", "1")` 백업 처리 |
| onboarding_done 컬럼 없는 구 DB | `ADD COLUMN IF NOT EXISTS`로 안전 처리 |
| 오버레이 표시 중 화면 전환 | `queue_free()` 후 시그널 연결 자동 해제 |

---

## 예상 기간
1일 (서버 마이그레이션 + 클라이언트 오버레이, 비교적 단순)
