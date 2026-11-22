'use strict';

// These release-specific values are inserted by scripts/pwa/build.py.
const CACHE_PREFIX = 'mwaqit-offline-';
const CACHE_NAME = '__CACHE_NAME__';
const PRECACHE_URLS = __PRECACHE_URLS__;
const LEGACY_CACHES = [
  'flutter-app-cache',
  'flutter-temp-cache',
  'flutter-app-manifest',
];

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    try {
      const requests = PRECACHE_URLS.map(path =>
        new Request(new URL(path, self.registration.scope), { cache: 'reload' })
      );
      await cache.addAll(requests);
    } catch (error) {
      await caches.delete(CACHE_NAME);
      await notifyClients({ type: 'OFFLINE_PRECACHE_FAILED' });
      throw error;
    }
  })());
});

self.addEventListener('message', event => {
  if (event.data?.type === 'SKIP_WAITING') {
    event.waitUntil(self.skipWaiting());
    return;
  }
  if (event.data?.type === 'CHECK_OFFLINE_CACHE') {
    event.waitUntil((async () => {
      const cache = await caches.open(CACHE_NAME);
      const results = await Promise.all(PRECACHE_URLS.map(path =>
        cache.match(new URL(path, self.registration.scope))
      ));
      event.source?.postMessage({
        type: 'OFFLINE_CACHE_STATUS',
        ready: results.every(Boolean),
      });
    })());
  }
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names.filter(name =>
      (name.startsWith(CACHE_PREFIX) && name !== CACHE_NAME) ||
      LEGACY_CACHES.includes(name)
    ).map(name => caches.delete(name)));
    await self.clients.claim();
    await notifyClients({ type: 'OFFLINE_READY' });
  })());
});

self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const scope = new URL(self.registration.scope);
  const url = new URL(request.url);
  if (url.origin !== scope.origin || !url.pathname.startsWith(scope.pathname)) {
    return;
  }

  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    const cached = await cache.match(request);
    if (cached) return cached;

    try {
      const response = await fetch(request);
      if (response.ok && response.type !== 'opaque') {
        await cache.put(request, response.clone());
      }
      return response;
    } catch (_) {
      if (request.mode === 'navigate') {
        const appShell = await cache.match(new URL('index.html', scope));
        if (appShell) return appShell;
      }
      return new Response('This resource is not available offline.', {
        status: 503,
        statusText: 'Offline',
      });
    }
  })());
});

async function notifyClients(message) {
  const clients = await self.clients.matchAll({
    type: 'window',
    includeUncontrolled: true,
  });
  for (const client of clients) client.postMessage(message);
}
