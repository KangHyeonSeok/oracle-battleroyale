# character-class-guide Validation

- Status: completed
- Action: completed-spec
- UpdatedAt: 2026-04-15T00:07:02.506Z
- Detail: test-validator: All 5 acceptance criteria confirmed passed in validation evidence. Implementation is complete with CLASS_DATA constant, guide labels with correct styling, and _update_class_guide() integrated safely into _populate_preview().

## Acceptance Criteria Review

1. AC1 — 💨 속도: X.X displayed after character_preview received
Status: passed
Evidence: _populate_preview() calls _update_class_guide(d.get('class','')) which sets _guide_spd_lbl.text = '💨 속도: %.1f' % cd['spd'] for known classes

2. AC2 — class description with autowrap displayed in preview panel
Status: passed
Evidence: _guide_desc_lbl created with autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; cd['desc'] assigned in _update_class_guide()

3. AC3 — unknown class key handled without crash
Status: passed
Evidence: _update_class_guide() opens with 'if not CLASS_DATA.has(cls)' guard → sets both labels to '' and returns early

4. AC4 — existing character creation flow unchanged
Status: passed
Evidence: No existing lines removed; _populate_preview() only gains one appended call; _build_ui(), WS handler, and save flow untouched

5. AC5 — TEXT_SECONDARY colour and _apply_font() applied to guide labels
Status: passed
Evidence: Both _guide_spd_lbl and _guide_desc_lbl have modulate = TEXT_SECONDARY and _apply_font() called before pvbox.add_child()

