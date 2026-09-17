// Sirr (سِرّ) Web Push Service Worker
self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

// Handle incoming Web Push notifications from Cloudflare Worker
self.addEventListener('push', (event) => {
  if (!event.data) {
    console.log('[Service Worker] Push event received with no data');
    return;
  }

  let data = {};
  try {
    data = event.data.json();
  } catch (e) {
    data = {
      title: 'سِرّ • مواقيت الصلاة',
      body: event.data.text(),
    };
  }

  const title = data.title || 'سِرّ • حان وقت الصلاة';
  const options = {
    body: data.body || 'Time to pray.',
    icon: data.icon || 'icons/Icon-192.png',
    badge: data.badge || 'icons/Icon-192.png',
    tag: data.tag || 'prayer-notification',
    renotify: true,
    requireInteraction: true,
    vibrate: [300, 100, 300, 100, 300],
    data: data.data || { url: '/' },
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

// Handle notification click to open or focus the web app
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const targetUrl = (event.notification.data && event.notification.data.url) || '/';

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      // Check if there is already a window/tab open with the target URL
      for (const client of windowClients) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          return client.focus();
        }
      }
      // If not, open a new window/tab
      if (self.clients.openWindow) {
        return self.clients.openWindow(targetUrl);
      }
    })
  );
});
