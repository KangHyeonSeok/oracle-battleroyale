---
specId: phase-1-infra-auth
title: 인프라 & 인증
status: queued
runnerProfile: developer
runnerExecution: assistant
createdAt: 2026-04-05
updatedAt: 2026-04-05
---

# Phase 1: 인프라 & 인증

## 목표
Node.js + WebSocket 서버 기반 인프라를 구성하고 Google OAuth 2.0 인증을 구현한다.

## 작업 목록

| # | 작업 | 산출물 |
|---|---|---|
| 1-1 | 프로젝트 초기 세팅 (Node.js + ws + Docker Compose) | 서버 boilerplate, Dockerfile |
| 1-2 | Redis + PostgreSQL 컨테이너 구성 | docker-compose.yml |
| 1-3 | Google OAuth 2.0 로그인 | /auth 엔드포인트, 세션 관리 |
| 1-4 | DB 스키마 설계 (캐릭터, 매치 히스토리) | migration 파일 |

## 완료 기준
- [ ] `docker-compose up`으로 서버, Redis, PostgreSQL 전체 실행 가능
- [ ] `/auth/google` → OAuth 콜백 → 세션 쿠키 발급 정상 동작
- [ ] DB 마이그레이션 파일 실행 후 캐릭터/매치 테이블 생성 확인

## 예상 기간
1주
