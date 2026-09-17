# Avui Regu? — Sitges (Club Nàutic Sitges)

## Què és
App web single-page per a regatistes del Club Nàutic Sitges. Mostra webcams, previsió meteo multi-model, corrents, radar de pluja, i molt més. Tot en un sol fitxer `index.html`.

## Idioma
L'app i les comunicacions són en **català**. Totes les etiquetes, traduccions i textos van en català.

## Arquitectura
- **Un sol fitxer**: `index.html` (~3200 línies) — HTML + CSS + JS tot inline
- **Versió**: `VERSION` (fitxer) i `<div class="subtitle">vX.XX</div>` dins index.html.
  Només aquests dos: el `CACHE_NAME` del `sw.js` ja **no** porta número (és
  `'avui-regu'`, estable), i la comprovació de versió nova llegeix el número
  del propi subtítol, no el té escrit.
- **No hi ha framework** — vanilla JS, sense build step
- **CDNs**: Leaflet (cdnjs.cloudflare.com), Google Fonts. Cap altre CDN extern per JS/CSS.

## Deploy (GitHub Pages)
1. Editar `index.html`
2. Incrementar versió a `VERSION` i al `<div class="subtitle">` dins index.html
3. `git add index.html VERSION && git commit -m "vX.XX: descripció" && git push origin master`
4. GitHub Pages desplega automàticament des de `master`
5. URL producció: https://tinyurl.com/avui-regu (→ https://xroigg737-design.github.io/webcams-cns/)

**GitHub Pages és l'únic lloc on es PUBLICA.** Les carpetes `avui-regu` i
`webcams-cns` del servidor AWS es van retirar el 15-set-2026 perquè quedaven
endarrerides i despistaven.

## Proves al mòbil (dev, 16-set-2026)
`./deploy-dev.sh` puja una còpia d'usar i llençar a
https://i-xr.duckdns.org/avui-regu-dev/index.html (amb usuari i contrasenya).
No és producció i no té versió pròpia. Desactiva el service worker i posa un
distintiu DEV amb l'hora de la pujada a la portada: si al mòbil no hi surt
l'hora que toca, estàs mirant una còpia vella guardada al telèfon.

## Regles de treball
- **SEMPRE** incrementar versió a cada deploy (format: 6.XX)
- **SEMPRE** fer git commit + push després de cada canvi
- **SEMPRE** acabar amb el missatge: `*** Xavi ja està, al ataque !!! ***`
- **NO** demanar feedback intermedi — executar directament
- **NO** crear fitxers nous si es pot editar l'existent

## Secció "Previ i Estacions Meteo" — Tabs
Els tabs de la secció meteo (~línia 1692):
- **Mapa Vent**: iframe Windy.com embed (vent animat amb partícules)
- **Comparar**: Widget Windy.app forecast amb selector de model (single-select, radio-button dots)
- **Models**: Mapa Leaflet + Open-Meteo API multi-model amb fletxes de vent. Selector dia/hora ergonòmic (pills dies + graella hores + play + botó ARA)
- **Windguru**: iframes Windguru
- **Pressió**: iframe Windy.com embed (mapa pressió/isòbares Atlàntic)

## Comparar tab — Detalls tècnics
- Widget Windy.app: `data-windywidget="forecast"`, `data-spotid="30007"`, `data-thememode="dark"`
- Cookie `forecast_widget_units`: índexs separats per comes `[temp,wind,height,time,pressure,model,tidedatum,precip]`
- **Compare mode és tot-o-res** — no es poden seleccionar models individualment en compare
- Model cookieId mappings: GFS27→gfs27_long, ECMWF→ecmwf, ICON13→iconeuro, ICON7→icon_d2, AROME→arome, EXP3→lew
- **NO fer servir MutationObserver** — causa loops infinits i pàgina penjada. Usar només timeouts (2s, 5s)
- **Etiquetes widget**: max ~6 chars. "m" i "s" per alçada/període (no hi caben textos llargs)
- Breeze Index = probabilitat marinada/tèrmic, NO ratxes

## Models tab — Detalls tècnics
- Mapa: Leaflet + tiles OpenStreetMap amb filtre CSS fosc (invert+hue-rotate). CartoDB ja no funciona sense API key.
- API: Open-Meteo multimodel (ECMWF, GFS, ICON, MétéoFr, AROME, GEM, JMA)
- Fletxes: direcció vent corregida +180° (API retorna d'on VE el vent, fletxa mostra cap on VA)
- Selector temps: pills de dies + graella 8 columnes d'hores + play/pausa + botó ARA

## Problemes resolts (no repetir)
- MutationObserver + widget Windy.app = loop infinit → Eliminat, usar timeouts
- `querySelectorAll('tr, div')` amb textContent check = molt lent → Usar selectors CSS específics
- `offsetWidth` dins observer = reflow storms a mòbil → No usar dins observers
- CartoDB tiles → API key required → Canviat a OSM + filtre CSS fosc
- Leaflet des d'unpkg.com → fallava → Canviat a cdnjs.cloudflare.com
- Fletxes vent invertides → +180° a la direcció
- **Esperar la xarxa abans de pintar** → l'app trigava 3,1s a obrir-se a
  l'iPhone, clavat al temps d'espera de 3.000 ms que li havíem posat: la xarxa
  no hi arribava mai a temps i acabava servint la còpia guardada igualment,
  havent perdut els 3 segons. Ara el service worker serveix la còpia a
  l'instant i refresca pel darrere.
- **Service worker sense `e.waitUntil()` a la petició de xarxa** → l'app es va
  quedar encallada a la v6.68 amb la v6.70 publicada. Quan es serveix la còpia
  guardada, iOS mata el service worker tot seguit i la descàrrega de la versió
  nova no acaba mai, així que la cache no s'actualitza **mai més**. Sempre
  `e.waitUntil(peticio)` a qualsevol descàrrega que hagi de sobreviure a la
  resposta.
- **Imatges massa pesades** → l'app trigava molt a mòbil (5,5 MB en imatges).
  El 15-set-2026 es van reoptimitzar: 5,3 MB → 1,55 MB. Regla: les miniatures
  dels widgets (`.ch-th`) es veuen a ~130 px, o sigui **440 px d'ample com a
  màxim**; les targetes (`.card-img`) fan 90 px d'alt, **620 px màxim**. Cap
  foto en PNG (`regu.png` pesava 1,5 MB; en JPEG fa 70 KB).
