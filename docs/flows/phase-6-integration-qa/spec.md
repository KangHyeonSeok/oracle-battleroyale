---
specId: phase-6-integration-qa
title: 통합 & QA
status: queued
runnerProfile: developer
runnerExecution: assistant
createdAt: 2026-04-05
updatedAt: 2026-04-05
dependsOn:
  - phase-4-oracle-system
  - phase-5-client-godot
---

# Phase 6: 통합 & QA

## 목표
풀 플로우 E2E 테스트, 32명 부하 테스트, Gemini 비용 검증, 버그 수정을 완료한다.

## 작업 목록

| # | 작업 | 산출물 |
|---|---|---|
| 6-1 | 풀 플로우 테스트 (로그인→생성→게임→종료) | E2E 시나리오 |
| 6-2 | 32명 동시 접속 부하 테스트 | 성능 리포트 |
| 6-3 | Gemini 비용 검증 (판당 $0.005 이하) | 비용 로그 |
| 6-4 | 버그 수정 + 밸런스 조정 | 패치 |

## 완료 기준
- [ ] 로그인 → 캐릭터 생성 → 매치 참가 → 신탁 전송 → 게임 종료 → 포인트 정산 전 구간 정상
- [ ] 32명 동시 WebSocket 연결 상태에서 60초 턴 처리 1,000ms 이내
- [ ] Gemini API 호출 비용: 판당 평균 $0.005 이하 검증
- [ ] 위 테스트에서 발견된 P0/P1 버그 전부 수정

## 예상 기간
1주
