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
  // The counter app cannot add staff on its own (only web/Manager can), so never claim it needs no web.
  expect(texts).not.toMatch(/không cần web|without the web/i)
})

test('three apps in order', async ({ page }) => {
  await page.goto('/index.html')
  const cards = page.locator('#apps [data-app]')
  expect(await cards.evaluateAll(els => els.map(e => e.getAttribute('data-app')))).toEqual(['pos', 'manager', 'admin'])
})

test('images resolve', async ({ page }) => {
  await page.goto('/index.html')
  // Lazy images only load near the viewport; walk the page so every one is requested.
  await page.evaluate(async () => {
    for (let y = 0; y < document.body.scrollHeight; y += 600) {
      window.scrollTo(0, y)
      await new Promise(r => setTimeout(r, 30))
    }
  })
  // Tab panels are hidden; force their images to load too.
  await page.evaluate(() => document.querySelectorAll('img[loading="lazy"]').forEach(i => i.setAttribute('loading', 'eager')))
  const imgs = await page.evaluate(async () => {
    const all = [...document.querySelectorAll('img')] as HTMLImageElement[]
    await Promise.all(all.map(i => (i.complete ? null : new Promise(r => { i.onload = i.onerror = r }))))
    return all.map(i => ({ src: i.getAttribute('src'), alt: i.getAttribute('alt'), ok: i.naturalWidth > 0, shot: i.dataset.shot ?? null }))
  })
  expect(imgs.filter(i => !i.src)).toEqual([])
  expect(imgs.filter(i => !i.ok)).toEqual([])
  expect(imgs.filter(i => i.shot && !i.alt)).toEqual([])
})

test('og meta', async ({ page }) => {
  await page.goto('/index.html')
  for (const sel of ['meta[property="og:image"]', 'meta[property="og:title"]', 'meta[property="og:description"]', 'meta[name="twitter:card"]']) {
    await expect(page.locator(sel)).toHaveCount(1)
  }
  await expect(page.locator('meta[property="og:image"]')).toHaveAttribute('content', /assets\/og\.png$/)
  await expect(page.locator('link[rel="icon"]')).toHaveCount(1)
  const res = await page.request.get('/assets/og.png')
  expect(res.ok()).toBe(true)
})

test('english page has no vietnamese left', async ({ page }) => {
  await page.goto('/index.html')
  await page.locator('[data-lang="en"]').first().click()
  const leftovers = await page.evaluate(() => {
    // Vietnamese-only letters; the currency sign "đ" alone is allowed.
    const vi = /[ăâêôơưàáảãạằắẳẵặầấẩẫậèéẻẽẹềếểễệìíỉĩịòóỏõọồốổỗộờớởỡợùúủũụừứửữựỳýỷỹỵ]|đ(?=[a-z])/i
    const out: string[] = []
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT)
    for (let n = walker.nextNode(); n; n = walker.nextNode()) {
      const el = n.parentElement!
      if (el.closest('[hidden], script, style, .lang')) continue
      const t = n.textContent!.trim()
      if (t && vi.test(t)) out.push(t)
    }
    document.querySelectorAll('[aria-label], img[alt]').forEach(el => {
      const v = el.getAttribute('aria-label') ?? el.getAttribute('alt') ?? ''
      if (vi.test(v)) out.push(v)
    })
    return out
  })
  expect(leftovers).toEqual([])
})

test('faq answers where data lives', async ({ page }) => {
  await page.goto('/index.html')
  await expect(page.locator('#faq')).toContainText('Dữ liệu')
  await expect(page.locator('#faq details')).toHaveCount(7)
})

test('tabs follow the aria tab pattern', async ({ page }) => {
  await page.goto('/index.html')
  const list = page.locator('#admin [role="tablist"]')
  const tabs = list.locator('[role="tab"]')
  await expect(tabs.nth(0)).toHaveAttribute('tabindex', '0')
  await expect(tabs.nth(1)).toHaveAttribute('tabindex', '-1')
  for (const panel of await page.locator('#admin [role="tabpanel"]').all()) {
    const by = await panel.getAttribute('aria-labelledby')
    expect(by).toBeTruthy()
    await expect(page.locator(`#${by}`)).toHaveAttribute('role', 'tab')
  }
  await tabs.nth(0).focus()
  await page.keyboard.press('ArrowRight')
  await expect(tabs.nth(1)).toBeFocused()
  await expect(tabs.nth(1)).toHaveAttribute('aria-selected', 'true')
  await page.keyboard.press('End')
  await expect(tabs.last()).toBeFocused()
  await page.keyboard.press('ArrowRight')
  await expect(tabs.first()).toBeFocused()
})

test('empty legal nav is hidden', async ({ page }) => {
  await page.goto('/index.html')
  await expect(page.locator('.site-footer nav')).toHaveAttribute('hidden', '')
})

test('mobile has an in-page nav', async ({ page }) => {
  await page.setViewportSize({ width: 360, height: 740 })
  await page.goto('/index.html')
  const link = page.locator('.mobile-nav a[href="#pricing"]')
  await expect(link).toBeVisible()
  const { sw, cw } = await page.evaluate(() => ({ sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth }))
  expect(sw).toBeLessThanOrEqual(cw)
})

test('english prices use english number format', async ({ page }) => {
  await page.goto('/index.html')
  await page.locator('[data-lang="en"]').first().click()
  const pricing = page.locator('#pricing')
  for (const text of ['149,000đ', '249,000đ', '49,000đ']) await expect(pricing).toContainText(text)
  await expect(pricing).not.toContainText('149.000đ')
  await expect(page.locator('[data-store="ios"]').first()).toContainText('the App Store')
})

test('paid tag text meets AA contrast', async ({ page }) => {
  await page.goto('/index.html')
  const ratio = await page.locator('.tag.paid').first().evaluate(el => {
    const rgb = (c: string) => (c.match(/[\d.]+/g) ?? []).slice(0, 4).map(Number)
    const lum = ([r, g, b]: number[]) => {
      const f = (v: number) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4 }
      return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)
    }
    const fg = rgb(getComputedStyle(el).color)
    const [r, g, b, a = 1] = rgb(getComputedStyle(el).backgroundColor)
    const bg = [r, g, b].map(v => v * a + 255 * (1 - a)) // tag sits on a white card
    const [l1, l2] = [lum(fg), lum(bg)].sort((x, y) => y - x)
    return (l1 + 0.05) / (l2 + 0.05)
  })
  expect(ratio).toBeGreaterThanOrEqual(4.5)
})

test('hero reuses section shots', async ({ page }) => {
  await page.goto('/index.html')
  await expect(page.locator('.hero img[src$="admin-dashboard.webp"]')).toHaveCount(1)
  await expect(page.locator('.hero img[src$="pos-sale.webp"]')).toHaveCount(1)
})
