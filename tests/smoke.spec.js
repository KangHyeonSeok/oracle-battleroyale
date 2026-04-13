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
