import { defineConfig } from '@playwright/test'
export default defineConfig({
  testDir: './tests',
  outputDir: 'test-results/pages',
  testMatch: 'pages.spec.ts',
  use: { baseURL: 'http://127.0.0.1:4173/xy107/' },
  webServer: {
    command: 'npm run preview -- --port 4173',
    url: 'http://127.0.0.1:4173/xy107/',
    reuseExistingServer: false,
  },
})
