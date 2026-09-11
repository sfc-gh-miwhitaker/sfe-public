// Pair-programmed by SE Community + Cortex Code
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const directory = path.join(path.dirname(fileURLToPath(import.meta.url)), '.build/public');
const types = {'.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript', '.json': 'application/json', '.svg': 'image/svg+xml', '.md': 'text/plain', '.sql': 'text/plain'};
http.createServer((request, response) => {
  let pathname;
  try { pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname); }
  catch { response.writeHead(400).end(); return; }
  if (pathname === '/') { response.writeHead(302, {Location: '/sfe-public/'}).end(); return; }
  if (!pathname.startsWith('/sfe-public/')) { response.writeHead(404).end(); return; }
  const filename = path.resolve(directory, pathname.slice('/sfe-public/'.length) || 'index.html');
  if (!filename.startsWith(directory + path.sep)) { response.writeHead(403).end(); return; }
  const target = fs.existsSync(filename) && fs.statSync(filename).isDirectory() ? path.join(filename, 'index.html') : filename;
  if (!fs.existsSync(target)) { response.writeHead(404).end('Not found'); return; }
  response.writeHead(200, {'Content-Type': `${types[path.extname(target)] || 'text/plain'}; charset=utf-8`});
  fs.createReadStream(target).pipe(response);
}).listen(Number(process.env.PORT || 4173), '127.0.0.1', () => console.log('Preview: http://127.0.0.1:4173/sfe-public/'));
