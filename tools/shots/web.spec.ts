import { test } from '@playwright/test'

const out = process.env.SHOTS_RAW ?? 'raw'
const email = process.env.DEMO_EMAIL ?? 'demo-owner@nanopos.local'
const password = process.env.DEMO_PASSWORD ?? 'demo-landing-2026'

const pages: [string, string][] = [
  ['admin-dashboard', '/vi/dashboard'],
  ['admin-pnl', '/vi/finance/pnl'],
  ['admin-inventory', '/vi/inventory/stock'],
  ['admin-cashbook', '/vi/finance/expenses']
]

test('nano admin shots', async ({ page }) => {
  await page.goto('/vi/login')
  await page.getByLabel('Email').fill(email)
  await page.getByRole('textbox', { name: 'Mật khẩu' }).fill(password)
  await page.getByRole('button', { name: 'Đăng nhập' }).click()
  await page.waitForURL(/\/vi\/(dashboard|$)/, { timeout: 120_000 })
  for (const [name, path] of pages) {
    await page.goto(path)
    await page.waitForLoadState('networkidle', { timeout: 120_000 })
    // Hide dev-only chrome (Next.js dev tools badge, theme customizer toggle).
    await page.addStyleTag({ content: 'nextjs-portal, [class*="toggler"] { display: none !important; }' })
    if (name === 'admin-dashboard') {
      // "Today" compares a half day with a full one; a week reads better.
      await page.getByRole('tab', { name: '7 ngày' }).click()
      await page.waitForLoadState('networkidle', { timeout: 60_000 })
    }
    await page.waitForTimeout(2500)
    await page.screenshot({ path: `${out}/${name}.png` })
  }
})
