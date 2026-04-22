# phase-5-client-godot Validation

- Status: review-required
- Action: completed-spec
- UpdatedAt: 2026-04-05T22:46:08.418Z
- Detail: test-validator: ACs 1–3 are fully passing. AC4 (Vercel deploy / .wasm) remains partial: all CI workflow, export preset, and vercel.json artifacts are in place and correct, but no actual .wasm build artifact or live Vercel URL has been confirmed — Godot is unavailable in this runner environment and a real CI run is required. Advancing to needs-review so a human can trigger CI and verify the live deployment.

## Acceptance Criteria Review

1. 서버 WebSocket 메시지 수신 → 캐릭터 위치/HP 실시간 업데이트
Status: passed
Evidence: GameState._on_message handles 'turn_result', emits characters_updated. Character.update_from_data() reads hp/x/y, animates via Tween, redraws HP bar. WebSocketClient auto-reconnects every 5 s.

2. 캐릭터 클릭 → 성좌 채팅 패널 슬라이드인 + 'X 성좌가 입장하였습니다' 알림
Status: passed
Evidence: Character emits character_clicked via Area2D. Main._on_character_clicked() calls OraclePanel.show_for_character() → _slide_in() tween + notification toast.

3. 신탁 버튼: 포인트 충분 시 활성, 부족 시 비활성화
Status: passed
Evidence: OraclePanel._refresh_button() gates oracle_btn.disabled on GameState.can_use_oracle() (points >= 5 AND cooldown <= 0). Button label changes to '포인트 부족' when insufficient.

4. vercel deploy → 브라우저에서 정상 실행 (Web Export .wasm)
Status: partial
Evidence: .github/workflows/client-web-export.yml, client/build.sh, vercel.json (COEP/COOP headers), and export_presets.cfg are all present and syntactically correct. No Godot binary available in runner; actual .wasm artifact and live Vercel URL require an external CI run to confirm.

