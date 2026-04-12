# oracle-point-system Validation

- Status: completed
- Action: completed-spec
- UpdatedAt: 2026-04-10T06:29:10.864Z
- Detail: test-validator: All 6 acceptance criteria passed per validation evidence (18/18 tests). Migration, points logic, WS push, auth integration, and match-end settlement are all confirmed implemented and tested.

## Acceptance Criteria Review

1. AC1: 신규 계정 생성 후 accounts.oracle_points = 100
Status: passed
Evidence: Default 100 set in schema; getPoints returns 100 for new user confirmed by test

2. AC2: 잔액 10pt 미만 시 insufficient_points 에러 반환
Status: passed
Evidence: deductPoint uses WHERE constellation_points >= 10; routes.js early guard returns insufficient_points; test user with 5pt correctly got the error

3. AC3: 신탁 전송 성공 시 -10pt 및 point_transactions 레코드 생성
Status: passed
Evidence: deductPoint atomically deducts 10pt and inserts delta=-10, reason='oracle_send' into point_transactions; test confirmed

4. AC4: 경기 우승 시 +50pt, win_bonus 레코드 생성
Status: passed
Evidence: awardMatchEndPoints awards WIN_REWARD=50 with reason='win_bonus' for placement=1; test confirmed +50pt and transaction record

5. AC5: 로그인 시 당일 첫 1회만 +10pt (중복 방지)
Status: passed
Evidence: grantDailyBonus queries same-day daily_login record before awarding; second call returns null without modifying balance; both paths tested

6. AC6: WS points_update 이벤트 즉시 전달
Status: passed
Evidence: broadcastToUser added to room-manager; called from deductPoint/awardPoints/grantDailyBonus; initial points_update sent on join_match; test confirmed event fired with numeric points value

