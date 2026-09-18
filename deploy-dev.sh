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

io.open(fitxer, 'w', encoding='utf-8').write(s)
PY

rsync -avz --delete -e "ssh -i $CLAU" "$PREP"/ "$REMOT"

echo
echo "Pujat: https://i-xr.duckdns.org/avui-regu-dev/index.html   (DEV $ARA)"
