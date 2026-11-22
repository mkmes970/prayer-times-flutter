const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync(
  `${__dirname}/../../mobile/prayer_times/web/update-app.js`, 'utf8',
);

function page({
  offline = false, fail = false, installing = false, installationFails = false,
} = {}) {
  let click;
  let destination;
  let worker;
  let registration;
  const button = {
    disabled: false,
    addEventListener: (_, callback) => { click = callback; },
  };
  const status = {};
  worker = {
    state: installing ? 'installing' : 'activated',
    postMessage(message) {
      assert.equal(message.type, 'SKIP_WAITING');
      worker.state = 'activated';
      registration.installing = null;
      registration.waiting = null;
      registration.active = worker;
    },
  };
  registration = {
    active: installing ? null : worker,
    installing: installing ? worker : null,
    waiting: null,
    update: async () => {},
  };
  const sandbox = {
    URL, Date, Promise,
    console: { warn: () => {} },
    fetch: async (_, options) => {
      assert.equal(options.cache, 'no-store');
      return { ok: !fail, json: async () => [{ path: 'main.dart.js' }] };
    },
    document: {
      baseURI: 'https://example.test/prayer/update-app.html',
      getElementById: id => id === 'update' ? button : status,
    },
    navigator: {
      onLine: !offline,
      serviceWorker: {
        register: async (url, options) => {
          assert.equal(String(url), 'https://example.test/prayer/offline-sw.js');
          assert.equal(options.scope, 'https://example.test/prayer/');
          assert.equal(options.updateViaCache, 'none');
          return registration;
        },
      },
    },
    window: {
      isSecureContext: true,
      location: { replace: url => { destination = new URL(url); } },
      setTimeout: callback => {
        if (installationFails) {
          worker.state = 'redundant';
          registration.installing = null;
          registration.active = { state: 'activated' };
          callback();
          return;
        }
        // Complete the install only after the first wait.
        worker.state = 'installed';
        registration.installing = null;
        registration.waiting = worker;
        callback();
      },
    },
  };
  for (const key of ['localStorage', 'indexedDB', 'caches']) {
    Object.defineProperty(sandbox, key, {
      get() { throw new Error(`Update must not clear ${key}`); },
    });
  }
  vm.runInNewContext(source, sandbox);
  return { run: () => click(), button, status, destination: () => destination };
}

test('recovery opens the same app scope after a complete release', async () => {
  const app = page();
  await app.run();
  assert.equal(app.destination().pathname, '/prayer/');
  assert(app.destination().searchParams.has('updated'));
});

test('an old controlled page waits for installation before activating', async () => {
  const app = page({ installing: true });
  await app.run();
  assert.equal(app.destination().pathname, '/prayer/');
});

for (const options of [
  { offline: true }, { fail: true },
  { installing: true, installationFails: true },
]) {
  test(`failed update preserves the old page and permits retry ${JSON.stringify(options)}`, async () => {
    const app = page(options);
    await app.run();
    assert.equal(app.destination(), undefined);
    assert.equal(app.button.disabled, false);
    assert.match(app.status.textContent, /لم نحذف إعداداتك/);
  });
}
