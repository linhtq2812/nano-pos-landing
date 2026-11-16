import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: '.',
  testMatch: /.*\.spec\.ts/,
  workers: 2,
  reporter: 'line',
  use: { baseURL: 'http://127.0.0.1:4173' },
  webServer: {
    command: 'bash tests/serve.sh',
    cwd: '..',
    url: 'http://127.0.0.1:4173/index.html',
    reuseExistingServer: true,
    stdout: 'ignore',
    stderr: 'ignore'
  }
})
