---
specId: random-character
title: 랜덤 성좌 생성
status: queued
runnerProfile: developer
runnerExecution: assistant
createdAt: 2026-04-12
updatedAt: 2026-04-12
dependsOn: phase-2-character-ai
---

# 랜덤 성좌 생성

## 목표
"새 성좌 만들기" 화면에 "랜덤 생성" 버튼을 추가해, 이름/프롬프트 입력 없이 AI가 랜덤으로 성좌를 만들고 바로 미리보기할 수 있게 한다.

## 요청 배경
hyeonseok 2026-04-12: "접속 해보니 새 성좌 만들기 나오는데, 랜덤으로 만들수 있도록 하자."

## 완료 기준 (Acceptance Criteria)

- [ ] **AC-1 버튼 노출**: `CharacterCreateScreen`에 "🎲 랜덤 생성" 버튼이 "AI로 스탯 분석하기" 버튼 옆에 표시된다
- [ ] **AC-2 WS 전송**: 버튼 클릭 시 `{"type": "random_character"}` WebSocket 메시지를 서버로 전송한다
- [ ] **AC-3 서버 응답**: 서버가 `random_character` 메시지를 받으면 Gemini로 랜덤 성좌명 + 스탯을 생성하고 기존 `character_preview` 형식으로 응답한다 — `name` 필드 포함
- [ ] **AC-4 자동 채워넣기**: `character_preview` 응답 수신 시 `_name_input`에 서버가 반환한 `name` 값이 자동으로 채워지고, 미리보기 패널이 표시된다
- [ ] **AC-5 저장 가능**: 랜덤 생성 후 "성좌 저장하기" 버튼이 활성화되어 정상 저장된다
- [ ] **AC-6 로딩 표시**: 랜덤 생성 중 "AI 생성 중..." 레이블이 표시되고, 버튼이 비활성화된다

## 구현 범위

### Client: `client/scripts/CharacterCreateScreen.gd`

1. `_random_btn: Button` 변수 추가
2. `_build_ui()` 내 버튼 행(`HBoxContainer`)으로 `_analyze_btn`과 `_random_btn`을 나란히 배치
   - `_random_btn.text = "🎲 랜덤 생성"`
3. `_on_random_pressed()` 추가:
   ```gdscript
   func _on_random_pressed() -> void:
       _random_btn.disabled = true
       _analyze_btn.disabled = true
       _loading_lbl.text = "AI 생성 중..."
       _loading_lbl.visible = true
       _preview_panel.visible = false
       _save_btn.visible = false
       WebSocketClient.send({"type": "random_character"})
   ```
4. `_on_ws_message()` 내 `character_preview` 분기에서 `name` 필드가 있으면 `_name_input.text` 자동 세팅:
   ```gdscript
   "character_preview":
       _loading_lbl.visible = false
       _analyze_btn.disabled = false
       _random_btn.disabled = false
       _preview_data = data.get("character", {})
       var name_from_server = _preview_data.get("name", "")
       if not name_from_server.is_empty():
           _name_input.text = name_from_server
           _pending_name = name_from_server
       _populate_preview(_preview_data)
       _preview_panel.visible = true
       _save_btn.visible = true
   ```

### Server (Node.js, `server/src/` 경로 탐색 후 적용)

1. WebSocket 메시지 라우터에서 `random_character` 타입 처리 추가
2. Gemini 프롬프트 예시:
   ```
   Create a random battle arena character with a Korean fantasy name.
   Return JSON: { "name": "캐릭터명", "class": "warrior|archer|mage", "hp": 80-120, "atk": 10-25, "def": 5-20, "tendency": "한 줄 설명" }
   ```
3. 응답: `{ "type": "character_preview", "character": { name, class, hp, atk, def, tendency } }`

## 파일 변경 목록

| 파일 | 변경 내용 |
|------|-----------|
| `client/scripts/CharacterCreateScreen.gd` | 랜덤 버튼 추가, WS 핸들러 확장 |
| `server/src/ws/handlers.js` (또는 동등 경로) | `random_character` 핸들러 추가 |

## 검증 방법
1. https://oracle-battleroyale.vercel.app 접속
2. 로그인 → "새 성좌 만들기"
3. "🎲 랜덤 생성" 클릭
4. 로딩 후 이름 자동 입력 + 미리보기 패널 표시 확인
5. "성좌 저장하기" 클릭 → 목록에 나타나는지 확인
