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
