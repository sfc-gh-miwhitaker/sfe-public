// Pair-programmed by SE Community + Cortex Code
const assert = require('node:assert/strict');
const {spawn} = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const chromePath = process.env.CHROME_PATH || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const profile = fs.mkdtempSync(path.join(os.tmpdir(),'ai-workbook-browser-'));
const chrome = spawn(chromePath,['--headless=new','--no-first-run','--no-default-browser-check','--disable-background-networking','--disable-sync','--remote-debugging-port=0',`--user-data-dir=${profile}`,'about:blank'],{stdio:['ignore','ignore','pipe']});
let socket;
const errors = [], requests = [];
const delay = ms => new Promise(resolve => setTimeout(resolve,ms));
async function main() {
  const endpoint = await new Promise((resolve,reject) => {
    let output = '';
    const timeout = setTimeout(() => reject(new Error('Chrome did not start within 15 seconds')),15000);
    chrome.on('error',error => { clearTimeout(timeout); reject(error); });
    chrome.stderr.on('data',chunk => { output += chunk; const match = output.match(/DevTools listening on (ws:\/\/[^\s]+)/); if (match) { clearTimeout(timeout); resolve(match[1]); } });
  });
  socket = new WebSocket(endpoint);
  await new Promise(resolve => socket.addEventListener('open',resolve,{once:true}));
  let sequence = 0, sessionId;
  const pending = new Map();
  socket.addEventListener('message',event => {
    const response = JSON.parse(event.data);
    if (response.id) { const callback = pending.get(response.id); if (callback) { pending.delete(response.id); response.error ? callback.reject(new Error(response.error.message)) : callback.resolve(response.result); } }
    if (response.method === 'Runtime.exceptionThrown') errors.push(response.params.exceptionDetails.text + ': ' + response.params.exceptionDetails.exception?.description);
    if (response.method === 'Network.requestWillBeSent') requests.push(response.params.request.url);
  });
  function send(method,params = {},session = sessionId) { return new Promise((resolve,reject) => { const id = ++sequence; pending.set(id,{resolve,reject}); socket.send(JSON.stringify({id,method,params,...(session ? {sessionId:session} : {})})); }); }
  const {targetId} = await send('Target.createTarget',{url:'about:blank'});
  ({sessionId} = await send('Target.attachToTarget',{targetId,flatten:true}));
  await send('Runtime.enable'); await send('Page.enable'); await send('Network.enable');
  await send('Network.setBlockedURLs',{urls:['http://*','https://*']});
  const evaluate = async expression => {
    const result = await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true,userGesture:true});
    if (result.exceptionDetails) throw new Error(result.exceptionDetails.exception?.description || result.exceptionDetails.text);
    return result.result.value;
  };
  const click = selector => evaluate(`document.querySelector(${JSON.stringify(selector)}).click()`);
  const set = (selector,value) => evaluate(`(() => { const element = document.querySelector(${JSON.stringify(selector)}); element.value = ${JSON.stringify(value)}; element.dispatchEvent(new Event('input',{bubbles:true})); element.dispatchEvent(new Event('change',{bubbles:true})); })()`);
  const step = index => click(`.step-link:nth-child(${index+1})`);
  const load = async state => {
    await click('#load'); await set('#transfer-text',JSON.stringify(state)); await click('#transfer-import');
    assert.equal(await evaluate('document.getElementById("confirm-dialog").open'),true);
    await click('#confirm-ok');
  };
  await send('Page.navigate',{url:pathToFileURL(path.join(__dirname,'../workbook.html')).href});
  for (let attempt = 0; attempt < 100; attempt++) { if (await evaluate('Boolean(document.querySelector(".step-link"))')) break; await delay(50); }
  assert.equal(await evaluate('document.querySelector("h1").textContent'),'Define success');
  assert.equal(await evaluate('document.querySelectorAll("iframe").length'),0);
  await evaluate('document.getElementById("load").focus()');
  await send('Input.dispatchKeyEvent',{type:'keyDown',key:'Tab',code:'Tab',windowsVirtualKeyCode:9});
  await send('Input.dispatchKeyEvent',{type:'keyUp',key:'Tab',code:'Tab',windowsVirtualKeyCode:9});
  assert.equal(await evaluate('document.activeElement.id'),'save');
  await click('#goals-adoption'); await set('#field-global-title','My local pilot');
  await step(1); await click('#selected-SNOWFLAKE_CORTEX'); await set('#pilot','SNOWFLAKE_CORTEX');
  await set('#field-SNOWFLAKE_CORTEX-owner','Platform owner');
  await step(5); assert.match(await evaluate('document.querySelector(".brief").textContent'),/My local pilot/);
  await click('#save'); const draftText = await evaluate('document.getElementById("transfer-text").value');
  assert.equal(JSON.parse(draftText).answers.title,'My local pilot');
  await send('Browser.setDownloadBehavior',{behavior:'allow',downloadPath:profile},null);
  await click('#transfer-download');
  const savedPath = path.join(profile,'ai-spend-workbook.json');
  for (let attempt = 0; attempt < 100 && !fs.existsSync(savedPath); attempt++) await delay(50);
  assert.deepEqual(JSON.parse(fs.readFileSync(savedPath,'utf8')),JSON.parse(draftText));
  await click('#transfer-close');
  await click('#example'); await click('#confirm-cancel');
  assert.match(await evaluate('document.querySelector(".brief").textContent'),/My local pilot/);
  await click('#example'); await click('#confirm-ok'); assert.equal(await evaluate('document.getElementById("example-banner").hidden'),false);
  await step(5); assert.match(await evaluate('document.querySelector(".brief").textContent'),/FICTIONAL EXAMPLE/);
  await click('#export-brief'); assert.match(await evaluate('document.getElementById("transfer-text").value'),/M365|Microsoft 365/); await click('#transfer-close');
  await click('#load'); await set('#transfer-text','invalid JSON'); await click('#transfer-import');
  assert.match(await evaluate('document.getElementById("transfer-error").textContent'),/Invalid JSON/);
  await click('#transfer-close'); assert.equal(await evaluate('document.getElementById("example-banner").hidden'),false);
  await click('#load');
  const {root} = await send('DOM.getDocument');
  const {nodeId} = await send('DOM.querySelector',{nodeId:root.nodeId,selector:'#file-input'});
  await send('DOM.setFileInputFiles',{nodeId,files:[savedPath]});
  for (let attempt = 0; attempt < 100; attempt++) { if (await evaluate('document.getElementById("transfer-text").value.includes("schemaVersion")')) break; await delay(25); }
  await click('#transfer-import'); await click('#confirm-ok');
  assert.equal(await evaluate('document.getElementById("example-banner").hidden'),true);
  assert.match(await evaluate('document.querySelector(".brief").textContent'),/My local pilot/);
  await click('#reset'); await click('#confirm-cancel'); assert.match(await evaluate('document.querySelector(".brief").textContent'),/My local pilot/);
  await click('#reset'); await click('#confirm-ok'); assert.equal(await evaluate('document.getElementById("field-global-title").value'),'');
  const complete = await evaluate(`(() => {
    const state = Workbook.blank(); state.selected = ['SNOWFLAKE_CORTEX']; state.pilot = 'SNOWFLAKE_CORTEX'; state.goals = ['forecast','adoption'];
    Object.assign(state.answers,{title:'Qualified planning example',purpose:'Review costs by platform',audience:'finance',rationale:'native',route:'build',owner:'Platform team',grain:'aggregate',privacy:'approved',directory:'HR directory',mapping:'Approved mapping; unresolved retained',retention:'Approved 90-day retention and pruning owner',performance:'excluded',transform:'native',acceptance:'Agreed reviewer, tolerance, freshness, and coverage'});
    Object.assign(state.platforms.SNOWFLAKE_CORTEX,{owner:'Platform team',access:'confirmed',contract:'meter',context:'yes',money:'native',currency:'USD',rateSource:'Finance contract source',identity:'mapped',cadence:'24',historyDays:'90',revisionDays:'2',historyPlan:'Verified source availability and recovery',sourceVerified:'yes'});
    return state;
  })()`);
  await load(complete); await step(5); assert.match(await evaluate('document.querySelector(".brief").textContent'),/Pilot status: Ready to plan/);
  await step(3); await set('#field-global-privacy','declined'); await step(5);
  assert.match(await evaluate('document.querySelector(".brief").textContent'),/Pilot status: Blocked/);
  await step(1); await click('#selected-CURSOR'); await step(2); await set('#field-CURSOR-contract','included');
  assert.equal(await evaluate('Boolean(document.getElementById("field-CURSOR-overlap"))'),true);
  await set('#field-CURSOR-money','reported'); assert.equal(await evaluate('Boolean(document.getElementById("field-CURSOR-rateSource"))'),false);
  await step(4); await set('#field-CURSOR-cadence','-1'); assert.equal(await evaluate('document.getElementById("field-CURSOR-cadence").getAttribute("aria-invalid")'),'true');
  await step(1); await click('#selected-CURSOR'); await click('#save');
  assert.equal(await evaluate('document.getElementById("transfer-dialog").open'),true); await click('#transfer-close');
  const hostile = {...complete,answers:{...complete.answers,title:'<img src=x onerror=alert(1)> '+ 'Long label '.repeat(90)}};
  await load(hostile); await step(5);
  assert.equal(await evaluate('document.querySelectorAll("#page img").length'),0);
  for (const theme of ['light','dark']) {
    await send('Emulation.setEmulatedMedia',{features:[{name:'prefers-color-scheme',value:theme}]});
    for (const width of [360,768,1440]) {
      await send('Emulation.setDeviceMetricsOverride',{width,height:1000,deviceScaleFactor:1,mobile:false});
      for (let index = 0; index < 6; index++) {
        await step(index);
        assert.equal(await evaluate('document.documentElement.scrollWidth <= innerWidth+1'),true,`${theme} ${width}px step ${index}`);
      }
    }
  }
  await send('Emulation.setDeviceMetricsOverride',{width:720,height:500,deviceScaleFactor:2,mobile:false});
  await evaluate('document.body.style.zoom = "2"'); await step(4);
  assert.equal(await evaluate('document.documentElement.scrollWidth <= innerWidth+1'),true,'200% zoom');
  await evaluate('document.body.style.zoom = "1"');
  await step(5); await send('Emulation.setEmulatedMedia',{media:'print'});
  assert.equal(await evaluate('getComputedStyle(document.querySelector(".topbar")).display'),'none');
  assert.match(await evaluate('document.querySelector(".brief").textContent'),/Acceptance evidence/);
  await send('Page.printToPDF',{printBackground:true});
  await send('Emulation.setEmulatedMedia',{media:'screen'});
  await click('#save'); await evaluate('window.originalCreateObjectURL = URL.createObjectURL; URL.createObjectURL = () => { throw new Error("restricted host"); }'); await click('#transfer-download');
  assert.match(await evaluate('document.getElementById("transfer-error").textContent'),/unavailable/);
  assert.match(await evaluate('document.getElementById("transfer-text").value'),/schemaVersion/);
  await click('#transfer-close');
  await evaluate('URL.createObjectURL = window.originalCreateObjectURL');
  await click('#example'); await click('#confirm-ok'); await step(5);
  await delay(100);
  assert.equal(await evaluate('document.querySelectorAll(".diagram-section").length'),3);
  assert.equal(await evaluate('document.querySelectorAll(".connector-prompt").length'),2);
  await click('.connector-prompt[data-platform="CURSOR"] summary');
  const promptText = await evaluate('document.getElementById("prompt-CURSOR").textContent');
  await evaluate('Object.defineProperty(navigator,"clipboard",{configurable:true,value:{writeText:async text => { window.copiedPrompt = text; }}})');
  await click('.connector-prompt[data-platform="CURSOR"] [data-action="copy"]');
  assert.equal(await evaluate('window.copiedPrompt'),promptText);
  await evaluate('navigator.clipboard.writeText = async () => { throw new Error("denied"); }');
  await click('.connector-prompt[data-platform="CURSOR"] [data-action="copy"]');
  assert.equal((await evaluate('window.getSelection().toString()')).trimEnd(),promptText.trimEnd());
  await click('.connector-prompt[data-platform="CURSOR"] [data-action="download"]');
  assert.equal(await evaluate('document.getElementById("transfer-text").value'),promptText);
  await click('#transfer-download');
  const connectorPath = path.join(profile,'connector-cursor.md');
  for (let attempt = 0; attempt < 100 && !fs.existsSync(connectorPath); attempt++) await delay(50);
  assert.equal(fs.readFileSync(connectorPath,'utf8'),promptText); await click('#transfer-close');
  await click('#export-brief'); assert.ok((await evaluate('document.getElementById("transfer-text").value')).includes(promptText)); await click('#transfer-close');
  const allPlatforms = await evaluate('(() => { const state = Workbook.example(); state.selected = Object.keys(Workbook.PLATFORMS); state.step = 5; return state; })()');
  await load(allPlatforms);
  const checkDiagramGeometry = async () => {
    await delay(120);
    assert.equal(await evaluate(`Array.from(document.querySelectorAll('.diagram-lane svg')).every(svg => {
      if (!svg.querySelector('title')?.textContent || !svg.querySelector('desc')?.textContent) return false;
      return Array.from(svg.querySelectorAll('g[data-node]')).every(group => {
        const rect = group.querySelector('rect').getBBox();
        return Array.from(group.querySelectorAll('text')).every(text => { const box = text.getBBox(); return box.x >= rect.x && box.y >= rect.y && box.x+box.width <= rect.x+rect.width+1 && box.y+box.height <= rect.y+rect.height+1; });
      });
    })`),true,'SVG accessible labels fit their node bounds');
  };
  for (const theme of ['light','dark']) {
    await send('Emulation.setEmulatedMedia',{features:[{name:'prefers-color-scheme',value:theme}]});
    for (const width of [360,768,1440]) {
      await send('Emulation.setDeviceMetricsOverride',{width,height:1000,deviceScaleFactor:1,mobile:false});
      await checkDiagramGeometry();
      assert.equal(await evaluate('document.documentElement.scrollWidth <= innerWidth+1'),true);
    }
  }
  await evaluate('document.body.style.zoom = "2"'); await checkDiagramGeometry(); await evaluate('document.body.style.zoom = "1"');
  await send('Emulation.setEmulatedMedia',{media:'print'}); await checkDiagramGeometry();
  assert.equal(await evaluate('getComputedStyle(document.querySelector(".connector-prompts")).display'),'none');
  const pdf = await send('Page.printToPDF',{printBackground:true});
  assert.ok(Buffer.from(pdf.data,'base64').subarray(0,4).toString() === '%PDF');
  if (process.env.WORKBOOK_ARTIFACT_DIR) fs.writeFileSync(path.join(process.env.WORKBOOK_ARTIFACT_DIR,'workbook-review-test.pdf'),Buffer.from(pdf.data,'base64'));
  await send('Emulation.setEmulatedMedia',{media:'screen'});
  if (process.env.WORKBOOK_ARTIFACT_DIR) {
    await load(complete); await step(5); await delay(150);
    const image = await send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});
    fs.writeFileSync(path.join(process.env.WORKBOOK_ARTIFACT_DIR,'workbook-review-test.png'),Buffer.from(image.data,'base64'));
  }
  await evaluate('window.print = () => { throw new Error("restricted host"); }'); await click('#print-brief');
  assert.match(await evaluate('document.getElementById("status").textContent'),/unavailable/);
  assert.deepEqual(errors,[]);
  assert.deepEqual(requests.filter(url => /^https?:/.test(url)),[]);
  console.log('PASS: blank/example/ready/blocked journeys, conditional fields, actual JSON download and file upload, draft restore, invalid import, cancel/reset, keyboard focus, safe text, 6 steps x 3 widths x 2 themes, 200% zoom, print rendering, restricted-host fallbacks, no runtime requests or JS errors.');
}
main().catch(error => { console.error(error); process.exitCode = 1; }).finally(async () => {
  if (socket) socket.close();
  chrome.kill();
  await new Promise(resolve => { if (chrome.exitCode !== null) resolve(); else { chrome.once('exit',resolve); setTimeout(resolve,3000); } });
  fs.rmSync(profile,{recursive:true,force:true});
});
