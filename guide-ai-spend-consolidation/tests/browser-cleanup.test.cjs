// Pair-programmed by SE Community + Cortex Code
const assert = require('node:assert/strict');
const {spawn} = require('node:child_process');
const {once} = require('node:events');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const {cleanupBrowser} = require('./browser-cleanup.cjs');

for (const ignoreTermination of [false, true]) {
  test(`cleanup waits for browser shutdown (ignore SIGTERM: ${ignoreTermination})`, async () => {
    const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'browser-cleanup-test-'));
    const child = spawn(process.execPath, ['-e', `
      const fs = require('node:fs');
      const path = require('node:path');
      const profile = process.argv[1];
      ${ignoreTermination ? "process.on('SIGTERM', () => {});" : ''}
      setInterval(() => {
        fs.mkdirSync(path.join(profile, 'Default'), {recursive: true});
        fs.writeFileSync(path.join(profile, 'Default', 'state'), 'active');
      }, 5);
      process.stdout.write('ready');
    `, profile], {stdio: ['ignore', 'pipe', 'inherit']});
    try {
      await once(child.stdout, 'data');
      await cleanupBrowser(child, profile, 100);
      assert.equal(child.signalCode, ignoreTermination ? 'SIGKILL' : 'SIGTERM');
      assert.equal(fs.existsSync(profile), false);
    } finally {
      if (child.exitCode === null && child.signalCode === null) {
        const closed = once(child, 'close');
        child.kill('SIGKILL');
        await closed;
      }
      fs.rmSync(profile, {recursive: true, force: true});
    }
  });
}

test('cleanup removes the profile after a failed browser launch', async () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'browser-cleanup-test-'));
  await cleanupBrowser({pid: undefined}, profile);
  assert.equal(fs.existsSync(profile), false);
});

test('cleanup removes the profile after the browser has already exited', async () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'browser-cleanup-test-'));
  await cleanupBrowser({pid: 1, exitCode: null, signalCode: 'SIGTERM'}, profile);
  assert.equal(fs.existsSync(profile), false);
});
