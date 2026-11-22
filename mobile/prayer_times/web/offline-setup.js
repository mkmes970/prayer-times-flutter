// Install the offline cache worker and offer a safe, user-confirmed app update.
(async function () {
  'use strict';
  if (!('serviceWorker' in navigator) || !window.isSecureContext) return;

  let registration;
  let reloadForUpdate = false;
  let notice;

  function showNotice(message, actionLabel, action) {
    if (!document.body) return;
    notice?.remove();
    const currentNotice = document.createElement('aside');
    notice = currentNotice;
    currentNotice.setAttribute('role', 'status');
    currentNotice.setAttribute('aria-live', 'polite');
    currentNotice.dir = 'rtl';
    Object.assign(currentNotice.style, {
      position: 'fixed',
      zIndex: '2147483647',
      left: 'max(12px, env(safe-area-inset-left))',
      right: 'max(12px, env(safe-area-inset-right))',
      bottom: 'max(12px, env(safe-area-inset-bottom))',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      gap: '12px',
      padding: '12px 16px',
      borderRadius: '14px',
      background: '#123d2d',
      color: '#fff8e9',
      boxShadow: '0 4px 18px rgba(0,0,0,.25)',
      font: '600 14px/1.5 system-ui, sans-serif',
    });
    const text = document.createElement('span');
    text.textContent = message;
    currentNotice.appendChild(text);
    if (actionLabel && action) {
      const button = document.createElement('button');
      button.type = 'button';
      button.textContent = actionLabel;
      Object.assign(button.style, {
        flex: '0 0 auto',
        border: '1px solid #e8cc7a',
        borderRadius: '10px',
        padding: '8px 12px',
        background: '#e8cc7a',
        color: '#123d2d',
        font: 'inherit',
        cursor: 'pointer',
      });
      button.addEventListener('click', action);
      currentNotice.appendChild(button);
    } else {
      window.setTimeout(() => currentNotice.remove(), 6000);
    }
    document.body.appendChild(currentNotice);
  }

  function requestOfflineStatus() {
    navigator.serviceWorker.controller?.postMessage({
      type: 'CHECK_OFFLINE_CACHE',
    });
  }

  function offerUpdate() {
    if (!registration?.waiting) return;
    showNotice('يتوفر تحديث جديد للتطبيق.', 'تحديث الآن', () => {
      reloadForUpdate = true;
      registration.waiting?.postMessage({ type: 'SKIP_WAITING' });
    });
  }

  navigator.serviceWorker.addEventListener('message', event => {
    switch (event.data?.type) {
      case 'OFFLINE_READY':
        requestOfflineStatus();
        break;
      case 'OFFLINE_CACHE_STATUS':
        if (registration?.waiting) {
          offerUpdate();
          break;
        }
        if (event.data.ready) {
          showNotice('التطبيق جاهز للعمل دون إنترنت.');
        } else {
          showNotice('لم يكتمل حفظ ملفات التطبيق. اتصل بالإنترنت وأعد فتحه.');
        }
        break;
      case 'OFFLINE_PRECACHE_FAILED':
        showNotice('تعذر حفظ ملفات التطبيق. تحقق من الاتصال وأعد المحاولة.');
        break;
    }
  });

  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (reloadForUpdate) {
      window.location.reload();
    } else {
      requestOfflineStatus();
    }
  });

  window.addEventListener('offline', () => {
    showNotice('لا يوجد اتصال بالإنترنت.');
  });

  try {
    const scope = new URL('./', document.baseURI).href;
    registration = await navigator.serviceWorker.register(
      new URL('offline-sw.js', scope),
      { scope, updateViaCache: 'none' },
    );
    registration.addEventListener('updatefound', () => {
      const installing = registration.installing;
      installing?.addEventListener('statechange', () => {
        if (installing.state === 'installed' &&
            navigator.serviceWorker.controller) {
          offerUpdate();
        }
      });
    });
    offerUpdate();
    requestOfflineStatus();
    if (navigator.onLine) registration.update().catch(() => {});
    window.addEventListener('online', () => {
      registration.update().catch(() => {});
    });
    window.addEventListener('focus', () => {
      if (navigator.onLine) registration.update().catch(() => {});
      offerUpdate();
    });
  } catch (error) {
    console.warn('Could not prepare offline app files:', error);
  }
})();
