#!/usr/bin/env bash
# Puja "Avui Regu?" a l'entorn de PROVES d'AWS, per mirar-s'ho al mòbil.
#
#   https://i-xr.duckdns.org/avui-regu-dev/index.html   (usuari + contrasenya)
#
# Producció segueix sent NOMÉS GitHub Pages. Això és una còpia de treball
# d'usar i llençar; no hi ha cap git ni cap versió associada.
#
# L'entorn de dev anterior es va retirar el 15-set-2026 perquè el que es veia
# al mòbil quedava endarrerit respecte del que s'acabava de pujar. La causa era
# el service worker: guardava l'app al telèfon i la tornava a servir tapant els
# canvis. Per això aquí el desactivem i, a sobre, la portada porta un distintiu
# DEV amb l'hora exacta de la pujada: si el que veus al mòbil no duu l'hora que
# toca, és que estàs mirant una còpia vella.
set -euo pipefail

ORIGEN=/home/xroig/webcams-cns
CLAU=~/AWS/claus/la-meva-clau-ubuntu.pem
REMOT=ubuntu@13.63.16.49:/var/www/html/avui-regu-dev/
PREP=$(mktemp -d)
trap 'rm -rf "$PREP"' EXIT

ARA=$(date '+%d-%b %H:%M')

rsync -a --exclude=.git --exclude=node_modules --exclude=sw.js \
      --exclude=package.json --exclude=package-lock.json \
      --exclude=setup.sh --exclude=deploy-dev.sh --exclude=CLAUDE.md \
      "$ORIGEN"/ "$PREP"/

python3 - "$PREP/index.html" "$ARA" <<'PY'
import io, re, sys
fitxer, ara = sys.argv[1], sys.argv[2]
s = io.open(fitxer, encoding='utf-8').read()

# 1) Fora el service worker. A més, esborrem el que ja hi hagi instal·lat en
#    aquest entorn, que si no el mòbil seguiria servint la còpia antiga.
#    Només toquem el nostre: a i-xr.duckdns.org hi viuen més aplicacions.
nou = """    <script>
    /* ENTORN DE PROVES — aquí no s'instal·la cap service worker, i esborrem
       el que hi pugui haver: el que es veu al mòbil ha de ser sempre l'última
       pujada, sense còpies guardades pel mig. */
    if ('serviceWorker' in navigator && navigator.serviceWorker.getRegistrations) {
        navigator.serviceWorker.getRegistrations().then(function(rs) {
            rs.forEach(function(r) {
                if (r.scope.indexOf('/avui-regu-dev/') !== -1) r.unregister();
            });
        });
    }
    if (window.caches) caches.delete('avui-regu');
    </script>"""
s, n = re.subn(r"    <script>\n    if \('serviceWorker' in navigator\).*?\n    </script>",
               nou, s, count=1, flags=re.S)
assert n == 1, 'no he trobat el bloc del service worker'

# 2) Distintiu DEV amb l'hora de la pujada, al costat de la versió.
s, n = re.subn(r'(<span id="tempsCarrega"></span>)',
               r'\1<span style="color:#ff9a76;font-weight:900;letter-spacing:2px;">'
               + ' &middot; DEV ' + ara + '</span>',
               s, count=1)
assert n == 1, 'no he trobat el subtítol'

# 3) Diagnostic. Va al capdamunt del <head>, abans que cap script de l'app:
#    si s'instal.la al final de la pagina es perd tot el que ha passat abans,
#    que es justament quan arrenquen les peticions. Cobreix errors de JS,
#    promeses no ateses i qualsevol peticio al backend, i a mes en fa una de
#    propia perque al mobil sapiguem sempre si el Worker respon o no.
diag = """<script>
/* NOMES A L'ENTORN DE PROVES — no existeix a produccio.
   Un fetch que es penja no llanca mai cap error, aixi que aqui tot porta
   rellotge: si en 8 s no hi ha resposta, ho diem igualment. */
(function(){
    var cua = [], barra = null, t0 = Date.now();
    function ms(){ return ((Date.now() - t0) / 1000).toFixed(1) + 's'; }
    function diu(txt, mena) {
        cua.push([ms() + '  ' + txt, mena]);
        buida();
    }
    function buida() {
        if (!document.body) return;
        if (!barra) {
            barra = document.createElement('div');
            barra.style.cssText = 'position:fixed;left:0;right:0;bottom:0;z-index:99999;' +
                'background:rgba(15,20,30,0.97);color:#fff;font:600 11px/1.5 ui-monospace,monospace;' +
                'padding:8px 10px;max-height:45vh;overflow:auto;white-space:pre-wrap;' +
                'border-top:2px solid #ff9a76;';
            barra.addEventListener('click', function(){ barra.style.display = 'none'; });
            document.body.appendChild(barra);
        }
        while (cua.length) {
            var f = cua.shift(), l = document.createElement('div');
            l.textContent = f[0];
            l.style.color = f[1] === 'ok' ? '#7dffb0' : f[1] === 'mal' ? '#ff8a80' : '#cfe3ff';
            barra.appendChild(l);
        }
        barra.scrollTop = barra.scrollHeight;
    }
    document.addEventListener('DOMContentLoaded', function(){
        diu('diagnostic actiu \u00b7 en linia=' + navigator.onLine);
        buida();
    });

    addEventListener('error', function(e){
        diu('ERROR: ' + (e.message || e.type) + ' @' +
            String(e.filename || '').split('/').pop() + ':' + e.lineno, 'mal');
    });
    addEventListener('unhandledrejection', function(e){
        diu('PROMESA: ' + ((e.reason && (e.reason.message || e.reason)) || '?'), 'mal');
    });

    var API = 'https://cns-wind-api.xroigg737.workers.dev';
    var fOrig = window.fetch.bind(window);
    var nApi = 0;

    /* Qualsevol peticio al backend queda cronometrada: si passa de 8 s sense
       contestar, es que esta penjada, i aixo ja es la resposta que buscavem. */
    window.fetch = function(u) {
        var url = (typeof u === 'string') ? u : (u && u.url) || '';
        if (url.indexOf('workers.dev') === -1) return fOrig.apply(null, arguments);
        var n = ++nApi, t = Date.now(), viu = true;
        var cua8 = setTimeout(function(){
            if (viu) diu('#' + n + ' PENJADA >8s: ' + url.replace(API, ''), 'mal');
        }, 8000);
        return fOrig.apply(null, arguments).then(function(r){
            viu = false; clearTimeout(cua8);
            diu('#' + n + ' HTTP ' + r.status + ' en ' + (Date.now()-t) + 'ms: ' +
                url.replace(API, ''), r.ok ? 'ok' : 'mal');
            return r;
        }, function(err){
            viu = false; clearTimeout(cua8);
            diu('#' + n + ' FALLA: ' + url.replace(API, '') + ' (' + err.message + ')', 'mal');
            throw err;
        });
    };

    /* Prova propia amb temps maxim, per si l'app no arribes a demanar res. */
    addEventListener('load', function(){
        diu('peticions al backend fins ara: ' + nApi);
        var ctl = window.AbortController ? new AbortController() : null;
        var t = Date.now();
        var fora = setTimeout(function(){ if (ctl) ctl.abort(); }, 8000);
        fOrig(API + '/', ctl ? { signal: ctl.signal, cache: 'no-store' } : { cache: 'no-store' })
            .then(function(r){ return r.text().then(function(txt){
                clearTimeout(fora);
                diu('PROVA: HTTP ' + r.status + ' en ' + (Date.now()-t) + 'ms \u2014 ' +
                    txt.slice(0, 80), r.ok ? 'ok' : 'mal');
            }); })
            .catch(function(e){
                clearTimeout(fora);
                diu('PROVA: SENSE RESPOSTA en ' + (Date.now()-t) + 'ms (' +
                    (e.name === 'AbortError' ? 'penjada, temps esgotat' : e.message) + ')', 'mal');
            });
    });
})();
</script>
"""
s, n = re.subn(r'(<head>\s*\n)', lambda m: m.group(1) + diag, s, count=1)
assert n == 1, 'no he trobat <head>'

io.open(fitxer, 'w', encoding='utf-8').write(s)
PY

rsync -avz --delete -e "ssh -i $CLAU" "$PREP"/ "$REMOT"

echo
echo "Pujat: https://i-xr.duckdns.org/avui-regu-dev/index.html   (DEV $ARA)"
