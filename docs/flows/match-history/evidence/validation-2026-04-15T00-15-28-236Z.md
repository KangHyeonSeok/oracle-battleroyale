# match-history Validation

- Status: completed
- Action: completed-spec
- UpdatedAt: 2026-04-15T00:15:28.236Z
- Detail: test-validator: All 9 acceptance criteria confirmed passed by prior developer tick with file-level evidence. Server routes/queries validated via node require checks, Godot screens and signals wired per spec. No failed or partial criteria found.

## Acceptance Criteria Review

1. AC1 — GET /history returns recent matches with matchId, myRank, participantCount, winner
Status: passed
Evidence: routes.js + queries.js: requireAuth, limit clamped 1-50, offset≥0, joins matches→match_participants→characters filtering by user_id and status='finished', returns all required fields

2. AC2 — GET /history/:matchId returns participants ranked + oracle messages time-ordered
Status: passed
Evidence: queries.js getMatchDetail: participants ORDER BY placement ASC; oracles via DESC LIMIT 100 subquery re-sorted ASC for time-order

3. AC3 — MatchHistoryScreen card list + '더 보기' loads next 20
Status: passed
Evidence: MatchHistoryScreen.gd: PAGE_SIZE=20, _offset incremented on _on_more_pressed, _more_btn shown when _offset < _total

4. AC4 — Card click → MatchDetailScreen with participants + oracle feed
Status: passed
Evidence: _make_card emits detail_requested(match_id); Main.gd _on_match_detail_requested calls load_match then _show_screen('match_detail'); MatchDetailScreen._render() builds both panels

5. AC5 — 1등 카드 accent-gold, 내 참가자 행 accent-purple 강조
Status: passed
Evidence: MatchHistoryScreen._make_card: is_winner → border_width_left=4 + ACCENT_GOLD; MatchDetailScreen._make_participant_row: is_me → ACCENT_PURPLE bg, rank==1 → ACCENT_GOLD bg

6. AC6 — CharacterListScreen '경기 기록' 버튼 → MatchHistoryScreen
Status: passed
Evidence: CharacterListScreen.gd: signal history_requested added, history_btn emits it; Main.gd connects to _on_history_requested → _show_screen('match_history')

7. AC7 — 경기 기록 없을 때 빈 상태 메시지
Status: passed
Evidence: MatchHistoryScreen._on_request_completed: offset==0 && matches.is_empty() → _empty_lbl.visible=true, text='아직 경기 기록이 없습니다.'

8. AC8 — isMe=true 신탁 메시지 accent-purple 배경
Status: passed
Evidence: MatchDetailScreen._make_oracle_card: is_me → style.bg_color=Color(ACCENT_PURPLE, 0.18)

9. AC9 — GET /history/:matchId 응답에 oracleCount 필드
Status: passed
Evidence: queries.js getMatchDetail: SELECT COUNT(*) from oracle_invocations returned as oracleCount in response object

