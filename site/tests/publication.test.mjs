// Pair-programmed by SE Community + Cortex Code
import assert from 'node:assert/strict';
import {test} from 'node:test';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {badgeText, discover, publicationFiles, route, site} from '../build.mjs';

test('static badges preserve labels, values, and escaped separators locally', () => {
  assert.equal(badgeText('https://img.shields.io/badge/Expires-2027--03--10-orange', 'Expires'), 'Expires: 2027-03-10');
  assert.equal(badgeText('https://img.shields.io/badge/Deploy-None-lightgrey', 'No Deploy'), 'Deploy: None');
  assert.equal(badgeText('https://img.shields.io/badge/Status-In_Review-blue.svg', 'Status'), 'Status: In Review');
  assert.equal(badgeText('https://img.shields.io/badge/Key-a__b-blue', 'Key'), 'Key: a_b');
  assert.equal(badgeText('https://example.com/image.svg', 'Architecture'), 'Architecture');
  assert.equal(badgeText('https://img.shields.io/badge/%ZZ', 'Status'), 'Status');
});

test('publication includes reader files and excludes development files', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'sfe-publication-'));
  try {
    for (const file of ['guide-fixture/README.md', 'guide-fixture/AGENTS.md', 'guide-fixture/.claude/SKILL.md', 'guide-fixture/docs/guide.md', 'guide-fixture/tests/test.md', 'guide-fixture/sql/example.sql', 'guide-fixture/app/package.json']) {
      fs.mkdirSync(path.dirname(path.join(root, file)), {recursive: true});
      fs.writeFileSync(path.join(root, file), 'Fixture');
    }
    assert.deepEqual(discover(root), ['guide-fixture']);
    const files = publicationFiles(root);
    assert(files.includes('guide-fixture/docs/guide.md'));
    assert(files.includes('guide-fixture/sql/example.sql'));
    assert(!files.some(file => /AGENTS|SKILL|test|package/.test(file)));
  } finally { fs.rmSync(root, {recursive: true, force: true}); }
});

test('stable routes distinguish rendered guides from raw downloads', () => {
  assert.equal(route('README.md'), '/');
  assert.equal(route('guide-fixture/README.md'), '/guide-fixture/');
  assert.equal(route('guide-fixture/docs/usage.md'), '/guide-fixture/docs/usage.html');
  assert.equal(route('guide-fixture/sql/example.sql'), '/guide-fixture/sql/example.sql');
});

test('CoWork action menu exists and is explicitly published', () => {
  const companion = 'guide-cowork-easter-eggs/WHAT-CAN-I-DO-NOW.md';
  assert(fs.existsSync(path.join(site, '..', companion)));
  assert(publicationFiles().includes(companion));
  assert.equal(route(companion), '/guide-cowork-easter-eggs/WHAT-CAN-I-DO-NOW.html');
});

test('real publication boundary excludes hidden and agent files', () => {
  const files = publicationFiles();
  assert(files.includes('guide-ai-spend-consolidation/workbook.html'));
  assert(!files.some(file => /(^|\/)(\.|tests\/|AGENTS.md|CLAUDE.md|SKILL.md)/.test(file)));
  assert(discover().length > 0);
});

test('client guides use host-specific defaults and preserve the VS Code direct path', () => {
  const root = path.join(site, '..');
  const expected = [
    ['guide-claude-code-coco', '## Recommended: AI Kit Plugin', '## Alternative: Native MCP'],
    ['guide-codex-coco', '## Recommended: Native MCP', '## Alternative: AI Kit Routing'],
  ];
  for (const [project, recommended, alternative] of expected) {
    const markdown = fs.readFileSync(path.join(root, project, 'README.md'), 'utf8');
    assert(markdown.indexOf(recommended) > 0);
    assert(markdown.indexOf(alternative) > markdown.indexOf(recommended));
    assert.match(markdown, /marketplace\.visualstudio\.com\/items\?itemName=snowflake\.snowflake-vsc/);
    assert.match(markdown, /not automatic delegation/);
    assert.match(markdown, /\*\*Last verified:\*\* 2026-10-08/);
    assert.match(markdown, /\*\*Expires:\*\* 2026-12-07/);
    assert(fs.existsSync(path.join(root, project, 'ELI5.md')));
  }
  const codex = fs.readFileSync(path.join(root, 'guide-codex-coco/README.md'), 'utf8');
  assert(codex.indexOf('--dangerously-allow-all-tool-calls') < codex.indexOf('codex plugin marketplace add'));
  const retired = JSON.parse(fs.readFileSync(path.join(site, 'retired.json'), 'utf8')).projects;
  assert.deepEqual(retired['guide-external-harness-coco'].successors, expected.map(entry => entry[0]));
  assert.equal(retired['guide-external-harness-coco'].routes.length, 5);
  assert(!discover().includes('guide-external-harness-coco'));
});

test('Desktop guide uses local config and publishes only its reader helper', () => {
  const root = path.join(site, '..');
  const guide = fs.readFileSync(path.join(root, 'guide-claude-desktop-coco/README.md'), 'utf8');
  assert.match(guide, /Developer > Edit Config/);
  assert.match(guide, /claude_desktop_config\.json/);
  assert.match(guide, /Merge only the generated/);
  assert.match(guide, /bypass=false and disallowed_tools/);
  assert.match(guide, /not approving each inner CoCo action/);
  assert.match(guide, /marketplace\.visualstudio\.com\/items\?itemName=snowflake\.snowflake-vsc/);
  assert(publicationFiles().includes('guide-claude-desktop-coco/tools/generate_config.py'));
  assert(!publicationFiles().includes('guide-claude-desktop-coco/tests/test_generate_config.py'));
});

test('Pages publication is gated and handles archive completion explicitly', () => {
  const workflow = fs.readFileSync(path.join(site, '../.github/workflows/pages.yml'), 'utf8');
  assert.match(workflow, /workflow_run:/);
  assert.match(workflow, /Auto-Archive Expired Projects/);
  assert.match(workflow, /PAGES_PILOT_ENABLED == 'true'/);
  assert.match(workflow, /github\.event_name != 'pull_request'/);
  assert.match(workflow, /persist-credentials: false/);
  assert.match(workflow, /needs: build/);
});
