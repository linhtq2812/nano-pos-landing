// Screenshots of Nano Admin against LOCAL Supabase with the demo shop (tools/demo/seed.sh).
// Run: bash tools/shots/web.sh   (starts nano-pos-web dev on :3100 with local env)
import { defineConfig } from '@playwright/test'

const anon = process.env.LOCAL_ANON_KEY ?? ''

export default defineConfig({
  testDir: '.',
  testMatch: /web\.spec\.ts/,
  workers: 1,
  timeout: 180_000,
  reporter: 'line',
  use: { baseURL: 'http://127.0.0.1:3100', viewport: { width: 1440, height: 900 }, colorScheme: 'light', locale: 'vi-VN', timezoneId: 'Asia/Ho_Chi_Minh' },
  webServer: {
    command: 'pnpm exec next dev -p 3100 -H 127.0.0.1',
    cwd: process.env.NANO_POS_WEB ?? '../../../nano-pos-web',
    url: 'http://127.0.0.1:3100/vi/login',
    timeout: 420_000,
    reuseExistingServer: false,
    stdout: 'ignore',
    stderr: 'pipe',
    env: { NEXT_PUBLIC_SUPABASE_URL: 'http://127.0.0.1:54321', NEXT_PUBLIC_SUPABASE_ANON_KEY: anon }
  }
})
