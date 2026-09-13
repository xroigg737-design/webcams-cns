// Service Worker — network-first: sempre intenta descarregar la versió nova
const CACHE_NAME = 'avui-regu-v111';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;

  // Les pàgines (index.html, regu.html…) les serveix GitHub Pages amb
  // max-age=600, així que el navegador les podia tornar de la seva pròpia
  // memòria durant 10 minuts i no véiem els canvis acabats de publicar.
  // Amb cache:'reload' saltem aquesta memòria i preguntem sempre al servidor.
  const isDoc = req.mode === 'navigate' || req.destination === 'document';

  e.respondWith(
    (isDoc ? fetch(req.url, { cache: 'reload', credentials: 'same-origin' }) : fetch(req))
      .then(res => {
        // Guardar còpia en cache per offline
        if (res.ok) {
          const clone = res.clone();
          caches.open(CACHE_NAME).then(c => c.put(req, clone));
        }
        return res;
      })
      .catch(() => caches.match(req))  // Fallback a cache si offline
  );
});
