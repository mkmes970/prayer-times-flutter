// A separate entry point can be opened even when an old worker caches index.html.
(() => {
  'use strict';
  const button = document.getElementById('update');
  const status = document.getElementById('status');
  const scope = new URL('./', document.baseURI);

  async function activateCompleteRelease(registration) {
    const deadline = Date.now() + 180000;
    // Keep the candidate reference: after a failed install the registration
    // falls back to its old active worker, which is not a successful update.
    const worker = registration.installing ||
      registration.waiting || registration.active;
    while (Date.now() < deadline) {
      if (!worker || worker.state === 'redundant') {
        throw new Error('The release could not be installed.');
      }
      if (worker.state === 'installed') {
        // Installation succeeds only after every release file is cached.
        worker.postMessage({ type: 'SKIP_WAITING' });
      }
      if (worker.state === 'activated') return;
      await new Promise(resolve => window.setTimeout(resolve, 250));
    }
    throw new Error('Timed out while downloading the release.');
  }

  button.addEventListener('click', async () => {
    button.disabled = true;
    status.textContent = 'جارٍ تحميل آخر تحديث… لا تغلق الصفحة.';
    try {
      if (!navigator.onLine) throw new Error('Offline');
      if (!('serviceWorker' in navigator) || !window.isSecureContext) {
        throw new Error('Secure service workers are required.');
      }
      // Check the network before starting; keep the working offline version
      // untouched if the server cannot be reached.
      const response = await fetch(new URL('release-files.json', scope), {
        cache: 'no-store',
      });
      if (!response.ok) throw new Error('Release is unavailable.');
      const files = await response.json();
      if (!Array.isArray(files) ||
          !files.some(file => file.path === 'main.dart.js')) {
        throw new Error('Invalid release manifest.');
      }
      const registration = await navigator.serviceWorker.register(
        new URL('offline-sw.js', scope),
        { scope: scope.href, updateViaCache: 'none' },
      );
      await registration.update();
      await activateCompleteRelease(registration);
      // No localStorage/IndexedDB deletion, unregistering, or manual cache
      // clearing: activate only a fully downloaded release.
      status.textContent = 'اكتمل التحديث. جارٍ فتح التطبيق…';
      const destination = new URL(scope);
      destination.searchParams.set('updated', String(Date.now()));
      window.location.replace(destination.href);
    } catch (error) {
      console.warn('App update failed:', error);
      status.textContent = 'لم يكتمل التحديث. تحقق من الاتصال ثم أعد المحاولة. لم نحذف إعداداتك أو النسخة السابقة.';
      button.disabled = false;
    }
  });
})();
