// Pair-programmed by SE Community + Cortex Code
import fs from 'node:fs';
import path from 'node:path';
import {load} from 'cheerio';
import {site, config, discover, publicationFiles, route} from './build.mjs';
const directory = path.join(site, '.build/public');
const files = [...fs.globSync('**/*', {cwd: directory})].filter(file => fs.statSync(path.join(directory, file)).isFile());
const documents = new Map(files.filter(file => file.endsWith('.html')).map(file => [file, load(fs.readFileSync(path.join(directory, file), 'utf8'))]));
const errors = [];
const inherited = [];
for (const file of files) {
  if (file.split('/').some(segment => segment.startsWith('.') || ['AGENTS.md', 'CLAUDE.md', 'SKILL.md', 'node_modules', 'tests', 'Gemfile'].includes(segment))) errors.push(`Unexpected publication: ${file}`);
}
for (const [file, document] of documents) {
  if (file.endsWith('workbook.html')) continue;
  document('a[href],img[src],script[src],link[href]').each((_, element) => {
    const href = document(element).attr('href') || document(element).attr('src');
    if (!href || /^(https?:|mailto:|tel:|data:)/.test(href) || href.startsWith('//')) {
      if (element.tagName !== 'a' && /^(https?:|\/\/)/.test(href || '') && document(element).attr('rel') !== 'canonical') errors.push(`${file}: external runtime asset ${href}`);
      return;
    }
    const resolved = new URL(href, `https://reader.invalid${config.baseurl}/${file}`);
    if (!resolved.pathname.startsWith(config.baseurl + '/')) { errors.push(`${file}: wrong base path ${href}`); return; }
    let target = decodeURIComponent(resolved.pathname.slice(config.baseurl.length + 1));
    if (!target || target.endsWith('/')) target += 'index.html';
    if (!files.includes(target)) { errors.push(`${file}: missing ${href}`); return; }
    if (resolved.hash && documents.has(target)) {
      const id = decodeURIComponent(resolved.hash.slice(1));
      if (!documents.get(target)('[id]').toArray().some(node => node.attribs.id === id)) {
        const message = `${file}: missing heading ${href}`;
        if (config.pilot.some(project => file.startsWith(project + '/')) || file === 'index.html') errors.push(message);
        else inherited.push(message);
      }
    }
  });
}
for (const project of discover()) {
  for (const suffix of ['index.html', 'README.html', 'README.md']) if (!files.includes(`${project}/${suffix}`)) errors.push(`Missing preserved route: ${project}/${suffix}`);
}
if (discover().includes('guide-ai-spend-consolidation')) {
  const sourceWorkbook = fs.readFileSync(path.join(site, '../guide-ai-spend-consolidation/workbook.html'));
  if (!sourceWorkbook.equals(fs.readFileSync(path.join(directory, 'guide-ai-spend-consolidation/workbook.html')))) errors.push('Workbook was modified during publication');
}
const universal = documents.get('guide-universal-data-sharing/index.html');
if (discover().includes('guide-universal-data-sharing') && universal('.reader-diagram svg').length < 3) errors.push('Universal sharing diagrams not rendered');
const spend = documents.get('guide-ai-spend-consolidation/index.html');
if (discover().includes('guide-ai-spend-consolidation') && (!spend('.markdown-alert').length || !spend('details table').length)) errors.push('AI spend alerts or collapsed Markdown missing');
const search = JSON.parse(documents.get('index.html')('#reader-index').text());
if (search.filter(entry => entry.kind === 'project').length !== discover().length) errors.push('Search catalog coverage incomplete');
for (const file of publicationFiles().filter(file => file.endsWith('.md') && discover().includes(file.split('/')[0]))) {
  if (!search.some(entry => entry.url === config.baseurl + route(file))) errors.push(`Full-text search missing document: ${file}`);
}
for (const entry of search) {
  const url = new URL(entry.url, 'https://reader.invalid');
  let target = url.pathname.slice(config.baseurl.length + 1);
  if (target.endsWith('/')) target += 'index.html';
  const document = documents.get(target);
  if (!document || (url.hash && !document('[id]').toArray().some(element => element.attribs.id === decodeURIComponent(url.hash.slice(1))))) errors.push(`Invalid search result: ${entry.url}`);
}
for (const [file, document] of documents) {
  if (!document('#reader-index').length) continue;
  const navigation = document('.site-nav a').toArray().map(element => document(element).attr('href'));
  for (const project of discover()) {
    if (navigation.filter(href => href === `${config.baseurl}/${project}/`).length !== 1) errors.push(`${file}: navigation must include ${project} exactly once`);
  }
}
for (const message of inherited) console.warn(`Inherited non-pilot link: ${message}`);
if (errors.length) { console.error(errors.join('\n')); process.exitCode = 1; }
else console.log(`Validated ${files.length} published files, ${documents.size} HTML routes, ${search.length} search entries. ${inherited.length} inherited non-pilot anchor warnings.`);
