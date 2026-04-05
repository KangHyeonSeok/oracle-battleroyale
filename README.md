# 성좌 배틀로얄 (Oracle Battle Royale)

> AI 자율 행동 캐릭터들이 콜로세움에서 싸우는 배틀로얄.  
> 플레이어는 직접 조작하지 않고 **신탁(채팅)** 으로 자신 또는 타인 캐릭터에게 개입.

## 기술 스택

| 컴포넌트 | 선택 |
|---|---|
| 클라이언트 | Godot 4.x Web Export (탑뷰 2D) |
| Game Server | Node.js + ws (WebSocket) |
| AI Service | Google Gemini Flash |
| 인증 | Google OAuth 2.0 |
| 상태 저장 | Redis |
| 영구 저장 | PostgreSQL |
| 배포 | Docker Compose |
| 정적 호스팅 | Vercel / Cloudflare Pages |

## 확정 스펙

| 항목 | 내용 |
|---|---|
| 세계관 | 판타지 (콜로세움) |
| LLM | Gemini Flash |
| 신탁 제한 | 분당 1회 (쿨다운) |
| 평균 게임 시간 | 10분 내외 |
| 참가 인원 | 1~32명 (4명 미만 시 NPC 자동 충원) |
| 인증 | Google OAuth (필수) |
| 성좌 포인트 기본값 | 100점 |
| 신탁 비용 | -5pt / 회 |

## MVP 개발 계획

- **Phase 1**: 인프라 & 인증 (1주)
- **Phase 2**: 캐릭터 & AI (1주)
- **Phase 3**: 게임 서버 코어 (1.5주)
- **Phase 4**: 신탁 시스템 (1주)
- **Phase 5**: 클라이언트 Godot (1.5주)
- **Phase 6**: 통합 & QA (1주)

**총 예상: ~6주**

## 미결 사항

- [ ] 콜로세움 맵 크기 (단위, 벽 배치)
- [ ] 기본 전투 수치 (근접/원거리 사거리, 데미지, 쿨다운)
- [ ] NPC 프리셋 종류 및 프롬프트

## 링크

- 기획 캔버스: Slack F0ANHMPSC0P
- 기획 채널: Slack C0ANSP7FU91
