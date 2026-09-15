// Service Worker — network-first amb temps límit: sempre intenta la versió nova,
// però si la xarxa triga més de NET_TIMEOUT serveix la còpia guardada.
const CACHE_NAME = 'avui-regu-v127';
const NET_TIMEOUT = 3000;   // ms d'espera abans de servir la còpia guardada

// A cada versió nova l'activate esborra la cache anterior, així que la primera
// arrencada després de publicar es trobava la cache BUIDA i havia d'esperar la
// xarxa sencera. Amb això la nova versió ja ve carregada d'abans.
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
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;

  // Les dades en directe (vent, tessel·les del radar, Windy…) no passen pel
  // service worker: són d'altres dominis, no s'han de guardar mai i anaven
  // més lentes donant tota la volta per aquí.
  if (new URL(req.url).origin !== self.location.origin) return;

  // Les pàgines (index.html, regu.html…) les serveix GitHub Pages amb
  // max-age=600, així que el navegador les podia tornar de la seva pròpia
  // memòria durant 10 minuts i no véiem els canvis acabats de publicar.
  // Amb cache:'reload' saltem aquesta memòria i preguntem sempre al servidor.
  const isDoc = req.mode === 'navigate' || req.destination === 'document';

  const xarxa = (isDoc ? fetch(req.url, { cache: 'reload', credentials: 'same-origin' }) : fetch(req))
    .then((res) => {
      if (res.ok) {
        const copia = res.clone();
        e.waitUntil(caches.open(CACHE_NAME).then((c) => c.put(req, copia)));
      }
      return res;
    });

  // ⚠️ IMPRESCINDIBLE: sense aquest waitUntil, quan servíem la còpia guardada
  // iOS matava el service worker tot seguit i la descàrrega de la versió nova
  // no arribava a acabar mai. Resultat: l'app es quedava encallada per sempre
  // en la versió que hi hagués guardada.
  e.waitUntil(xarxa.catch(() => {}));

  e.respondWith(new Promise((resolve) => {
    let servit = false;
    const respon = (r) => { if (!servit && r) { servit = true; resolve(r); } };

    xarxa.then(respon).catch(() => {
      caches.match(req).then((c) => {
        if (c) respon(c);
        else if (!servit) { servit = true; resolve(Response.error()); }
      });
    });

    // Si la xarxa no contesta a temps servim la còpia guardada i deixem que la
    // descàrrega acabi en segon pla (viva gràcies al waitUntil de sobre).
    setTimeout(() => {
      if (servit) return;
      caches.match(req).then((c) => respon(c));
    }, NET_TIMEOUT);
  }));
});
