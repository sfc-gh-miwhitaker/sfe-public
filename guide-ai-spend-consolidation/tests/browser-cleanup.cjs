// Pair-programmed by SE Community + Cortex Code
const {rm} = require('node:fs/promises');

async function cleanupBrowser(chrome, profile, timeoutMs = 3000) {
  if (chrome.pid && chrome.exitCode === null && chrome.signalCode === null) {
    await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        chrome.kill('SIGKILL');
      }, timeoutMs);
      const deadline = setTimeout(() => {
        chrome.removeListener('close', onClose);
        reject(new Error('Chrome did not stop; temporary profile retained. Stop the browser before removing it.'));
      }, timeoutMs * 2);
      function onClose() {
        clearTimeout(timeout);
        clearTimeout(deadline);
        resolve();
      }
      chrome.once('close', onClose);
      chrome.kill('SIGTERM');
    });
  }
  await rm(profile, {recursive: true, force: true, maxRetries: 5, retryDelay: 200});
}

module.exports = {cleanupBrowser};
