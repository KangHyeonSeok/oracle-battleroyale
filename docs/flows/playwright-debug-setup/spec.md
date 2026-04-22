---
specId: playwright-debug-setup
title: Playwright UI 테스트 + JavaScript Debug Bridge
status: in-flight
runnerProfile: developer
runnerExecution: assistant
createdAt: 2026-04-12
updatedAt: 2026-04-13
dependsOn: phase-5-client-godot
---

# Playwright UI 테스트 + JavaScript Debug Bridge

## 목표
AI 파트너(태연)가 배포된 oracle-battleroyale 웹 클라이언트의 현재 화면과 UI 상태를 코드로 확인할 수 있도록:
1. Godot → JavaScript 상태 브릿지 추가 (`window.gameDebug`)
2. Playwright 기반 스크린샷 + 상태 확인 테스트 추가
3. GitHub Actions `workflow_dispatch` 워크플로우 추가 (수동 트리거 → 스크린샷 → Slack 전송)

## 배포 URL
- Production: `https://oracle-battleroyale.vercel.app` (또는 최신 deploy URL — workflow output에서 확인)
- WebSocket: `wss://oracle.hyeonseok.uk/ws`

## 작업 목록

| # | 파일 | 작업 내용 |
|---|------|-----------|
| 1 | `client/scripts/Main.gd` | `_update_debug_state(screen: String)` 추가, `_show_screen()` 호출 시 실행. `JavaScriptBridge` OS.has_feature("web") 체크 후 `window.gameDebug = {currentScreen, wsStatus, ready}` 노출 |
| 2 | `tests/package.json` | playwright 의존성 설정 |
| 3 | `tests/playwright.config.js` | baseURL, timeout, screenshot 설정 |
| 4 | `tests/smoke.spec.js` | (1) URL 로드 → canvas 존재 확인 (2) 5초 대기 후 `window.gameDebug.currentScreen` 읽기 (3) 풀페이지 스크린샷 저장 (4) 결과 콘솔 출력 |
| 5 | `.github/workflows/playwright-screenshot.yml` | `workflow_dispatch` 트리거, Playwright 실행, 스크린샷 artifact 업로드, Slack C0ANSP7FU91에 결과 + 이미지 전송 |

## 구현 상세

### 1. Main.gd — JavaScript Debug Bridge

`_show_screen()` 함수는 `client/scripts/Main.gd:172` 에 위치. 현재 char_list/char_create/match_wait/arena/result 5개 화면을 처리함.
`_on_ws_connected()`는 `:182`, `_on_ws_disconnected()`는 `:187` 에 위치.

`_show_screen()` 함수 끝에 추가:
```gdscript
func _show_screen(name: String) -> void:
    # ... existing visibility code ...
    _update_debug_state(name)

func _update_debug_state(screen: String) -> void:
    if OS.has_feature("web"):
        var js := "window.gameDebug = window.gameDebug || {}; window.gameDebug.currentScreen = '%s'; window.gameDebug.ready = true;" % screen
        JavaScriptBridge.eval(js)
```

WebSocket 연결 시 추가:
```gdscript
func _on_ws_connected() -> void:
    # ... existing code ...
    if OS.has_feature("web"):
        JavaScriptBridge.eval("window.gameDebug = window.gameDebug || {}; window.gameDebug.wsStatus = 'connected';")

func _on_ws_disconnected() -> void:
    # ... existing code ...
    if OS.has_feature("web"):
        JavaScriptBridge.eval("window.gameDebug = window.gameDebug || {}; window.gameDebug.wsStatus = 'disconnected';")
```

### 2. tests/package.json
```json
{
  "name": "oracle-battleroyale-tests",
  "version": "1.0.0",
  "scripts": {
    "test": "playwright test",
    "test:headed": "playwright test --headed"
  },
  "devDependencies": {
    "@playwright/test": "^1.44.0"
  }
}
```

### 3. tests/playwright.config.js
```js
const { defineConfig } = require('@playwright/test');
module.exports = defineConfig({
  testDir: '.',
  timeout: 60000,
  use: {
    baseURL: process.env.BASE_URL || 'https://oracle-battleroyale.vercel.app',
    screenshot: 'on',
    video: 'off',
  },
  reporter: [['list'], ['json', { outputFile: 'test-results/results.json' }]],
});
```

### 4. tests/smoke.spec.js
```js
const { test, expect } = require('@playwright/test');

test('game loads and shows initial screen', async ({ page }) => {
  await page.goto('/');

  // canvas 존재 확인
  const canvas = page.locator('#canvas');
  await expect(canvas).toBeVisible({ timeout: 30000 });

  // 게임 초기화 대기 (Godot WASM 로딩)
  await page.waitForFunction(() => window.gameDebug?.ready === true, { timeout: 45000 });

  // 현재 화면 확인
  const currentScreen = await page.evaluate(() => window.gameDebug?.currentScreen);
  console.log('[DEBUG] currentScreen:', currentScreen);
  console.log('[DEBUG] wsStatus:', await page.evaluate(() => window.gameDebug?.wsStatus));

  // 풀페이지 스크린샷
  await page.screenshot({ path: 'test-results/initial-load.png', fullPage: true });

  // 최소 검증: canvas가 렌더됨
  expect(canvas).toBeTruthy();
});

test('screenshot after 5s', async ({ page }) => {
  await page.goto('/');
  await page.waitForTimeout(5000);
  await page.screenshot({ path: 'test-results/after-5s.png', fullPage: true });
  const screen = await page.evaluate(() => window.gameDebug?.currentScreen ?? 'unknown');
  console.log('[DEBUG] screen after 5s:', screen);
});
```

### 5. .github/workflows/playwright-screenshot.yml
```yaml
name: Playwright Screenshot

on:
  workflow_dispatch:
    inputs:
      base_url:
        description: '테스트할 URL (기본: 최근 배포 URL)'
        required: false
        default: 'https://oracle-battleroyale.vercel.app'

jobs:
  screenshot:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install Playwright
        working-directory: tests
        run: |
          npm install
          npx playwright install chromium --with-deps

      - name: Run Playwright tests
        working-directory: tests
        env:
          BASE_URL: ${{ github.event.inputs.base_url }}
        run: npx playwright test || true  # 실패해도 스크린샷은 저장

      - name: Upload screenshots as artifacts
        uses: actions/upload-artifact@v4
        with:
          name: screenshots
          path: tests/test-results/

      - name: Send screenshots to Slack
        if: always()
        env:
          SLACK_BOT_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}
        run: |
          SHORT_SHA="${GITHUB_SHA:0:7}"
          RUN_URL="https://github.com/KangHyeonSeok/oracle-battleroyale/actions/runs/${GITHUB_RUN_ID}"
          # 텍스트 결과 먼저 전송
          curl -s -X POST "https://slack.com/api/chat.postMessage" \
            -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{
              \"channel\": \"C0ANSP7FU91\",
              \"text\": \"🎭 Playwright 스크린샷 완료\nURL: ${{ github.event.inputs.base_url }}\ncommit: \`${SHORT_SHA}\`\nArtifacts: ${RUN_URL}\"
            }"
          # 스크린샷 파일 업로드
          for f in tests/test-results/*.png; do
            [ -f "$f" ] || continue
            curl -s -X POST "https://slack.com/api/files.uploadV2" \
              -H "Authorization: Bearer $SLACK_BOT_TOKEN" \
              -F "channels=C0ANSP7FU91" \
              -F "file=@$f" \
              -F "filename=$(basename $f)"
          done
```

## 완료 기준 (AC)
- [ ] `window.gameDebug.currentScreen`이 화면 전환 시 업데이트됨 (브라우저 콘솔 확인)
- [ ] `window.gameDebug.wsStatus`가 WS 연결/해제 시 업데이트됨
- [ ] `npx playwright test` 실행 시 `test-results/initial-load.png` 생성
- [ ] GitHub Actions `playwright-screenshot.yml` 수동 트리거 성공
- [ ] 스크린샷 2장 이상이 Slack C0ANSP7FU91에 업로드됨
- [ ] `OS.has_feature("web")` 체크로 데스크탑 빌드에서 오류 없음

## 제약
- `JavaScriptBridge`는 Godot 4.x에서 web export 전용. `OS.has_feature("web")` 체크 필수
- Playwright baseURL은 환경변수 `BASE_URL`로 주입 가능하게 유지
- 스크린샷은 Slack에 직접 파일 업로드 (`files.uploadV2`)
- Vercel COOP/COEP 헤더로 SharedArrayBuffer 활성화됨 — Playwright Chromium은 정상 지원

## 예상 기간
0.5일
