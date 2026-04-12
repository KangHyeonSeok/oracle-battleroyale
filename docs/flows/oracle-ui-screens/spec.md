---
specId: oracle-ui-screens
title: 성좌 배틀로얄 UI 화면 구현
status: ready
owner: partner
runnerProfile: developer
runnerExecution: assistant
createdAt: 2026-04-06
updatedAt: 2026-04-06
---

# Goal

캐릭터 목록, 캐릭터 생성, 매칭 대기, 신탁 스트림(채팅 피드), 경기 결과 화면을 구현하여 성좌 배틀로얄 게임의 전체 UI 플로우를 완성한다.

## Context

신탁 배틀로얄(oracle-battleroyale)은 Godot 4.x Web Export 클라이언트 + Node.js WebSocket 서버 구조다.
현재 구현된 화면: 접속(WS URL 입력), 경기 입장(매치 ID 입력), 아레나(맵·캐릭터·HUD), 신탁 패널(골격만, 채팅 목록 없음).
구현 대상은 아직 없는 5개 화면이다.

## Screens to Implement

### 1. 캐릭터 목록 화면 (CharacterListScreen)
- 계정에 저장된 내 성좌 목록을 카드형으로 표시 (이름, 클래스, 승률)
- "새 성좌 만들기" 버튼 → 캐릭터 생성 화면으로 이동
- 경기 참여 시 출전 캐릭터 선택 → 매칭 대기 화면으로 이동

### 2. 캐릭터 생성 화면 (CharacterCreateScreen)
- 성좌명 입력 (필수)
- 챔피언 프롬프트 입력 (자유 텍스트) → Gemini API로 스탯 추출
- 결과 미리보기: 클래스, HP/ATK/DEF, 행동 성향 표시
- 저장 버튼 → 계정에 영구 보관 후 목록으로 이동

### 3. 매칭 대기 화면 (MatchWaitScreen)
- "경기 참가" 진입 시 대기열에 자동 등록 (방장 없음, 시스템 자동 매칭)
- 현재 대기 참가자 수 표시 (예: 7/32)
- 대기 시간 카운트다운 표시
- 참가자 부족 시 NPC 자동 충원 안내 텍스트
- 취소 버튼 → 캐릭터 목록으로 복귀

### 4. 채팅 피드 (OracleStreamPanel) — 신탁 스트림 개선
- 신탁 메시지 히스토리 목록 (보낸이 → 대상, 내용, 성공/실패 뱃지)
- LLM 서사 이벤트 메시지 (시스템 발행)
- 자동 스크롤, 시간순 정렬
- 관전자도 신탁 입력 가능 (경기 참여 여부 무관)

### 5. 경기 결과 화면 (MatchResultScreen)
- 우승 성좌명 + 연출
- 순위 목록 (탈락 순서)
- 신탁 포인트 정산 (소모 -pt / 우승 보너스 +pt)
- 다시 참가 / 메인으로 버튼

## Screen Flow

```
앱 진입
  └─ 캐릭터 목록
       ├─ 새 성좌 만들기 → 캐릭터 생성 → 목록으로
       └─ 출전 선택 → 매칭 대기 → 경기(아레나 + OracleStreamPanel) → 결과
                                          ↑
                               관전자도 OracleStreamPanel 진입 가능
```

## Base Stats (LLM multiplier 0.8x–1.3x applied per prompt)

| 클래스 | HP  | ATK | DEF | 사거리     | 쿨다운 |
|--------|-----|-----|-----|-----------|--------|
| 전사   | 150 |  25 |  15 | 근거리 1.5 | 1.2s   |
| 궁수   | 100 |  20 |   8 | 원거리 6.0 | 1.5s   |
| 마법사 |  80 |  35 |   5 | 원거리 5.0 | 2.5s   |
| 암살자 |  90 |  30 |   6 | 근거리 1.0 | 0.8s   |
| 치유사 | 110 |  12 |  10 | 중거리 4.0 | 3.0s   |

NPC도 동일 수치 테이블 사용.

## Acceptance Criteria

1. CharacterListScreen: 저장된 성좌 카드가 표시되고, 새 성좌 만들기 버튼이 CharacterCreateScreen으로 이동한다.
2. CharacterCreateScreen: 프롬프트 입력 후 Gemini 호출 결과(클래스·스탯)가 미리보기에 표시되고 저장된다.
3. MatchWaitScreen: 대기열 진입 후 참가자 수와 카운트다운이 실시간 업데이트된다. 시스템이 자동으로 매치를 시작한다.
4. OracleStreamPanel: 신탁 메시지 히스토리가 시간순으로 표시되고, 관전자 포함 누구나 신탁을 보낼 수 있다.
5. MatchResultScreen: 경기 종료 시 우승자·순위·포인트 정산이 표시되고 재참가 버튼이 동작한다.
6. 전체 플로우를 앱 진입부터 결과 화면까지 중단 없이 진행할 수 있다.

## Constraints

- Godot 4.x GDScript 기반 클라이언트 (client/ 디렉토리)
- 서버 WebSocket API와 연동 (server/ 디렉토리 기존 엔드포인트 최대 활용)
- 기존 Arena/OraclePanel 씬 구조를 최대한 유지하고 새 씬을 추가하는 방식으로 구현
- Gemini API 호출은 서버 사이드에서 수행 (클라이언트 API 키 노출 금지)

## Notes

- 클라이언트 구조: client/ (Godot 프로젝트)
- 서버 구조: server/ (Node.js)
- 기존 handoff: /shared/handoff-oracle-battleroyale-v1.md 참조
