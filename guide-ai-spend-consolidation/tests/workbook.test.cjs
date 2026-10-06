// Pair-programmed by SE Community + Cortex Code
const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const html = fs.readFileSync(path.join(__dirname,'../workbook.html'),'utf8');
const model = html.match(/<script id="workbook-model">([\s\S]*?)<\/script>/)[1];
const context = vm.createContext({TextEncoder});
vm.runInContext(model+'\nglobalThis.api = Workbook;',context);
const api = context.api;
const plain = value => JSON.parse(JSON.stringify(value));
function ready(id = 'SNOWFLAKE_CORTEX',goals = ['forecast','adoption']) {
  const state = api.blank(); state.selected = [id]; state.pilot = id; state.goals = goals;
  Object.assign(state.answers,{title:'Test pilot',purpose:'Test a reporting decision',audience:'finance',rationale:'native',route:'build',owner:'Platform team',grain:'aggregate',privacy:'approved',directory:'Authoritative directory',mapping:'Approved mappings; retain unresolved',retention:'Approved pruning by data owner',performance:'excluded',transform:'native',acceptance:'Named reviewer; reconciliation, latency, and coverage evidence'});
  Object.assign(state.platforms[id],{owner:'Source team',access:'confirmed',contract:api.PLATFORMS[id].contract,context:'yes',money:api.PLATFORMS[id].money,currency:'USD',rateSource:'Dated finance rate table',seatSource:'Complete license inventory',overlap:'overage',identity:'mapped',cadence:'24',historyDays:'90',revisionDays:'30',historyPlan:'Verified source history and recovery policy',sourceVerified:'yes',boxFeed:'admin',logging:'enabled'});
  return state;
}
test('all executable script blocks parse',() => {
  for (const match of html.matchAll(/<script id="[^"]+">([\s\S]*?)<\/script>/g)) assert.doesNotThrow(() => new vm.Script(match[1]));
});
test('covers all 12 registry keys, including separate API Platform',() => {
  assert.equal(Object.keys(api.PLATFORMS).length,12);
  assert.notEqual(api.PLATFORMS.OPENAI_API_PLATFORM.context,api.PLATFORMS.CHATGPT_ENTERPRISE.context);
  assert.notEqual(api.PLATFORMS.ANTHROPIC_API_CONSOLE.context,api.PLATFORMS.ANTHROPIC_CLAUDE_ENTERPRISE.context);
  const registry = fs.readFileSync(path.join(__dirname,'../sql/01_landing.sql'),'utf8');
  for (const id of Object.keys(api.PLATFORMS)) assert.ok(registry.includes(`('${id}',`),id);
});
test('blank answers are not approvals and draft export works',() => {
  assert.equal(api.evaluate(api.blank()).pilotStatus,'Needs decisions');
  assert.ok(api.evaluate(api.blank()).issues.length > 10);
  assert.match(api.brief(api.blank()),/Not decided/);
  assert.equal(api.completion(api.blank()).filter(Boolean).length,0);
});
test('native pilot can be ready to plan but never production qualified',() => {
  const state = ready();
  assert.equal(api.evaluate(state).pilotStatus,'Ready to plan');
  assert.equal(api.completion(state).filter(Boolean).length,5);
  const text = api.brief(state);
  assert.match(text,/does not mean deployed/);
  assert.match(text,/sql\/01_landing.sql/);
  assert.match(text,/sql\/05_snowflake_native.sql/);
  assert.match(text,/sql\/06_normalize.sql/);
  assert.match(text,/sql\/07_gold_dts.sql/);
});
test('seat-only adoption skips billing; seat review requires roster',() => {
  const state = ready('M365_COPILOT',['adoption']);
  assert.equal(api.billingFields(state,'M365_COPILOT').length,0);
  state.platforms.M365_COPILOT.cadence = '72';
  assert.equal(api.evaluate(state).pilotStatus,'Ready to plan');
  state.goals = ['seats']; state.platforms.M365_COPILOT.seatSource = '';
  assert.equal(api.evaluate(state).pilotStatus,'Needs decisions');
  assert.ok(api.billingFields(state,'M365_COPILOT').includes('seatSource'));
});
test('M365 depth and consumption anomalies are unavailable',() => {
  const state = ready('M365_COPILOT',['engagement','anomalies']);
  for (const goal of state.goals) assert.equal(api.capability(state,'M365_COPILOT',goal).status,'Unavailable');
});
test('concealed M365 identity blocks departmental allocation, not another pilot',() => {
  const state = ready('M365_COPILOT',['allocation']);
  state.platforms.M365_COPILOT.identity = 'concealed';
  assert.equal(api.evaluate(state).pilotStatus,'Blocked for the selected outcome');
  const native = ready('SNOWFLAKE_CORTEX',['allocation']);
  native.selected.push('M365_COPILOT'); native.platforms.M365_COPILOT = state.platforms.M365_COPILOT;
  assert.equal(api.evaluate(native).pilotStatus,'Ready to plan');
  assert.equal(api.evaluate(native).statuses.M365_COPILOT,'Blocked for the selected outcome');
});
test('non-person feeds do not promise person adoption or measured user cost',() => {
  for (const id of ['GOOGLE_VERTEX_AI','ANTHROPIC_API_CONSOLE','OPENAI_API_PLATFORM']) {
    const state = ready(id,['adoption','allocation']);
    assert.equal(api.capability(state,id,'adoption').status,'Unavailable');
    assert.equal(api.capability(state,id,'allocation').status,'Conditional');
    assert.equal(api.PLATFORMS[id].userCost,false);
  }
});
test('included pool versus additive cost uses different gates',() => {
  const cursor = ready('CURSOR',['forecast']);
  cursor.platforms.CURSOR.overlap = 'overall';
  assert.ok(api.evaluate(cursor).issues.some(issue => issue.level === 'blocker' && /included usage/.test(issue.message)));
  cursor.platforms.CURSOR.overlap = 'overage';
  assert.equal(api.evaluate(cursor).pilotStatus,'Ready to plan');
  const claude = ready('ANTHROPIC_CLAUDE_ENTERPRISE',['forecast']);
  claude.platforms.ANTHROPIC_CLAUDE_ENTERPRISE.overlap = '';
  assert.equal(api.evaluate(claude).pilotStatus,'Ready to plan');
});
test('reported currency cannot be multiplied by native rates',() => {
  for (const id of ['CURSOR','ANTHROPIC_CLAUDE_ENTERPRISE']) {
    const state = ready(id,['forecast']); state.platforms[id].money = 'native';
    assert.equal(api.evaluate(state).pilotStatus,'Blocked for the selected outcome');
  }
});
test('missing rates are unknown and mixed currencies stay separate',() => {
  const state = ready(); state.platforms.SNOWFLAKE_CORTEX.rateSource = '';
  assert.equal(api.evaluate(state).pilotStatus,'Needs decisions');
  state.selected.push('CURSOR'); state.platforms.CURSOR = ready('CURSOR').platforms.CURSOR; state.platforms.CURSOR.currency = 'EUR';
  assert.deepEqual(plain(api.evaluate(state).currencies),['USD','EUR']);
  assert.match(api.brief(state),/Keep each separate; no FX conversion/);
});
test('Claude revision window must cover 30 days',() => {
  const state = ready('ANTHROPIC_CLAUDE_ENTERPRISE'); state.platforms.ANTHROPIC_CLAUDE_ENTERPRISE.revisionDays = '29';
  assert.equal(api.evaluate(state).pilotStatus,'Blocked for the selected outcome');
  state.platforms.ANTHROPIC_CLAUDE_ENTERPRISE.revisionDays = '30';
  assert.equal(api.evaluate(state).pilotStatus,'Ready to plan');
});
test('Box event retention and monthly-only activity limitations',() => {
  const state = ready('BOX_AI',['adoption']); const config = state.platforms.BOX_AI;
  config.boxFeed = 'streaming'; config.cadence = '336';
  assert.equal(api.evaluate(state).pilotStatus,'Blocked for the selected outcome');
  config.cadence = '24'; config.historyDays = '7';
  assert.equal(api.evaluate(state).pilotStatus,'Ready to plan');
  config.boxFeed = 'monthly';
  assert.equal(api.capability(state,'BOX_AI','adoption').status,'Unavailable');
});
test('Google Workspace depth unavailable, Code Assist depends on logging',() => {
  const state = ready('GOOGLE_WORKSPACE_GEMINI',['engagement']);
  assert.equal(api.capability(state,'GOOGLE_WORKSPACE_GEMINI','engagement').status,'Unavailable');
  const code = ready('GOOGLE_CODE_ASSIST',['adoption']); code.platforms.GOOGLE_CODE_ASSIST.logging = 'pending';
  assert.equal(api.capability(code,'GOOGLE_CODE_ASSIST','adoption').status,'Conditional');
});
test('privacy and team-only boundary cannot be greenwashed by form completion',() => {
  const state = ready(); state.answers.privacy = 'declined';
  assert.equal(api.completion(state).filter(Boolean).length,5);
  assert.equal(api.evaluate(state).pilotStatus,'Blocked for the selected outcome');
  state.answers.privacy = 'approved'; state.answers.grain = 'team';
  assert.equal(api.evaluate(state).pilotStatus,'Blocked for the selected outcome');
});
test('removing a platform removes output requirements but retains its answers',() => {
  const state = ready(); state.selected.push('CURSOR'); state.platforms.CURSOR.owner = 'Deferred owner';
  assert.ok(api.evaluate(state).issues.some(issue => issue.scope === 'CURSOR'));
  state.selected = ['SNOWFLAKE_CORTEX'];
  assert.ok(!api.evaluate(state).issues.some(issue => issue.scope === 'CURSOR'));
  assert.ok(!api.brief(state).includes('Deferred owner'));
  assert.equal(state.platforms.CURSOR.owner,'Deferred owner');
});
test('adapter status remains distinct from capability and readiness',() => {
  const state = ready('CURSOR');
  assert.equal(api.evaluate(state).pilotStatus,'Ready to plan');
  assert.match(api.brief(state),/Adapter development and shredding required/);
  assert.match(api.brief(state),/zero-row shredding stubs are not working connectors/);
});
test('buy path defers implementation and keeps acceptance criteria',() => {
  const state = ready(); state.answers.route = 'buy';
  assert.match(api.brief(state),/Build sequence deferred/);
  assert.ok(!api.brief(state).includes('### Pilot:'));
  assert.match(api.brief(state),/Acceptance evidence still required/);
});
test('blank, complete, and example JSON round-trip exactly',() => {
  for (const state of [api.blank(),ready(),api.example()]) assert.deepEqual(plain(api.validateImport(JSON.stringify(state))),plain(state));
});
test('strict schema rejects malformed, oversized, foreign, and unknown fields',() => {
  for (const text of ['not JSON','[]','null','x'.repeat(api.MAX_BYTES+1)]) assert.throws(() => api.validateImport(text));
  const mutations = [
    state => { state.schemaVersion = 9; },state => { state.contentVersion = 'old'; },
    state => { state.goals = ['unknown']; },state => { state.goals = ['adoption','adoption']; },
    state => { state.selected = ['UNKNOWN']; },state => { state.pilot = 'CURSOR'; },
    state => { state.answers.owner = '<'.repeat(2001); },state => { state.answers.owner = {}; },
    state => { state.answers.privacy = 'looks fine'; },state => { state.extra = true; },
    state => { state.platforms.SNOWFLAKE_CORTEX.__proto__ = {bad:true}; state.platforms.SNOWFLAKE_CORTEX['constructor'] = 'no'; }
  ];
  for (const mutate of mutations) { const state = ready(); mutate(state); assert.throws(() => api.validateImport(JSON.stringify(state))); }
});
test('special characters stay data; brief escapes markdown and html',() => {
  const state = ready(); state.answers.title = '<script>alert("x")</script> [go](https://example.com)';
  const restored = api.validateImport(JSON.stringify(state));
  assert.equal(restored.answers.title,state.answers.title);
  const text = api.brief(restored);
  assert.ok(!text.includes('<script>'));
  assert.ok(!text.includes('[go]('));
});
test('invalid numeric and currency drafts round-trip even when hidden',() => {
  const state = ready(); state.platforms.CURSOR.cadence = '-1'; state.platforms.CURSOR.currency = 'bad';
  assert.deepEqual(plain(api.validateImport(JSON.stringify(state))),plain(state));
  assert.equal(api.evaluate(state).pilotStatus,'Ready to plan');
  state.platforms.SNOWFLAKE_CORTEX.cadence = '-1';
  assert.equal(api.evaluate(state).pilotStatus,'Needs decisions');
});
test('seat-only Cursor review does not need metered pricing',() => {
  const state = ready('CURSOR',['seats']);
  for (const key of ['money','currency','rateSource','contract','overlap','context']) state.platforms.CURSOR[key] = '';
  assert.equal(api.evaluate(state).pilotStatus,'Ready to plan');
  assert.deepEqual(plain(api.billingFields(state,'CURSOR')),['seatSource']);
});
test('anonymous M365 adoption does not require a corporate identity spine',() => {
  const state = ready('M365_COPILOT',['adoption']); state.answers.directory = ''; state.answers.mapping = '';
  state.platforms.M365_COPILOT.identity = 'concealed';
  assert.equal(api.evaluate(state).pilotStatus,'Ready to plan');
});
test('future person platform does not downgrade ready non-person forecast pilot',() => {
  const state = ready('GOOGLE_VERTEX_AI',['forecast']); state.answers.directory = ''; state.answers.mapping = '';
  state.selected.push('CURSOR');
  assert.equal(api.evaluate(state).pilotStatus,'Ready to plan');
  assert.equal(api.evaluate(state).statuses.CURSOR,'Needs decisions');
});
test('conditional design can be settled without rewriting source capability',() => {
  for (const id of ['GOOGLE_VERTEX_AI','BOX_AI','GOOGLE_WORKSPACE_GEMINI']) {
    const state = ready(id,['allocation']);
    assert.equal(api.evaluate(state).pilotStatus,'Needs decisions');
    Object.assign(state.platforms[id],{adaptation:'Approved scoped reporting design with documented allocation rules.',adaptationConfirmed:'yes'});
    assert.equal(api.evaluate(state).pilotStatus,'Ready to plan');
    assert.equal(api.capability(state,id,'allocation').status,'Conditional');
  }
});
test('review diagrams are empty until scope exists and native bypasses raw',() => {
  assert.equal(api.reviewDiagrams(api.blank()).length,0);
  const diagrams = api.reviewDiagrams(ready());
  assert.equal(diagrams.length,3);
  assert.match(JSON.stringify(diagrams[0]),/ACCOUNT_USAGE; no external adapter/);
  assert.doesNotMatch(JSON.stringify(diagrams[0]),/immutable RAW/);
  assert.equal(api.connectorPrompts(ready()).length,0);
  assert.equal(api.connectorPrompts(ready('GITHUB_COPILOT')).length,0);
});
test('diagrams preserve chosen cost shape, currency and activity scope',() => {
  const state = ready('CURSOR'); state.platforms.CURSOR.overlap = 'overall';
  let text = JSON.stringify(api.reviewDiagrams(state)[1]);
  assert.match(text,/STOP: included usage not separated/);
  state.platforms.CURSOR.overlap = 'overage'; text = JSON.stringify(api.reviewDiagrams(state)[1]);
  assert.match(text,/Exclude included-usage value/);
  assert.match(text,/Reported currency; no second rate/);
  const claude = ready('ANTHROPIC_CLAUDE_ENTERPRISE'); claude.platforms.ANTHROPIC_CLAUDE_ENTERPRISE.currency = 'EUR';
  assert.match(JSON.stringify(api.reviewDiagrams(claude)[1]),/Seat \+ separately billed usage/);
  assert.match(JSON.stringify(api.reviewDiagrams(claude)[1]),/EUR/);
  state.goals = ['seats']; assert.equal(api.reviewDiagrams(state)[1].title,'Your activity coverage');
});
test('diagrams reflect boundary, dbt and optional extensions',() => {
  const state = ready(); state.answers.transform = 'dbt_port'; state.extensions = ['agents','outcomes'];
  assert.match(JSON.stringify(api.reviewDiagrams(state)[0]),/Port transform layer into dbt/);
  assert.match(JSON.stringify(api.reviewDiagrams(state)[0]),/Optional agent/);
  state.answers.grain = 'team'; assert.match(api.reviewDiagrams(state)[0].description,/blocked/);
  state.answers.route = 'buy';
  assert.equal(api.connectorPrompts(state).length,0);
  assert.match(api.reviewDiagrams(state)[0].title,/evaluation/);
  assert.doesNotMatch(JSON.stringify(api.reviewDiagrams(state)[2]),/Build missing connector/);
});
test('all missing connectors have scoped prompts with boundaries and unique checks',() => {
  const state = ready('CURSOR'); state.selected = Object.keys(api.PLATFORMS);
  const prompts = api.connectorPrompts(state);
  assert.equal(prompts.length,10); assert.equal(prompts[0].id,'CURSOR');
  for (const prompt of prompts) {
    assert.match(prompt.text,/Start with discovery/);
    assert.match(prompt.text,/user explicitly authorizes changes/);
    assert.match(prompt.text,/untrusted reference data/);
    assert.match(prompt.text,/sql\/06_normalize.sql/);
    assert.match(prompt.text,/Not decided|Platform team/);
    assert.ok(prompt.text.includes(api.PLATFORMS[prompt.id].context));
    assert.ok(api.brief(state).includes(prompt.text));
    assert.ok(!api.brief(state,false).includes(prompt.text));
  }
  assert.match(prompts.find(prompt => prompt.id === 'BOX_AI').text,/monthly AI Units/);
  assert.match(prompts.find(prompt => prompt.id === 'M365_COPILOT').text,/nextLink pagination/);
  assert.match(prompts.find(prompt => prompt.id === 'GOOGLE_CODE_ASSIST').text,/Cloud Logging rather than aggregate Cloud Monitoring/);
  assert.match(prompts.find(prompt => prompt.id === 'ANTHROPIC_CLAUDE_ENTERPRISE').text,/30-day revision reload/);
});
test('prompt blockers are scoped and selection removal removes derived output',() => {
  const state = ready('CURSOR'); state.selected.push('M365_COPILOT');
  state.platforms.M365_COPILOT.access = 'denied';
  assert.doesNotMatch(api.connectorPrompts(state)[0].text,/Source access denied/);
  assert.match(api.connectorPrompts(state)[1].text,/Source access denied/);
  state.selected = ['CURSOR']; assert.equal(api.connectorPrompts(state).length,1);
  assert.equal(api.reviewDiagrams(state)[0].lanes.some(lane => lane.id === 'M365_COPILOT'),false);
  const restored = api.validateImport(JSON.stringify(state));
  assert.deepEqual(plain(api.reviewDiagrams(restored)),plain(api.reviewDiagrams(state)));
  assert.deepEqual(plain(api.connectorPrompts(restored)),plain(api.connectorPrompts(state)));
});
test('diagrams cannot greenwash prohibited grain or unsupported outcomes',() => {
  const team = ready(); team.answers.grain = 'team';
  const data = JSON.stringify(api.reviewDiagrams(team)[0]);
  assert.match(data,/Upstream aggregation redesign/); assert.doesNotMatch(data,/Anonymous activity/);
  for (const [id,goal] of [['M365_COPILOT','engagement'],['BOX_AI','adoption']]) {
    const state = ready(id,[goal]); state.platforms[id].boxFeed = 'monthly';
    assert.ok(api.reviewDiagrams(state)[1].lanes[0].nodes.some(node => node.status === 'blocked'));
  }
  for (const id of ['CURSOR','ANTHROPIC_CLAUDE_ENTERPRISE']) {
    const state = ready(id); state.platforms[id].money = 'native';
    const diagram = api.reviewDiagrams(state)[1];
    assert.match(JSON.stringify(diagram),/Correct the cost feed/);
    assert.doesNotMatch(JSON.stringify(diagram),/Native units \+ dated verified rate/);
  }
});
test('content sources and delivery reference paths exist',() => {
  for (const id of Object.keys(api.PLATFORMS)) for (const [,reference] of api.workPackages(ready(id),id)) assert.ok(fs.existsSync(path.join(__dirname,'..',reference.split('#')[0])),reference);
  const metadata = JSON.parse(html.match(/id="snowflake-report-metadata">([\s\S]*?)<\/script>/)[1]);
  for (const source of metadata.dataSources) assert.ok(fs.existsSync(path.join(__dirname,'..',source.path)),source.path);
});
test('offline security and accessibility baseline',() => {
  assert.doesNotMatch(html,/\b(?:fetch|XMLHttpRequest|WebSocket|sendBeacon|eval|localStorage|sessionStorage)\s*\(/);
  assert.doesNotMatch(html,/<(?:script|img|iframe)\b[^>]*\bsrc=/i);
  assert.doesNotMatch(html,/\bon(?:click|load|change|error)\s*=/i);
  assert.doesNotMatch(html,/innerHTML|new Function|document\.cookie/);
  assert.match(html,/aria-current/);
  assert.match(html,/aria-invalid/);
  assert.match(html,/@media print/);
  assert.match(html,/prefers-color-scheme:dark/);
  assert.match(html,/addEventListener\('beforeunload'/);
});
