// Render a local HTML/SVG file to PNG with nano-pos-web's Playwright Chromium.
// Usage: node tools/shots/render.mjs <file> <out.png> <width> <height>
import { pathToFileURL } from 'node:url'
import path from 'node:path'
const web = process.env.NANO_POS_WEB ?? path.resolve(import.meta.dirname, '../../../nano-pos-web')
const { chromium } = await import(pathToFileURL(path.join(web, 'node_modules/playwright/index.mjs')).href)
const [, , file, out, w, h] = process.argv
const browser = await chromium.launch()
const page = await browser.newPage({ viewport: { width: +w, height: +h } })
await page.goto(pathToFileURL(path.resolve(file)).href)
await page.waitForLoadState('networkidle')
await page.waitForTimeout(300)
await page.screenshot({ path: out })
await browser.close()
