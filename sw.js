// Service Worker — network-first amb temps límit: sempre intenta la versió nova,
// però si la xarxa triga més de NET_TIMEOUT serveix la còpia guardada.
const CACHE_NAME = 'avui-regu-v126';
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

  // Les pàgines (index.html, regu.html…) les serveix GitHub Pages amb
  // max-age=600, així que el navegador les podia tornar de la seva pròpia
  // memòria durant 10 minuts i no véiem els canvis acabats de publicar.
  // Amb cache:'reload' saltem aquesta memòria i preguntem sempre al servidor.
  const isDoc = req.mode === 'navigate' || req.destination === 'document';

  e.respondWith(new Promise((resolve) => {
    let servit = false;
    const respon = (r) => { if (!servit && r) { servit = true; resolve(r); } };

    (isDoc ? fetch(req.url, { cache: 'reload', credentials: 'same-origin' }) : fetch(req))
      .then((res) => {
        // Guardar còpia en cache per offline
        if (res.ok) {
          const copia = res.clone();
          caches.open(CACHE_NAME).then((c) => c.put(req, copia));
        }
        respon(res);
      })
      .catch(() => {
        caches.match(req).then((c) => {
          if (c) respon(c);
          else if (!servit) { servit = true; resolve(Response.error()); }
        });
      });

    // Si la xarxa no contesta a temps servim la còpia guardada i deixem que la
    // descàrrega acabi en segon pla, així el proper cop ja serà la versió nova.
    // Sense això, a l'iPhone amb cobertura fluixa l'app es quedava en blanc
    // esperant la xarxa abans de pintar res.
    setTimeout(() => {
      if (servit) return;
      caches.match(req).then((c) => respon(c));
    }, NET_TIMEOUT);
  }));
});
