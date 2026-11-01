/* PCU Connect web push (Firebase Cloud Messaging) service worker.
 * Shows pushes that arrive while the app is closed or in the background.
 * The Firebase SDK is served from this site (firebasejs/13.1.0), not a CDN.
 * Web push cannot play a custom sound; the phone uses its own. */
importScripts('firebasejs/13.1.0/firebase-app-compat.js', 'firebasejs/13.1.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBcrUS4Y_vyj0Q5D9Xes9Mg96CExhN-E1Q',
  appId: '1:727373224836:web:abce1f0f5a3045a43cdbd1',
  messagingSenderId: '727373224836',
  projectId: 'pcu-workflow',
  authDomain: 'pcu-workflow.firebaseapp.com',
  storageBucket: 'pcu-workflow.firebasestorage.app',
});

const ICON = 'icons/notification-icon-192-v2.png';
const BADGE = 'icons/notification-badge-96-v2.png';

const messaging = firebase.messaging();

// Pushes with a "notification" block are shown by the SDK (Apps Script sets
// the icon, badge and link). Data-only pushes are shown here.
messaging.onBackgroundMessage((payload) => {
  if (payload.notification) return;
  const data = payload.data || {};
  return self.registration.showNotification(data.title || 'PCU Connect', {
    body: data.body || '',
    icon: ICON,
    badge: BADGE,
    tag: data.tag || undefined,
    data: { link: data.link || './' },
  });
});

// Opens (or focuses) the app when a data-only notification is tapped.
self.addEventListener('notificationclick', (event) => {
  const link = (event.notification.data && event.notification.data.link) || './';
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      for (const client of list) {
        if ('focus' in client) return client.focus();
      }
      return self.clients.openWindow(link);
    }),
  );
});
