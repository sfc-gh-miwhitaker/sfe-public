// Pair-programmed by SE Community + Cortex Code
import assert from 'node:assert/strict';
import {chromium} from 'playwright-core';
import {discover} from '../build.mjs';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const base = process.env.SITE_URL || 'http://127.0.0.1:4173/sfe-public/';
const executablePath = process.env.CHROME_PATH || (process.platform === 'darwin' ? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' : '/usr/bin/google-chrome');
const browser = await chromium.launch({executablePath, headless: true});
const page = await browser.newPage();
const failures = [];
const external = [];
const active = discover();
const pilotRoutes = ['guide-cortex-agent-versioning', 'guide-universal-data-sharing', 'guide-ai-spend-consolidation'].filter(project => active.includes(project));
page.on('pageerror', error => { failures.push(error.message); console.error('Browser error:', error.message); });
page.on('response', response => { if (response.status() >= 400) failures.push(`${response.status()} ${response.url()}`); });
await page.route('**/*', request => {
  if (new URL(request.request().url()).origin !== new URL(base).origin) { external.push(request.request().url()); return request.abort(); }
  return request.continue();
});
try {
  await page.goto(base);
  await page.locator('#reader-query').fill(active.includes('guide-powerbi-oauth') ? 'Power BI' : active[0].replace(/^(guide|demo)-/, '').split('-')[0]);
  await page.locator('#reader-results a').first().waitFor();
  assert(await page.locator('#reader-results a').count() > 0);
  await page.locator('#reader-query').press('ArrowDown');
  assert.equal(await page.evaluate(() => document.activeElement.tagName), 'A');
  await page.keyboard.press('Escape');
  assert(await page.locator('#reader-results').isHidden(), 'Escape must dismiss results from a result link');
  assert(await page.locator('#reader-query').evaluate(element => element === document.activeElement));
  await page.locator('#reader-query').press('ArrowDown');
  assert(await page.locator('#reader-results').isVisible(), 'ArrowDown must reopen results');
  await page.keyboard.press('ArrowUp');
  assert(await page.locator('#reader-query').evaluate(element => element === document.activeElement));
  if (active.includes('guide-snowflake-firewall-allowlist')) {
    await page.locator('#reader-query').fill('OCSP');
    assert(await page.locator('#reader-results a[href$="/guide-snowflake-firewall-allowlist/"]').count(), 'Non-pilot full text must be searchable');
  }
  await page.locator('#reader-query').fill('no-such-result-xyz');
  assert.match(await page.locator('#reader-results').innerText(), /No matches/);
  await page.locator('#reader-query').press('Escape');
  assert(await page.locator('#reader-results').isHidden());
  for (const theme of ['light', 'dark']) {
    await page.emulateMedia({colorScheme: theme});
    for (const width of [360, 767, 768, 799, 800, 1088, 1440]) {
      await page.setViewportSize({width, height: 1000});
      for (const route of ['', ...pilotRoutes.map(project => project + '/')]) {
        await page.goto(base + route);
        assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), `${theme} ${width}px ${route} overflows`);
        assert(await page.locator('#reader-query').isVisible(), `${theme} ${width}px search hidden behind menu`);
        const header = await page.locator('#main-header').boundingBox();
        const input = await page.locator('#reader-query').boundingBox();
        assert(input.y >= header.y && input.y + input.height <= header.y + header.height, `${theme} ${width}px input escapes header`);
        const contrast = await page.evaluate(() => {
          const luminance = color => {
            const channels = color.match(/[\d.]+/g).slice(0, 3).map(Number).map(value => value / 255)
              .map(value => value <= .04045 ? value / 12.92 : ((value + .055) / 1.055) ** 2.4);
            return channels[0] * .2126 + channels[1] * .7152 + channels[2] * .0722;
          };
          const background = luminance(getComputedStyle(document.querySelector('#main-header')).backgroundColor);
          return ['.reader-search label', '.aux-nav a'].map(selector => {
            const foreground = luminance(getComputedStyle(document.querySelector(selector)).color);
            return (Math.max(background, foreground) + .05) / (Math.min(background, foreground) + .05);
          });
        });
        assert(contrast.every(value => value >= 4.5), `${theme} ${width}px header contrast below 4.5:1: ${contrast}`);
        assert(await page.locator('#main-header').evaluate(element => getComputedStyle(element).backgroundColor === getComputedStyle(document.body).backgroundColor), 'Header must follow the page theme');
        await page.locator('.aux-nav a').hover();
        assert(await page.locator('.aux-nav a').evaluate(element => getComputedStyle(element).backgroundColor !== 'rgb(255, 255, 255)'), 'Header hover must not introduce a white surface');
        if (width === 360) await page.locator('#menu-button').click();
        const navigation = await page.locator('.site-nav a').evaluateAll(elements => elements.map(element => element.getAttribute('href')));
        for (const project of active) {
          const href = new URL(base).pathname + project + '/';
          if (route === project + '/') {
            assert.equal(await page.locator('.site-nav a.nav-list-link.active:not([href])').count(), 1, 'Current project must remain in navigation');
            continue;
          }
          assert.equal(navigation.filter(value => value === href).length, 1, `Missing or duplicate menu project: ${project}`);
          if (width === 360 || width >= 800) assert(await page.locator(`.site-nav a[href="${href}"]`).isVisible(), `Project hidden in category: ${project}`);
        }
        if (width === 360) {
          await page.locator('#menu-button').click();
          assert(await page.locator('#reader-query').isVisible(), 'Closing mobile menu must not hide search');
        }
        await page.locator('#reader-query').fill('snowflake');
        assert(await page.locator('#reader-results').isVisible());
        const results = await page.locator('#reader-results').boundingBox();
        assert(results.x >= 0 && results.x + results.width <= width && results.y >= input.y + input.height, 'Search results overlap input or leave viewport');
        await page.locator('#reader-query').press('Escape');
      }
    }
  }
  await page.setViewportSize({width: 1440, height: 1000});
  const screenshots = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../.cache/screenshots');
  fs.mkdirSync(screenshots, {recursive: true});
  await page.emulateMedia({colorScheme: 'light'});
  await page.goto(base);
  await page.screenshot({path: path.join(screenshots, 'home.png')});
  if (active.includes('guide-universal-data-sharing')) {
    await page.goto(base + 'guide-universal-data-sharing/');
    assert(await page.locator('.reader-diagram svg').count() >= 3);
    await page.locator('.reader-diagram').first().screenshot({path: path.join(screenshots, 'diagram.png')});
  }
  if (active.includes('guide-cortex-agent-versioning')) {
  await page.goto(base + 'guide-cortex-agent-versioning/');
  await page.locator('#reader-query').fill('promote');
  assert.match(await page.locator('#reader-results').innerText(), /versioning/i);
  assert(await page.locator('#reader-results a[href*="#"]').count(), 'Pilot section-level search links must be preserved');
  const copy = page.getByRole('button', {name: 'Copy code to clipboard'}).first();
  assert(await copy.count(), 'Code copy control missing');
  await page.context().grantPermissions(['clipboard-read', 'clipboard-write']);
  await copy.click();
  assert((await page.evaluate(() => navigator.clipboard.readText())).trim().length > 10);
  }
  if (active.includes('guide-ai-spend-consolidation')) {
  await page.goto(base + 'guide-ai-spend-consolidation/');
  assert.match(await page.locator('.source-badge').allTextContents().then(values => values.join(' ')), /Expires: \d{4}-\d{2}-\d{2}.*Status: Active/);
  assert(await page.locator('.markdown-alert').count() > 0);
  await page.emulateMedia({media: 'print'});
  assert(await page.locator('.main-header').isHidden());
  await page.pdf({printBackground: true});
  await page.emulateMedia({media: 'screen'});
  await page.goto(base + 'guide-ai-spend-consolidation/workbook.html');
  assert.equal(await page.locator('h1').innerText(), 'Define success');
  await page.locator('#example').click();
  await page.locator('#confirm-ok').click();
  await page.locator('.step-link').last().click();
  assert.match(await page.locator('.brief').innerText(), /FICTIONAL EXAMPLE/);
  for (const route of ['guide-ai-spend-consolidation/README.md', 'guide-ai-spend-consolidation/sql/05_snowflake_native.sql']) {
    assert.equal((await page.request.get(base + route)).status(), 200);
  }
  }
  assert.deepEqual(external, [], 'Unexpected external requests');
  assert.deepEqual(failures, [], 'Browser errors');
  console.log('Browser checks passed: full catalog navigation, full-text search, keyboard dismissal, header containment/contrast, light/dark at seven widths, diagrams, code copy, print, workbook, old routes, no external requests.');
} finally { await browser.close(); }
