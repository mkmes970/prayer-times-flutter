'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');

const template = fs.readFileSync(`${__dirname}/offline-sw.js`, 'utf8');
const setup = fs.readFileSync(
  `${__dirname}/../../mobile/prayer_times/web/offline-setup.js`,
  'utf8',
);
const scope = 'https://example.github.io/prayer-times/';
const testWorker = template
  .replace('__CACHE_NAME__', 'mwaqit-offline-test')
  .replace('__PRECACHE_URLS__', JSON.stringify(['index.html', 'main.dart.js']));

function makeWorker({ failPrecache = false, networkFetch } = {}) {
  const handlers = {};
  const entries = new Map();
  const removed = [];
  const messages = [];
  let claimed = false;
  let skippedWaiting = false;
  const cache = {
    addAll: async requests => {
      if (failPrecache) throw new Error('network unavailable');
      for (const request of requests) {
        entries.set(request.url, { cachedUrl: request.url });
      }
    },
    match: async request => entries.get(
      typeof request === 'string'
        ? request
        : request.url || request.toString(),
    ),
    put: async (request, response) => {
      entries.set(typeof request === 'string' ? request : request.url, response);
    },
  };
  const cacheNames = new Set([
    'mwaqit-offline-old',
    'flutter-app-cache',
    'other-app-cache',
  ]);
  const caches = {
    open: async name => {
      cacheNames.add(name);
      return cache;
    },
    keys: async () => [...cacheNames],
    delete: async name => {
      removed.push(name);
      cacheNames.delete(name);
      return true;
    },
  };
  const clients = [
    { postMessage: message => messages.push(message) },
  ];
  const context = {
    URL,
    Request,
    Response,
    fetch: networkFetch || (async request => {
      if (request.url.endsWith('/index.html')) {
        return new Response('<main>online page</main>');
      }
      throw new Error('offline');
    }),
    caches,
    self: {
      location: { origin: new URL(scope).origin },
      registration: { scope },
      addEventListener: (name, handler) => { handlers[name] = handler; },
      skipWaiting: async () => { skippedWaiting = true; },
      clients: {
        matchAll: async () => clients,
        claim: async () => { claimed = true; },
      },
    },
  };
  vm.runInNewContext(testWorker, context);
  return {
    handlers, entries, removed, messages, cacheNames,
    get claimed() { return claimed; },
    get skippedWaiting() { return skippedWaiting; },
  };
}

test('install caches all release files before the worker can activate', async () => {
  const worker = makeWorker();
  let installPromise;
  worker.handlers.install({
    waitUntil: promise => { installPromise = promise; },
  });
  await installPromise;
  assert.deepEqual(
    [...worker.entries.keys()].sort(),
    [
      `${scope}index.html`,
      `${scope}main.dart.js`,
    ].sort(),
  );
});

test('failed pre-cache removes only the incomplete new cache', async () => {
  const worker = makeWorker({ failPrecache: true });
  let installPromise;
  worker.handlers.install({
    waitUntil: promise => { installPromise = promise; },
  });
  await assert.rejects(installPromise, /network unavailable/);
  assert.deepEqual(worker.removed, ['mwaqit-offline-test']);
  assert(worker.cacheNames.has('mwaqit-offline-old'));
  assert(worker.messages.some(
    message => message.type === 'OFFLINE_PRECACHE_FAILED',
  ));
});

test('activation replaces only app caches and leaves unrelated caches intact', async () => {
  const worker = makeWorker();
  let activationPromise;
  worker.handlers.activate({
    waitUntil: promise => { activationPromise = promise; },
  });
  await activationPromise;
  assert.deepEqual(
    worker.removed.sort(),
    ['flutter-app-cache', 'mwaqit-offline-old'].sort(),
  );
  assert(worker.cacheNames.has('other-app-cache'));
  assert.equal(worker.claimed, true);
  assert(worker.messages.some(message => message.type === 'OFFLINE_READY'));
});

test('navigation falls back to the cached app shell while offline', async () => {
  const worker = makeWorker();
  worker.entries.set(
    `${scope}index.html`,
    new Response('<main>cached app</main>'),
  );
  let responsePromise;
  worker.handlers.fetch({
    request: { method: 'GET', mode: 'navigate', url: scope },
    respondWith: promise => { responsePromise = promise; },
  });
  const response = await responsePromise;
  assert.equal(await response.text(), '<main>cached app</main>');
});

test('cached application resources are served without a network request', async () => {
  let requests = 0;
  const worker = makeWorker({
    networkFetch: async () => {
      requests += 1;
      throw new Error('network should not be used');
    },
  });
  const asset = `${scope}main.dart.js`;
  worker.entries.set(asset, new Response('cached javascript'));
  let responsePromise;
  worker.handlers.fetch({
    request: { method: 'GET', mode: 'cors', url: asset },
    respondWith: promise => { responsePromise = promise; },
  });
  const response = await responsePromise;
  assert.equal(await response.text(), 'cached javascript');
  assert.equal(requests, 0);
});

test('the user action activates a waiting update', async () => {
  const worker = makeWorker();
  let messagePromise;
  worker.handlers.message({
    data: { type: 'SKIP_WAITING' },
    waitUntil: promise => { messagePromise = promise; },
  });
  await messagePromise;
  assert.equal(worker.skippedWaiting, true);
});

test('a first online visit registers the offline worker without touching settings', async () => {
  let resolveRegistered;
  const registered = new Promise(resolve => { resolveRegistered = resolve; });
  let registrationUrl;
  let registrationOptions;
  const listeners = {};
  const registration = {
    waiting: null,
    installing: null,
    addEventListener: () => {},
    update: async () => {},
  };
  const serviceWorker = {
    controller: null,
    addEventListener: (name, handler) => { listeners[name] = handler; },
    register: async (url, options) => {
      registrationUrl = String(url);
      registrationOptions = options;
      resolveRegistered();
      return registration;
    },
  };
  const sandbox = {
    URL,
    console,
    navigator: { serviceWorker, onLine: false },
    window: {
      isSecureContext: true,
      addEventListener: () => {},
    },
    document: {
      baseURI: scope,
      body: { appendChild: () => {} },
      createElement: () => ({
        style: {},
        setAttribute: () => {},
        appendChild: () => {},
        addEventListener: () => {},
        remove: () => {},
      }),
    },
  };
  Object.defineProperty(sandbox, 'localStorage', {
    get() { throw new Error('Saved settings must not be touched'); },
  });
  vm.runInNewContext(setup, sandbox);
  await registered;
  assert.equal(registrationUrl, `${scope}offline-sw.js`);
  assert.equal(registrationOptions.scope, scope);
  assert.equal(registrationOptions.updateViaCache, 'none');
  assert.equal(typeof listeners.message, 'function');
});
