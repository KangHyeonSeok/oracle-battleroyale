---
specId: phase-5-client-godot
title: 클라이언트 (Godot)
status: queued
runnerProfile: developer
runnerExecution: assistant
createdAt: 2026-04-05
updatedAt: 2026-04-05
dependsOn: phase-3-game-server
---

# Phase 5: 클라이언트 (Godot)

## 목표
Godot 4.x 탑뷰 2D 클라이언트를 구현하고 Web Export로 Vercel 배포한다.

## 확정된 맵 사양
| 항목 | 값 |
|------|-----|
| 맵 크기 | 800×800px (소형) |
| 벽/장애물 | 심플 기둥/잔해 배치 (TileMap, 소수 배치로 개방감 유지) |

## 작업 목록

| # | 작업 | 산출물 |
|---|---|---|
| 5-1 | Godot 4.x 프로젝트 세팅 (탑뷰 2D) | 프로젝트 구조 |
| 5-2 | 콜로세움 맵 800×800 (심플 기둥/잔해, 충돌 타일맵) | 맵 씬 |
| 5-3 | 캐릭터 렌더링 (위치 동기화, HP바) | WebSocket ↔ 노드 바인딩 |
| 5-4 | 신탁 채팅 UI (캐릭터 클릭 → 패널, 입장 알림, 쿨다운 표시) | UI 씬 |
| 5-5 | 관전 화면 | 카메라 + 전체 맵 뷰 |
| 5-6 | Web Export 빌드 + Vercel 배포 | .wasm 패키지 |

## 완료 기준
- [ ] 서버 WebSocket 메시지 수신 → 캐릭터 위치/HP 실시간 업데이트
- [ ] 캐릭터 클릭 → 성좌 채팅 패널 슬라이드인 + "X 성좌가 입장하였습니다" 알림
- [ ] 신탁 버튼: 포인트 충분 시 활성, 부족 시 비활성화
- [ ] `vercel deploy` → 브라우저에서 정상 실행 (Web Export .wasm)

## 예상 기간
1.5주
