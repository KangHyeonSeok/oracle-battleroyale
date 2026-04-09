---
specId: ci-deploy-notify
title: CI 배포 알림
status: queued
owner: partner
runnerProfile: developer
runnerExecution: assistant
createdAt: 2026-04-09
updatedAt: 2026-04-09
dependsOn: phase-5-client-godot
---

# CI 배포 알림

## 목표

GitHub Actions `client-web-export` 워크플로우 완료 후 Vercel 배포 URL과 commit SHA를 Slack `C0ANSP7FU91` 채널에 자동 전송한다.

## 구현 위치

- 파일: `.github/workflows/client-web-export.yml`
- 기존 Vercel 배포 step 이후에 Slack 알림 step 추가

## 작업 목록

| # | 작업 | 산출물 |
|---|------|--------|
| 1 | `client-web-export.yml`에 Vercel output 캡처 (`preview-url` or `deployment-url`) | 수정된 workflow 파일 |
| 2 | Slack notify step 추가 (`slackapi/slack-github-action`) | 알림 step |
| 3 | GitHub Secrets 목록 정의 (`SLACK_BOT_TOKEN`, `VERCEL_TOKEN` 등) | README 또는 주석 |

## 메시지 형식

```
✅ oracle-battleroyale 배포 완료
commit: {shortSHA}
URL: {vercel-url}
```

- `shortSHA`: `${{ github.sha }}` 앞 7자리
- `vercel-url`: Vercel action output `preview-url` 또는 `deployment-url`
- 채널: `C0ANSP7FU91` (성좌게임 채널)

## 완료 기준

- [ ] `git push` 또는 수동 트리거 시 CI 완료 후 Slack에 배포 URL + commit SHA 자동 전송
- [ ] URL이 클릭 가능한 형태로 Slack에 표시됨
- [ ] 배포 실패 시 알림이 전송되지 않거나 실패 메시지가 전송됨

## Constraints

- GitHub Secrets 값 자체는 하드코딩 불가 — 변수명만 명시
- 기존 Godot 빌드/Vercel 배포 step 변경 최소화
- `SLACK_BOT_TOKEN` secret은 repo에 추가 필요 (runner가 추가 불가 — 수동 설정 필요)

## Notes

- `SLACK_BOT_TOKEN`은 hyeonseok가 직접 GitHub repo Secrets에 추가해야 함
- Vercel action이 `amondnet/vercel-action` 기준으로 작성 (기존 yml 확인 필요)
