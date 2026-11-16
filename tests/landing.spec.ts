import { expect, test, type Page } from '@playwright/test'

const collectErrors = (page: Page) => {
  const errors: string[] = []
  page.on('pageerror', e => errors.push(e.message))
  page.on('console', m => {
    if (m.type() === 'error') errors.push(m.text())
  })
  return errors
}

test('empty config hides contact', async ({ page }) => {
  await page.goto('/index.html')
  await expect(page.locator('a[href=""], a[href="tel:"], a[href="mailto:"]')).toHaveCount(0)
  for (const key of ['zalo', 'phone', 'email', 'terms', 'privacy']) {
    for (const el of await page.locator(`[data-site="${key}"]`).all()) await expect(el).toBeHidden()
  }
  const android = page.locator('[data-store="android"]').first()
  await expect(android).toHaveAttribute('aria-disabled', 'true')
  await expect(android).toContainText('Sắp có')
})

test('config fills contact', async ({ page }) => {
  await page.addInitScript(() => {
    ;(window as any).SITE_OVERRIDE = {
      phone: '0900000000',
      zaloUrl: 'https://zalo.me/0900000000',
      androidUrl: 'https://play.google.com/store/apps/details?id=x'
    }
  })
  await page.goto('/index.html')
  await expect(page.locator('[data-site="phone"]').first()).toHaveAttribute('href', 'tel:0900000000')
  await expect(page.locator('[data-site="zalo"]').first()).toHaveAttribute('href', 'https://zalo.me/0900000000')
  await expect(page.locator('[data-site="zalo"]').first()).toBeVisible()
  const android = page.locator('[data-store="android"]').first()
  await expect(android).toHaveAttribute('href', /play\.google\.com/)
  await expect(android).not.toHaveAttribute('aria-disabled', 'true')
})

test('i18n parity', async ({ page }) => {
  await page.goto('/index.html')
  const { vi, en, used } = await page.evaluate(() => {
    const dict = (window as any).I18N
    return {
      vi: Object.keys(dict.vi).sort(),
      en: Object.keys(dict.en).sort(),
      used: [...document.querySelectorAll('[data-i18n]')].map(e => e.getAttribute('data-i18n'))
    }
  })
  expect(en).toEqual(vi)
  expect(used.filter(k => !vi.includes(k!))).toEqual([])
  const h1vi = await page.locator('h1').innerText()
  await page.locator('[data-lang="en"]').first().click()
  await expect(page.locator('html')).toHaveAttribute('lang', 'en')
  expect(await page.locator('h1').innerText()).not.toEqual(h1vi)
})

for (const [w, h] of [
  [360, 740],
  [1440, 900]
]) {
  for (const scheme of ['light', 'dark'] as const) {
    test(`no horizontal scroll ${w}px ${scheme}`, async ({ page }) => {
      await page.emulateMedia({ colorScheme: scheme })
      await page.setViewportSize({ width: w, height: h })
      await page.goto('/index.html')
      const { sw, cw } = await page.evaluate(() => ({
        sw: document.documentElement.scrollWidth,
        cw: document.documentElement.clientWidth
      }))
      expect(sw).toBeLessThanOrEqual(cw)
    })
  }
}

test('storage blocked', async ({ page }) => {
  const errors = collectErrors(page)
  await page.addInitScript(() => {
    Object.defineProperty(window, 'localStorage', {
      get() {
        throw new Error('blocked')
      }
    })
  })
  await page.goto('/index.html')
  await expect(page.locator('h1')).toBeVisible()
  await expect(page.locator('html')).toHaveAttribute('lang', 'vi')
  await page.locator('[data-lang="en"]').first().click()
  await expect(page.locator('html')).toHaveAttribute('lang', 'en')
  expect(errors).toEqual([])
})

test('pricing values', async ({ page }) => {
  await page.goto('/index.html')
  const pricing = page.locator('#pricing')
  for (const text of ['0đ', '149.000đ', '249.000đ', '49.000đ']) await expect(pricing).toContainText(text)
  const staff = await pricing.locator('[data-staff]').allInnerTexts()
  expect(staff.map(s => s.match(/\d+/)?.[0])).toEqual(['2', '5', '15'])
  await expect(pricing).toContainText('14 ngày')
})

test('no forbidden claims', async ({ page }) => {
  await page.goto('/index.html')
  const texts = await page.evaluate(() => {
    const d = (window as any).I18N
    return [document.body.innerText, JSON.stringify(d.vi), JSON.stringify(d.en)].join('\n')
  })
  expect(texts).not.toMatch(/hoá đơn điện tử|hóa đơn điện tử|e-invoice|google sheets|gemini|kiotviet|trợ lý ai|ai assistant/i)
})

test('three apps in order', async ({ page }) => {
  await page.goto('/index.html')
  const cards = page.locator('#apps [data-app]')
  expect(await cards.evaluateAll(els => els.map(e => e.getAttribute('data-app')))).toEqual(['pos', 'manager', 'admin'])
})
