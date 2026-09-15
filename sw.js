// Service Worker — "serveix el que tens, refresca pel darrere".
//
// Abans intentàvem la xarxa primer i només al cap de 3s servíem la còpia
// guardada: a l'iPhone la xarxa mai no hi arribava a temps, així que l'app
// esperava SEMPRE els 3 segons sencers per acabar servint la còpia igualment.
// Ara la còpia es dóna a l'instant i la versió nova es baixa en segon pla.
const CACHE_NAME = 'avui-regu';   // estable: no s'esborra a cada versió publicada

// Perquè la primera visita ja tingui les altres pantalles a punt.
const PREPARAR = ['./', 'index.html', 'regu.html', 'cockpit.html',
                  'manifest.json', 'favicon.ico'];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE_NAME).then((c) =>
      // Un a un: si un fitxer falla, els altres s'han de guardar igualment.
      Promise.all(PREPARAR.map((u) =>
        fetch(u, { cache: 'reload' })
          .then((r) => (r.ok ? c.put(u, r) : null))
          .catch(() => null)
      ))
    ).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((noms) =>
      // Neteja les caches velles amb número (avui-regu-v127 i companyia)
      Promise.all(noms.filter((n) => n !== CACHE_NAME).map((n) => caches.delete(n)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;

  // Les dades en directe (vent, tessel·les del radar, Windy…) no passen per
  // aquí: són d'altres dominis i no s'han de guardar mai.
  if (new URL(req.url).origin !== self.location.origin) return;

  const isDoc = req.mode === 'navigate' || req.destination === 'document';

  const xarxa = (isDoc ? fetch(req.url, { cache: 'reload', credentials: 'same-origin' })
                       : fetch(req))
    .then((res) => {
      if (res.ok) {
        const copia = res.clone();
        e.waitUntil(caches.open(CACHE_NAME).then((c) => c.put(req, copia)));
      }
      return res;
    });

  // ⚠️ IMPRESCINDIBLE: sense això iOS mata el service worker així que hem
  // contestat des de la cache, la descàrrega no acaba mai i l'app es queda
  // encallada per sempre en la versió guardada (ens va passar a la v6.68).
  e.waitUntil(xarxa.catch(() => {}));

  // El que tenim guardat, a l'instant. Si no en tenim, el que porti la xarxa.
  e.respondWith(
    caches.match(req).then((desat) => desat || xarxa)
  );
});
