# Avui Regu? — Sitges (Club Nàutic Sitges)

## Què és
App web single-page per a regatistes del Club Nàutic Sitges. Mostra webcams, previsió meteo multi-model, corrents, radar de pluja, i molt més. Tot en un sol fitxer `index.html`.

## Idioma
L'app i les comunicacions són en **català**. Totes les etiquetes, traduccions i textos van en català.

## Arquitectura
- **Un sol fitxer**: `index.html` (~3200 línies) — HTML + CSS + JS tot inline
- **Versió**: controlada per `VERSION` (fitxer) i `<div class="subtitle">vX.XX</div>` dins index.html (~línia 1225)
- **No hi ha framework** — vanilla JS, sense build step
- **CDNs**: Leaflet (cdnjs.cloudflare.com), Google Fonts. Cap altre CDN extern per JS/CSS.

## Deploy (GitHub Pages)
1. Editar `index.html`
2. Incrementar versió a `VERSION` i al `<div class="subtitle">` dins index.html
3. `git add index.html VERSION && git commit -m "vX.XX: descripció" && git push origin master`
4. GitHub Pages desplega automàticament des de `master`
5. URL producció: https://tinyurl.com/avui-regu (→ https://xroigg737-design.github.io/webcams-cns/)

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
