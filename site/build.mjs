// Pair-programmed by SE Community + Cortex Code
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {Marked} from 'marked';
import {load} from 'cheerio';
import GithubSlugger from 'github-slugger';
import {chromium} from 'playwright-core';
import sanitizeHtml from 'sanitize-html';
import {execFileSync} from 'node:child_process';

export const site = path.dirname(fileURLToPath(import.meta.url));
export const root = path.dirname(site);
export const config = JSON.parse(fs.readFileSync(path.join(site, 'publication.json'), 'utf8'));
const sourceUrl = 'https://github.com/sfc-gh-miwhitaker/sfe-public/blob/main/';
const build = path.join(site, '.build');
const staging = path.join(build, 'source');

export function discover(repository = root) {
  return fs.readdirSync(repository, {withFileTypes: true})
    .filter(entry => entry.isDirectory() && /^(guide|demo)-[a-z0-9-]+$/.test(entry.name)
      && fs.existsSync(path.join(repository, entry.name, 'README.md')))
    .map(entry => entry.name).sort();
}

export function publicationFiles(repository = root) {
  const files = new Set(['README.md', 'CONTRIBUTING.md', 'LICENSE']);
  const tracked = repository === root ? new Set(execFileSync('git', ['-C', root, 'ls-files', '-z'], {encoding: 'utf8'}).split('\0')) : null;
  for (const project of discover(repository)) {
    for (const pattern of config.readerPatterns) {
      for (const relative of fs.globSync(`${project}/${pattern}`, {cwd: repository})) {
        const segments = relative.split(path.sep);
        if (tracked && !tracked.has(relative)) continue;
        if (segments.some(segment => segment.startsWith('.') || config.excludedNames.includes(segment))) continue;
        const absolute = path.join(repository, relative);
        if (fs.lstatSync(absolute).isSymbolicLink() || !fs.statSync(absolute).isFile()) continue;
        if (!fs.realpathSync(absolute).startsWith(fs.realpathSync(repository) + path.sep)) throw new Error(`File escapes repository: ${relative}`);
        files.add(relative);
      }
    }
  }
  for (const file of config.extraFiles) {
    if (fs.existsSync(path.join(repository, file))) {
      if (fs.lstatSync(path.join(repository, file)).isSymbolicLink()) throw new Error(`Symlink forbidden: ${file}`);
      files.add(file);
    }
  }
  return [...files].sort();
}

export function route(file) {
  if (file === 'README.md') return '/';
  if (file.endsWith('/README.md')) return `/${file.slice(0, -9)}`;
  return `/${file.replace(/\.md$/, '.html')}`;
}

export function badgeText(source, fallback) {
  try {
    const url = new URL(source);
    if (url.hostname === 'img.shields.io' && url.pathname.startsWith('/badge/')) {
      const parts = decodeURIComponent(url.pathname.slice(7)).replace(/\.svg$/, '')
        .match(/(?:--|__|[^-])+/g)?.map(part => part.replaceAll('--', '-').replaceAll('__', '\u0000').replaceAll('_', ' ').replaceAll('\u0000', '_'));
      if (parts?.length === 3) return `${parts[0]}: ${parts[1]}`;
    }
  } catch {}
  return fallback || 'Image available in source';
}

function write(relative, text) {
  const destination = path.join(staging, relative);
  fs.mkdirSync(path.dirname(destination), {recursive: true});
  fs.writeFileSync(destination, text);
}

function page(relative, title, content, metadata = {}) {
  const frontmatter = Object.entries({layout: 'default', title, permalink: route(relative),
    source_path: relative, nav_exclude: true, has_toc: false, render_with_liquid: false, ...metadata})
    .map(([key, value]) => `${key}: ${JSON.stringify(value)}`).join('\n');
  const generated = createHash('sha256').update(relative).digest('hex');
  write(`pages/${generated}.html`, `---\n${frontmatter}\n---\n${content}`);
}

async function main() {
  fs.mkdirSync(build, {recursive: true});
  fs.rmSync(staging, {recursive: true, force: true});
  fs.mkdirSync(staging, {recursive: true});
  fs.cpSync(path.join(site, '_includes'), path.join(staging, '_includes'), {recursive: true});
  fs.copyFileSync(path.join(site, '_config.yml'), path.join(staging, '_config.yml'));
  const files = publicationFiles();
  const allowed = new Set(files);
  const projects = discover();
  const retired = JSON.parse(fs.readFileSync(path.join(site, 'retired.json'), 'utf8')).projects;
  const warnings = [];
  const search = [];
  const inventory = [];
  const catalog = new Map();
  const rootHtml = load(await new Marked().parse(fs.readFileSync(path.join(root, 'README.md'), 'utf8')));
  rootHtml('table tr').each((_, row) => {
    const cells = rootHtml(row).find('td');
    const link = cells.first().find('a').first();
    const project = (link.attr('href') || '').replace(/\/$/, '');
    if (projects.includes(project)) {
      const category = rootHtml(row).closest('table').prevAll('h3').first().text();
      if (!category) throw new Error(`Project missing a catalog category: ${project}`);
      catalog.set(project, {title: link.text(), summary: cells.eq(1).text(), topics: cells.eq(2).text(), category});
    }
  });
  for (const project of projects) if (!catalog.has(project)) throw new Error(`Project missing from README catalog: ${project}`);
  const categorySlugger = new GithubSlugger();
  for (const [index, category] of [...new Set([...catalog.values()].map(entry => entry.category))].entries()) {
    const categoryRoute = `catalog/${categorySlugger.slug(category)}/`;
    const links = [...catalog].filter(([, entry]) => entry.category === category)
      .map(([project, entry]) => `<li><a href="${config.baseurl}/${project}/">${escapeHtml(entry.title)}</a>: ${escapeHtml(entry.summary)}</li>`).join('');
    page(categoryRoute, category, `<h1>${escapeHtml(category)}</h1><ul>${links}</ul>`, {
      permalink: `/${categoryRoute}`, nav_exclude: false, nav_order: index + 2, has_children: true
    });
    inventory.push(categoryRoute);
  }

  const cache = path.join(site, '.cache/diagrams');
  fs.mkdirSync(cache, {recursive: true});
  let browser;
  let diagramPage;
  async function diagram(code) {
    const hash = createHash('sha256').update(`mermaid-11.17.0-strict-v2\n${code}`).digest('hex');
    const cached = path.join(cache, `${hash}.svg`);
    if (fs.existsSync(cached)) return fs.readFileSync(cached, 'utf8');
    if (!browser) {
      const executablePath = process.env.CHROME_PATH || (process.platform === 'darwin'
        ? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' : '/usr/bin/google-chrome');
      browser = await chromium.launch({executablePath, headless: true});
      diagramPage = await browser.newPage();
      await diagramPage.route('**/*', request => request.abort());
      await diagramPage.setContent('<!doctype html><html><body></body></html>');
      await diagramPage.addScriptTag({content: fs.readFileSync(path.join(site, 'node_modules/mermaid/dist/mermaid.min.js'), 'utf8')});
      await diagramPage.evaluate(() => mermaid.initialize({startOnLoad: false, securityLevel: 'strict', theme: 'default', flowchart: {htmlLabels: false}}));
    }
    const svg = await diagramPage.evaluate(async ({code, hash}) => (await mermaid.render(`diagram-${hash}`, code)).svg, {code, hash});
    fs.writeFileSync(cached, svg);
    return svg;
  }

  try {
    for (const file of files) {
      const absolute = path.join(root, file);
      if (!file.endsWith('.md')) {
        write(file, fs.readFileSync(absolute));
        inventory.push(file);
        continue;
      }
      const markdown = fs.readFileSync(absolute, 'utf8');
      const parser = new Marked({gfm: true});
      const document = load(sanitizeHtml(await parser.parse(markdown), {
        allowedTags: [...sanitizeHtml.defaults.allowedTags, 'details', 'summary', 'img'],
        allowedAttributes: {...sanitizeHtml.defaults.allowedAttributes, '*': ['id'], code: ['class'], img: ['src', 'alt', 'width', 'height']},
        allowedSchemes: ['http', 'https', 'mailto', 'tel'],
        allowProtocolRelative: false
      }));
      const project = file.split('/')[0];
      const pilot = config.pilot.includes(project);
      const title = document('h1').first().text() || path.basename(file, '.md');
      const slugger = new GithubSlugger();
      const headings = [];
      document('h1,h2,h3,h4,h5,h6').each((_, heading) => {
        const element = document(heading);
        const id = element.attr('id') || slugger.slug(element.text());
        element.attr('id', id);
        if (['h2', 'h3'].includes(heading.tagName)) headings.push({id, title: element.text()});
      });
      document('details').each((_, element) => {
        const details = document(element);
        const summary = details.find('summary').first();
        if (!summary.length) return;
        const body = details.html().slice(details.html().indexOf('</summary>') + 10);
        if (!/<(?:p|table|ul|ol|pre|div)[\s>]/i.test(body)) details.html(summary.toString() + parser.parse(body));
      });
      document('blockquote').each((_, element) => {
        const block = document(element);
        const first = block.find('p').first();
        const marker = first.text().match(/^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]/);
        if (marker) {
          block.addClass(`markdown-alert markdown-alert-${marker[1].toLowerCase()}`);
          first.html(first.html().replace(/^\[![A-Z]+\]/, `<strong>${marker[1]}</strong>`));
        }
      });
      for (const element of document('pre > code.language-mermaid').toArray()) {
        const code = document(element).text();
        try {
          const svg = await diagram(code);
          document(element).parent().replaceWith(`<div class="reader-diagram" role="img" aria-label="Architecture diagram">${svg}</div>`);
        } catch (error) {
          if (pilot) throw new Error(`${file}: Mermaid failed: ${error.message}`);
          warnings.push(`${file}: Mermaid left as source: ${error.message.split('\n')[0]}`);
        }
      }
      document('script,iframe,object,embed,base,form,link').remove();
      document('*').each((_, element) => {
        for (const attribute of Object.keys(element.attribs || {})) {
          if (/^on/i.test(attribute)) document(element).removeAttr(attribute);
        }
      });
      document('img').each((_, image) => {
        const element = document(image);
        if (/^https?:|^\/\//.test(element.attr('src') || '')) {
          element.replaceWith(document('<span class="source-badge"></span>').text(badgeText(element.attr('src'), element.attr('alt'))));
        }
      });
      document('a[href]').each((_, anchor) => {
        const element = document(anchor);
        const href = element.attr('href');
        if (/^(https?:|mailto:|tel:|#)/i.test(href)) return;
        if (/^[a-z][a-z0-9+.-]*:/i.test(href) || href.startsWith('//')) { element.removeAttr('href'); return; }
        const parsed = new URL(href, `https://reader.invalid/${file}`);
        const target = decodeURIComponent(parsed.pathname).replace(/^\//, '');
        const candidate = target.endsWith('/') ? `${target}README.md` : target;
        if (allowed.has(candidate)) {
          element.attr('href', config.baseurl + route(candidate) + parsed.hash);
        } else if (retired[candidate.split('/')[0]]) {
          element.attr('href', `${config.baseurl}/${candidate.split('/')[0]}/`);
        } else {
          element.attr('href', sourceUrl + target + parsed.hash);
          if (!fs.existsSync(path.join(root, target))) warnings.push(`${file}: existing source link not found: ${href}`);
        }
      });
      document('pre:has(code)').wrap('<div class="highlighter-rouge"><div class="highlight"></div></div>');
      const searchDocument = load(document('body').html());
      searchDocument('.reader-diagram').remove();
      const contentText = searchDocument('body').text().replace(/\s+/g, ' ').trim();
      const summary = catalog.get(project);
      if (summary && file === `${project}/README.md`) {
        search.push({title: summary.title, text: `${summary.summary} ${summary.topics} ${contentText}`, url: config.baseurl + route(file), scope: summary.category, kind: 'project'});
        if (pilot) {
          for (const heading of searchDocument('h2,h3').toArray()) {
            const element = searchDocument(heading);
            search.push({title: `${summary.title}: ${element.text()}`, text: element.nextUntil('h2,h3').text().replace(/\s+/g, ' ').trim(), url: config.baseurl + route(file) + '#' + element.attr('id'), scope: 'Guide section', kind: 'section'});
          }
        }
      } else if (summary) search.push({title: `${summary.title}: ${title}`, text: contentText, url: config.baseurl + route(file), scope: 'Supporting document', kind: 'document'});
      const toc = pilot ? `<details class="reader-toc"><summary>On this page</summary><ul>${headings.map(heading => `<li><a href="#${heading.id}">${escapeHtml(heading.title)}</a></li>`).join('')}</ul></details>` : '';
      const created = markdown.match(/\*\*Created:\*\*\s*(\d{4}-\d{2}-\d{2})/)?.[1];
      const expires = markdown.match(/\*\*Expires:\*\*\s*(\d{4}-\d{2}-\d{2})/)?.[1];
      const notice = pilot ? `<div class="reader-notice">Reader-layout pilot. ${created ? `Source created: ${created}. ` : ''}${expires ? `Review due: ${expires}. ` : ''}Technical verification dates remain those stated in the guide.</div>` : '';
      let body = document('body').html();
      page(file, file === 'README.md' ? 'Start here' : title, `${notice}${toc}<div class="reader-tools"><a href="${sourceUrl}${file}">View source</a><a href="${config.baseurl}/#projects">All projects</a></div>${body}`, {
        nav_exclude: !(summary && file === `${project}/README.md`) && file !== 'README.md',
        ...(file === 'README.md' ? {nav_order: 1} : {}),
        ...(summary && file === `${project}/README.md` ? {title: summary.title, parent: summary.category} : {})
      });
      write(file, markdown);
      inventory.push(file, route(file));
      if (file === 'README.md') {
        page('README.html', 'Start here', body, {permalink: '/README.html', source_path: file});
        inventory.push('README.html');
      }
      if (file.endsWith('/README.md')) {
        const alias = `${project}/README.html`;
        page(alias, title, `${notice}${toc}${body}`, {permalink: `/${alias}`, source_path: file});
        inventory.push(alias);
      }
    }
    for (const [project, entry] of Object.entries(retired)) {
      if (projects.includes(project)) continue;
      for (const retiredRoute of entry.routes) {
        if (!retiredRoute.startsWith(`/${project}/`) || retiredRoute.includes('..')) throw new Error(`Invalid retired route: ${retiredRoute}`);
        const output = retiredRoute.endsWith('/') ? `${retiredRoute}index.html` : retiredRoute;
        if (output.endsWith('.html')) page(output.slice(1), 'Guide retired', `<h1>Guide retired</h1><p>${escapeHtml(project)} was retired on ${escapeHtml(entry.date)}. It is no longer maintained.</p><p><a href="${config.baseurl}/#projects">Browse current guides</a></p>`, {permalink: retiredRoute});
        else write(output.slice(1), `Guide retired on ${entry.date}. Browse ${config.baseurl}/ for current guides.\n`);
      }
    }
    page('404.html', 'Page not found', `<h1>Page not found</h1><p>This link may refer to a moved or retired example.</p><p><a href="${config.baseurl}/">Browse current guides</a></p>`, {permalink: '/404.html'});
    write('_includes/search-index.json', JSON.stringify(search).replaceAll('<', '\\u003c'));
    fs.writeFileSync(path.join(build, 'inventory.json'), JSON.stringify({files, inventory, warnings}, null, 2));
    console.log(`Staged ${files.length} source files, ${projects.length} projects, ${search.length} search entries.`);
    for (const warning of warnings) console.warn(warning);
  } finally {
    await browser?.close();
  }
}

function escapeHtml(value) { return value.replace(/[&<>"']/g, character => ({'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[character])); }

if (process.argv[1] === fileURLToPath(import.meta.url)) await main();
